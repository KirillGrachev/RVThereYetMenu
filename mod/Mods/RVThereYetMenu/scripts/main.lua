--- RVThereYetMenu — трейнер для «RV There Yet?» (UE5, UE4SS Lua mod).
---
--- Тонкая точка входа (конвенция RiskOfRainMenu/WindowsConfigurator):
--- здесь только бутстрап — пути, конфиг, локализация, регистрация
--- действий и хуков, хоткей меню. Логика живёт в модулях:
---   core/    — лог, конфиг, lang, GameRefs, CheatState, ApiGuard, Engine
---   menu/    — тема, фабрика виджетов, окно и вкладки
---   hooks/   — сессия (слоты), анлоки, чит-менеджер
---   actions.lua — диспетчер действий меню
local ScriptPath = debug.getinfo(1, "S").source:match("@?(.*)[\\/]main%.lua$") or "."
package.path = ScriptPath .. "/?.lua;" .. ScriptPath .. "/?/init.lua;" .. package.path

local VERSION = "0.1.0"

local Log = require("core.log")
Log.Init("RVThereYetMenu")

local Config = require("core.config")
local Lang = require("core.lang")
local MenuUI = require("menu.menuui")
local Actions = require("actions")
local SessionHooks = require("hooks.session")

local ConfigPath = ScriptPath .. "/../config.ini"
local config = Config.Load(ConfigPath)
Log.Init("RVThereYetMenu", config.LogLevel)
Lang.Load(ScriptPath .. "/../lang/lang.tsv", config.Language)

local context = {
    Version = VERSION,
    Config = config,
    ConfigPath = ConfigPath,
    LastStatus = "",
    OnStatus = function(statusText) MenuUI.SetStatus(statusText) end,
}

Actions.RegisterDefaults()

MenuUI.Init(context, {
    require("tabs.session"),
    require("tabs.unlocks"),
    require("tabs.vehicle"),
    require("tabs.run"),
    require("tabs.players"),
    require("tabs.info"),
})

SessionHooks.Install(context)

--- Хоткей меню. Имя клавиши берётся из config.ini в привычных UE-именах
--- (INSERT, DELETE, ENTER), а таблица Key у UE4SS названа по VK-кодам
--- (INS, DEL, RETURN) — имена прогоняются через таблицу алиасов.
--- Неизвестное имя деградирует в INS, а не в отсутствие меню.
local KEY_ALIASES = {
    INSERT = "INS",
    DELETE = "DEL",
    ENTER = "RETURN",
    ESC = "ESCAPE",
}

local function registerMenuHotkey()
    local keyName = tostring(config.ToggleKey or "INSERT"):upper()
    local resolvedName = KEY_ALIASES[keyName] or keyName
    local key = Key and Key[resolvedName] or nil
    if key == nil and resolvedName ~= KEY_ALIASES.INSERT then
        Log.Warn("unknown ToggleKey '" .. keyName .. "', falling back to INS")
        resolvedName = KEY_ALIASES.INSERT
        key = Key and Key[resolvedName] or nil
    end
    if key == nil then
        if Key == nil then
            Log.Error("Key table unavailable - menu hotkey NOT registered")
        else
            Log.Error("no Key entry for '" .. keyName .. "' (nor INS) - menu hotkey NOT registered")
        end
        return false
    end
    local ok, err = pcall(function()
        RegisterKeyBind(key, function()
            ExecuteInGameThread(function()
                MenuUI.Toggle()
            end)
        end)
    end)
    if not ok then
        Log.Error("RegisterKeyBind failed: " .. tostring(err))
        return false
    end
    Log.Info("menu hotkey registered: " .. resolvedName)
    return true
end

if Key == nil then
    -- Таблица Key появляется вместе с инициализацией ввода: лучше подождать
    -- пару секунд через LoopAsync, чем остаться вообще без меню.
    local attempts = 0
    LoopAsync(1000, function()
        attempts = attempts + 1
        if Key ~= nil then
            registerMenuHotkey()
            return true
        end
        return attempts >= 10
    end)
else
    registerMenuHotkey()
end

--- Смена уровня: дерево виджетов и объекты мира пересоздаются —
--- сбрасываем меню (пересоберётся при следующем открытии).
pcall(function()
    RegisterLoadMapPostHook(function()
        MenuUI.Invalidate()
    end)
end)

do
    local ue4ssVersion = "unknown"
    pcall(function()
        if UE4SS and UE4SS.GetVersion then
            local major, minor, hotfix = UE4SS.GetVersion()
            ue4ssVersion = string.format("%s.%s.%s", tostring(major), tostring(minor), tostring(hotfix))
        end
    end)
    local engineVersion = "unknown"
    pcall(function()
        if UnrealVersion and UnrealVersion.GetMajor then
            engineVersion = string.format("%d.%d", UnrealVersion:GetMajor(), UnrealVersion:GetMinor())
        end
    end)
    Log.Fmt("INFO", "RVThereYetMenu v%s loaded (UE4SS %s, UE %s, lang=%s, hotkey=%s)",
        VERSION, ue4ssVersion, engineVersion, tostring(config.Language), tostring(config.ToggleKey))
end
