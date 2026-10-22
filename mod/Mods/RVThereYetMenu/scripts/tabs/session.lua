--- Вкладка Session: слоты сессии (главная фича «увеличение слотов»).
local Guard = require("core.guard")
local Lang = require("core.lang")
local Config = require("core.config")
local State = require("core.state")
local Engine = require("core.engine")
local Session = require("hooks.session")
local Actions = require("actions")
local Theme = require("menu.theme")
local W = require("menu.widgets")

local Tab = { Id = "session", TitleKey = "tab.session" }

local els = {}

function Tab.Build(page, ctx)
    local s = W.Section(page, Lang.T("session.title"))

    els.slider = W.Slider(s, Lang.T("session.maxplayers"), 1, 24, ctx.Config.MaxPlayers, function(v)
        ctx.Config.MaxPlayers = v
        -- Значение переживает перезапуск игры: конфиг пишется сразу.
        if ctx.ConfigPath then
            pcall(function() Config.Save(ctx.ConfigPath, ctx.Config) end)
        end
    end)
    W.AddTo(s, els.slider, { Bottom = 6 })

    els.apply = W.Button(s, Lang.T("session.apply"), function()
        Actions.Run(ctx, "session.apply")
    end)
    W.AddTo(s, els.apply, { Bottom = 3 })

    els.release = W.Button(s, Lang.T("session.release"), function()
        Actions.Run(ctx, "session.release")
    end)
    W.AddTo(s, els.release, { Bottom = 6 })

    els.status = W.TextBlock(s, "", { size = Theme.Fonts.Small, color = Theme.Colors.MutedText })
    W.AddTo(s, els.status, { Bottom = 4 })

    els.note = W.TextBlock(s, Lang.T("session.note"), { size = Theme.Fonts.Small, color = Theme.Colors.MutedText })
    W.AddTo(s, els.note)
end

function Tab.Refresh()
    if not Guard.IsValid(els.status or nil) then return end
    local parts = {}
    local cap = Session.GetCurrentCap()
    parts[#parts + 1] = Lang.T("session.current") .. ": " .. tostring(cap or "?")
    local players = Engine.AllPlayerStates()
    parts[#parts + 1] = Lang.T("session.players") .. ": " .. tostring(players and #players or "?")
    parts[#parts + 1] = Engine.IsHost() and Lang.T("session.host") or Lang.T("session.client")
    local mirror = State.GetMirror("GameSession.MaxPlayers")
    if mirror and mirror.original then
        parts[#parts + 1] = Lang.T("session.original") .. ": " .. tostring(mirror.original)
    end
    els.status:UpdateText(table.concat(parts, "  |  "))
end

return Tab
