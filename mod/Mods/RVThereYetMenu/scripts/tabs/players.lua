--- Вкладка Players: список игроков сессии + действия над ними.
--- Деструктивные dev-читы (DamageAllPlayers) — за двухступенчатой
--- кнопкой, чтобы клик вслепую не убил сессию друзьям.
local Guard = require("core.guard")
local Lang = require("core.lang")
local Engine = require("core.engine")
local Actions = require("actions")
local Theme = require("menu.theme")
local W = require("menu.widgets")

local Tab = { Id = "players", TitleKey = "tab.players" }

local els = {}

local function playerDisplayName(ps)
    local ok, name = Guard.Try("PlayerName", function()
        local raw = ps.PlayerName
        if raw == nil then return "?" end
        if raw.ToString then return raw:ToString() end
        return tostring(raw)
    end)
    if ok and name ~= nil then return tostring(name) end
    return "?"
end

function Tab.Build(page, ctx)
    local list = W.Section(page, Lang.T("players.title.list"))
    els.listBox = W.VBox(list)
    W.AddTo(list, els.listBox)

    local actions = W.Section(page, Lang.T("players.title.actions"))
    local row = W.HBox(actions)
    W.AddTo(actions, row, { Bottom = 3 })
    W.AddTo(row, W.Button(row, Lang.T("players.epipens"), function()
        Actions.Run(ctx, "players.epipens")
    end), { Right = 4 }, 1.0)
    W.AddTo(row, W.Button(row, Lang.T("players.removeinactive"), function()
        Actions.Run(ctx, "players.removeinactive")
    end), {}, 1.0)

    W.AddTo(actions, W.Button(actions, Lang.T("players.ignoreattached"), function()
        Actions.Run(ctx, "players.ignoreattached")
    end), { Bottom = 3 })

    local dev = W.Section(page, Lang.T("players.title.dev"))
    W.AddTo(dev, W.DangerButton(dev,
        Lang.T("players.damageall"),
        Lang.T("players.confirm"),
        function() Actions.Run(ctx, "players.damageall") end), { Bottom = 3 })
end

function Tab.Refresh()
    if not Guard.IsValid(els.listBox or nil) then return end
    local players, reason = Engine.AllPlayerStates()
    pcall(function() els.listBox:ClearChildren() end)
    if not players then
        W.AddTo(els.listBox, W.TextBlock(els.listBox, tostring(reason or "?"),
            { size = Theme.Fonts.Small, color = Theme.Colors.MutedText }))
        return
    end
    if #players == 0 then
        W.AddTo(els.listBox, W.TextBlock(els.listBox, Lang.T("players.empty"),
            { size = Theme.Fonts.Small, color = Theme.Colors.MutedText }))
        return
    end
    for i, ps in ipairs(players) do
        W.AddTo(els.listBox, W.TextBlock(els.listBox,
            string.format("%d. %s", i, playerDisplayName(ps)),
            { size = Theme.Fonts.Normal }), { Bottom = 2 })
    end
end

return Tab
