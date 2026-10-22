-- Тесты чистой Lua-логики мода (аналог CheatStateTests/ProtocolTests из
-- RiskOfRainMenu). Запускаются без UE4SS и без игры:
--   lua5.4 tests/lua/run_tests.lua
-- Проверяют контракты, от которых зависит рантайм: парсинг/клампы
-- конфига, деградацию локализации, семантику State (original-зеркала),
-- полноту реестра действий и наличие переводов для каждого labelKey.

local here = debug.getinfo(1, "S").source:match("@?(.*)[\\/]run_tests%.lua$") or "."
local MOD = here .. "/../../mod/Mods/RVThereYetMenu"
package.path = MOD .. "/scripts/?.lua;" .. MOD .. "/scripts/?/init.lua;" .. package.path

local passed, failed = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("[PASS] " .. name)
    else
        failed = failed + 1
        print("[FAIL] " .. name .. ": " .. tostring(err))
    end
end

local function eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", msg or "eq", tostring(expected), tostring(actual)), 2)
    end
end

local function truthy(value, msg)
    if not value then error((msg or "truthy") .. ": got " .. tostring(value), 2) end
end

--- Config: парсинг секций, клампы, bool-слова, дефолты, save/load roundtrip.

local Config = require("core.config")

test("config: parse sections and keys", function()
    local data = Config._parse(table.concat({
        "; comment",
        "# comment",
        "[Menu]",
        "ToggleKey = f5",
        "Language=en",
        "",
        "[Session]",
        "MaxPlayers = 12",
        "AutoApplySlots = false",
    }, "\n"))
    eq(data.Menu.ToggleKey, "f5", "ToggleKey")
    eq(data.Menu.Language, "en", "Language")
    eq(data.Session.MaxPlayers, "12", "MaxPlayers raw string")
    eq(data.Session.AutoApplySlots, "false", "AutoApplySlots raw string")
end)

test("config: clamps MaxPlayers into 1..24", function()
    eq(Config._normalize({ Session = { MaxPlayers = "99" } }).MaxPlayers, 24, "upper clamp")
    eq(Config._normalize({ Session = { MaxPlayers = "0" } }).MaxPlayers, 1, "lower clamp")
    eq(Config._normalize({ Session = { MaxPlayers = "abc" } }).MaxPlayers, 8, "fallback default")
    eq(Config._normalize({ Session = { MaxPlayers = "7.6" } }).MaxPlayers, 7, "floor")
end)

test("config: defaults on empty input", function()
    local cfg = Config._normalize({})
    eq(cfg.ToggleKey, "INSERT", "ToggleKey default")
    eq(cfg.Language, "ru", "Language default")
    eq(cfg.MaxPlayers, 8, "MaxPlayers default")
    eq(cfg.AutoApplySlots, true, "AutoApplySlots default")
    eq(cfg.LogLevel, "INFO", "LogLevel default")
end)

test("config: bool parsing", function()
    eq(Config._normalize({ Session = { AutoApplySlots = "no" } }).AutoApplySlots, false, "no")
    eq(Config._normalize({ Session = { AutoApplySlots = "0" } }).AutoApplySlots, false, "0")
    eq(Config._normalize({ Session = { AutoApplySlots = "yes" } }).AutoApplySlots, true, "yes")
    eq(Config._normalize({ Session = { AutoApplySlots = "garbage" } }).AutoApplySlots, true, "fallback true")
end)

test("config: save/load roundtrip", function()
    local path = os.tmpname()
    local cfg = Config._normalize({ Session = { MaxPlayers = "16" }, Menu = { Language = "en" } })
    truthy(Config.Save(path, cfg), "save ok")
    local loaded = Config.Load(path)
    eq(loaded.MaxPlayers, 16, "MaxPlayers roundtrip")
    eq(loaded.Language, "en", "Language roundtrip")
    os.remove(path)
end)

test("config: missing file degrades to defaults", function()
    local cfg = Config.Load("/nonexistent/config.ini")
    eq(cfg.MaxPlayers, Config.DEFAULTS.Session.MaxPlayers, "default cap")
end)

--- Lang: перевод, деградация пустой строки в fallback, format-аргументы.

local Lang = require("core.lang")

test("lang: load tsv, translate, fallback, format", function()
    local path = os.tmpname()
    local f = io.open(path, "w")
    f:write(table.concat({
        "key\tru\ten",
        "# comment line",
        "greeting\tПривет, %s!\tHello, %s!",
        "empty.ru\t\tOnly English",
        "missing.row\tТолько русский\t",
    }, "\n"))
    f:close()

    truthy(Lang.Load(path, "ru"), "load ok")
    eq(Lang.T("greeting", "мир"), "Привет, мир!", "ru translation with format")
    Lang.SetLanguage("en")
    eq(Lang.T("greeting", "world"), "Hello, world!", "en translation")
    eq(Lang.T("empty.ru"), "Only English", "empty ru falls back to en")
    eq(Lang.T("no.such.key"), "no.such.key", "unknown key degrades to key")
    Lang.SetLanguage("ru")
    eq(Lang.T("missing.row"), "Только русский", "empty en does not break ru")
    os.remove(path)
end)

--- State: флаги, original-зеркала, метрики ok/fail.

local State = require("core.state")

test("state: flags default false, set/get", function()
    State.Reset()
    eq(State.GetFlag("godmode"), false, "default flag")
    State.SetFlag("godmode", true)
    eq(State.GetFlag("godmode"), true, "flag set")
    State.SetFlag("godmode", nil)
    eq(State.GetFlag("godmode"), false, "flag cleared by nil")
end)

test("state: mirror keeps first original", function()
    State.Reset()
    State.Mirror("GameSession.MaxPlayers", 8, 4)
    State.Mirror("GameSession.MaxPlayers", 12, 8) -- повторное применение
    local m = State.GetMirror("GameSession.MaxPlayers")
    eq(m.applied, 12, "applied updated")
    eq(m.original, 4, "original preserved from first write")
end)

test("state: metrics counters", function()
    State.Reset()
    State.Count("X", true)
    State.Count("X", true)
    State.Count("X", false)
    eq(State.Metrics.X.ok, 2, "ok count")
    eq(State.Metrics.X.fail, 1, "fail count")
end)

--- Refs: форма данных - /Game/-пути, идентификаторы, префиксы тегов.

local Refs = require("core.refs")

test("refs: game assets are /Game/ paths", function()
    local n = 0
    for key, path in pairs(Refs.Assets) do
        truthy(type(path) == "string" and path:match("^/Game/"), "asset " .. key .. " = " .. tostring(path))
        n = n + 1
    end
    truthy(n >= 10, "asset count " .. n)
end)

test("refs: members are non-empty identifiers", function()
    for owner, members in pairs(Refs.Members) do
        for _, name in ipairs(members) do
            truthy(type(name) == "string" and name ~= "" and not name:match("%s"),
                owner .. " member: " .. tostring(name))
        end
    end
    truthy(Refs.Members.BP_CheatManager and #Refs.Members.BP_CheatManager >= 20, "cheat manager members")
end)

test("refs: cosmetic/level tags", function()
    for _, tag in ipairs(Refs.CosmeticTags) do
        truthy(tag:match("^Cosmetic%."), "cosmetic tag " .. tag)
    end
    for _, tag in ipairs(Refs.LevelTags) do
        truthy(tag:match("^Level%."), "level tag " .. tag)
    end
end)

--- Actions: полнота реестра, labelKey/вкладки в lang.tsv, dangerous-флаги.

truthy(Lang.Load(MOD .. "/lang/lang.tsv", "ru"), "real lang.tsv loads")
local Actions = require("actions")
Actions.RegisterDefaults()

test("actions: registry populated with expected ids", function()
    local expected = {
        "session.apply", "session.release",
        "unlocks.cosmetics", "unlocks.tapes", "unlocks.checkpoint",
        "vehicle.repair.all", "vehicle.drive.winnebago", "vehicle.drive.jetski",
        "vehicle.winch.grab", "vehicle.winch.reset.rear",
        "vehicle.studs.add", "vehicle.studs.wear",
        "run.tp.checkpoint", "run.tp.playerstart", "run.golf.balltoaim",
        "run.wp.save.1", "run.wp.apply.3",
        "players.epipens", "players.removeinactive", "players.damageall", "players.ignoreattached",
        "info.dump.objects", "info.dump.sdk", "info.dump.usmap",
    }
    for _, id in ipairs(expected) do
        truthy(Actions.Registry[id] ~= nil, "missing action " .. id)
    end
end)

test("actions: every def has labelKey and run()", function()
    local n = 0
    for id, def in pairs(Actions.Registry) do
        truthy(type(def.labelKey) == "string" and def.labelKey ~= "", id .. ": labelKey")
        truthy(type(def.run) == "function", id .. ": run()")
        n = n + 1
    end
    truthy(n >= 25, "action count " .. n)
end)

test("actions: labelKeys and tab keys exist in lang.tsv (ru and en)", function()
    local t = Lang._table()
    local missing = {}
    for id, def in pairs(Actions.Registry) do
        if not t[def.labelKey] then missing[#missing + 1] = id .. "->" .. def.labelKey end
    end
    -- way-point-кнопки используют общие ключи с суффиксом слота в UI:
    -- run.wp.save/run.wp.apply обязаны существовать.
    for _, key in ipairs({ "run.wp.save", "run.wp.apply", "players.confirm", "menu.title" }) do
        if not t[key] then missing[#missing + 1] = key end
    end
    for _, tabKey in ipairs({ "tab.session", "tab.unlocks", "tab.vehicle", "tab.run", "tab.players", "tab.info" }) do
        if not t[tabKey] then missing[#missing + 1] = tabKey end
    end
    eq(#missing, 0, "missing lang keys: " .. table.concat(missing, ", "))
    for _, entry in pairs(t) do
        truthy(entry.ru ~= nil and entry.en ~= nil, "entry has ru+en")
    end
end)

test("actions: dangerous flags", function()
    eq(Actions.Registry["players.damageall"].dangerous, true, "damageall is dangerous")
    eq(Actions.Registry["session.apply"].dangerous, nil, "apply is not dangerous")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
