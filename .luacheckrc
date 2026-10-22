-- Конфиг luacheck для Lua-кода мода и тестов.
-- Глобальные символы UE4SS объявлены явно: линтер не должен считать их
-- «неопределёнными», а мы — случайно опечататься в имени API.
std = "lua54"
max_line_length = false

globals = {
    -- поиск/создание объектов
    "StaticFindObject",
    "StaticConstructObject",
    "FindFirstOf",
    "FindAllOf",
    "FindObject",
    "FindObjects",
    "ForEachUObject",
    "CreateInvalidObject",
    "LoadAsset",
    -- хуки и события
    "RegisterHook",
    "UnregisterHook",
    "NotifyOnNewObject",
    "RegisterCustomEvent",
    "RegisterCustomProperty",
    "RegisterKeyBind",
    "IsKeyBindRegistered",
    "RegisterLoadMapPreHook",
    "RegisterLoadMapPostHook",
    "RegisterInitGameStatePreHook",
    "RegisterInitGameStatePostHook",
    "RegisterBeginPlayPreHook",
    "RegisterBeginPlayPostHook",
    "RegisterProcessConsoleExecPreHook",
    "RegisterProcessConsoleExecPostHook",
    "RegisterCallFunctionByNameWithArgumentsPreHook",
    "RegisterCallFunctionByNameWithArgumentsPostHook",
    "RegisterULocalPlayerExecPreHook",
    "RegisterULocalPlayerExecPostHook",
    "RegisterConsoleCommandHandler",
    "RegisterConsoleCommandGlobalHandler",
    -- поток исполнения
    "ExecuteInGameThread",
    "ExecuteAsync",
    "ExecuteWithDelay",
    "LoopAsync",
    -- примитивы UE
    "FName",
    "FText",
    -- дамперы UE4SS (кнопки вкладки Info)
    "DumpAllObjects",
    "DumpUSMAP",
    "DumpJMAP",
    "GenerateSDK",
    "GenerateLuaTypes",
    "GenerateUHTCompatibleHeaders",
    "DumpStaticMeshes",
    "DumpAllActors",
    -- управление модами
    "RestartCurrentMod",
    "UninstallCurrentMod",
    "RestartMod",
    "UninstallMod",
    "IterateGameDirectories",
}

read_globals = {
    "UE",
    "UEHelpers",
    "Key",
    "ModifierKey",
    "UnrealVersion",
    "UE4SS",
    "PropertyTypes",
    "EObjectFlags",
    "EInternalObjectFlags",
}

exclude_files = {
    "**/bin/**",
    "**/obj/**",
}
