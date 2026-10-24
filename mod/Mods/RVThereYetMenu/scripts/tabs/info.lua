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
local Widgets = require("menu.widgets")

local Tab = { Id = "info", TitleKey = "tab.info" }

local ui = {}

local function availabilityLine(label, object)
    return string.format("%s: %s", label, object and "OK" or "--")
end

function Tab.Build(page, context)
    local versions = Widgets.Section(page, Lang.T("info.title.versions"))
    ui.versions = Widgets.TextBlock(versions, "", { size = Theme.Fonts.Small, color = Theme.Colors.MutedText })
    Widgets.AddTo(versions, ui.versions)

    local diag = Widgets.Section(page, Lang.T("info.title.diag"))
    ui.diag = Widgets.TextBlock(diag, "", { size = Theme.Fonts.Small, color = Theme.Colors.NormalText })
    Widgets.AddTo(diag, ui.diag)

    local dumps = Widgets.Section(page, Lang.T("info.title.dumps"))
    local dumpActionIds = { "info.dump.objects", "info.dump.sdk", "info.dump.usmap" }
    for _, id in ipairs(dumpActionIds) do
        Widgets.AddTo(dumps, Widgets.Button(dumps, Lang.T(id), function()
            Actions.Run(context, id)
        end), { Bottom = 3 })
    end

    ui.loglevel = Widgets.TextBlock(dumps, "", { size = Theme.Fonts.Small, color = Theme.Colors.MutedText })
    Widgets.AddTo(dumps, ui.loglevel, { Top = 4 })
end

function Tab.Refresh(context)
    if Guard.IsValid(ui.versions or nil) then
        local ue4ssVersion = "?"
        pcall(function()
            local major, minor, hotfix = UE4SS.GetVersion()
            ue4ssVersion = string.format("%d.%d.%d", major or 0, minor or 0, hotfix or 0)
        end)
        local engineVersion = "?"
        pcall(function()
            engineVersion = string.format("%d.%d", UnrealVersion:GetMajor(), UnrealVersion:GetMinor())
        end)
        Widgets.SetText(ui.versions, string.format("%s v%s  |  UE4SS %s  |  UE %s",
            Lang.T("menu.title"), tostring(context.Version), ue4ssVersion, engineVersion))
    end

    if Guard.IsValid(ui.diag or nil) then
        local gameInstance = Engine.GameInstance()
        local session = Engine.GameSession()
        local save = Engine.PlayerSave()
        local cheatManager = Engine.CheatManager()
        local lines = {
            availabilityLine("GameInstance", gameInstance),
            availabilityLine("GameSession", session),
            availabilityLine("PlayerSave", save),
            availabilityLine("CheatManager", cheatManager),
            "Level: " .. tostring(Engine.LevelName() or "?"),
            "Host: " .. tostring(Engine.IsHost()),
        }
        Widgets.SetText(ui.diag, table.concat(lines, "\n"))
    end

    if Guard.IsValid(ui.loglevel or nil) then
        Widgets.SetText(ui.loglevel, Lang.T("info.loglevel") .. ": " .. Log.GetLevel())
    end
end

return Tab
