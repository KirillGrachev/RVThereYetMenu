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

local W = {}

local nameCounter = 0
local ftextBroken = false

function W.UniqueName(base)
    nameCounter = nameCounter + 1
    return string.format("RVTYM_%s_%d", base or "W", nameCounter)
end

--- Создать виджет класса UMG. classPath — "/Script/UMG.Border" и т.п.
function W.New(classPath, outer, name)
    local cls = StaticFindObject(classPath)
    if cls == nil then
        error("widget class not found: " .. classPath)
    end
    return StaticConstructObject(cls, outer, FName(name or W.UniqueName()))
end

--- FText с деградацией (см. шапку файла).
local ftextWarned = false
function W.Text(raw)
    local s = tostring(raw == nil and "" or raw)
    if not ftextBroken then
        local ok, ft = pcall(function() return FText(s) end)
        if ok and ft ~= nil then return ft end
        ftextBroken = true
    end
    local ok2, ft2 = pcall(function()
        return UE.UKismetTextLibrary.Conv_StringToText(s)
    end)
    if ok2 and ft2 ~= nil then return ft2 end
    if not ftextWarned then
        ftextWarned = true
        Log.Warn("FText unavailable: install ue4ss/UE4SS_Signatures/FText_Constructor.lua (see INSTALL.md). Falling back to raw strings, some texts may render empty.")
    end
    return s
end

function W.SetVisible(widget, visible)
    if not Guard.IsValid(widget) then return end
    widget.Visibility = visible and Theme.Visibility.SelfHitTestInvisible or Theme.Visibility.Collapsed
end

-- ---------------------------------------------------------------------------
-- Контейнеры
-- ---------------------------------------------------------------------------

function W.Canvas(outer) return W.New("/Script/UMG.CanvasPanel", outer) end

function W.VBox(outer)
    local box = W.New("/Script/UMG.VerticalBox", outer)
    box.Add = function(_, child) return box:AddChildToVerticalBox(child) end
    return box
end

function W.HBox(outer)
    local box = W.New("/Script/UMG.HorizontalBox", outer)
    box.Add = function(_, child) return box:AddChildToHorizontalBox(child) end
    return box
end

function W.ScrollBox(outer)
    local sb = W.New("/Script/UMG.ScrollBox", outer)
    sb.Add = function(_, child) return sb:AddChild(child) end
    return sb
end

function W.Switcher(outer) return W.New("/Script/UMG.WidgetSwitcher", outer) end

function W.Border(outer)
    return W.New("/Script/UMG.Border", outer)
end

function W.SizeBox(outer)
    return W.New("/Script/UMG.SizeBox", outer)
end

--- Добавляет child в vertical/horizontal box с паддингом и (опц.) fill.
function W.AddTo(box, child, padding, fillWeight)
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
function W.AddToCanvas(canvas, child, opts)
    opts = opts or {}
    local slot = canvas:AddChildToCanvas(child)
    if not slot then return nil end
    pcall(function()
        local a = opts.anchor or { 0, 0 }
        slot:SetAnchors({ Minimum = { X = a[1], Y = a[2] }, Maximum = { X = a[1], Y = a[2] } })
        slot:SetAlignment({ X = (opts.align or { 0, 0 })[1], Y = (opts.align or { 0, 0 })[2] })
        slot:SetPosition({ X = opts.x or 0, Y = opts.y or 0 })
        if opts.autosize ~= false and not opts.size then
            slot:SetAutoSize(true)
        end
        if opts.size then
            slot:SetSize({ X = opts.size[1], Y = opts.size[2] })
        end
    end)
    return slot
end

-- ---------------------------------------------------------------------------
-- Примитивы
-- ---------------------------------------------------------------------------

function W.TextBlock(outer, text, opts)
    opts = opts or {}
    local tb = W.New("/Script/UMG.TextBlock", outer)
    pcall(function()
        tb.Font.Size = opts.size or Theme.Fonts.Normal
        tb:SetText(W.Text(text))
        local color = opts.color or Theme.Colors.NormalText
        tb:SetColorAndOpacity(Theme.FSlateColor(color.R, color.G, color.B, color.A))
        tb:SetShadowOffset({ X = 1, Y = 1 })
        tb:SetShadowColorAndOpacity(Theme.FLinearColor(0, 0, 0, 0.6))
        if opts.alignment then
            tb:SetJustification(opts.alignment)
        end
    end)
    tb.UpdateText = function(_, newText)
        pcall(function() tb:SetText(W.Text(newText)) end)
    end
    return tb
end

--- Кнопка с подписью и колбэком. onClick выполняется в контексте
--- delegates UE4SS (вне game thread — вызывающий сам уходит в
--- ExecuteInGameThread через Actions.Run).
function W.Button(outer, label, onClick, opts)
    opts = opts or {}
    local btn = W.New("/Script/UMG.Button", outer)
    pcall(function()
        local style = btn.WidgetStyle or nil
        if style then
            -- Normal/Tinted — базовые состояния; hovered/pressed оставим
            -- движку, чтобы не бороться со стилями вслепую.
            style.Normal.TintColor = Theme.FSlateColor(
                (opts.background or Theme.Colors.ButtonBackground).R,
                (opts.background or Theme.Colors.ButtonBackground).G,
                (opts.background or Theme.Colors.ButtonBackground).B, 1.0)
        end
    end)

    local content = W.HBox(btn)
    pcall(function() btn:SetContent(content) end)

    local tb = W.TextBlock(content, label, {
        size = opts.size or Theme.Fonts.Normal,
        color = opts.color or Theme.Colors.NormalText,
    })
    W.AddTo(content, tb, { Left = 8, Top = 4, Right = 8, Bottom = 4 })

    local okBind, bindErr = pcall(function()
        btn.OnClicked:Add(function()
            if onClick then onClick() end
        end)
    end)
    if not okBind then
        Log.Warn("button delegate bind failed: " .. tostring(bindErr))
    end

    btn.SetLabel = function(_, newText) tb:UpdateText(newText) end
    return btn
end

--- Чекбокс с подписью и колбэком onToggle(isChecked).
function W.Checkbox(outer, label, initial, onToggle)
    local cb = W.New("/Script/UMG.CheckBox", outer)
    pcall(function() cb:SetIsChecked(initial == true) end)

    local row = W.HBox(outer)
    W.AddTo(row, cb, { Right = 6 })
    local tb = W.TextBlock(row, label)
    W.AddTo(row, tb, { Top = 2 })

    pcall(function()
        cb.OnCheckStateChanged:Add(function(checked)
            if onToggle then onToggle(checked == true) end
        end)
    end)
    row.SetLabel = function(_, newText) tb:UpdateText(newText) end
    row.Checkbox = cb
    return row
end

--- Слайдер min..max с подписью-значением. onChange(numberValue).
function W.Slider(outer, label, min, max, value, onChange)
    local row = W.HBox(outer)
    local tb = W.TextBlock(row, string.format("%s: %s", label, tostring(value)))
    W.AddTo(row, tb, { Right = 8, Top = 4 }, 0.45)

    local slider = W.New("/Script/UMG.Slider", row)
    pcall(function()
        slider:SetMinValue(min)
        slider:SetMaxValue(max)
        slider:SetValue(value)
    end)
    W.AddTo(row, slider, { Top = 6, Bottom = 6 }, 0.55)

    pcall(function()
        slider.OnValueChanged:Add(function(v)
            local iv = math.floor((tonumber(v) or value) + 0.5)
            tb:UpdateText(string.format("%s: %d", label, iv))
            if onChange then onChange(iv) end
        end)
    end)
    row.Slider = slider
    return row
end

--- Секция: заголовок + бордер-контейнер (VBox внутри).
function W.Section(outer, title)
    local box = W.VBox(outer)
    local header = W.TextBlock(box, title, { size = Theme.Fonts.Section, color = Theme.Colors.TitleText })
    W.AddTo(box, header, { Top = Theme.Layout.SectionSpacing, Bottom = 2 })

    local border = W.Border(box)
    pcall(function()
        border:SetBrushColor(Theme.Colors.SectionBackground)
        border:SetPadding(Theme.Layout.Padding)
    end)
    W.AddTo(box, border, { Bottom = 2 })

    local content = W.VBox(border)
    pcall(function() border:SetContent(content) end)
    return content
end

--- Двухступенчатая кнопка для деструктивных действий: первый клик
--- «взводит» подпись, второй (в пределах armSeconds) — исполняет.
function W.DangerButton(outer, label, confirmLabel, onClick, armSeconds)
    local armed = false
    local btn
    btn = W.Button(outer, label, function()
        if not armed then
            armed = true
            btn:SetLabel(confirmLabel)
            ExecuteWithDelay((armSeconds or 3) * 1000, function()
                if armed then
                    armed = false
                    btn:SetLabel(label)
                end
            end)
        else
            armed = false
            btn:SetLabel(label)
            if onClick then onClick() end
        end
    end, { background = Theme.Colors.DangerousBackground })
    return btn
end

return W
