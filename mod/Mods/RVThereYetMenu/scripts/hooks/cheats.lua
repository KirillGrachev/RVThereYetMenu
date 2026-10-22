--- Чит-менеджер: тонкая обёртка над BP_CheatManager (внутриигровой
--- набор dev-читов подтверждён дампом: ремонт, выдача предметов,
--- посадка в транспорт, лебёдка, гольф, кассеты, косметика).
---
--- Требует включённый CheatManagerEnablerMod (входит в наш UE4SS-набор):
--- без него APlayerController.CheatManager == nil.
local Guard = require("core.guard")
local Log = require("core.log")
local State = require("core.state")
local Engine = require("core.engine")

local Cheats = {}

--- Доступен ли чит-менеджер сейчас (для status-бара и блокировки кнопок).
function Cheats.IsAvailable()
    local cheatManager, reason = Engine.CheatManager()
    return cheatManager ~= nil, reason
end

--- Вызов чита по имени с аргументами. Все вызовы — в game thread
--- (вызывающий обязан это обеспечить; меню и хоткеи так и делают).
function Cheats.Call(name, ...)
    local cheatManager, reason = Engine.CheatManager()
    if not cheatManager then
        return false, reason or "CheatManager not found"
    end
    local arguments = { ... }
    local ok, err = Guard.Call(cheatManager, name, table.unpack(arguments))
    if ok then
        State.Count("Cheat." .. name, true)
        Log.Fmt("INFO", "cheat called: %s", name)
        return true
    end
    State.Count("Cheat." .. name, false)
    return false, err
end

--- Пакетный вызов: первые успехи не отменяют остальные отказы
--- (часть функций может отсутствовать после патча игры).
function Cheats.CallAll(names)
    local results = {}
    for _, name in ipairs(names) do
        results[name] = { Cheats.Call(name) }
    end
    return results
end

return Cheats
