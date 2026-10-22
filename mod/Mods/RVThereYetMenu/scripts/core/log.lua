--- Логирование мода.
--- Сообщения — на английском (уходят в консоль UE4SS вместе с логами других
--- модов и движка), префикс фиксирован, чтобы вывод легко находился поиском.
--- Уровни повторяют договорённость MoreRVers/сообщества: DEBUG/INFO/WARN/ERROR.
local Log = {}

local LEVELS = { DEBUG = 10, INFO = 20, WARN = 30, ERROR = 40 }
local current = LEVELS.INFO
local tag = "RVThereYetMenu"

--- Инициализирует тег и уровень. Вызывается из main.lua до первого сообщения.
function Log.Init(modTag, levelName)
    if modTag then tag = modTag end
    Log.SetLevel(levelName)
end

--- Устанавливает уровень по имени; неизвестное имя трактует как INFO,
--- потому что опечатка в конфиге не должна оставлять мод немым.
function Log.SetLevel(levelName)
    current = LEVELS[tostring(levelName or "INFO"):upper()] or LEVELS.INFO
end

function Log.GetLevel()
    for name, value in pairs(LEVELS) do
        if value == current then return name end
    end
    return "INFO"
end

local function emit(level, msg)
    if LEVELS[level] < current then return end
    local line = string.format("[%s] [%s] %s", tag, level, tostring(msg))
    -- print у UE4SS уходит и в GUI-консоль, и в UE4SS.log
    print(line)
end

function Log.Debug(msg) emit("DEBUG", msg) end
function Log.Info(msg) emit("INFO", msg) end
function Log.Warn(msg) emit("WARN", msg) end
function Log.Error(msg) emit("ERROR", msg) end

--- Форматированный вывод: Log.Fmt("INFO", "cap %d -> %d", a, b).
function Log.Fmt(level, fmt, ...)
    emit(level, string.format(fmt, ...))
end

return Log
