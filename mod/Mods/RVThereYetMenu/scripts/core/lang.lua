--- Локализация: lang/lang.tsv (формат как в RiskOfRainMenu — TSV,
--- колонка ключа + языковые колонки). Первая строка — заголовок:
--- key<TAB>ru<TAB>en. Отсутствие перевода деградирует в английский,
--- отсутствие ключа — в сам ключ, чтобы дырка в переводе была видна в UI.
local Log = require("core.log")

local Lang = {}

local table_ = {}
local language = "ru"
local fallback = "en"

--- Загружает TSV. Файл читается один раз при старте мода.
function Lang.Load(path, lang)
    language = (lang or "ru"):lower()
    table_ = {}
    local file = io.open(path, "r")
    if not file then
        Log.Warn("lang file not found: " .. tostring(path))
        return false
    end

    local columns = nil
    for raw in file:lines() do
        local line = raw:gsub("\r$", "")
        if line ~= "" and not line:match("^#") then
            local cells = {}
            for cell in (line .. "\t"):gmatch("([^\t]*)\t") do
                cells[#cells + 1] = cell
            end
            if not columns then
                columns = cells
            else
                local key = cells[1]
                local entry = {}
                for i = 2, #columns do
                    entry[columns[i]] = cells[i]
                end
                table_[key] = entry
            end
        end
    end
    file:close()

    local count = 0
    for _ in pairs(table_) do count = count + 1 end
    Log.Fmt("INFO", "lang loaded: %d keys, language=%s", count, language)
    return true
end

--- Перевод по ключу. Вторым аргументом можно передать параметры format.
--- Пустая строка в активном языке считается отсутствием перевода и
--- деградирует в fallback-язык (в Lua "" truthy — проверяем явно).
function Lang.T(key, ...)
    local entry = table_[key]
    local text = nil
    if entry then
        text = entry[language]
        if text == nil or text == "" then
            text = entry[fallback]
        end
        if text == "" then
            text = nil
        end
    end
    if text == nil then text = key end
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, text, ...)
        if ok then return formatted end
    end
    return text
end

function Lang.SetLanguage(lang)
    language = (lang or "ru"):lower()
end

function Lang.GetLanguage()
    return language
end

-- Экспорт для тестов.
Lang._table = function() return table_ end

return Lang
