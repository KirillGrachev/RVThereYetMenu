--- Вкладка Run: телепорты (чекпоинт/спавн), три waypoint-слота, гольф.
--- Waypoint-ы помнят уровень и отказываются применяться на чужом —
--- договорённость из RiskOfRainMenu (защита от падения в void).
local Lang = require("core.lang")
local State = require("core.state")
local Actions = require("actions")
local Theme = require("menu.theme")
local Widgets = require("menu.widgets")

local Tab = { Id = "run", TitleKey = "tab.run" }

local ui = {}

function Tab.Build(page, context)
    local teleports = Widgets.Section(page, Lang.T("run.title.tp"))
    local teleportRow = Widgets.HBox(teleports)
    Widgets.AddTo(teleports, teleportRow, { Bottom = 3 })
    Widgets.AddTo(teleportRow, Widgets.Button(teleportRow, Lang.T("run.tp.checkpoint"), function()
        Actions.Run(context, "run.tp.checkpoint")
    end), { Right = 4 }, 1.0)
    Widgets.AddTo(teleportRow, Widgets.Button(teleportRow, Lang.T("run.tp.playerstart"), function()
        Actions.Run(context, "run.tp.playerstart")
    end), {}, 1.0)

    local golf = Widgets.Section(page, Lang.T("run.title.golf"))
    Widgets.AddTo(golf, Widgets.Button(golf, Lang.T("run.golf.balltoaim"), function()
        Actions.Run(context, "run.golf.balltoaim")
    end), { Bottom = 3 })

    local waypoints = Widgets.Section(page, Lang.T("run.title.wp"))
    ui.wpStatus = {}
    for slot = 1, 3 do
        local row = Widgets.HBox(waypoints)
        Widgets.AddTo(waypoints, row, { Bottom = 3 })
        local label = Widgets.TextBlock(row, Lang.T("run.wp.slot", slot), { size = Theme.Fonts.Normal })
        Widgets.AddTo(row, label, { Right = 6, Top = 4 }, 0.3)
        Widgets.AddTo(row, Widgets.Button(row, Lang.T("run.wp.save"), function()
            Actions.Run(context, "run.wp.save." .. slot)
        end), { Right = 4 }, 0.35)
        Widgets.AddTo(row, Widgets.Button(row, Lang.T("run.wp.apply"), function()
            Actions.Run(context, "run.wp.apply." .. slot)
        end), {}, 0.35)
        ui.wpStatus[slot] = label
    end
end

function Tab.Refresh()
    for slot = 1, 3 do
        local label = ui.wpStatus[slot]
        if label then
            local waypoint = State.GetMirror("Waypoint." .. slot)
            local text = Lang.T("run.wp.slot", slot)
            if waypoint and waypoint.applied then
                text = text .. "  (" .. tostring(waypoint.applied.level or "?") .. ")"
            end
            Widgets.SetText(label, text)
        end
    end
end

return Tab
