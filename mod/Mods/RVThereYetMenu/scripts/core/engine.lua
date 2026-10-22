--- Engine — доступ к ключевым объектам игры. Все точки входа собираются
--- здесь, чтобы хуки и меню не искали объекты каждый по-своему
--- (в RiskOfRainMenu эту роль играл GameApi).
---
--- Стратегия поиска (по убыванию надёжности):
---  1. FindFirstOf по короткому имени базового класса — находит и
---     BP-наследников (RideGameInstance наследует GameInstance и т.д.);
---  2. свойства найденных объектов (GameInstance.GameSession и пр.);
---  3. StaticFindObject по полному пути — для CDO/классов.
--- Всё через Guard: nil вместо исключения, причина — вторым значением.
local Guard = require("core.guard")
local Log = require("core.log")
local Refs = require("core.refs")

local Engine = {}

--- GameInstance (RideGameInstance — Blueprint-наследник UGameInstance).
function Engine.GameInstance()
    local ok, gi = Guard.Try("FindGameInstance", function()
        return FindFirstOf(Refs.ShortClasses.GameInstance)
    end)
    if ok and Guard.IsValid(gi) then return gi end
    return nil, "GameInstance not found"
end

--- Локальный PlayerController. Сначала через GameInstance.LocalPlayers —
--- в кооп-сессии FindFirstOf("PlayerController") может вернуть чужого.
function Engine.PlayerController()
    local gi = Engine.GameInstance()
    if gi then
        local ok, pc = Guard.Try("LocalPlayers[1].PlayerController", function()
            local players = gi.LocalPlayers
            if players and players.GetArrayNum and players:GetArrayNum() > 0 then
                local localPlayer = players[1]
                if localPlayer then
                    local lp = localPlayer.get and localPlayer:get() or localPlayer
                    return lp.PlayerController
                end
            end
            return nil
        end)
        if ok and Guard.IsValid(pc) then return pc end
    end
    local ok2, pc2 = Guard.Try("FindPlayerController", function()
        return FindFirstOf(Refs.ShortClasses.PlayerController)
    end)
    if ok2 and Guard.IsValid(pc2) then return pc2 end
    return nil, "PlayerController not found"
end

function Engine.Pawn()
    local pc = Engine.PlayerController()
    if not pc then return nil, "PlayerController not found" end
    local ok, pawn = Guard.Get(pc, "Pawn")
    if ok and Guard.IsValid(pawn) then return pawn end
    return nil, "Pawn not found"
end

function Engine.World()
    local pc = Engine.PlayerController()
    if pc then
        local ok, world = Guard.Try("pc:GetWorld()", function() return pc:GetWorld() end)
        if ok and Guard.IsValid(world) then return world end
    end
    return nil, "World not found"
end

--- GameState — через UGameplayStatics (штатный движковый путь).
function Engine.GameState()
    local world = Engine.World()
    if not world then return nil, "World not found" end
    local ok, gs = Guard.Try("GetGameState", function()
        return UE.UGameplayStatics.GetGameState(world)
    end)
    if ok and Guard.IsValid(gs) then return gs end
    return nil, "GameState not found"
end

--- GameSession: сначала свойство GameInstance/GameState (точнее),
--- потом FindFirstOf (фронтенд может держать сессию без GameState).
function Engine.GameSession()
    local gi = Engine.GameInstance()
    if gi then
        local ok, session = Guard.Get(gi, "GameSession")
        if ok and Guard.IsValid(session) then return session end
    end
    local gs = Engine.GameState()
    if gs then
        local ok2, session2 = Guard.Get(gs, "GameSession")
        if ok2 and Guard.IsValid(session2) then return session2 end
    end
    local ok3, session3 = Guard.Try("FindGameSession", function()
        return FindFirstOf(Refs.ShortClasses.GameSession)
    end)
    if ok3 and Guard.IsValid(session3) then return session3 end
    return nil, "GameSession not found (host a session first)"
end

--- CheatManager живёт на PlayerController и существует только при
--- включённом CheatManagerEnablerMod (идёт в составе нашего UE4SS-набора).
function Engine.CheatManager()
    local pc = Engine.PlayerController()
    if not pc then return nil, "PlayerController not found" end
    local ok, cm = Guard.Get(pc, "CheatManager")
    if ok and Guard.IsValid(cm) then return cm end
    return nil, "CheatManager not found (is CheatManagerEnablerMod enabled?)"
end

--- PlayerSave — сейв локального игрока (BP_SaveGamePlayer).
--- Основной источник для анлоков: косметика/кассеты/чекпоинты живут в нём.
function Engine.PlayerSave()
    local gi = Engine.GameInstance()
    if not gi then return nil, "GameInstance not found" end
    local ok, save = Guard.Try("gi:GetPlayerSave()", function()
        return gi:GetPlayerSave()
    end)
    if ok and Guard.IsValid(save) then return save end
    -- Фолбэк: экземпляр класса сейва может существовать до инициализации GI
    local ok2, save2 = Guard.Try("FindPlayerSave", function()
        return FindFirstOf(Refs.ShortClasses.PlayerSave)
    end)
    if ok2 and Guard.IsValid(save2) then return save2 end
    return nil, "PlayerSave not found (load a game first)"
end

function Engine.PlayerState()
    local pc = Engine.PlayerController()
    if not pc then return nil, "PlayerController not found" end
    local ok, ps = Guard.Get(pc, "PlayerState")
    if ok and Guard.IsValid(ps) then return ps end
    return nil, "PlayerState not found"
end

--- Список PlayerState всех игроков сессии (для вкладки Players).
function Engine.AllPlayerStates()
    local gs = Engine.GameState()
    if not gs then return nil, "GameState not found" end
    local ok, result = Guard.Try("PlayerArray", function()
        local out = {}
        local arr = gs.PlayerArray
        if not arr then return out end
        local n = arr.GetArrayNum and arr:GetArrayNum() or 0
        for i = 1, n do
            local elem = arr[i]
            local ps = elem and (elem.get and elem:get() or elem) or nil
            if Guard.IsValid(ps) then out[#out + 1] = ps end
        end
        return out
    end)
    if ok then return result end
    return nil, "PlayerArray unavailable"
end

--- Все экземпляры класса (чекпоинты, транспорт, косметика-пикапы).
function Engine.FindAll(shortClass)
    local ok, list = Guard.Try("FindAllOf(" .. shortClass .. ")", function()
        return FindAllOf(shortClass)
    end)
    if ok and type(list) == "table" then return list end
    return {}
end

--- CDO класса по полному пути (для пред-патча дефолтов, приём MoreRVers).
function Engine.CDO(classPath)
    local ok, result = Guard.Try("CDO(" .. classPath .. ")", function()
        local cls = StaticFindObject(classPath)
        if cls == nil then return nil end
        if cls.GetDefaultObject then return cls:GetDefaultObject() end
        return nil
    end)
    if ok then return result end
    return nil
end

--- Имя текущего уровня (для статуса и защиты waypoint-ов от смены карты,
--- как в RiskOfRainMenu: слот помнит уровень и отказывается применяться
--- на другом).
function Engine.LevelName()
    local world = Engine.World()
    if not world then return nil end
    local ok, name = Guard.Try("WorldName", function()
        if world.GetName then return world:GetName() end
        return nil
    end)
    if ok and name then return tostring(name) end
    return nil
end

--- Является ли локальный игрок хостом сессии. В Listen-серверной модели
--- UE «хост» = там, где живёт GameSession/GameMode.
function Engine.IsHost()
    local gm = nil
    local world = Engine.World()
    if world then
        local ok = Guard.Try("GetGameMode", function()
            gm = UE.UGameplayStatics.GetGameMode(world)
        end)
        if not ok then gm = nil end
    end
    if Guard.IsValid(gm) then return true end
    return false
end

Log.Debug("engine module loaded")

return Engine
