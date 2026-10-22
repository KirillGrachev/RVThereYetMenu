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
    local ok, gameInstance = Guard.Try("FindGameInstance", function()
        return FindFirstOf(Refs.ShortClasses.GameInstance)
    end)
    if ok and Guard.IsValid(gameInstance) then return gameInstance end
    return nil, "GameInstance not found"
end

--- Локальный PlayerController. Сначала через GameInstance.LocalPlayers —
--- в кооп-сессии FindFirstOf("PlayerController") может вернуть чужого.
function Engine.PlayerController()
    local gameInstance = Engine.GameInstance()
    if gameInstance then
        local found, playerController = Guard.Try("LocalPlayers[1].PlayerController", function()
            local localPlayers = gameInstance.LocalPlayers
            if localPlayers and localPlayers.GetArrayNum and localPlayers:GetArrayNum() > 0 then
                local playerEntry = localPlayers[1]
                if playerEntry then
                    local localPlayer = playerEntry.get and playerEntry:get() or playerEntry
                    return localPlayer.PlayerController
                end
            end
            return nil
        end)
        if found and Guard.IsValid(playerController) then return playerController end
    end
    local foundBySearch, searchedController = Guard.Try("FindPlayerController", function()
        return FindFirstOf(Refs.ShortClasses.PlayerController)
    end)
    if foundBySearch and Guard.IsValid(searchedController) then return searchedController end
    return nil, "PlayerController not found"
end

function Engine.Pawn()
    local playerController = Engine.PlayerController()
    if not playerController then return nil, "PlayerController not found" end
    local ok, pawn = Guard.Get(playerController, "Pawn")
    if ok and Guard.IsValid(pawn) then return pawn end
    return nil, "Pawn not found"
end

function Engine.World()
    local playerController = Engine.PlayerController()
    if playerController then
        local ok, world = Guard.Try("PlayerController:GetWorld()", function() return playerController:GetWorld() end)
        if ok and Guard.IsValid(world) then return world end
    end
    return nil, "World not found"
end

--- GameState — через UGameplayStatics (штатный движковый путь).
function Engine.GameState()
    local world = Engine.World()
    if not world then return nil, "World not found" end
    local ok, gameState = Guard.Try("GetGameState", function()
        return UE.UGameplayStatics.GetGameState(world)
    end)
    if ok and Guard.IsValid(gameState) then return gameState end
    return nil, "GameState not found"
end

--- GameSession: сначала свойство GameInstance/GameState (точнее),
--- потом FindFirstOf (фронтенд может держать сессию без GameState).
function Engine.GameSession()
    local gameInstance = Engine.GameInstance()
    if gameInstance then
        local found, session = Guard.Get(gameInstance, "GameSession")
        if found and Guard.IsValid(session) then return session end
    end
    local gameState = Engine.GameState()
    if gameState then
        local foundInState, stateSession = Guard.Get(gameState, "GameSession")
        if foundInState and Guard.IsValid(stateSession) then return stateSession end
    end
    local foundBySearch, searchedSession = Guard.Try("FindGameSession", function()
        return FindFirstOf(Refs.ShortClasses.GameSession)
    end)
    if foundBySearch and Guard.IsValid(searchedSession) then return searchedSession end
    return nil, "GameSession not found (host a session first)"
end

--- CheatManager живёт на PlayerController и существует только при
--- включённом CheatManagerEnablerMod (идёт в составе нашего UE4SS-набора).
function Engine.CheatManager()
    local playerController = Engine.PlayerController()
    if not playerController then return nil, "PlayerController not found" end
    local ok, cheatManager = Guard.Get(playerController, "CheatManager")
    if ok and Guard.IsValid(cheatManager) then return cheatManager end
    return nil, "CheatManager not found (is CheatManagerEnablerMod enabled?)"
end

--- PlayerSave — сейв локального игрока (BP_SaveGamePlayer).
--- Основной источник для анлоков: косметика/кассеты/чекпоинты живут в нём.
function Engine.PlayerSave()
    local gameInstance = Engine.GameInstance()
    if not gameInstance then return nil, "GameInstance not found" end
    local found, save = Guard.Try("GameInstance:GetPlayerSave()", function()
        return gameInstance:GetPlayerSave()
    end)
    if found and Guard.IsValid(save) then return save end
    -- Фолбэк: экземпляр класса сейва может существовать до инициализации GameInstance
    local foundBySearch, saveFromSearch = Guard.Try("FindPlayerSave", function()
        return FindFirstOf(Refs.ShortClasses.PlayerSave)
    end)
    if foundBySearch and Guard.IsValid(saveFromSearch) then return saveFromSearch end
    return nil, "PlayerSave not found (load a game first)"
end

function Engine.PlayerState()
    local playerController = Engine.PlayerController()
    if not playerController then return nil, "PlayerController not found" end
    local ok, playerState = Guard.Get(playerController, "PlayerState")
    if ok and Guard.IsValid(playerState) then return playerState end
    return nil, "PlayerState not found"
end

--- Список PlayerState всех игроков сессии (для вкладки Players).
function Engine.AllPlayerStates()
    local gameState = Engine.GameState()
    if not gameState then return nil, "GameState not found" end
    local found, result = Guard.Try("PlayerArray", function()
        local playerStates = {}
        local playerArray = gameState.PlayerArray
        if not playerArray then return playerStates end
        local playerCount = playerArray.GetArrayNum and playerArray:GetArrayNum() or 0
        for index = 1, playerCount do
            local arrayEntry = playerArray[index]
            local playerState = arrayEntry and (arrayEntry.get and arrayEntry:get() or arrayEntry) or nil
            if Guard.IsValid(playerState) then playerStates[#playerStates + 1] = playerState end
        end
        return playerStates
    end)
    if found then return result end
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
        local classObject = StaticFindObject(classPath)
        if classObject == nil then return nil end
        if classObject.GetDefaultObject then return classObject:GetDefaultObject() end
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
    local gameMode = nil
    local world = Engine.World()
    if world then
        local found = Guard.Try("GetGameMode", function()
            gameMode = UE.UGameplayStatics.GetGameMode(world)
        end)
        if not found then gameMode = nil end
    end
    if Guard.IsValid(gameMode) then return true end
    return false
end

Log.Debug("engine module loaded")

return Engine
