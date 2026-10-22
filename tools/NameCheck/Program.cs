// NameCheck — валидатор reflection-имён мода (аналог GameRefsTests из
// RiskOfRainMenu, который сверял Harmony-цели с игровой сборкой).
//
// Источник истины мода — scripts/core/refs.lua. Инструмент парсит его
// секции и сверяет каждое имя с офлайн-данными игры:
//   --assets   assets.txt от tools/AssetIndex (пакеты IoStore);
//   --dumps    каталог name-batch дампов от tools/AssetDump;
//   --object-dump UE4SS_ObjectDump.txt / CXXHeaderDump-склейка (опц.):
//              по нему дополнительно проверяются движковые имена
//              (без него они попадают в статус ENGINE = whitelist).
//
// Статусы: OK / ENGINE / UNKNOWN. Наличие UNKNOWN -> exit 1.
//
// Использование:
//   NameCheck --refs <refs.lua> --assets <assets.txt> --dumps <dir>
//             [--object-dump <file>] [--quiet]
using System.Text;
using System.Text.RegularExpressions;

namespace NameCheck;

public static class RefsParser
{
    /// Одна строковая константа refs.lua в контексте секции/владельца.
    public sealed record RefString(string Section, string? Owner, string Value);

    /// Достаёт содержимое блока `name = {` ... `}` с учётом вложенности.
    public static string? ExtractBlock(string text, string name)
    {
        var start = text.IndexOf(name + " = {", StringComparison.Ordinal);
        if (start < 0) return null;
        var i = text.IndexOf('{', start);
        var depth = 0;
        for (var j = i; j < text.Length; j++)
        {
            if (text[j] == '{') depth++;
            else if (text[j] == '}')
            {
                depth--;
                if (depth == 0) return text[(i + 1)..j];
            }
        }
        return null;
    }

    /// Все строковые литералы блока.
    public static IEnumerable<string> Strings(string block) =>
        Regex.Matches(block, "\"([^\"]+)\"").Select(m => m.Groups[1].Value);

    /// Парсит refs.lua в плоский список (секция, владелец, значение).
    /// Секции: Assets, EngineClasses, Hooks(+вложенные), ShortClasses,
    /// Members (владелец = ключ подблока), CosmeticTags, LevelTags.
    public static List<RefString> Parse(string refsText)
    {
        var result = new List<RefString>();

        void AddPlain(string section, string blockName)
        {
            var block = ExtractBlock(refsText, blockName);
            if (block == null) return;
            foreach (var s in Strings(block))
                result.Add(new RefString(section, null, s));
        }

        AddPlain("Assets", "Refs.Assets");
        AddPlain("EngineClasses", "Refs.EngineClasses");
        AddPlain("ShortClasses", "Refs.ShortClasses");
        AddPlain("CosmeticTags", "Refs.CosmeticTags");
        AddPlain("LevelTags", "Refs.LevelTags");

        var hooks = ExtractBlock(refsText, "Refs.Hooks");
        if (hooks != null)
            foreach (var s in Strings(hooks))
                result.Add(new RefString("Hooks", null, s));

        var members = ExtractBlock(refsText, "Refs.Members");
        if (members != null)
        {
            foreach (Match m in Regex.Matches(members, "(\\w+)\\s*=\\s*\\{"))
            {
                var owner = m.Groups[1].Value;
                var ownerBlock = ExtractBlock(members, owner);
                if (ownerBlock == null) continue;
                foreach (var s in Strings(ownerBlock))
                    result.Add(new RefString("Members", owner, s));
            }
        }

        return result;
    }
}

public static class Program
{
    /// Владельцы-движковые классы: их члены не видны в ассет-дампах
    /// (классы живут в exe) — до object-dump проверяются по whitelist.
    private static readonly Dictionary<string, HashSet<string>> EngineMembers = new()
    {
        ["GameSession"] = new() { "MaxPlayers" },
        ["PlayerController"] = new() { "CheatManager", "PlayerState", "Pawn", "bShowMouseCursor" },
    };

    private static readonly HashSet<string> EngineShortClasses = new()
    {
        "GameInstance", "GameSession", "PlayerController", "PlayerState", "CheatManager",
    };

    public static int Main(string[] args)
    {
        string? refsPath = null, assetsPath = null, dumpsDir = null, objectDumpPath = null;
        var quiet = false;

        for (var i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--refs": refsPath = args[++i]; break;
                case "--assets": assetsPath = args[++i]; break;
                case "--dumps": dumpsDir = args[++i]; break;
                case "--object-dump": objectDumpPath = args[++i]; break;
                case "--quiet": quiet = true; break;
            }
        }

        if (refsPath == null)
        {
            Console.Error.WriteLine("usage: NameCheck --refs <refs.lua> --assets <assets.txt> --dumps <dir> [--object-dump <file>]");
            return 2;
        }
        if (!File.Exists(refsPath))
        {
            Console.Error.WriteLine($"refs not found: {refsPath}");
            return 2;
        }

        // Источники валидации.
        var assets = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        if (assetsPath != null && File.Exists(assetsPath))
            foreach (var line in File.ReadAllLines(assetsPath))
                assets.Add(line.Trim());

        var dumpNames = new HashSet<string>(StringComparer.Ordinal);
        var dumpsByOwner = new Dictionary<string, HashSet<string>>(StringComparer.Ordinal);
        if (dumpsDir != null && Directory.Exists(dumpsDir))
        {
            foreach (var file in Directory.GetFiles(dumpsDir, "*.txt"))
            {
                var set = new HashSet<string>(StringComparer.Ordinal);
                foreach (var line in File.ReadAllLines(file))
                {
                    var name = line.Trim();
                    if (name.Length == 0 || name.StartsWith('#')) continue;
                    set.Add(name);
                    dumpNames.Add(name);
                }
                dumpsByOwner[Path.GetFileNameWithoutExtension(file)] = set;
            }
        }

        string? objectDump = null;
        if (objectDumpPath != null && File.Exists(objectDumpPath))
            objectDump = File.ReadAllText(objectDumpPath);

        if (assets.Count == 0 && dumpNames.Count == 0 && objectDump == null)
        {
            Console.Error.WriteLine("no validation sources found (assets/dumps/object-dump empty) - nothing to check against");
            return 2;
        }

        var refs = RefsParser.Parse(File.ReadAllText(refsPath));
        if (refs.Count == 0)
        {
            Console.Error.WriteLine("refs.lua parsed to zero strings - format changed?");
            return 2;
        }

        var ok = 0;
        var engine = 0;
        var unknown = new List<string>();

        foreach (var r in refs)
        {
            var status = Check(r, assets, dumpNames, dumpsByOwner, objectDump);
            switch (status)
            {
                case "OK": ok++; break;
                case "ENGINE": engine++; break;
                default: unknown.Add($"{r.Section}{(r.Owner != null ? "." + r.Owner : "")}: {r.Value}"); break;
            }
        }

        if (!quiet)
        {
            Console.WriteLine($"refs strings : {refs.Count}");
            Console.WriteLine($"OK           : {ok}");
            Console.WriteLine($"ENGINE (w/l) : {engine}");
            Console.WriteLine($"UNKNOWN      : {unknown.Count}");
            foreach (var u in unknown)
                Console.WriteLine("  UNKNOWN " + u);
        }

        return unknown.Count == 0 ? 0 : 1;
    }

    private static string Check(RefsParser.RefString r,
        HashSet<string> assets,
        HashSet<string> dumpNames,
        Dictionary<string, HashSet<string>> dumpsByOwner,
        string? objectDump)
    {
        switch (r.Section)
        {
            case "Assets":
                // "/Game/Ride/Game/X" -> пакет "Ride/Content/Ride/Game/X.uasset" (или .umap)
            {
                if (!r.Value.StartsWith("/Game/")) return "UNKNOWN";
                var tail = r.Value["/Game/".Length..];
                return assets.Contains("Ride/Content/" + tail + ".uasset")
                       || assets.Contains("Ride/Content/" + tail + ".umap")
                    ? "OK"
                    : "UNKNOWN";
            }

            case "EngineClasses":
            case "Hooks":
                // "/Script/..." и UFunction-сигнатуры движка: без object-dump
                // не проверить — whitelist; с object-dump ищем подстроки.
                if (!r.Value.StartsWith("/Script/")) return "UNKNOWN";
                if (objectDump != null)
                {
                    var parts = r.Value["/Script/".Length..].Split(':', '.');
                    var all = parts.All(p => p.Length == 0 || objectDump.Contains(p, StringComparison.Ordinal));
                    return all ? "OK" : "UNKNOWN";
                }
                return "ENGINE";

            case "ShortClasses":
            {
                if (EngineShortClasses.Contains(r.Value)) return "ENGINE";
                // BP_*_C: базовое имя обязано быть пакетом игры.
                if (r.Value.EndsWith("_C"))
                {
                    var baseName = r.Value[..^2];
                    var found = assets.Any(a => a.EndsWith("/" + baseName + ".uasset", StringComparison.OrdinalIgnoreCase));
                    return found || dumpNames.Contains(r.Value) ? "OK" : "UNKNOWN";
                }
                return dumpNames.Contains(r.Value) ? "OK" : "UNKNOWN";
            }

            case "CosmeticTags":
            case "LevelTags":
                return dumpNames.Contains(r.Value) ? "OK" : "UNKNOWN";

            case "Members":
            {
                var owner = r.Owner ?? "";
                if (EngineMembers.TryGetValue(owner, out var whitelist))
                {
                    if (whitelist.Contains(r.Value))
                        return objectDump != null && objectDump.Contains(r.Value, StringComparison.Ordinal)
                            ? "OK"
                            : "ENGINE";
                    return "UNKNOWN";
                }
                // Игровой владелец: ищем имя в ЕГО дампе (строже), при
                // отсутствии дампа — в объединении всех.
                if (dumpsByOwner.TryGetValue(owner, out var ownerSet) && ownerSet.Contains(r.Value))
                    return "OK";
                return dumpNames.Contains(r.Value) ? "OK" : "UNKNOWN";
            }

            default:
                return "UNKNOWN";
        }
    }
}
