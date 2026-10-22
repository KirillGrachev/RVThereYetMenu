--- Вкладка Session: слоты сессии (главная фича «увеличение слотов»).
local Guard = require("core.guard")
local Lang = require("core.lang")
local Config = require("core.config")
local State = require("core.state")
local Engine = require("core.engine")
local Session = require("hooks.session")
local Actions = require("actions")
local Theme = require("menu.theme")
local Widgets = require("menu.widgets")

local Tab = { Id = "session", TitleKey = "tab.session" }

local ui = {}

function Tab.Build(page, context)
    local section = Widgets.Section(page, Lang.T("session.title"))

    ui.slider = Widgets.Slider(section, Lang.T("session.maxplayers"), 1, 24, context.Config.MaxPlayers, function(newValue)
        context.Config.MaxPlayers = newValue
        -- Значение переживает перезапуск игры: конфиг пишется сразу.
        if context.ConfigPath then
            pcall(function() Config.Save(context.ConfigPath, context.Config) end)
        end
    end)
    Widgets.AddTo(section, ui.slider, { Bottom = 6 })

    ui.apply = Widgets.Button(section, Lang.T("session.apply"), function()
        Actions.Run(context, "session.apply")
    end)
    Widgets.AddTo(section, ui.apply, { Bottom = 3 })

    ui.release = Widgets.Button(section, Lang.T("session.release"), function()
        Actions.Run(context, "session.release")
    end)
    Widgets.AddTo(section, ui.release, { Bottom = 6 })

    ui.status = Widgets.TextBlock(section, "", { size = Theme.Fonts.Small, color = Theme.Colors.MutedText })
    Widgets.AddTo(section, ui.status, { Bottom = 4 })

    ui.note = Widgets.TextBlock(section, Lang.T("session.note"), { size = Theme.Fonts.Small, color = Theme.Colors.MutedText })
    Widgets.AddTo(section, ui.note)
end

function Tab.Refresh()
    if not Guard.IsValid(ui.status or nil) then return end
    local parts = {}
    local currentCap = Session.GetCurrentCap()
    parts[#parts + 1] = Lang.T("session.current") .. ": " .. tostring(currentCap or "?")
    local players = Engine.AllPlayerStates()
    parts[#parts + 1] = Lang.T("session.players") .. ": " .. tostring(players and #players or "?")
    parts[#parts + 1] = Engine.IsHost() and Lang.T("session.host") or Lang.T("session.client")
    local mirror = State.GetMirror("GameSession.MaxPlayers")
    if mirror and mirror.original then
        parts[#parts + 1] = Lang.T("session.original") .. ": " .. tostring(mirror.original)
    end
    ui.status:UpdateText(table.concat(parts, "  |  "))
end

return Tab
