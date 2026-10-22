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
local W = require("menu.widgets")

local MenuUI = {}

local ctx = nil
local tabDefs = {}
local hud = nil
local rootCanvas = nil
local switcher = nil
local statusText = nil
local tabButtons = {}
local activeTabIndex = 1
local isOpen = false

function MenuUI.Init(context, tabs)
    ctx = context
    tabDefs = tabs
end

function MenuUI.IsOpen()
    return isOpen
end

--- Текст в статус-бар (из любого потока — уходим в game thread).
function MenuUI.SetStatus(text)
    if not Guard.IsValid(statusText) then return end
    local line = tostring(text or "")
    if #line > 160 then line = line:sub(1, 157) .. "..." end
    ExecuteInGameThread(function()
        if Guard.IsValid(statusText) then
            statusText:UpdateText(line)
        end
    end)
end

local function highlightActiveTab()
    for i, btn in ipairs(tabButtons) do
        pcall(function()
            local color = (i == activeTabIndex) and Theme.Colors.TabActive or Theme.Colors.TabInactive
            btn:SetBackgroundColor(Theme.FLinearColor(color.R, color.G, color.B, color.A))
        end)
    end
end

local function selectTab(index)
    if not switcher or not Guard.IsValid(switcher) then return end
    activeTabIndex = index
    pcall(function() switcher:SetActiveWidgetIndex(index - 1) end)
    highlightActiveTab()
    local tab = tabDefs[index]
    if tab and tab.Refresh then
        local ok, err = pcall(tab.Refresh, ctx)
        if not ok then Log.Warn("tab refresh failed: " .. tostring(err)) end
    end
end

--- Построить дерево виджетов. Только game thread.
local function buildHud()
    local gi, giReason = Engine.GameInstance()
    if not gi then
        return false, giReason or "GameInstance not found"
    end

    local ok, err = pcall(function()
        hud = StaticConstructObject(StaticFindObject("/Script/UMG.UserWidget"), gi, FName(W.UniqueName("HUD")))
        hud.WidgetTree = StaticConstructObject(StaticFindObject("/Script/UMG.WidgetTree"), hud, FName(W.UniqueName("Tree")))

        rootCanvas = W.Canvas(hud.WidgetTree)
        hud.WidgetTree.RootWidget = rootCanvas

        -- Размер окна: SizeBox с фиксированными габаритами по центру экрана.
        local size = W.SizeBox(rootCanvas)
        pcall(function()
            size:SetWidthOverride(Theme.Layout.WindowWidth)
            size:SetHeightOverride(Theme.Layout.WindowHeight)
        end)
        W.AddToCanvas(rootCanvas, size, { anchor = { 0.5, 0.5 }, align = { 0.5, 0.5 }, size = { Theme.Layout.WindowWidth, Theme.Layout.WindowHeight } })

        local border = W.Border(size)
        pcall(function()
            border:SetBrushColor(Theme.Colors.WindowBackground)
            border:SetPadding(Theme.Layout.Padding)
        end)
        pcall(function() size:SetContent(border) end)

        local root = W.VBox(border)
        pcall(function() border:SetContent(root) end)

        -- Шапка: название + версия + кнопка закрытия.
        local header = W.HBox(root)
        local title = W.TextBlock(header, string.format("%s  v%s", Lang.T("menu.title"), tostring(ctx.Version)), {
            size = Theme.Fonts.Title, color = Theme.Colors.TitleText,
        })
        W.AddTo(header, title, { Top = 2, Bottom = 6 }, 1.0)
        local closeBtn = W.Button(header, "X", function() MenuUI.Close() end, { size = Theme.Fonts.Normal })
        W.AddTo(header, closeBtn, { Left = 6 })
        W.AddTo(root, header, { Bottom = 4 })

        -- Панель вкладок.
        local tabBar = W.HBox(root)
        tabButtons = {}
        for i, tab in ipairs(tabDefs) do
            local btn = W.Button(tabBar, Lang.T(tab.TitleKey), function() selectTab(i) end, { size = Theme.Fonts.Tab })
            W.AddTo(tabBar, btn, { Right = 3, Bottom = 4 }, 1.0)
            tabButtons[i] = btn
        end
        W.AddTo(root, tabBar, { Bottom = 4 })

        -- Контент: WidgetSwitcher, страница вкладки = ScrollBox с VBox.
        switcher = W.Switcher(root)
        W.AddTo(root, switcher, { Bottom = 4 }, 1.0)
        for _, tab in ipairs(tabDefs) do
            local scroll = W.ScrollBox(switcher)
            pcall(function() switcher:AddChild(scroll) end)
            local page = W.VBox(scroll)
            pcall(function() scroll:AddChild(page) end)
            if tab.Build then
                tab.Build(page, ctx)
            end
        end

        -- Статус-бар.
        statusText = W.TextBlock(root, Lang.T("menu.ready"), { size = Theme.Fonts.Small, color = Theme.Colors.StatusText })
        W.AddTo(root, statusText, { Top = 2 })

        hud:AddToViewport(99)
        W.SetVisible(rootCanvas, false)
    end)

    if not ok then
        hud = nil
        rootCanvas = nil
        switcher = nil
        statusText = nil
        tabButtons = {}
        return false, tostring(err)
    end

    selectTab(1)
    return true
end

local function setInput(inMenu)
    local pc = Engine.PlayerController()
    if not pc then return end
    pcall(function()
        if inMenu then
            UE.UWidgetBlueprintLibrary.SetInputMode_GameAndUI(pc, hud, 0, false)
        else
            UE.UWidgetBlueprintLibrary.SetInputMode_GameOnly(pc)
        end
    end)
    Guard.Set(pc, "bShowMouseCursor", inMenu)
end

local function startRefreshLoop()
    LoopAsync(1000, function()
        if not isOpen then return true end
        local tab = tabDefs[activeTabIndex]
        if tab and tab.Refresh then
            local ok, err = pcall(tab.Refresh, ctx)
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
            if ctx and ctx.OnStatus then ctx.OnStatus("menu build failed: " .. tostring(reason)) end
            return
        end
    end
    W.SetVisible(rootCanvas, true)
    isOpen = true
    setInput(true)
    startRefreshLoop()
    Log.Debug("menu opened")
end

function MenuUI.Close()
    if not isOpen then return end
    isOpen = false
    if Guard.IsValid(rootCanvas) then
        W.SetVisible(rootCanvas, false)
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
    switcher = nil
    statusText = nil
    tabButtons = {}
    Guard.ResetErrorCache()
    State.Session.LevelName = nil
    Log.Fmt("INFO", "menu invalidated on map change (wasOpen=%s)", tostring(wasOpen))
end

return MenuUI
