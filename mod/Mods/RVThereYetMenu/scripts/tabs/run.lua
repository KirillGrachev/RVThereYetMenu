--- Вкладка Run: телепорты (чекпоинт/спавн), три waypoint-слота, гольф.
--- Waypoint-ы помнят уровень и отказываются применяться на чужом —
--- договорённость из RiskOfRainMenu (защита от падения в void).
local Lang = require("core.lang")
local State = require("core.state")
local Actions = require("actions")
local Theme = require("menu.theme")
local W = require("menu.widgets")

local Tab = { Id = "run", TitleKey = "tab.run" }

local els = {}

function Tab.Build(page, ctx)
    local tp = W.Section(page, Lang.T("run.title.tp"))
    local row1 = W.HBox(tp)
    W.AddTo(tp, row1, { Bottom = 3 })
    W.AddTo(row1, W.Button(row1, Lang.T("run.tp.checkpoint"), function()
        Actions.Run(ctx, "run.tp.checkpoint")
    end), { Right = 4 }, 1.0)
    W.AddTo(row1, W.Button(row1, Lang.T("run.tp.playerstart"), function()
        Actions.Run(ctx, "run.tp.playerstart")
    end), {}, 1.0)

    local golf = W.Section(page, Lang.T("run.title.golf"))
    W.AddTo(golf, W.Button(golf, Lang.T("run.golf.balltoaim"), function()
        Actions.Run(ctx, "run.golf.balltoaim")
    end), { Bottom = 3 })

    local wp = W.Section(page, Lang.T("run.title.wp"))
    els.wpStatus = {}
    for slot = 1, 3 do
        local row = W.HBox(wp)
        W.AddTo(wp, row, { Bottom = 3 })
        local label = W.TextBlock(row, Lang.T("run.wp.slot", slot), { size = Theme.Fonts.Normal })
        W.AddTo(row, label, { Right = 6, Top = 4 }, 0.3)
        W.AddTo(row, W.Button(row, Lang.T("run.wp.save"), function()
            Actions.Run(ctx, "run.wp.save." .. slot)
        end), { Right = 4 }, 0.35)
        W.AddTo(row, W.Button(row, Lang.T("run.wp.apply"), function()
            Actions.Run(ctx, "run.wp.apply." .. slot)
        end), {}, 0.35)
        els.wpStatus[slot] = label
    end
end

function Tab.Refresh()
    for slot = 1, 3 do
        local label = els.wpStatus[slot]
        if label and label.UpdateText then
            local wp = State.GetMirror("Waypoint." .. slot)
            local text = Lang.T("run.wp.slot", slot)
            if wp and wp.applied then
                text = text .. "  (" .. tostring(wp.applied.level or "?") .. ")"
            end
            label:UpdateText(text)
        end
    end
end

return Tab
