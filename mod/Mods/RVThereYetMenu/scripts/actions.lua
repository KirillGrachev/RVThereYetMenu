--- Actions — диспетчер действий (аналог SandboxActions из RiskOfRainMenu).
--- Меню не обращается к игре напрямую: кнопка знает только id действия.
--- Здесь живут: реестр действий, исполнение строго в game thread,
--- единый статус-ответ для status-бара и защита от двойного клика.
---
--- Действие (def):
---   labelKey    — ключ lang.tsv для кнопки;
---   section     — grouping для логов/тестов;
---   dangerous   — требует подтверждения в UI (деструктивные dev-читы);
---   run(ctx)    -> ok:boolean, message:string|nil   (в game thread);
---   available(ctx) -> ok:boolean, reason:string|nil (nil-функция = всегда).
local Guard = require("core.guard")
local Log = require("core.log")
local Refs = require("core.refs")
local State = require("core.state")
local Engine = require("core.engine")
local Cheats = require("hooks.cheats")
local Session = require("hooks.session")
local Unlocks = require("hooks.unlocks")

local Actions = {}

Actions.Registry = {}
local running = false

function Actions.Register(id, def)
    if Actions.Registry[id] then
        Log.Warn("action re-registered: " .. id)
    end
    Actions.Registry[id] = def
end

--- Проверка доступности (для блокировки кнопок в UI).
function Actions.Available(ctx, id)
    local def = Actions.Registry[id]
    if not def then return false, "unknown action" end
    if not def.available then return true end
    local ok, res, reason = pcall(def.available, ctx)
    if not ok then return false, tostring(res) end
    return res, reason
end

--- Выполнить действие. Всегда через ExecuteInGameThread (UI-колбэки
--- ImGui/UMG приходят вне game thread), статус — в ctx.LastStatus и
--- в лог. Повторный запуск во время выполнения игнорируется.
function Actions.Run(ctx, id)
    local def = Actions.Registry[id]
    if not def then
        Log.Warn("unknown action: " .. tostring(id))
        return
    end
    if running then
        Log.Debug("action ignored (another is running): " .. id)
        return
    end
    running = true

    ExecuteInGameThread(function()
        local okRun, ok, msg = pcall(function() return def.run(ctx) end)
        running = false
        if not okRun then
            ctx.LastStatus = id .. ": EXCEPTION " .. tostring(ok)
            Log.Fmt("ERROR", "action %s threw: %s", id, tostring(ok))
            if ctx.OnStatus then ctx.OnStatus(ctx.LastStatus) end
            return
        end
        ctx.LastStatus = string.format("%s: %s", id, ok and (msg or "OK") or ("FAILED " .. (msg or "")))
        Log.Fmt(ok and "INFO" or "WARN", "action %s -> %s", id, ok and (msg or "OK") or ("FAILED " .. (msg or "")))
        if ctx.OnStatus then ctx.OnStatus(ctx.LastStatus) end
    end)
end

--- Регистрация действий. Вынесена в функцию, чтобы тесты могли зарегистрировать
--- действия на «голом» реестре без игрового окружения.

local function cheatAvailable()
    return Cheats.IsAvailable()
end

local function cheatAction(id, cheatName, labelKey, section, dangerous)
    Actions.Register(id, {
        labelKey = labelKey,
        section = section or "cheats",
        dangerous = dangerous or false,
        available = cheatAvailable,
        run = function()
            local ok, err = Cheats.Call(cheatName)
            return ok, ok and nil or err
        end,
    })
end

function Actions.RegisterDefaults()
    --- Сессия: применить и снять кап слотов.
    Actions.Register("session.apply", {
        labelKey = "session.apply",
        section = "session",
        run = function(ctx)
            local ok, msg = Session.ApplyNow(ctx)
            return ok, ok and ("MaxPlayers=" .. tostring(ctx.Config.MaxPlayers)) or msg
        end,
    })
    Actions.Register("session.release", {
        labelKey = "session.release",
        section = "session",
        run = function()
            local ok, msg = Session.Release()
            return ok, ok and "restored" or msg
        end,
    })

    --- Анлоки: косметика, кассеты, прогресс чекпоинтов.
    Actions.Register("unlocks.cosmetics", {
        labelKey = "unlocks.cosmetics",
        section = "unlocks",
        run = function()
            local ok, report = Unlocks.AllCosmetics()
            return ok, report
        end,
    })
    Actions.Register("unlocks.tapes", {
        labelKey = "unlocks.tapes",
        section = "unlocks",
        available = cheatAvailable,
        run = function()
            local ok = Unlocks.AllTapes()
            return ok, ok and "all tapes added" or "AddAllTapes failed"
        end,
    })
    Actions.Register("unlocks.checkpoint", {
        labelKey = "unlocks.checkpoint",
        section = "unlocks",
        run = function()
            local ok = Unlocks.SaveCheckpointProgression()
            return ok, ok and "checkpoint progression saved" or "no path succeeded"
        end,
    })

    --- Транспорт: ремонт, посадка, лебёдка, шипы (обёртки чит-менеджера).
    cheatAction("vehicle.repair.all", "RepairDamage", "vehicle.repair.all", "vehicle")
    cheatAction("vehicle.repair.engine", "RepairEngineDamage", "vehicle.repair.engine", "vehicle")
    cheatAction("vehicle.repair.frame", "RepairFrameDamage", "vehicle.repair.frame", "vehicle")
    cheatAction("vehicle.repair.wheels", "RepairWheelDamage", "vehicle.repair.wheels", "vehicle")
    cheatAction("vehicle.drive.winnebago", "DriveWinnebago", "vehicle.drive.winnebago", "vehicle")
    cheatAction("vehicle.drive.jetski", "DriveClosestJetski", "vehicle.drive.jetski", "vehicle")
    cheatAction("vehicle.winch.grab", "GrabWinch", "vehicle.winch.grab", "vehicle")
    cheatAction("vehicle.winch.grab.rear", "GrabRearWinch", "vehicle.winch.grab.rear", "vehicle")
    cheatAction("vehicle.winch.reset", "ResetAndGrabWinch", "vehicle.winch.reset", "vehicle")
    cheatAction("vehicle.winch.reset.rear", "ResetAndGrabRearWinch", "vehicle.winch.reset.rear", "vehicle")
    cheatAction("vehicle.studs.add", "AddIceStudsToAllWheels", "vehicle.studs.add", "vehicle")
    cheatAction("vehicle.studs.wear", "Cheat_WearDownIceStuds", "vehicle.studs.wear", "vehicle")

    --- Заезд: телепорты, чекпоинты, гольф, waypoint-слоты.
    Actions.Register("run.tp.checkpoint", {
        labelKey = "run.tp.checkpoint",
        section = "run",
        run = function()
            -- Ближайший чекпоинт: ищем все BP_CheckPoint_C и берём
            -- минимальную дистанцию до пешки игрока.
            local pawn = Engine.Pawn()
            if not pawn then return false, "pawn not found" end
            local points = Engine.FindAll(Refs.ShortClasses.Checkpoint)
            if #points == 0 then return false, "no checkpoints in world" end
            local ok, msg = Guard.Try("TP-nearest-checkpoint", function()
                local pl = pawn:K2_GetActorLocation()
                local best, bestD = nil, nil
                for _, cp in ipairs(points) do
                    if Guard.IsValid(cp) then
                        local cl = cp:K2_GetActorLocation()
                        local dx, dy, dz = cl.X - pl.X, cl.Y - pl.Y, cl.Z - pl.Z
                        local d = dx * dx + dy * dy + dz * dz
                        if not bestD or d < bestD then best, bestD = cp, d end
                    end
                end
                if not best then return false, "no valid checkpoint" end
                local tl = best:K2_GetActorLocation()
                local tr = best:K2_GetActorRotation()
                local moved = pawn:K2_TeleportTo(tl, tr)
                return moved == true, moved and ("moved to checkpoint (d2=" .. string.format("%.0f", bestD) .. ")") or "K2_TeleportTo refused"
            end)
            return ok, msg
        end,
    })
    Actions.Register("run.tp.playerstart", {
        labelKey = "run.tp.playerstart",
        section = "run",
        available = cheatAvailable,
        run = function()
            local pawn = Engine.Pawn()
            if not pawn then return false, "pawn not found" end
            local cm = Engine.CheatManager()
            if not cm then return false, "CheatManager not found" end
            local ok, msg = Guard.Try("TP-playerstart", function()
                local start = cm:GetPlayerStartActor()
                if not Guard.IsValid(start) then return false, "PlayerStart not found" end
                local tl = start:K2_GetActorLocation()
                local moved = pawn:K2_TeleportTo(tl, pawn:K2_GetActorRotation())
                return moved == true, moved and "moved to player start" or "K2_TeleportTo refused"
            end)
            return ok, msg
        end,
    })
    Actions.Register("run.golf.balltoaim", {
        labelKey = "run.golf.balltoaim",
        section = "run",
        available = cheatAvailable,
        run = function()
            local ok, err = Cheats.Call("Golf_MoveBallToAimLocation")
            return ok, ok and "ball moved to aim location" or err
        end,
    })

    --- Waypoints: три слота, помнят уровень (договорённость RiskOfRainMenu —
    --- точка, сохранённая на другой карте, не применяется: иначе игрок
    --- улетает в void).
    for slot = 1, 3 do
        Actions.Register("run.wp.save." .. slot, {
            labelKey = "run.wp.save",
            section = "run",
            run = function()
                local pawn = Engine.Pawn()
                if not pawn then return false, "pawn not found" end
                local ok, msg = Guard.Try("WP-save-" .. slot, function()
                    local loc = pawn:K2_GetActorLocation()
                    local rot = pawn:K2_GetActorRotation()
                    State.Mirrors["Waypoint." .. slot] = {
                        applied = { level = Engine.LevelName(), X = loc.X, Y = loc.Y, Z = loc.Z, Pitch = rot.Pitch, Yaw = rot.Yaw, Roll = rot.Roll },
                    }
                    return true, string.format("slot %d saved (%s)", slot, tostring(State.Mirrors["Waypoint." .. slot].applied.level))
                end)
                return ok, msg
            end,
        })
        Actions.Register("run.wp.apply." .. slot, {
            labelKey = "run.wp.apply",
            section = "run",
            run = function()
                local wp = State.Mirrors["Waypoint." .. slot]
                if not wp or not wp.applied then return false, "slot " .. slot .. " is empty" end
                local level = Engine.LevelName()
                if wp.applied.level and level and wp.applied.level ~= level then
                    return false, "waypoint belongs to another level"
                end
                local pawn = Engine.Pawn()
                if not pawn then return false, "pawn not found" end
                local ok, msg = Guard.Try("WP-apply-" .. slot, function()
                    local dest = { X = wp.applied.X, Y = wp.applied.Y, Z = wp.applied.Z }
                    local rot = { Pitch = wp.applied.Pitch, Yaw = wp.applied.Yaw, Roll = wp.applied.Roll }
                    local moved = pawn:K2_TeleportTo(dest, rot)
                    return moved == true, moved and ("slot " .. slot .. " applied") or "K2_TeleportTo refused"
                end)
                return ok, msg
            end,
        })
    end

    --- Игроки: выдача EpiPen, очистка сессии, dev-читы.
    cheatAction("players.epipens", "GiveEpiPens", "players.epipens", "players")
    cheatAction("players.removeinactive", "RemoveInactivePlayers", "players.removeinactive", "players")
    cheatAction("players.damageall", "DamageAllPlayers", "players.damageall", "players", true)
    Actions.Register("players.ignoreattached", {
        labelKey = "players.ignoreattached",
        section = "players",
        available = cheatAvailable,
        run = function()
            local ok, err = Cheats.Call("IgnoreActorsWithPlayersAttachedToThem")
            return ok, ok and nil or err
        end,
    })

    --- Info: дампы UE4SS (объекты, CXX-заголовки, usmap).
    Actions.Register("info.dump.objects", {
        labelKey = "info.dump.objects",
        section = "info",
        run = function()
            if not Guard.HasGlobal("DumpAllObjects") then return false, "DumpAllObjects unavailable" end
            DumpAllObjects()
            return true, "UE4SS_ObjectDump.txt written to ue4ss/"
        end,
    })
    Actions.Register("info.dump.sdk", {
        labelKey = "info.dump.sdk",
        section = "info",
        run = function()
            if not Guard.HasGlobal("GenerateSDK") then return false, "GenerateSDK unavailable" end
            GenerateSDK()
            return true, "CXXHeaderDump written to ue4ss/"
        end,
    })
    Actions.Register("info.dump.usmap", {
        labelKey = "info.dump.usmap",
        section = "info",
        run = function()
            if not Guard.HasGlobal("DumpUSMAP") then return false, "DumpUSMAP unavailable in this UE4SS build" end
            DumpUSMAP()
            return true, "Mappings.usmap written to ue4ss/"
        end,
    })
end

return Actions
