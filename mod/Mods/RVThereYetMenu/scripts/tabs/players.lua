--- Вкладка Players: список игроков сессии + действия над ними.
--- Деструктивные dev-читы (DamageAllPlayers) — за двухступенчатой
--- кнопкой, чтобы клик вслепую не убил сессию друзьям.
local Guard = require("core.guard")
local Lang = require("core.lang")
local Engine = require("core.engine")
local Actions = require("actions")
local Theme = require("menu.theme")
local Widgets = require("menu.widgets")

local Tab = { Id = "players", TitleKey = "tab.players" }

local ui = {}

local function playerDisplayName(playerState)
    local ok, name = Guard.Try("PlayerName", function()
        local raw = playerState.PlayerName
        if raw == nil then return "?" end
        if raw.ToString then return raw:ToString() end
        return tostring(raw)
    end)
    if ok and name ~= nil then return tostring(name) end
    return "?"
end

function Tab.Build(page, context)
    local listSection = Widgets.Section(page, Lang.T("players.title.list"))
    ui.listBox = Widgets.VBox(listSection)
    Widgets.AddTo(listSection, ui.listBox)

    local actionsSection = Widgets.Section(page, Lang.T("players.title.actions"))
    local row = Widgets.HBox(actionsSection)
    Widgets.AddTo(actionsSection, row, { Bottom = 3 })
    Widgets.AddTo(row, Widgets.Button(row, Lang.T("players.epipens"), function()
        Actions.Run(context, "players.epipens")
    end), { Right = 4 }, 1.0)
    Widgets.AddTo(row, Widgets.Button(row, Lang.T("players.removeinactive"), function()
        Actions.Run(context, "players.removeinactive")
    end), {}, 1.0)

    Widgets.AddTo(actionsSection, Widgets.Button(actionsSection, Lang.T("players.ignoreattached"), function()
        Actions.Run(context, "players.ignoreattached")
    end), { Bottom = 3 })

    local devSection = Widgets.Section(page, Lang.T("players.title.dev"))
    Widgets.AddTo(devSection, Widgets.DangerButton(devSection,
        Lang.T("players.damageall"),
        Lang.T("players.confirm"),
        function() Actions.Run(context, "players.damageall") end), { Bottom = 3 })
end

function Tab.Refresh()
    if not Guard.IsValid(ui.listBox or nil) then return end
    local players, reason = Engine.AllPlayerStates()
    pcall(function() ui.listBox:ClearChildren() end)
    if not players then
        Widgets.AddTo(ui.listBox, Widgets.TextBlock(ui.listBox, tostring(reason or "?"),
            { size = Theme.Fonts.Small, color = Theme.Colors.MutedText }))
        return
    end
    if #players == 0 then
        Widgets.AddTo(ui.listBox, Widgets.TextBlock(ui.listBox, Lang.T("players.empty"),
            { size = Theme.Fonts.Small, color = Theme.Colors.MutedText }))
        return
    end
    for i, playerState in ipairs(players) do
        Widgets.AddTo(ui.listBox, Widgets.TextBlock(ui.listBox,
            string.format("%d. %s", i, playerDisplayName(playerState)),
            { size = Theme.Fonts.Normal }), { Bottom = 2 })
    end
end

return Tab
