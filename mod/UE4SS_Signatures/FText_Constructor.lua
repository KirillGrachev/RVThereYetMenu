-- FText constructor signature for UE 5.4+ (RV There Yet? runs UE 5.6).
--
-- Без этой сигнатуры FText(...) в Lua падает, и весь текст UMG-виджетов
-- не создаётся. Файл кладётся в ue4ss/UE4SS_Signatures/ (рядом с папкой
-- Mods). Сигнатура — из проверенного примера SupraTools (joric), который
-- рекомендован командой UE4SS как образец чисто-Lua виджетов.
-- AOB универсален для UE 5.4/5.5/5.6 (пролог FText::FText(const FString&)).

function Register()
    return "40 53 57 48 83 EC 38 48 89 6C 24 ?? 48 8B FA 48 89 74 24 ?? 48 8B D9 33 F6 4C 89 74 24 30 ?? ?? ?? ?? ?? ?? ?? ?? 7F ?? E8 ?? ?? 00 00 48 8B F0"
end

function OnMatchFound(MatchAddress)
    return MatchAddress
end
