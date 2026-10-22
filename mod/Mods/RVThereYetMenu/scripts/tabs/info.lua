--- Вкладка Info: версии, диагностика доступности объектов, дампы UE4SS.
--- Кнопки дампов дублируют то, что автор делает через F10-консоль:
--- ObjectDump/CXX SDK/usmap пишутся в папку ue4ss/ — их потом забирает
--- tools/NameCheck для валидации имён (тесты как в RiskOfRainMenu).
local Guard = require("core.guard")
local Lang = require("core.lang")
local Log = require("core.log")
local Engine = require("core.engine")
local Actions = require("actions")
local Theme = require("menu.theme")
local W = require("menu.widgets")

local Tab = { Id = "info", TitleKey = "tab.info" }

local els = {}

local function availabilityLine(label, obj)
    return string.format("%s: %s", label, obj and "OK" or "--")
end

function Tab.Build(page, ctx)
    local versions = W.Section(page, Lang.T("info.title.versions"))
    els.versions = W.TextBlock(versions, "", { size = Theme.Fonts.Small, color = Theme.Colors.MutedText })
    W.AddTo(versions, els.versions)

    local diag = W.Section(page, Lang.T("info.title.diag"))
    els.diag = W.TextBlock(diag, "", { size = Theme.Fonts.Small, color = Theme.Colors.NormalText })
    W.AddTo(diag, els.diag)

    local dumps = W.Section(page, Lang.T("info.title.dumps"))
    local ids = { "info.dump.objects", "info.dump.sdk", "info.dump.usmap" }
    for _, id in ipairs(ids) do
        W.AddTo(dumps, W.Button(dumps, Lang.T(id), function()
            Actions.Run(ctx, id)
        end), { Bottom = 3 })
    end

    els.loglevel = W.TextBlock(dumps, "", { size = Theme.Fonts.Small, color = Theme.Colors.MutedText })
    W.AddTo(dumps, els.loglevel, { Top = 4 })
end

function Tab.Refresh(ctx)
    if Guard.IsValid(els.versions or nil) then
        local ue4ss = "?"
        pcall(function()
            local major, minor, hotfix = UE4SS.GetVersion()
            ue4ss = string.format("%d.%d.%d", major or 0, minor or 0, hotfix or 0)
        end)
        local engineVer = "?"
        pcall(function()
            engineVer = string.format("%d.%d", UnrealVersion:GetMajor(), UnrealVersion:GetMinor())
        end)
        els.versions:UpdateText(string.format("%s v%s  |  UE4SS %s  |  UE %s",
            Lang.T("menu.title"), tostring(ctx.Version), ue4ss, engineVer))
    end

    if Guard.IsValid(els.diag or nil) then
        local gi = Engine.GameInstance()
        local session = Engine.GameSession()
        local save = Engine.PlayerSave()
        local cm = Engine.CheatManager()
        local lines = {
            availabilityLine("GameInstance", gi),
            availabilityLine("GameSession", session),
            availabilityLine("PlayerSave", save),
            availabilityLine("CheatManager", cm),
            "Level: " .. tostring(Engine.LevelName() or "?"),
            "Host: " .. tostring(Engine.IsHost()),
        }
        els.diag:UpdateText(table.concat(lines, "\n"))
    end

    if Guard.IsValid(els.loglevel or nil) then
        els.loglevel:UpdateText(Lang.T("info.loglevel") .. ": " .. Log.GetLevel())
    end
end

return Tab
