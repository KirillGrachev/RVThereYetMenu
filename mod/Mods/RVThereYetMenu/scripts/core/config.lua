--- Конфигурация мода: INI-файл рядом с папкой мода (../config.ini).
--- INI-парсер свой (в UE4SS Lua нет штатного), формат — как у MoreRVers:
--- [Section] + Key = Value, ';' и '#' — комментарии.
--- Все значения клампятся здесь, а не в точках использования: меню и хуки
--- должны получать уже безопасные числа (договорённость из RiskOfRainMenu,
--- где Protocol clamps жили в одном месте).
local Log = require("core.log")

local Config = {}

--- Значения по умолчанию. MaxPlayers=8 как у MoreRVers (ванильный кап 4,
--- жёсткий предел 24 — движковый лимит на число replicated-соединений
--- проверяется уже на стороне хуков).
local DEFAULTS = {
    Menu = {
        ToggleKey = "INSERT",
        Language = "ru",
    },
    Session = {
        MaxPlayers = 8,
        AutoApplySlots = true,
    },
    Logging = {
        Level = "INFO",
    },
}

local LIMITS = {
    MaxPlayers = { min = 1, max = 24 },
}

--- Разбирает INI-текст в таблицу { Section = { Key = "строковое значение" } }.
--- Значения остаются строками — приведением типов занимается Normalize,
--- чтобы ошибка парсинга не теряла всю секцию.
local function parse(text)
    local data = {}
    local section = data
    for raw in (text .. "\n"):gmatch("([^\n]*)\n") do
        local line = raw:match("^%s*(.-)%s*$")
        if line ~= "" and not line:match("^[;#]") then
            local sec = line:match("^%[(.+)%]$")
            if sec then
                section = data[sec] or {}
                data[sec] = section
            else
                local key, value = line:match("^([^=]+)%s*=%s*(.*)$")
                if key then
                    section[key:match("^%s*(.-)%s*$")] = value:match("^%s*(.-)%s*$")
                end
            end
        end
    end
    return data
end

local function toBool(value, fallback)
    if value == nil then return fallback end
    local v = tostring(value):lower()
    if v == "true" or v == "1" or v == "yes" then return true end
    if v == "false" or v == "0" or v == "no" then return false end
    return fallback
end

local function toNumber(value, fallback)
    local n = tonumber(value)
    if n == nil then return fallback end
    return n
end

local function clamp(value, limit)
    if not limit then return value end
    if value < limit.min then return limit.min end
    if value > limit.max then return limit.max end
    return value
end

--- Приводит сырые строки к типам конфига и клампит численные значения.
--- Возвращает плоскую таблицу: cfg.ToggleKey, cfg.MaxPlayers, ...
local function normalize(raw)
    local cfg = {}

    cfg.ToggleKey = tostring(raw.Menu and raw.Menu.ToggleKey or DEFAULTS.Menu.ToggleKey):upper()
    cfg.Language = tostring(raw.Menu and raw.Menu.Language or DEFAULTS.Menu.Language):lower()

    cfg.MaxPlayers = math.floor(clamp(
        toNumber(raw.Session and raw.Session.MaxPlayers, DEFAULTS.Session.MaxPlayers),
        LIMITS.MaxPlayers))
    cfg.AutoApplySlots = toBool(raw.Session and raw.Session.AutoApplySlots,
        DEFAULTS.Session.AutoApplySlots)

    cfg.LogLevel = tostring(raw.Logging and raw.Logging.Level or DEFAULTS.Logging.Level):upper()

    return cfg
end

--- Загружает конфиг из файла. Отсутствующий/нечитаемый файл — не ошибка:
--- возвращаем дефолты, иначе мод не стартует у пользователя без config.ini.
function Config.Load(path)
    local file = io.open(path, "r")
    if not file then
        Log.Warn("config.ini not found at " .. tostring(path) .. ", using defaults")
        return normalize({})
    end
    local text = file:read("*a")
    file:close()
    local ok, cfg = pcall(function()
        return normalize(parse(text))
    end)
    if not ok then
        Log.Error("config.ini parse failed: " .. tostring(cfg) .. ", using defaults")
        return normalize({})
    end
    return cfg
end

--- Сохраняет конфиг обратно (после изменения значений из меню).
--- Пишет все известные ключи, чтобы файл оставался полным и читаемым.
function Config.Save(path, cfg)
    local lines = {
        "[Menu]",
        "ToggleKey = " .. tostring(cfg.ToggleKey or DEFAULTS.Menu.ToggleKey),
        "Language = " .. tostring(cfg.Language or DEFAULTS.Menu.Language),
        "",
        "[Session]",
        "MaxPlayers = " .. tostring(cfg.MaxPlayers or DEFAULTS.Session.MaxPlayers),
        "AutoApplySlots = " .. tostring(cfg.AutoApplySlots ~= false),
        "",
        "[Logging]",
        "Level = " .. tostring(cfg.LogLevel or DEFAULTS.Logging.Level),
        "",
    }
    local file = io.open(path, "w")
    if not file then
        Log.Warn("cannot write config: " .. tostring(path))
        return false
    end
    file:write(table.concat(lines, "\n"))
    file:close()
    return true
end

-- Экспорт для тестов (tests/lua проверяют parse/normalize без файла).
Config._parse = parse
Config._normalize = normalize
Config._clamp = clamp
Config.LIMITS = LIMITS
Config.DEFAULTS = DEFAULTS

return Config
