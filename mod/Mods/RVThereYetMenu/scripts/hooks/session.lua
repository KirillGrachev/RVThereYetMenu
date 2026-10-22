--- Слоты сессии: AGameSession.MaxPlayers на живом экземпляре и CDO.
--- Механика проверена на этой игре модом MoreRVers (4 → 24, host-only,
--- клиенты без мода подключаются нормально): кап читается сервером в
--- момент approve-а подключения, поэтому достаточно поднять свойство.
---
--- Отличия от MoreRVers:
---  - значение из config.ini с клампом в Config (1..24);
---  - исходное значение запоминается в State.Mirrors — есть честный
---    Release (вернуть как было) для вкладки Session;
---  - повторное применение при каждом пересоздании GameSession
---    (фронтенд → уровень → следующий уровень), NotifyOnNewObject +
---    BeginPlay-хук страхуют друг друга.
local Guard = require("core.guard")
local Log = require("core.log")
local Refs = require("core.refs")
local State = require("core.state")
local Engine = require("core.engine")

local Session = {}

local MIRROR_KEY = "GameSession.MaxPlayers"

--- Читает текущий MaxPlayers сессии (number или nil).
function Session.GetCurrentCap()
    local session = Engine.GameSession()
    if not session then return nil end
    local ok, value = Guard.Get(session, "MaxPlayers")
    if ok and type(value) == "number" then return value end
    if ok and value ~= nil then
        -- свойство могло прийти обёрткой RemoteUnrealParam
        local okGet, raw = pcall(function() return value.get and value:get() or value end)
        if okGet and type(raw) == "number" then return raw end
    end
    return nil
end

--- Применяет кап к сессии + CDO. Возвращает ok, применённое значение.
function Session.ApplyTo(session, cap)
    if not Guard.IsValid(session) then return false end

    local original = Session.GetCurrentCap()
    local okSet, errSet = Guard.Set(session, "MaxPlayers", cap)
    if not okSet then
        Log.Fmt("WARN", "MaxPlayers set failed: %s", tostring(errSet))
        State.Count("SessionCap", false)
        return false
    end
    State.Mirror(MIRROR_KEY, cap, original)
    State.Session.MaxPlayersApplied = cap
    State.Session.MaxPlayersOriginal = State.Session.MaxPlayersOriginal or original
    State.Count("SessionCap", true)
    Log.Fmt("INFO", "Applied MaxPlayers override: %s -> %d", tostring(original or "?"), cap)

    -- CDO: сессии, созданные ПОСЛЕ патча, наследуют дефолт класса;
    -- приём MoreRVers, снижает риск «кап слетел после загрузки уровня».
    local cdo = Engine.CDO(Refs.EngineClasses.GameSession)
    if Guard.IsValid(cdo) then
        Guard.Set(cdo, "MaxPlayers", cap)
        Log.Debug("CDO MaxPlayers set to " .. tostring(cap))
    end
    return true, cap
end

--- Применить к текущей сессии (кнопка «Apply now» / AutoApplySlots).
function Session.ApplyNow(ctx)
    local session = Engine.GameSession()
    if not session then
        return false, "GameSession not found (host a session first)"
    end
    local ok = Session.ApplyTo(session, ctx.Config.MaxPlayers)
    if ok then return true end
    return false, "MaxPlayers set failed"
end

--- Вернуть исходный кап (если он запомнен).
function Session.Release(ctx)
    local mirror = State.GetMirror(MIRROR_KEY)
    if not mirror or mirror.original == nil then
        return false, "nothing to release"
    end
    local session = Engine.GameSession()
    if not session then
        return false, "GameSession not found"
    end
    local okSet = Guard.Set(session, "MaxPlayers", mirror.original)
    if okSet then
        State.Mirror(MIRROR_KEY, nil, nil)
        State.Mirrors[MIRROR_KEY] = nil
        State.Session.MaxPlayersApplied = nil
        Log.Fmt("INFO", "Released MaxPlayers override (restored %s)", tostring(mirror.original))
        return true
    end
    return false, "restore failed"
end

--- Установка хуков при старте мода. Все регистрации в pcall: на части
--- сборок движка/игры сигнатуры могут отсутствовать — это не фатально,
--- основной путь (NotifyOnNewObject) уже проверен на этой игре.
function Session.Install(ctx)
    local installed = 0

    local okNotify = pcall(function()
        NotifyOnNewObject(Refs.Hooks.GameSessionCreated, function(obj)
            if not ctx.Config.AutoApplySlots then return end
            -- Сессия могла создаться до загрузки config-значений; cap
            -- берём из конфига на момент создания.
            Session.ApplyTo(obj, ctx.Config.MaxPlayers)
        end)
    end)
    if okNotify then
        installed = installed + 1
        Log.Debug("hook installed: NotifyOnNewObject(GameSession)")
    end

    local okBegin = pcall(function()
        RegisterHook(Refs.Hooks.GameSessionBeginPlay, function(self)
            if not ctx.Config.AutoApplySlots then return end
            Session.ApplyTo(self, ctx.Config.MaxPlayers)
        end)
    end)
    if okBegin then
        installed = installed + 1
        Log.Debug("hook installed: GameSession:ReceiveBeginPlay")
    end

    -- Join-gate кандидаты: informational-хуки (логируем отказы сверх капа).
    -- Возврат nil из post-hook не меняет результат оригинала.
    for _, sig in ipairs(Refs.Hooks.CanPlayerJoin) do
        local ok = pcall(function()
            RegisterHook(sig, function()
                local cap = State.Session.MaxPlayersApplied
                local current = #((Engine.AllPlayerStates()) or {})
                if cap and current > cap then
                    Log.Fmt("WARN", "join beyond cap detected: %d > %d (%s)", current, cap, sig)
                end
            end)
        end)
        if ok then
            installed = installed + 1
            Log.Debug("hook installed: " .. sig)
        end
    end

    Log.Fmt("INFO", "session hooks installed: %d", installed)
    return installed
end

return Session
