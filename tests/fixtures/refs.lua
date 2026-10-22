-- Синтетический refs.lua для сквозного прогона NameCheck в CI.
-- Форма совпадает с боевым scripts/core/refs.lua; имена резолвятся в
-- tests/fixtures/assets.txt и tests/fixtures/dumps/.
local Refs = {}

Refs.EngineClasses = {
    GameSession = "/Script/Engine.GameSession",
}

Refs.Hooks = {
    GameSessionCreated = "/Script/Engine.GameSession",
    GameSessionBeginPlay = "/Script/Engine.GameSession:ReceiveBeginPlay",
}

Refs.Assets = {
    PlayerSave = "/Game/Ride/Game/BP_SaveGamePlayer",
    CheatManager = "/Game/Ride/Cheats/BP_CheatManager",
}

Refs.ShortClasses = {
    GameInstance = "GameInstance",
    PlayerSave = "BP_SaveGamePlayer_C",
}

Refs.Members = {
    GameSession = {
        "MaxPlayers",
    },
    BP_SaveGamePlayer = {
        "GetUnlockedCosmetics",
        "AsyncSaveGameToSlotForLocalPlayer",
    },
    BP_CheatManager = {
        "AddAllTapes",
    },
}

Refs.CosmeticTags = {
    "Cosmetic.Hat",
}

Refs.LevelTags = {
    "Level.JungleLevel",
}

return Refs
