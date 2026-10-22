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

var usmapArgumentIndex = Array.IndexOf(args, "--usmap");
string? usmapPath = null;
if (usmapArgumentIndex >= 0 && usmapArgumentIndex + 1 < args.Length)
{
    usmapPath = args[usmapArgumentIndex + 1];
    args = args.Where((_, index) => index != usmapArgumentIndex && index != usmapArgumentIndex + 1).ToArray();
}

var paksDir = args[0];
var outDir = args[1];
var gameName = args.Length > 2 ? args[2] : "GAME_UE5_6";
var packageArguments = args.Skip(3).ToArray();

if (!Enum.TryParse<EGame>(gameName, out var game))
{
    Console.Error.WriteLine($"Unknown EGame '{gameName}'");
    return 2;
}

List<string> packages;
if (packageArguments.Length == 1 && File.Exists(packageArguments[0]))
    packages = File.ReadAllLines(packageArguments[0])
        .Select(line => line.Trim())
        .Where(line => line.Length > 0 && !line.StartsWith('#'))
        .ToList();
else
    packages = packageArguments.ToList();

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

var fullCount = 0;
var namesOnlyCount = 0;
var failed = new List<string>();

foreach (var pkgPath in packages)
{
    var dumpFileName = pkgPath.Replace('/', '_').Replace(".uasset", "");
    var dumpPath = Path.Combine(outDir, dumpFileName + ".txt");
    try
    {
        using var writer = new StreamWriter(dumpPath);
        writer.WriteLine($"# Package: {pkgPath}");

        var fullDumpWritten = false;
        if (usmapPath is not null)
        {
            try
            {
                var package = provider.LoadPackage(pkgPath);
                writer.WriteLine($"# Exports: {package.ExportMapLength}, Imports: {package.ImportMapLength}, Names: {package.NameMap.Length}");
                writer.WriteLine("# Mode: FULL (usmap)");
                writer.WriteLine();
                foreach (var export in package.GetExports())
                {
                    writer.WriteLine($"[{export.ExportType}] {export.GetFullName()}");
                    try
                    {
                        var classType = export.GetType();
                        var superField = classType.GetField("SuperStruct") ?? classType.BaseType?.GetField("SuperStruct");
                        var super = superField?.GetValue(export);
                        if (super is not null)
                            writer.WriteLine($"  SuperStruct: {super.GetType().GetProperty("Name")?.GetValue(super)}");
                    }
                    catch
                    {
                        // не критично
                    }

                    foreach (var propertyTag in export.Properties)
                        writer.WriteLine($"  {propertyTag}");
                    writer.WriteLine();
                }

                fullDumpWritten = true;
                fullCount++;
                Console.WriteLine($"[full]  {pkgPath}");
            }
            catch (Exception ex)
            {
                writer.WriteLine($"# FULL failed ({ex.GetType().Name}: {ex.Message.Split('\n')[0]}) — falling back to NAMES");
            }
        }

        if (!fullDumpWritten)
        {
            var packageData = provider.Files[pkgPath].Read();
            FNameEntrySerialized[]? names = null;
            long nameBatchOffset = -1;
            foreach (var candidateOffset in new long[] { 60, 68, 64, 72 })
            {
                try
                {
                    var archive = new FByteArchive(pkgPath, packageData, versions) { Position = candidateOffset };
                    var batch = FNameEntrySerialized.LoadNameBatch(archive);
                    if (batch.Length > 0 && (names == null || batch.Length > names.Length))
                    {
                        names = batch;
                        nameBatchOffset = candidateOffset;
                    }
                }
                catch
                {
                    // пробуем следующее выравнивание
                }
            }

            if (names == null || names.Length == 0)
                throw new InvalidDataException("name batch not found at expected offsets");

            writer.WriteLine($"# Names: {names.Length} (batch@{nameBatchOffset})");
            writer.WriteLine("# Mode: NAMES");
            writer.WriteLine();
            foreach (var nameEntry in names)
                writer.WriteLine(nameEntry.Name);

            namesOnlyCount++;
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
Console.WriteLine($"Done: {fullCount} full, {namesOnlyCount} names-only, {failed.Count} failed -> {outDir}");
return failed.Count == 0 ? 0 : 1;
