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
            local sectionName = line:match("^%[(.+)%]$")
            if sectionName then
                section = data[sectionName] or {}
                data[sectionName] = section
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
    local text = tostring(value):lower()
    if text == "true" or text == "1" or text == "yes" then return true end
    if text == "false" or text == "0" or text == "no" then return false end
    return fallback
end

local function toNumber(value, fallback)
    local number = tonumber(value)
    if number == nil then return fallback end
    return number
end

local function clamp(value, limit)
    if not limit then return value end
    if value < limit.min then return limit.min end
    if value > limit.max then return limit.max end
    return value
end

--- Приводит сырые строки к типам конфига и клампит численные значения.
--- Возвращает плоскую таблицу: config.ToggleKey, config.MaxPlayers, ...
local function normalize(raw)
    local config = {}

    config.ToggleKey = tostring(raw.Menu and raw.Menu.ToggleKey or DEFAULTS.Menu.ToggleKey):upper()
    config.Language = tostring(raw.Menu and raw.Menu.Language or DEFAULTS.Menu.Language):lower()

    config.MaxPlayers = math.floor(clamp(
        toNumber(raw.Session and raw.Session.MaxPlayers, DEFAULTS.Session.MaxPlayers),
        LIMITS.MaxPlayers))
    config.AutoApplySlots = toBool(raw.Session and raw.Session.AutoApplySlots,
        DEFAULTS.Session.AutoApplySlots)

    config.LogLevel = tostring(raw.Logging and raw.Logging.Level or DEFAULTS.Logging.Level):upper()

    return config
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
    local parseOk, parsed = pcall(function()
        return normalize(parse(text))
    end)
    if not parseOk then
        Log.Error("config.ini parse failed: " .. tostring(parsed) .. ", using defaults")
        return normalize({})
    end
    return parsed
end

--- Сохраняет конфиг обратно (после изменения значений из меню).
--- Пишет все известные ключи, чтобы файл оставался полным и читаемым.
function Config.Save(path, config)
    local lines = {
        "[Menu]",
        "ToggleKey = " .. tostring(config.ToggleKey or DEFAULTS.Menu.ToggleKey),
        "Language = " .. tostring(config.Language or DEFAULTS.Menu.Language),
        "",
        "[Session]",
        "MaxPlayers = " .. tostring(config.MaxPlayers or DEFAULTS.Session.MaxPlayers),
        "AutoApplySlots = " .. tostring(config.AutoApplySlots ~= false),
        "",
        "[Logging]",
        "Level = " .. tostring(config.LogLevel or DEFAULTS.Logging.Level),
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

--- Экспорт для тестов: tests/lua проверяют парсинг и нормализацию без файла.
Config.Parse = parse
Config.Normalize = normalize
Config.Clamp = clamp
Config.LIMITS = LIMITS
Config.DEFAULTS = DEFAULTS

return Config
