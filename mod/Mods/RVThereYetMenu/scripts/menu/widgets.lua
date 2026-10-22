--- Widgets — фабрика UMG-виджетов из чистого Lua.
---
--- Приём (проверен сообществом на UE5, SupraTools/ModMenu): объект
--- виджета создаётся StaticConstructObject от класса, найденного
--- StaticFindObject("/Script/UMG.<Class>"), и крепится в дерево вручную:
---   hud.WidgetTree = StaticConstructObject(WidgetTree, hud)
---   root = CanvasPanel; hud.WidgetTree.RootWidget = root
---   child = Border(root-outer); canvas:AddChildToCanvas(child)
---
--- Имена UObject обязаны быть уникальными в пределах outer'а — поэтому
--- все имена генерируются счётчиком (урок ModMenu: два мода с одинаковыми
--- именами ломают друг друга).
---
--- FText в UE5.4+ требует signature-файл FText_Constructor.lua (идёт в
--- нашем наборе установки). Делаем три уровня деградации:
---   FText(s) → UKismetTextLibrary.Conv_StringToText(s) → сырая строка.
local Guard = require("core.guard")
local Log = require("core.log")
local Theme = require("menu.theme")

local Widgets = {}

local nameCounter = 0
local ftextBroken = false

function Widgets.UniqueName(base)
    nameCounter = nameCounter + 1
    return string.format("RVTYM_%s_%d", base or "W", nameCounter)
end

--- Создать виджет класса UMG. classPath — "/Script/UMG.Border" и т.п.
function Widgets.New(classPath, outer, name)
    local widgetClass = StaticFindObject(classPath)
    if widgetClass == nil then
        error("widget class not found: " .. classPath)
    end
    return StaticConstructObject(widgetClass, outer, FName(name or Widgets.UniqueName()))
end

--- FText с деградацией (см. шапку файла).
local ftextWarned = false
function Widgets.Text(raw)
    local text = tostring(raw == nil and "" or raw)
    if not ftextBroken then
        local constructorOk, constructedText = pcall(function() return FText(text) end)
        if constructorOk and constructedText ~= nil then return constructedText end
        ftextBroken = true
    end
    local conversionOk, convertedText = pcall(function()
        return UE.UKismetTextLibrary.Conv_StringToText(text)
    end)
    if conversionOk and convertedText ~= nil then return convertedText end
    if not ftextWarned then
        ftextWarned = true
        Log.Warn("FText unavailable: install ue4ss/UE4SS_Signatures/FText_Constructor.lua (see INSTALL.md). Falling back to raw strings, some texts may render empty.")
    end
    return text
end

function Widgets.SetVisible(widget, visible)
    if not Guard.IsValid(widget) then return end
    widget.Visibility = visible and Theme.Visibility.SelfHitTestInvisible or Theme.Visibility.Collapsed
end

--- Canvas-панель: корень дерева виджетов, дети размещаются слотами с якорями.
function Widgets.Canvas(outer) return Widgets.New("/Script/UMG.CanvasPanel", outer) end

--- Вертикальный бокс; поле Add у возвращённого виджета добавляет ребёнка.
function Widgets.VBox(outer)
    local box = Widgets.New("/Script/UMG.VerticalBox", outer)
    box.Add = function(_, child) return box:AddChildToVerticalBox(child) end
    return box
end

--- Горизонтальный бокс; поле Add у возвращённого виджета добавляет ребёнка.
function Widgets.HBox(outer)
    local box = Widgets.New("/Script/UMG.HorizontalBox", outer)
    box.Add = function(_, child) return box:AddChildToHorizontalBox(child) end
    return box
end

--- Прокручиваемый контейнер для длинных вкладок.
function Widgets.ScrollBox(outer)
    local scrollBox = Widgets.New("/Script/UMG.ScrollBox", outer)
    scrollBox.Add = function(_, child) return scrollBox:AddChild(child) end
    return scrollBox
end

--- Переключатель страниц: по странице на вкладку меню.
function Widgets.Switcher(outer) return Widgets.New("/Script/UMG.WidgetSwitcher", outer) end

--- Бордер: фон и паддинги окна/секций.
function Widgets.Border(outer)
    return Widgets.New("/Script/UMG.Border", outer)
end

--- Бокс фиксированного размера (габариты окна меню).
function Widgets.SizeBox(outer)
    return Widgets.New("/Script/UMG.SizeBox", outer)
end

--- Добавляет child в vertical/horizontal box с паддингом и (опц.) fill.
function Widgets.AddTo(box, child, padding, fillWeight)
    local slot = box:Add(child)
    if slot then
        if padding then
            pcall(function() slot:SetPadding(padding) end)
        end
        if fillWeight then
            pcall(function()
                slot:SetSize({ SizeRule = 1, Value = fillWeight })
            end)
        end
    end
    return slot
end

--- Добавляет child на canvas с якорями/позицией/размером.
function Widgets.AddToCanvas(canvas, child, options)
    options = options or {}
    local slot = canvas:AddChildToCanvas(child)
    if not slot then return nil end
    pcall(function()
        local anchor = options.anchor or { 0, 0 }
        slot:SetAnchors({ Minimum = { X = anchor[1], Y = anchor[2] }, Maximum = { X = anchor[1], Y = anchor[2] } })
        slot:SetAlignment({ X = (options.align or { 0, 0 })[1], Y = (options.align or { 0, 0 })[2] })
        slot:SetPosition({ X = options.x or 0, Y = options.y or 0 })
        if options.autosize ~= false and not options.size then
            slot:SetAutoSize(true)
        end
        if options.size then
            slot:SetSize({ X = options.size[1], Y = options.size[2] })
        end
    end)
    return slot
end

--- Текстовый блок; поле UpdateText меняет текст без пересборки дерева.
function Widgets.TextBlock(outer, text, options)
    options = options or {}
    local textBlock = Widgets.New("/Script/UMG.TextBlock", outer)
    pcall(function()
        textBlock.Font.Size = options.size or Theme.Fonts.Normal
        textBlock:SetText(Widgets.Text(text))
        local color = options.color or Theme.Colors.NormalText
        textBlock:SetColorAndOpacity(Theme.FSlateColor(color.R, color.G, color.B, color.A))
        textBlock:SetShadowOffset({ X = 1, Y = 1 })
        textBlock:SetShadowColorAndOpacity(Theme.FLinearColor(0, 0, 0, 0.6))
        if options.alignment then
            textBlock:SetJustification(options.alignment)
        end
    end)
    textBlock.UpdateText = function(_, newText)
        pcall(function() textBlock:SetText(Widgets.Text(newText)) end)
    end
    return textBlock
end

--- Кнопка с подписью и колбэком. onClick выполняется в контексте
--- delegates UE4SS (вне game thread — вызывающий сам уходит в
--- ExecuteInGameThread через Actions.Run).
function Widgets.Button(outer, label, onClick, options)
    options = options or {}
    local button = Widgets.New("/Script/UMG.Button", outer)
    pcall(function()
        local style = button.WidgetStyle or nil
        if style then
            -- Normal/Tinted — базовые состояния; hovered/pressed оставим
            -- движку, чтобы не бороться со стилями вслепую.
            style.Normal.TintColor = Theme.FSlateColor(
                (options.background or Theme.Colors.ButtonBackground).R,
                (options.background or Theme.Colors.ButtonBackground).G,
                (options.background or Theme.Colors.ButtonBackground).B, 1.0)
        end
    end)

    local content = Widgets.HBox(button)
    pcall(function() button:SetContent(content) end)

    local labelText = Widgets.TextBlock(content, label, {
        size = options.size or Theme.Fonts.Normal,
        color = options.color or Theme.Colors.NormalText,
    })
    Widgets.AddTo(content, labelText, { Left = 8, Top = 4, Right = 8, Bottom = 4 })

    local bindOk, bindError = pcall(function()
        button.OnClicked:Add(function()
            if onClick then onClick() end
        end)
    end)
    if not bindOk then
        Log.Warn("button delegate bind failed: " .. tostring(bindError))
    end

    button.SetLabel = function(_, newText) labelText:UpdateText(newText) end
    return button
end

--- Чекбокс с подписью и колбэком onToggle(isChecked).
function Widgets.Checkbox(outer, label, initial, onToggle)
    local checkbox = Widgets.New("/Script/UMG.CheckBox", outer)
    pcall(function() checkbox:SetIsChecked(initial == true) end)

    local row = Widgets.HBox(outer)
    Widgets.AddTo(row, checkbox, { Right = 6 })
    local labelText = Widgets.TextBlock(row, label)
    Widgets.AddTo(row, labelText, { Top = 2 })

    pcall(function()
        checkbox.OnCheckStateChanged:Add(function(checked)
            if onToggle then onToggle(checked == true) end
        end)
    end)
    row.SetLabel = function(_, newText) labelText:UpdateText(newText) end
    row.Checkbox = checkbox
    return row
end

--- Слайдер min..max с подписью-значением. onChange(numberValue).
function Widgets.Slider(outer, label, min, max, value, onChange)
    local row = Widgets.HBox(outer)
    local valueText = Widgets.TextBlock(row, string.format("%s: %s", label, tostring(value)))
    Widgets.AddTo(row, valueText, { Right = 8, Top = 4 }, 0.45)

    local slider = Widgets.New("/Script/UMG.Slider", row)
    pcall(function()
        slider:SetMinValue(min)
        slider:SetMaxValue(max)
        slider:SetValue(value)
    end)
    Widgets.AddTo(row, slider, { Top = 6, Bottom = 6 }, 0.55)

    pcall(function()
        slider.OnValueChanged:Add(function(newValue)
            local roundedValue = math.floor((tonumber(newValue) or value) + 0.5)
            valueText:UpdateText(string.format("%s: %d", label, roundedValue))
            if onChange then onChange(roundedValue) end
        end)
    end)
    row.Slider = slider
    return row
end

--- Секция: заголовок + бордер-контейнер (VBox внутри).
function Widgets.Section(outer, title)
    local box = Widgets.VBox(outer)
    local header = Widgets.TextBlock(box, title, { size = Theme.Fonts.Section, color = Theme.Colors.TitleText })
    Widgets.AddTo(box, header, { Top = Theme.Layout.SectionSpacing, Bottom = 2 })

    local border = Widgets.Border(box)
    pcall(function()
        border:SetBrushColor(Theme.Colors.SectionBackground)
        border:SetPadding(Theme.Layout.Padding)
    end)
    Widgets.AddTo(box, border, { Bottom = 2 })

    local content = Widgets.VBox(border)
    pcall(function() border:SetContent(content) end)
    return content
end

--- Двухступенчатая кнопка для деструктивных действий: первый клик
--- «взводит» подпись, второй (в пределах armSeconds) — исполняет.
function Widgets.DangerButton(outer, label, confirmLabel, onClick, armSeconds)
    local armed = false
    local button
    button = Widgets.Button(outer, label, function()
        if not armed then
            armed = true
            button:SetLabel(confirmLabel)
            ExecuteWithDelay((armSeconds or 3) * 1000, function()
                if armed then
                    armed = false
                    button:SetLabel(label)
                end
            end)
        else
            armed = false
            button:SetLabel(label)
            if onClick then onClick() end
        end
    end, { background = Theme.Colors.DangerousBackground })
    return button
end

return Widgets
