--- MenuUI — главное окно трейнера (аналог MenuUI из RiskOfRainMenu).
---
--- Окно строится лениво при первом открытии и только в game thread:
--- UUserWidget создаётся вручную (StaticConstructObject + WidgetTree,
--- приём SupraTools), живёт на GameInstance и переживает смену уровня;
--- на LoadMap дерево сбрасывается (Invalidate) и пересобирается — так
--- дешевле, чем искать протухшие виджеты.
---
--- Вкладки — декларативные модули { Id, TitleKey, Build, Refresh }.
--- Refresh активного таба вызывается раз в секунду, пока меню открыто
--- (LoopAsync останавливается возвратом true).
local Guard = require("core.guard")
local Log = require("core.log")
local Lang = require("core.lang")
local State = require("core.state")
local Engine = require("core.engine")
local Theme = require("menu.theme")
local Widgets = require("menu.widgets")

local MenuUI = {}

local context = nil
local tabDefinitions = {}
local hud = nil
local rootCanvas = nil
local tabSwitcher = nil
local statusText = nil
local tabButtons = {}
local activeTabIndex = 1
local isOpen = false

function MenuUI.Init(appContext, tabs)
    context = appContext
    tabDefinitions = tabs
end

function MenuUI.IsOpen()
    return isOpen
end

--- Текст в статус-бар (из любого потока — уходим в game thread).
function MenuUI.SetStatus(text)
    if not Guard.IsValid(statusText) then return end
    local truncated = tostring(text or "")
    if #truncated > 160 then truncated = truncated:sub(1, 157) .. "..." end
    ExecuteInGameThread(function()
        if Guard.IsValid(statusText) then
            statusText:UpdateText(truncated)
        end
    end)
end

local function highlightActiveTab()
    for index, button in ipairs(tabButtons) do
        pcall(function()
            local color = (index == activeTabIndex) and Theme.Colors.TabActive or Theme.Colors.TabInactive
            button:SetBackgroundColor(Theme.FLinearColor(color.R, color.G, color.B, color.A))
        end)
    end
end

local function selectTab(index)
    if not tabSwitcher or not Guard.IsValid(tabSwitcher) then return end
    activeTabIndex = index
    pcall(function() tabSwitcher:SetActiveWidgetIndex(index - 1) end)
    highlightActiveTab()
    local tab = tabDefinitions[index]
    if tab and tab.Refresh then
        local ok, err = pcall(tab.Refresh, context)
        if not ok then Log.Warn("tab refresh failed: " .. tostring(err)) end
    end
end

--- Построить дерево виджетов. Только game thread.
local function buildHud()
    local gameInstance, reason = Engine.GameInstance()
    if not gameInstance then
        return false, reason or "GameInstance not found"
    end

    local ok, err = pcall(function()
        hud = StaticConstructObject(StaticFindObject("/Script/UMG.UserWidget"), gameInstance, FName(Widgets.UniqueName("HUD")))
        hud.WidgetTree = StaticConstructObject(StaticFindObject("/Script/UMG.WidgetTree"), hud, FName(Widgets.UniqueName("Tree")))

        rootCanvas = Widgets.Canvas(hud.WidgetTree)
        hud.WidgetTree.RootWidget = rootCanvas

        -- Размер окна: SizeBox с фиксированными габаритами по центру экрана.
        local windowBox = Widgets.SizeBox(rootCanvas)
        pcall(function()
            windowBox:SetWidthOverride(Theme.Layout.WindowWidth)
            windowBox:SetHeightOverride(Theme.Layout.WindowHeight)
        end)
        Widgets.AddToCanvas(rootCanvas, windowBox, { anchor = { 0.5, 0.5 }, align = { 0.5, 0.5 }, size = { Theme.Layout.WindowWidth, Theme.Layout.WindowHeight } })

        local border = Widgets.Border(windowBox)
        pcall(function()
            border:SetBrushColor(Theme.Colors.WindowBackground)
            border:SetPadding(Theme.Layout.Padding)
        end)
        pcall(function() windowBox:SetContent(border) end)

        local rootBox = Widgets.VBox(border)
        pcall(function() border:SetContent(rootBox) end)

        -- Шапка: название + версия + кнопка закрытия.
        local header = Widgets.HBox(rootBox)
        local title = Widgets.TextBlock(header, string.format("%s  v%s", Lang.T("menu.title"), tostring(context.Version)), {
            size = Theme.Fonts.Title, color = Theme.Colors.TitleText,
        })
        Widgets.AddTo(header, title, { Top = 2, Bottom = 6 }, 1.0)
        local closeButton = Widgets.Button(header, "X", function() MenuUI.Close() end, { size = Theme.Fonts.Normal })
        Widgets.AddTo(header, closeButton, { Left = 6 })
        Widgets.AddTo(rootBox, header, { Bottom = 4 })

        -- Панель вкладок.
        local tabBar = Widgets.HBox(rootBox)
        tabButtons = {}
        for index, tab in ipairs(tabDefinitions) do
            local button = Widgets.Button(tabBar, Lang.T(tab.TitleKey), function() selectTab(index) end, { size = Theme.Fonts.Tab })
            Widgets.AddTo(tabBar, button, { Right = 3, Bottom = 4 }, 1.0)
            tabButtons[index] = button
        end
        Widgets.AddTo(rootBox, tabBar, { Bottom = 4 })

        -- Контент: WidgetSwitcher, страница вкладки = ScrollBox с VBox.
        tabSwitcher = Widgets.Switcher(rootBox)
        Widgets.AddTo(rootBox, tabSwitcher, { Bottom = 4 }, 1.0)
        for _, tab in ipairs(tabDefinitions) do
            local scrollBox = Widgets.ScrollBox(tabSwitcher)
            pcall(function() tabSwitcher:AddChild(scrollBox) end)
            local page = Widgets.VBox(scrollBox)
            pcall(function() scrollBox:AddChild(page) end)
            if tab.Build then
                tab.Build(page, context)
            end
        end

        -- Статус-бар.
        statusText = Widgets.TextBlock(rootBox, Lang.T("menu.ready"), { size = Theme.Fonts.Small, color = Theme.Colors.StatusText })
        Widgets.AddTo(rootBox, statusText, { Top = 2 })

        hud:AddToViewport(99)
        Widgets.SetVisible(rootCanvas, false)
    end)

    if not ok then
        hud = nil
        rootCanvas = nil
        tabSwitcher = nil
        statusText = nil
        tabButtons = {}
        return false, tostring(err)
    end

    selectTab(1)
    return true
end

local function setInput(inMenu)
    local playerController = Engine.PlayerController()
    if not playerController then return end
    pcall(function()
        if inMenu then
            UE.UWidgetBlueprintLibrary.SetInputMode_GameAndUI(playerController, hud, 0, false)
        else
            UE.UWidgetBlueprintLibrary.SetInputMode_GameOnly(playerController)
        end
    end)
    Guard.Set(playerController, "bShowMouseCursor", inMenu)
end

local function startRefreshLoop()
    LoopAsync(1000, function()
        if not isOpen then return true end
        local tab = tabDefinitions[activeTabIndex]
        if tab and tab.Refresh then
            local ok, err = pcall(tab.Refresh, context)
            if not ok then Log.Debug("refresh failed: " .. tostring(err)) end
        end
        return false
    end)
end

function MenuUI.Open()
    if isOpen then return end
    if not Guard.IsValid(hud) then
        local ok, reason = buildHud()
        if not ok then
            Log.Warn("menu build failed: " .. tostring(reason))
            if context and context.OnStatus then context.OnStatus("menu build failed: " .. tostring(reason)) end
            return
        end
    end
    Widgets.SetVisible(rootCanvas, true)
    isOpen = true
    setInput(true)
    startRefreshLoop()
    Log.Debug("menu opened")
end

function MenuUI.Close()
    if not isOpen then return end
    isOpen = false
    if Guard.IsValid(rootCanvas) then
        Widgets.SetVisible(rootCanvas, false)
    end
    setInput(false)
    Log.Debug("menu closed")
end

function MenuUI.Toggle()
    if isOpen then MenuUI.Close() else MenuUI.Open() end
end

--- Сброс после смены уровня: виджеты и объекты мира пересозданы,
--- старые ссылки недействительны. Флаги/зеркала State сохраняются —
--- уровневую защиту несут сами waypoint-ы (сверяют LevelName).
function MenuUI.Invalidate()
    local wasOpen = isOpen
    isOpen = false
    hud = nil
    rootCanvas = nil
    tabSwitcher = nil
    statusText = nil
    tabButtons = {}
    Guard.ResetErrorCache()
    State.Session.LevelName = nil
    Log.Fmt("INFO", "menu invalidated on map change (wasOpen=%s)", tostring(wasOpen))
end

return MenuUI
