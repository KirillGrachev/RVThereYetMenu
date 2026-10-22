--- Анлоки: косметика, кассеты, сохранение прогресса.
---
--- Механика игры (подтверждено дампами BP_SaveGamePlayer/BP_CheatManager/
--- BPFL_SaveStatics):
---  - разблокированная косметика хранится в сейве игрока (массив
---    FUnlockedCosmetic { Cosmetic: SoftObject, Type }), выдача — через
---    CheatGiveCosmeticsWithoutUnlockingAchievement (есть и у сейва, и у
---    чит-менеджера; у чит-менеджера дополнительно есть уровневые
---    варианты Mabutts/Snow);
---  - кассеты — AddAllTapes у чит-менеджера, в сейве хранятся
---    *LevelTapes-массивы и OnTapePlayed;
---  - персистентность — AsyncSaveGameToSlotForLocalPlayer (есть и у
---    RideGameInstance, и у BP_SaveGamePlayer; зовём оба под pcall —
---    какой сработает, зависит от версии игры).
--- Все вызовы идемпотентны: повторная выдача уже unlocked не ломает сейв.
local Guard = require("core.guard")
local Log = require("core.log")
local Refs = require("core.refs")
local State = require("core.state")
local Engine = require("core.engine")
local Cheats = require("hooks.cheats")

local Unlocks = {}

--- Сохранить прогресс локального игрока в слот.
function Unlocks.SavePlayerGame()
    local saved = false
    local gameInstance = Engine.GameInstance()
    if gameInstance then
        local gameInstanceOk = Guard.Call(gameInstance, "AsyncSaveGameToSlotForLocalPlayer")
        saved = saved or gameInstanceOk
    end
    local save = Engine.PlayerSave()
    if save then
        local saveGameOk = Guard.Call(save, "AsyncSaveGameToSlotForLocalPlayer")
        saved = saved or saveGameOk
    end
    if saved then
        Log.Info("player game save requested (async)")
    else
        Log.Warn("no save path available (neither GameInstance nor PlayerSave responded)")
    end
    return saved
end

--- Выдать всю косметику: сначала через чит-менеджер (там есть уровневые
--- варианты), затем дублируем базовую функцию на самом сейве, и в конце —
--- сохранение. Возвращает ok, отчёт-строку для статус-бара.
function Unlocks.AllCosmetics()
    local reportLines = {}

    local cheatResults = Cheats.CallAll({
        "CheatGiveCosmeticsWithoutUnlockingAchievement",
        "GiveAllCosmeticsForMabuttsWithoutUnlockingAchievement",
        "GiveAllCosmeticsForSnowLevelWithoutUnlockingAchievement",
    })
    for name, callResult in pairs(cheatResults) do
        reportLines[#reportLines + 1] = name .. "=" .. tostring(callResult[1])
    end

    local save = Engine.PlayerSave()
    if save then
        local saveCallOk = Guard.Call(save, "CheatGiveCosmeticsWithoutUnlockingAchievement")
        reportLines[#reportLines + 1] = "PlayerSave.CheatGive=" .. tostring(saveCallOk)
    else
        reportLines[#reportLines + 1] = "PlayerSave=unavailable"
    end

    local saved = Unlocks.SavePlayerGame()
    reportLines[#reportLines + 1] = "Saved=" .. tostring(saved)

    local anySucceeded = false
    for _, callResult in pairs(cheatResults) do anySucceeded = anySucceeded or callResult[1] == true end
    if save then anySucceeded = true end
    State.Count("Unlocks.Cosmetics", anySucceeded)
    return anySucceeded, table.concat(reportLines, ", ")
end

--- Выдать все кассеты (AddAllTapes; DEBUG_-вариант как страховка).
function Unlocks.AllTapes()
    local tapeResults = Cheats.CallAll({ "AddAllTapes", "DEBUG_AddAllTapes" })
    local succeeded = (tapeResults.AddAllTapes and tapeResults.AddAllTapes[1])
        or (tapeResults.DEBUG_AddAllTapes and tapeResults.DEBUG_AddAllTapes[1])
    if succeeded then Unlocks.SavePlayerGame() end
    State.Count("Unlocks.Tapes", succeeded == true)
    return succeeded == true
end

--- Зафиксировать текущий чекпоинт в сейве (Cheat_SaveCheckpointProgression
--- есть и у чит-менеджера, и у сейва — пробуем оба).
function Unlocks.SaveCheckpointProgression()
    local viaCheatManager = Cheats.Call("Cheat_SaveCheckpointProgression")
    local viaSaveGame = false
    local save = Engine.PlayerSave()
    if save then
        viaSaveGame = Guard.Call(save, "Cheat_SaveCheckpointProgression")
    end
    local succeeded = viaCheatManager or viaSaveGame
    if succeeded then Unlocks.SavePlayerGame() end
    return succeeded
end

--- Сколько косметики разблокировано в сейве (для статуса вкладки).
function Unlocks.UnlockedCosmeticsCount()
    local save = Engine.PlayerSave()
    if not save then return nil end
    local ok, cosmetics = Guard.Try("GetUnlockedCosmetics", function()
        return save:GetUnlockedCosmetics()
    end)
    if not ok or cosmetics == nil then return nil end
    local countOk, count = pcall(function()
        if type(cosmetics) == "table" and cosmetics.GetArrayNum then return cosmetics:GetArrayNum() end
        if type(cosmetics) == "table" then return #cosmetics end
        return nil
    end)
    if countOk and type(count) == "number" then return count end
    return nil
end

--- Сколько кассет собрано (сумма длин *LevelTapes-массивов сейва).
function Unlocks.CollectedTapesCount()
    local save = Engine.PlayerSave()
    if not save then return nil end
    --- Массивы сейва с собранными кассетами (подтверждён пока Jungle-уровень;
    --- остальные добавятся по мере подтверждения дампами).
    local tapeArrayProperties = { "JungleLevelTapes" }
    local total = 0
    local anyArrayRead = false
    for _, tapeArrayProperty in ipairs(tapeArrayProperties) do
        local ok, tapeArray = Guard.Get(save, tapeArrayProperty)
        if ok and tapeArray then
            local countOk, count = pcall(function()
                if tapeArray.GetArrayNum then return tapeArray:GetArrayNum() end
                if type(tapeArray) == "table" then return #tapeArray end
                return nil
            end)
            if countOk and type(count) == "number" then
                total = total + count
                anyArrayRead = true
            end
        end
    end
    if anyArrayRead then return total end
    return nil
end

Log.Debug("unlocks module loaded; tags: " .. table.concat(Refs.CosmeticTags, ","))

return Unlocks
