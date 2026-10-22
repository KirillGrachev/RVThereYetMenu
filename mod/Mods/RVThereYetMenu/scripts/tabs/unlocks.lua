--- Вкладка Unlocks: косметика, кассеты, прогресс чекпоинтов.
local Guard = require("core.guard")
local Lang = require("core.lang")
local Unlocks = require("hooks.unlocks")
local Actions = require("actions")
local Theme = require("menu.theme")
local W = require("menu.widgets")

local Tab = { Id = "unlocks", TitleKey = "tab.unlocks" }

local els = {}

function Tab.Build(page, ctx)
    local s = W.Section(page, Lang.T("unlocks.title"))

    els.cosmetics = W.Button(s, Lang.T("unlocks.cosmetics"), function()
        Actions.Run(ctx, "unlocks.cosmetics")
    end)
    W.AddTo(s, els.cosmetics, { Bottom = 3 })

    els.tapes = W.Button(s, Lang.T("unlocks.tapes"), function()
        Actions.Run(ctx, "unlocks.tapes")
    end)
    W.AddTo(s, els.tapes, { Bottom = 3 })

    els.checkpoint = W.Button(s, Lang.T("unlocks.checkpoint"), function()
        Actions.Run(ctx, "unlocks.checkpoint")
    end)
    W.AddTo(s, els.checkpoint, { Bottom = 6 })

    els.counts = W.TextBlock(s, "", { size = Theme.Fonts.Small, color = Theme.Colors.MutedText })
    W.AddTo(s, els.counts, { Bottom = 4 })

    els.note = W.TextBlock(s, Lang.T("unlocks.note"), { size = Theme.Fonts.Small, color = Theme.Colors.MutedText })
    W.AddTo(s, els.note)
end

function Tab.Refresh()
    if not Guard.IsValid(els.counts or nil) then return end
    local cosmetics = Unlocks.UnlockedCosmeticsCount()
    local tapes = Unlocks.CollectedTapesCount()
    els.counts:UpdateText(string.format("%s: %s   |   %s: %s",
        Lang.T("unlocks.counts.cosmetics"), tostring(cosmetics or "?"),
        Lang.T("unlocks.counts.tapes"), tostring(tapes or "?")))
end

return Tab
