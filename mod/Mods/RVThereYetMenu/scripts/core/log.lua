--- Логирование мода.
--- Сообщения — на английском (уходят в консоль UE4SS вместе с логами других
--- модов и движка), префикс фиксирован, чтобы вывод легко находился поиском.
--- Уровни повторяют договорённость MoreRVers/сообщества: DEBUG/INFO/WARN/ERROR.
local Log = {}

local LEVELS = { DEBUG = 10, INFO = 20, WARN = 30, ERROR = 40 }
local currentLevel = LEVELS.INFO
local prefix = "RVThereYetMenu"

--- Инициализирует префикс и уровень. Вызывается из main.lua до первого сообщения.
function Log.Init(modTag, levelName)
    if modTag then prefix = modTag end
    Log.SetLevel(levelName)
end

--- Устанавливает уровень по имени; неизвестное имя трактует как INFO,
--- потому что опечатка в конфиге не должна оставлять мод немым.
function Log.SetLevel(levelName)
    currentLevel = LEVELS[tostring(levelName or "INFO"):upper()] or LEVELS.INFO
end

function Log.GetLevel()
    for name, value in pairs(LEVELS) do
        if value == currentLevel then return name end
    end
    return "INFO"
end

local function emit(level, message)
    if LEVELS[level] < currentLevel then return end
    local line = string.format("[%s] [%s] %s", prefix, level, tostring(message))
    -- print у UE4SS уходит и в GUI-консоль, и в UE4SS.log
    print(line)
end

function Log.Debug(message) emit("DEBUG", message) end
function Log.Info(message) emit("INFO", message) end
function Log.Warn(message) emit("WARN", message) end
function Log.Error(message) emit("ERROR", message) end

--- Форматированный вывод: Log.Fmt("INFO", "cap %d -> %d", a, b).
function Log.Fmt(level, format, ...)
    emit(level, string.format(format, ...))
end

return Log
