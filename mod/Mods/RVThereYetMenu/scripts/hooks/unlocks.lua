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
    local gi = Engine.GameInstance()
    if gi then
        local ok = Guard.Call(gi, "AsyncSaveGameToSlotForLocalPlayer")
        saved = saved or ok
    end
    local save = Engine.PlayerSave()
    if save then
        local ok2 = Guard.Call(save, "AsyncSaveGameToSlotForLocalPlayer")
        saved = saved or ok2
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
    local report = {}

    local viaCheat = Cheats.CallAll({
        "CheatGiveCosmeticsWithoutUnlockingAchievement",
        "GiveAllCosmeticsForMabuttsWithoutUnlockingAchievement",
        "GiveAllCosmeticsForSnowLevelWithoutUnlockingAchievement",
    })
    for name, res in pairs(viaCheat) do
        report[#report + 1] = name .. "=" .. tostring(res[1])
    end

    local save = Engine.PlayerSave()
    if save then
        local ok = Guard.Call(save, "CheatGiveCosmeticsWithoutUnlockingAchievement")
        report[#report + 1] = "PlayerSave.CheatGive=" .. tostring(ok)
    else
        report[#report + 1] = "PlayerSave=unavailable"
    end

    local saved = Unlocks.SavePlayerGame()
    report[#report + 1] = "Saved=" .. tostring(saved)

    local anyOk = false
    for _, res in pairs(viaCheat) do anyOk = anyOk or res[1] == true end
    if save then anyOk = true end
    State.Count("Unlocks.Cosmetics", anyOk)
    return anyOk, table.concat(report, ", ")
end

--- Выдать все кассеты (AddAllTapes; DEBUG_-вариант как страховка).
function Unlocks.AllTapes()
    local results = Cheats.CallAll({ "AddAllTapes", "DEBUG_AddAllTapes" })
    local ok = (results.AddAllTapes and results.AddAllTapes[1])
        or (results.DEBUG_AddAllTapes and results.DEBUG_AddAllTapes[1])
    if ok then Unlocks.SavePlayerGame() end
    State.Count("Unlocks.Tapes", ok == true)
    return ok == true
end

--- Зафиксировать текущий чекпоинт в сейве (Cheat_SaveCheckpointProgression
--- есть и у чит-менеджера, и у сейва — пробуем оба).
function Unlocks.SaveCheckpointProgression()
    local okCheat = Cheats.Call("Cheat_SaveCheckpointProgression")
    local okSave = false
    local save = Engine.PlayerSave()
    if save then
        okSave = Guard.Call(save, "Cheat_SaveCheckpointProgression")
    end
    local ok = okCheat or okSave
    if ok then Unlocks.SavePlayerGame() end
    return ok
end

--- Сколько косметики разблокировано в сейве (для статуса вкладки).
function Unlocks.UnlockedCosmeticsCount()
    local save = Engine.PlayerSave()
    if not save then return nil end
    local ok, list = Guard.Try("GetUnlockedCosmetics", function()
        return save:GetUnlockedCosmetics()
    end)
    if not ok or list == nil then return nil end
    local okNum, n = pcall(function()
        if type(list) == "table" and list.GetArrayNum then return list:GetArrayNum() end
        if type(list) == "table" then return #list end
        return nil
    end)
    if okNum and type(n) == "number" then return n end
    return nil
end

--- Сколько кассет собрано (сумма длин *LevelTapes-массивов сейва).
function Unlocks.CollectedTapesCount()
    local save = Engine.PlayerSave()
    if not save then return nil end
    local total = 0
    local found = false
    for _, prop in ipairs({ "JungleLevelTapes" }) do
        local ok, arr = Guard.Get(save, prop)
        if ok and arr then
            local okNum, n = pcall(function()
                if arr.GetArrayNum then return arr:GetArrayNum() end
                if type(arr) == "table" then return #arr end
                return nil
            end)
            if okNum and type(n) == "number" then
                total = total + n
                found = true
            end
        end
    end
    if found then return total end
    return nil
end

Log.Debug("unlocks module loaded; tags: " .. table.concat(Refs.CosmeticTags, ","))

return Unlocks
