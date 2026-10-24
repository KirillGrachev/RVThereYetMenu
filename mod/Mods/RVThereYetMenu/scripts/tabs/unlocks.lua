--- Вкладка Unlocks: косметика, кассеты, прогресс чекпоинтов.
local Guard = require("core.guard")
local Lang = require("core.lang")
local Unlocks = require("hooks.unlocks")
local Actions = require("actions")
local Theme = require("menu.theme")
local Widgets = require("menu.widgets")

local Tab = { Id = "unlocks", TitleKey = "tab.unlocks" }

local ui = {}

function Tab.Build(page, context)
    local section = Widgets.Section(page, Lang.T("unlocks.title"))

    ui.cosmetics = Widgets.Button(section, Lang.T("unlocks.cosmetics"), function()
        Actions.Run(context, "unlocks.cosmetics")
    end)
    Widgets.AddTo(section, ui.cosmetics, { Bottom = 3 })

    ui.tapes = Widgets.Button(section, Lang.T("unlocks.tapes"), function()
        Actions.Run(context, "unlocks.tapes")
    end)
    Widgets.AddTo(section, ui.tapes, { Bottom = 3 })

    ui.checkpoint = Widgets.Button(section, Lang.T("unlocks.checkpoint"), function()
        Actions.Run(context, "unlocks.checkpoint")
    end)
    Widgets.AddTo(section, ui.checkpoint, { Bottom = 6 })

    ui.counts = Widgets.TextBlock(section, "", { size = Theme.Fonts.Small, color = Theme.Colors.MutedText })
    Widgets.AddTo(section, ui.counts, { Bottom = 4 })

    ui.note = Widgets.TextBlock(section, Lang.T("unlocks.note"), { size = Theme.Fonts.Small, color = Theme.Colors.MutedText })
    Widgets.AddTo(section, ui.note)
end

function Tab.Refresh()
    if not Guard.IsValid(ui.counts or nil) then return end
    local cosmetics = Unlocks.UnlockedCosmeticsCount()
    local tapes = Unlocks.CollectedTapesCount()
    Widgets.SetText(ui.counts, string.format("%s: %s   |   %s: %s",
        Lang.T("unlocks.counts.cosmetics"), tostring(cosmetics or "?"),
        Lang.T("unlocks.counts.tapes"), tostring(tapes or "?")))
end

return Tab
