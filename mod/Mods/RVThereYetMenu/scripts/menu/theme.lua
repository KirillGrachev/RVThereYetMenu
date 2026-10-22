--- Тема меню: цвета, размеры, отступы (аналог Theme из RiskOfRainMenu).
--- Все значения — данные, виджеты не хардкодят оформление.
local Theme = {}

local function FLinearColor(R, G, B, A) return { R = R, G = G, B = B, A = A } end
local function FSlateColor(R, G, B, A) return { SpecifiedColor = FLinearColor(R, G, B, A), ColorUseRule = 0 } end

Theme.FLinearColor = FLinearColor
Theme.FSlateColor = FSlateColor

Theme.Colors = {
    WindowBackground = FLinearColor(0.06, 0.07, 0.09, 0.94),
    HeaderBackground = FLinearColor(0.10, 0.12, 0.16, 1.0),
    SectionBackground = FLinearColor(0.09, 0.10, 0.13, 1.0),
    TitleText = FLinearColor(0.95, 0.80, 0.30, 1.0),
    NormalText = FLinearColor(0.90, 0.90, 0.92, 1.0),
    MutedText = FLinearColor(0.62, 0.64, 0.68, 1.0),
    StatusText = FLinearColor(0.70, 0.78, 0.70, 1.0),
    ErrorText = FLinearColor(0.95, 0.45, 0.40, 1.0),
    ButtonBackground = FLinearColor(0.16, 0.19, 0.25, 1.0),
    ButtonHovered = FLinearColor(0.22, 0.27, 0.35, 1.0),
    DangerousBackground = FLinearColor(0.30, 0.12, 0.10, 1.0),
    TabActive = FLinearColor(0.24, 0.29, 0.38, 1.0),
    TabInactive = FLinearColor(0.12, 0.13, 0.17, 1.0),
}

Theme.Fonts = {
    Title = 22,
    Tab = 14,
    Section = 15,
    Normal = 13,
    Small = 11,
}

Theme.Layout = {
    WindowWidth = 560.0,
    WindowHeight = 620.0,
    Padding = { Left = 10, Top = 8, Right = 10, Bottom = 8 },
    RowSpacing = 4.0,
    SectionSpacing = 8.0,
    ButtonHeight = 30.0,
}

--- Видимость (ESlateVisibility): виджеты переключаются числами,
--- как в SupraTools (строковые enum-значения в Lua-биндингах ненадёжны).
Theme.Visibility = {
    Visible = 0,
    Collapsed = 1,
    Hidden = 2,
    HitTestInvisible = 3,
    SelfHitTestInvisible = 4,
}

return Theme
