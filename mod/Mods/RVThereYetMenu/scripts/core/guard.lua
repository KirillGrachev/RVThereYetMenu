--- ApiGuard — защитные обёртки вокруг UE4SS API (аналог ApiGuard из
--- RiskOfRainMenu). Весь код мода обращается к игре ТОЛЬКО через Guard:
--- любой reflection-вызов может упасть (объект уничтожен, функция
--- переименована патчем игры, хост/клиент различаются), а падение в
--- game-thread уронит игру пользователю.
local Log = require("core.log")

local Guard = {}

--- Выполняет func под pcall. Возвращает ok, resultOrError.
--- Ошибки логирует один раз на (label+сообщение) — повторные одинаковые
--- падения (например, каждый кадр) не должны флудить консоль.
local seenErrors = {}
function Guard.Try(label, func, ...)
    local ok, result = pcall(func, ...)
    if not ok then
        local key = label .. "|" .. tostring(result)
        if not seenErrors[key] then
            seenErrors[key] = true
            Log.Fmt("WARN", "%s failed: %s", label, tostring(result))
        end
    end
    return ok, result
end

--- Сбрасывает кэш залогированных ошибок (после смены уровня — состав
--- объектов другой, те же сообщения могут быть уже неактуальны).
function Guard.ResetErrorCache()
    seenErrors = {}
end

--- Проверяет UObject на валидность. IsValid есть у всех Remote-объектов
--- UE4SS; nil/garbage отбраковываются до обращения.
function Guard.IsValid(obj)
    if obj == nil then return false end
    local ok, valid = pcall(function() return obj:IsValid() end)
    return ok and valid == true
end

--- Возвращает obj, если он валиден, иначе nil + причина (для статус-бара).
function Guard.Require(obj, label)
    if Guard.IsValid(obj) then
        return obj
    end
    return nil, (label or "object") .. " is not available"
end

--- Безопасный вызов метода по имени: Guard.Call(obj, "MethodName", args...).
--- Отличает «объекта нет» от «метода нет» — второе обычно означает патч
--- игры, и об этом стоит сказать пользователю явно.
function Guard.Call(obj, methodName, ...)
    if not Guard.IsValid(obj) then
        return false, "object unavailable"
    end
    local member
    local indexOk = pcall(function() member = obj[methodName] end)
    if not indexOk or member == nil then
        return false, "method '" .. methodName .. "' not found"
    end
    -- UFunction приходят callable-объектами (userdata/table); значение
    -- любого другого типа вызывать нельзя.
    local memberType = type(member)
    if memberType ~= "function" and memberType ~= "userdata" and memberType ~= "table" then
        return false, "member '" .. methodName .. "' is not callable (" .. memberType .. ")"
    end
    local arguments = { ... }
    local callOk, callError = pcall(function() member(obj, table.unpack(arguments)) end)
    if not callOk then
        return false, tostring(callError)
    end
    return true
end

--- Безопасное чтение свойства: Guard.Get(obj, "PropName") -> ok, value.
function Guard.Get(obj, propName)
    if not Guard.IsValid(obj) then return false, nil end
    return pcall(function() return obj[propName] end)
end

--- Безопасная запись свойства: Guard.Set(obj, "PropName", value) -> ok, err.
function Guard.Set(obj, propName, value)
    if not Guard.IsValid(obj) then return false, "object unavailable" end
    local ok, err = pcall(function() obj[propName] = value end)
    return ok, err
end

--- Проверяет доступность глобального API UE4SS (для старых/урезанных сборок).
function Guard.HasGlobal(name)
    local ok, value = pcall(function() return _G[name] end)
    return ok and value ~= nil
end

return Guard
