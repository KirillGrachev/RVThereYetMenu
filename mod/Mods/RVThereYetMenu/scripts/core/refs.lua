--- GameRefs — единственный источник всех reflection-строк мода
--- (аналог GameRefs из RiskOfRainMenu, который тесты сверяли с игровой
--- сборкой). Здесь только ДАННЫЕ: пути классов, UFunction-сигнатуры,
--- имена ассетов, имена свойств и функций.
---
--- Каждый путь проверен офлайн-дампом name-batch (tools/AssetDump) по
--- контейнерам игры от 2026-09. tests/NameCheck валидирует файл целиком:
--- новое имя добавляется сюда, а не размазывается по коду.
---
--- Происхождение имён (дампы в /root/work/rvty-game/dumps):
---  - BP_SaveGamePlayer: GetUnlockedCosmetics, DefaultUnlockedCosmetics,
---    CheatGiveCosmeticsWithoutUnlockingAchievement,
---    GiveAllCosmeticsForMabuttsWithoutUnlockingAchievement (имя из
---    BP_CheatManager; у сейва подтверждены Jungle-вариант и Cheat_*),
---    AsyncSaveGameToSlotForLocalPlayer, CheckpointIndex, BannedPlayers
---  - BP_CheatManager: AddAllTapes, RepairDamage, RepairEngineDamage,
---    RepairFrameDamage, RepairWheelDamage, DriveWinnebago,
---    DriveClosestJetski, GrabWinch, GrabRearWinch, ResetAndGrabWinch,
---    ResetAndGrabRearWinch, AddIceStudsToAllWheels, GiveEpiPens,
---    RemoveInactivePlayers, Cheat_SaveCheckpointProgression,
---    GetSpawnPointInFrontOfPlayer, Golf_MoveBallToAimLocation
---  - RideGameInstance: GetPlayerSave, GetLocalPlayerController,
---    GetCurrentCheckpointIndex, OnCheckpointReached, GameSession
local Refs = {}

--- Движковые классы (валидируются по UE4SS ObjectDump, когда он появится;
--- офлайн-дампы игру их не содержат — движок в exe).
Refs.EngineClasses = {
    GameSession = "/Script/Engine.GameSession",
    PlayerController = "/Script/Engine.PlayerController",
    GameState = "/Script/Engine.GameStateBase",
    CheatManager = "/Script/Engine.CheatManager",
}

--- UFunction-сигнатуры для RegisterHook/NotifyOnNewObject.
Refs.Hooks = {
    -- Пересоздание сессии при каждом заходе в уровень/меню — основная
    -- точка применения капа слотов (проверено MoreRVers на этой игре).
    GameSessionCreated = "/Script/Engine.GameSession",
    GameSessionBeginPlay = "/Script/Engine.GameSession:ReceiveBeginPlay",
    -- Кандидаты на join-gate (как у MoreRVers: движок/игра могут
    -- реализовывать валидацию в любом из этих мест).
    CanPlayerJoin = {
        "/Script/Engine.GameSession:CanPlayerJoin",
        "/Script/Engine.GameModeBase:CanPlayerJoin",
        "/Script/Engine.GameSession:ApproveLogin",
    },
}

--- Игровые ассеты (полные пути пакетов; проверены по assets.txt —
--- все существуют в Ride-Windows.utoc от 2026-09).
Refs.Assets = {
    PlayerSave = "/Game/Ride/Game/BP_SaveGamePlayer",
    PlayerSaveBase = "/Game/Ride/Game/BP_SaveGamePlayerBase",
    SessionSave = "/Game/Ride/Game/BP_SessionSaveGame",
    SaveStatics = "/Game/Ride/Game/BPFL_SaveStatics",
    ActorLibrary = "/Game/Ride/Game/BPFL_ActorLibrary",
    GameInstance = "/Game/Ride/Game/RideGameInstance",
    GameState = "/Game/Ride/Game/RideGameState",
    CheatManager = "/Game/Ride/Cheats/BP_CheatManager",
    GameMode = "/Game/Ride/Character/Blueprints/GM_FirstPerson",
    PlayerCharacter = "/Game/Ride/Character/Blueprints/BP_FirstPersonCharacter",
    PlayerController = "/Game/Ride/Character/Blueprints/BP_FirstPersonPlayerController",
    PlayerState = "/Game/Ride/Character/Blueprints/BP_PlayerState",
    Checkpoint = "/Game/Ride/Game/BP_CheckPoint",
    VehicleBase = "/Game/Ride/Vehicle/Blueprints/BP_VehicleBase",
    Winnebago = "/Game/Ride/Vehicle/Blueprints/BP_Vehicle_Winnebago_01",
    CosmeticPickup = "/Game/Ride/Character/Customization/BP_CosmeticPickup",
    MenuStatics = "/Game/Ride/Menu/BPFL_Menu",
    OnlineStatics = "/Game/Ride/Menu/BPFL_Online",
}

--- Короткие имена классов для FindFirstOf/FindAllOf (UE4SS ищет по
--- IsChildOf, поэтому базовое имя находит и BP-наследников).
Refs.ShortClasses = {
    GameInstance = "GameInstance",
    GameSession = "GameSession",
    PlayerController = "PlayerController",
    PlayerState = "PlayerState",
    CheatManager = "CheatManager",
    Checkpoint = "BP_CheckPoint_C",
    VehicleBase = "BP_VehicleBase_C",
    PlayerCharacter = "BP_FirstPersonCharacter_C",
    PlayerSave = "BP_SaveGamePlayer_C",
    CosmeticPickup = "BP_CosmeticPickup_C",
}

--- Имена свойств/функций, вызываемых на найденных объектах.
--- Сгруппированы по владельцу — так валидатор сверяет имя с дампом
--- конкретного пакета, а не «со всем сразу».
Refs.Members = {
    GameSession = {
        "MaxPlayers",
    },
    RideGameInstance = {
        "GetPlayerSave",
        "GetLocalPlayerController",
        "GetCurrentCheckpointIndex",
        "AsyncSaveGameToSlotForLocalPlayer",
        "CreateOrLoadPlayerSaveGame",
        "GetCheckpoint",
        "GameSession",
    },
    BP_SaveGamePlayer = {
        "GetUnlockedCosmetics",
        "DefaultUnlockedCosmetics",
        "CheatGiveCosmeticsWithoutUnlockingAchievement",
        "AsyncSaveGameToSlotForLocalPlayer",
        "Cheat_SaveCheckpointProgression",
        "CheckpointIndex",
        "CheckpointProgression",
        "GetUnlockedLevels",
        "JungleLevelTapes",
        "BannedPlayers",
        "GolfScoreDifferentials",
        "OnTapePlayed",
    },
    BPFL_SaveStatics = {
        "GetPlayerProgression",
        "UnlockCosmetic",
        "OnTapePlayed",
    },
    BP_CheatManager = {
        "CheatGiveCosmeticsWithoutUnlockingAchievement",
        "GiveAllCosmeticsForMabuttsWithoutUnlockingAchievement",
        "GiveAllCosmeticsForSnowLevelWithoutUnlockingAchievement",
        "AddAllTapes",
        "DEBUG_AddAllTapes",
        "GiveEpiPens",
        "GivePart",
        "ReceiveGiveItem",
        "RepairDamage",
        "RepairEngineDamage",
        "RepairFrameDamage",
        "RepairWheelDamage",
        "DriveWinnebago",
        "DriveClosestJetski",
        "GrabWinch",
        "GrabRearWinch",
        "ResetAndGrabWinch",
        "ResetAndGrabRearWinch",
        "AddIceStudsToAllWheels",
        "AddIceStudsToOneWheel",
        "Cheat_WearDownIceStuds",
        "RemoveInactivePlayers",
        "Cheat_SaveCheckpointProgression",
        "GetSpawnPointInFrontOfPlayer",
        "GetPlayerStartActor",
        "Golf_MoveBallToAimLocation",
        "Golf_MoveBallToLocation",
        "CheatSimulateGolfBallStrokeByOwner",
        "DamageAllPlayers",
        "DamageAllClientPlayers",
        "DamageServerPlayer",
        "IgnoreActorsWithPlayersAttachedToThem",
        "LogAllVehicleParts",
    },
    PlayerController = {
        "CheatManager",
        "PlayerState",
        "Pawn",
        "bShowMouseCursor",
    },
}

--- GameplayTag-строки категорий косметики (подтверждены дампом
--- BP_SaveGamePlayer: ветка Cosmetic.* переключается в UnlockCosmetic).
Refs.CosmeticTags = {
    "Cosmetic.Hat",
    "Cosmetic.Glasses",
}

--- Теги уровней (из дампа BP_SaveGamePlayer: Level.*).
Refs.LevelTags = {
    "Level.JungleLevel",
    "Level.SnowLevel",
    "Level.MabuttsValley",
    "Level.GolfLevel",
}

return Refs
