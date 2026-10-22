// NameCheck — валидатор reflection-имён мода (аналог GameRefsTests из
// RiskOfRainMenu, который сверял Harmony-цели с игровой сборкой).
//
// Источник истины мода — scripts/core/refs.lua. Инструмент парсит его
// секции и сверяет каждое имя с офлайн-данными игры:
//   --refs        refs.lua (обязательно);
//   --assets      assets.txt от tools/AssetIndex (пакеты IoStore);
//   --dumps       каталог name-batch дампов от tools/AssetDump;
//   --object-dump UE4SS_ObjectDump.txt / CXXHeaderDump-склейка (опц.):
//                 по нему дополнительно проверяются движковые имена
//                 (без него они попадают в статус ENGINE = whitelist).
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
        var braceIndex = text.IndexOf('{', start);
        var depth = 0;
        for (var scanIndex = braceIndex; scanIndex < text.Length; scanIndex++)
        {
            if (text[scanIndex] == '{') depth++;
            else if (text[scanIndex] == '}')
            {
                depth--;
                if (depth == 0) return text[(braceIndex + 1)..scanIndex];
            }
        }
        return null;
    }

    /// Все строковые литералы блока.
    public static IEnumerable<string> Strings(string block) =>
        Regex.Matches(block, "\"([^\"]+)\"").Select(match => match.Groups[1].Value);

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
            foreach (var value in Strings(block))
                result.Add(new RefString(section, null, value));
        }

        AddPlain("Assets", "Refs.Assets");
        AddPlain("EngineClasses", "Refs.EngineClasses");
        AddPlain("ShortClasses", "Refs.ShortClasses");
        AddPlain("CosmeticTags", "Refs.CosmeticTags");
        AddPlain("LevelTags", "Refs.LevelTags");

        var hooks = ExtractBlock(refsText, "Refs.Hooks");
        if (hooks != null)
            foreach (var value in Strings(hooks))
                result.Add(new RefString("Hooks", null, value));

        var members = ExtractBlock(refsText, "Refs.Members");
        if (members != null)
        {
            foreach (Match match in Regex.Matches(members, "(\\w+)\\s*=\\s*\\{"))
            {
                var owner = match.Groups[1].Value;
                var ownerBlock = ExtractBlock(members, owner);
                if (ownerBlock == null) continue;
                foreach (var value in Strings(ownerBlock))
                    result.Add(new RefString("Members", owner, value));
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
                var fileNames = new HashSet<string>(StringComparer.Ordinal);
                foreach (var line in File.ReadAllLines(file))
                {
                    var name = line.Trim();
                    if (name.Length == 0 || name.StartsWith('#')) continue;
                    fileNames.Add(name);
                    dumpNames.Add(name);
                }
                dumpsByOwner[Path.GetFileNameWithoutExtension(file)] = fileNames;
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

        var parsedRefs = RefsParser.Parse(File.ReadAllText(refsPath));
        if (parsedRefs.Count == 0)
        {
            Console.Error.WriteLine("refs.lua parsed to zero strings - format changed?");
            return 2;
        }

        var okCount = 0;
        var engineCount = 0;
        var unknown = new List<string>();

        foreach (var refString in parsedRefs)
        {
            var status = Check(refString, assets, dumpNames, dumpsByOwner, objectDump);
            switch (status)
            {
                case "OK": okCount++; break;
                case "ENGINE": engineCount++; break;
                default: unknown.Add($"{refString.Section}{(refString.Owner != null ? "." + refString.Owner : "")}: {refString.Value}"); break;
            }
        }

        if (!quiet)
        {
            Console.WriteLine($"refs strings : {parsedRefs.Count}");
            Console.WriteLine($"OK           : {okCount}");
            Console.WriteLine($"ENGINE (w/l) : {engineCount}");
            Console.WriteLine($"UNKNOWN      : {unknown.Count}");
            foreach (var entry in unknown)
                Console.WriteLine("  UNKNOWN " + entry);
        }

        return unknown.Count == 0 ? 0 : 1;
    }

    private static string Check(RefsParser.RefString refString,
        HashSet<string> assets,
        HashSet<string> dumpNames,
        Dictionary<string, HashSet<string>> dumpsByOwner,
        string? objectDump)
    {
        switch (refString.Section)
        {
            case "Assets":
                // "/Game/Ride/Game/X" -> пакет "Ride/Content/Ride/Game/X.uasset" (или .umap)
            {
                if (!refString.Value.StartsWith("/Game/")) return "UNKNOWN";
                var gameRelativePath = refString.Value["/Game/".Length..];
                return assets.Contains("Ride/Content/" + gameRelativePath + ".uasset")
                       || assets.Contains("Ride/Content/" + gameRelativePath + ".umap")
                    ? "OK"
                    : "UNKNOWN";
            }

            case "EngineClasses":
            case "Hooks":
                // "/Script/..." и UFunction-сигнатуры движка: без object-dump
                // не проверить — whitelist; с object-dump ищем подстроки.
                if (!refString.Value.StartsWith("/Script/")) return "UNKNOWN";
                if (objectDump != null)
                {
                    var parts = refString.Value["/Script/".Length..].Split(':', '.');
                    var allPartsMatch = parts.All(part => part.Length == 0 || objectDump.Contains(part, StringComparison.Ordinal));
                    return allPartsMatch ? "OK" : "UNKNOWN";
                }
                return "ENGINE";

            case "ShortClasses":
            {
                if (EngineShortClasses.Contains(refString.Value)) return "ENGINE";
                // BP_*_C: базовое имя обязано быть пакетом игры.
                if (refString.Value.EndsWith("_C"))
                {
                    var baseName = refString.Value[..^2];
                    var found = assets.Any(assetPath => assetPath.EndsWith("/" + baseName + ".uasset", StringComparison.OrdinalIgnoreCase));
                    return found || dumpNames.Contains(refString.Value) ? "OK" : "UNKNOWN";
                }
                return dumpNames.Contains(refString.Value) ? "OK" : "UNKNOWN";
            }

            case "CosmeticTags":
            case "LevelTags":
                return dumpNames.Contains(refString.Value) ? "OK" : "UNKNOWN";

            case "Members":
            {
                var owner = refString.Owner ?? "";
                if (EngineMembers.TryGetValue(owner, out var whitelist))
                {
                    if (whitelist.Contains(refString.Value))
                        return objectDump != null && objectDump.Contains(refString.Value, StringComparison.Ordinal)
                            ? "OK"
                            : "ENGINE";
                    return "UNKNOWN";
                }
                // Игровой владелец: ищем имя в ЕГО дампе (строже объединения).
                // Дамп владельца существует — значит имя обязано быть в нём,
                // иначе владелец в refs.lua указан неверно.
                var ownerDump = FindOwnerDump(dumpsByOwner, owner);
                if (ownerDump != null)
                    return ownerDump.Contains(refString.Value) ? "OK" : "UNKNOWN";
                // Дампа владельца нет вовсе — сверяем с объединением всех дампов.
                return dumpNames.Contains(refString.Value) ? "OK" : "UNKNOWN";
            }

            default:
                return "UNKNOWN";
        }
    }

    /// Ищет дамп владельца: сначала точный ключ, затем суффикс "_&lt;owner&gt;"
    /// на границе подчёркивания. AssetDump именует файлы полным путём пакета
    /// (Ride_Content_Ride_Game_BP_SaveGamePlayer), а владельцы в refs.lua —
    /// короткие имена классов, поэтому точный ключ почти никогда не совпадает.
    public static HashSet<string>? FindOwnerDump(Dictionary<string, HashSet<string>> dumpsByOwner, string owner)
    {
        if (owner.Length == 0) return null;
        if (dumpsByOwner.TryGetValue(owner, out var exact)) return exact;
        foreach (var (fileName, names) in dumpsByOwner)
            if (fileName.EndsWith("_" + owner, StringComparison.Ordinal)) return names;
        return null;
    }
}
