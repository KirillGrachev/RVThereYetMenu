--- CheatState — состояние читов и оптимистичные зеркала игровых значений
--- (аналог CheatState из RiskOfRainMenu). Единственное место, где живёт
--- «что включено сейчас»: меню читает отсюда, хуки сюда пишут.
---
--- Зеркала нужны потому, что игровые объекты пересоздаются при смене
--- уровня/сессии: применив MaxPlayers один раз, мы запоминаем и исходное
--- значение (для честного Release), и применённое (для статуса в меню).
local Log = require("core.log")

local State = {}

--- Флаги-переключатели (вкл/выкл до смены уровня или явно).
State.Flags = {}

--- Зеркала числовых/структурных значений: { applied = ..., original = ... }.
State.Mirrors = {}

--- Сводка текущей сессии для вкладки Info/Session (обновляет menu Refresh).
State.Session = {
    LevelName = nil,
    IsHost = nil,
    PlayerCount = 0,
    MaxPlayersApplied = nil,
    MaxPlayersOriginal = nil,
}

--- Диагностика: счётчики применений/отказов по действиям.
State.Metrics = {}

function State.Reset()
    State.Flags = {}
    State.Mirrors = {}
    State.Metrics = {}
    State.Session = {
        LevelName = nil,
        IsHost = nil,
        PlayerCount = 0,
        MaxPlayersApplied = nil,
        MaxPlayersOriginal = nil,
    }
end

function State.SetFlag(name, value)
    State.Flags[name] = value and true or false
    Log.Fmt("DEBUG", "flag %s := %s", name, tostring(State.Flags[name]))
    return State.Flags[name]
end

function State.GetFlag(name)
    return State.Flags[name] == true
end

--- Запоминает зеркало значения. original сохраняется один раз —
--- повторные применения не должны затирать истинное исходное значение.
function State.Mirror(name, applied, original)
    local mirror = State.Mirrors[name] or {}
    mirror.applied = applied
    if original ~= nil and mirror.original == nil then
        mirror.original = original
    end
    State.Mirrors[name] = mirror
    return mirror
end

function State.GetMirror(name)
    return State.Mirrors[name]
end

function State.Count(name, ok)
    State.Metrics[name] = State.Metrics[name] or { ok = 0, fail = 0 }
    if ok then
        State.Metrics[name].ok = State.Metrics[name].ok + 1
    else
        State.Metrics[name].fail = State.Metrics[name].fail + 1
    end
end

return State
