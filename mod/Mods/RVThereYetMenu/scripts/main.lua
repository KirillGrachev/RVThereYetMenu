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
local cfg = Config.Load(ConfigPath)
Log.Init("RVThereYetMenu", cfg.LogLevel)
Lang.Load(ScriptPath .. "/../lang/lang.tsv", cfg.Language)

local ctx = {
    Version = VERSION,
    Config = cfg,
    ConfigPath = ConfigPath,
    LastStatus = "",
    OnStatus = function(s) MenuUI.SetStatus(s) end,
}

Actions.RegisterDefaults()

MenuUI.Init(ctx, {
    require("tabs.session"),
    require("tabs.unlocks"),
    require("tabs.vehicle"),
    require("tabs.run"),
    require("tabs.players"),
    require("tabs.info"),
})

SessionHooks.Install(ctx)

--- Хоткей меню. Имя клавиши — из config.ini (Key.<NAME> у UE4SS);
--- неизвестное имя деградирует в INSERT, а не в отсутствие меню.
do
    local keyName = tostring(cfg.ToggleKey or "INSERT"):upper()
    local key = Key and Key[keyName] or nil
    if key == nil then
        Log.Warn("unknown ToggleKey '" .. keyName .. "', falling back to INSERT")
        key = Key and Key.INSERT or nil
    end
    if key ~= nil then
        local ok, err = pcall(function()
            RegisterKeyBind(key, function()
                ExecuteInGameThread(function()
                    MenuUI.Toggle()
                end)
            end)
        end)
        if ok then
            Log.Info("menu hotkey registered: " .. keyName)
        else
            Log.Error("RegisterKeyBind failed: " .. tostring(err))
        end
    else
        Log.Error("Key table unavailable - menu hotkey NOT registered")
    end
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
        VERSION, ue4ssVersion, engineVersion, tostring(cfg.Language), tostring(cfg.ToggleKey))
end
