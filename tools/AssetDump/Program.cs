// AssetDump — офлайн-разбор пакетов игры (CUE4Parse).
//
// Режимы:
//  - FULL (нужен .usmap): экспорты, родительские классы, свойства со значениями;
//  - NAMES (без usmap): name batch пакета через штатный
//    FNameEntrySerialized.LoadNameBatch — все идентификаторы ассета
//    (имена свойств/функций/перечислений + soft object paths).
//    UE5 Zen-заголовок: FZenPackageSummary (60 байт при bHasVersioningInfo=0),
//    сразу за ним — батч имён; при неудаче пробуем соседние выравнивания.
//
// Использование:
//   dotnet run -c Release -- <paksDir> <outDir> <game> <listFile|pkgPath...> [--usmap <file>]
using CUE4Parse.FileProvider;
using CUE4Parse.MappingsProvider.Usmap;
using CUE4Parse.UE4.Objects.UObject;
using CUE4Parse.UE4.Readers;
using CUE4Parse.UE4.Versions;

var usmapIdx = Array.IndexOf(args, "--usmap");
string? usmapPath = null;
if (usmapIdx >= 0 && usmapIdx + 1 < args.Length)
{
    usmapPath = args[usmapIdx + 1];
    args = args.Where((_, i) => i != usmapIdx && i != usmapIdx + 1).ToArray();
}

var paksDir = args[0];
var outDir = args[1];
var gameName = args.Length > 2 ? args[2] : "GAME_UE5_6";
var rest = args.Skip(3).ToArray();

if (!Enum.TryParse<EGame>(gameName, out var game))
{
    Console.Error.WriteLine($"Unknown EGame '{gameName}'");
    return 2;
}

List<string> packages;
if (rest.Length == 1 && File.Exists(rest[0]))
    packages = File.ReadAllLines(rest[0])
        .Select(l => l.Trim())
        .Where(l => l.Length > 0 && !l.StartsWith('#'))
        .ToList();
else
    packages = rest.ToList();

Directory.CreateDirectory(outDir);

var versions = new VersionContainer(game);
var provider = new DefaultFileProvider(paksDir, SearchOption.AllDirectories, true, versions);
if (usmapPath is not null)
{
    provider.MappingsContainer = new FileUsmapTypeMappingsProvider(usmapPath, StringComparer.OrdinalIgnoreCase);
    Console.WriteLine($"Mappings: {usmapPath}");
}

provider.UseLazyPackageSerialization = true;
provider.Initialize();
provider.Mount();
Console.WriteLine($"Mounted {provider.MountedVfs.Count} vfs, {provider.Files.Count} files");

var ok = 0;
var namesOnly = 0;
var failed = new List<string>();

foreach (var pkgPath in packages)
{
    var safeName = pkgPath.Replace('/', '_').Replace(".uasset", "");
    var outPath = Path.Combine(outDir, safeName + ".txt");
    try
    {
        using var w = new StreamWriter(outPath);
        w.WriteLine($"# Package: {pkgPath}");

        var done = false;
        if (usmapPath is not null)
        {
            try
            {
                var pkg = provider.LoadPackage(pkgPath);
                w.WriteLine($"# Exports: {pkg.ExportMapLength}, Imports: {pkg.ImportMapLength}, Names: {pkg.NameMap.Length}");
                w.WriteLine("# Mode: FULL (usmap)");
                w.WriteLine();
                foreach (var export in pkg.GetExports())
                {
                    w.WriteLine($"[{export.ExportType}] {export.GetFullName()}");
                    try
                    {
                        var classType = export.GetType();
                        var superField = classType.GetField("SuperStruct") ?? classType.BaseType?.GetField("SuperStruct");
                        var super = superField?.GetValue(export);
                        if (super is not null)
                            w.WriteLine($"  SuperStruct: {super.GetType().GetProperty("Name")?.GetValue(super)}");
                    }
                    catch
                    {
                        // не критично
                    }

                    foreach (var tag in export.Properties)
                        w.WriteLine($"  {tag}");
                    w.WriteLine();
                }

                done = true;
                ok++;
                Console.WriteLine($"[full]  {pkgPath}");
            }
            catch (Exception ex)
            {
                w.WriteLine($"# FULL failed ({ex.GetType().Name}: {ex.Message.Split('\n')[0]}) — falling back to NAMES");
            }
        }

        if (!done)
        {
            var data = provider.Files[pkgPath].Read();
            FNameEntrySerialized[]? names = null;
            long usedStart = -1;
            foreach (var start in new long[] { 60, 68, 64, 72 })
            {
                try
                {
                    var ar = new FByteArchive(pkgPath, data, versions) { Position = start };
                    var batch = FNameEntrySerialized.LoadNameBatch(ar);
                    if (batch.Length > 0 && (names == null || batch.Length > names.Length))
                    {
                        names = batch;
                        usedStart = start;
                    }
                }
                catch
                {
                    // пробуем следующее выравнивание
                }
            }

            if (names == null || names.Length == 0)
                throw new InvalidDataException("name batch not found at expected offsets");

            w.WriteLine($"# Names: {names.Length} (batch@{usedStart})");
            w.WriteLine("# Mode: NAMES");
            w.WriteLine();
            foreach (var n in names)
                w.WriteLine(n.Name);

            namesOnly++;
            Console.WriteLine($"[names] {pkgPath} ({names.Length})");
        }
    }
    catch (Exception ex)
    {
        failed.Add(pkgPath);
        Console.WriteLine($"[FAIL] {pkgPath}: {ex.GetType().Name}: {ex.Message.Split('\n')[0]}");
    }
}

Console.WriteLine();
Console.WriteLine($"Done: {ok} full, {namesOnly} names-only, {failed.Count} failed -> {outDir}");
return failed.Count == 0 ? 0 : 1;
