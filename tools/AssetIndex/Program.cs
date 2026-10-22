// AssetIndex — офлайн-перечисление всех пакетов IoStore-контейнеров игры
// (Ride-Windows.utoc/.ucas + global.utoc/.ucas) через CUE4Parse.
//
// Использование:
//   dotnet run -c Release -- <paksDir> <outFile> [GAME_UE5_6|GAME_UE5_7]
using CUE4Parse.FileProvider;
using CUE4Parse.UE4.Versions;

var paksDir = args.Length > 0 ? args[0] : "/root/work/rvty-game/game/Ride/Ride/Content/Paks";
var outFile = args.Length > 1 ? args[1] : "/root/work/rvty-game/assets.txt";
var gameName = args.Length > 2 ? args[2] : "GAME_UE5_6";

if (!Enum.TryParse<EGame>(gameName, out var game))
{
    Console.Error.WriteLine($"Unknown EGame '{gameName}'");
    return 2;
}

Console.WriteLine($"Paks dir : {paksDir}");
Console.WriteLine($"Game ver : {game}");

var versions = new VersionContainer(game);
var provider = new DefaultFileProvider(paksDir, SearchOption.AllDirectories, true, versions);

provider.VfsRegistered += (_, eventArgs) => Console.WriteLine($"[registered] {eventArgs}");
provider.VfsMounted += (_, eventArgs) => Console.WriteLine($"[mounted]    {eventArgs}");

provider.Initialize();

Console.WriteLine($"Unloaded vfs: {provider.UnloadedVfs.Count}");
foreach (var vfs in provider.UnloadedVfs)
    Console.WriteLine($"  needs key? {vfs.Name}");
Console.WriteLine($"Required keys: {string.Join(", ", provider.RequiredKeys.Select(key => key.ToString()))}");

provider.Mount();

Console.WriteLine($"Mounted vfs : {provider.MountedVfs.Count}");
Console.WriteLine($"Total files : {provider.Files.Count}");
Console.WriteLine($"Loose files : {provider.LooseFileCount}");

var sortedPaths = provider.Files.Keys.OrderBy(path => path, StringComparer.OrdinalIgnoreCase).ToList();
File.WriteAllLines(outFile, sortedPaths);
Console.WriteLine($"Written: {outFile}");

Console.WriteLine();
Console.WriteLine("By extension:");
foreach (var byExtension in sortedPaths.GroupBy(packagePath => Path.GetExtension(packagePath))
             .OrderByDescending(byExtension => byExtension.Count()))
    Console.WriteLine($"{byExtension.Key,-12} {byExtension.Count()}");

Console.WriteLine();
Console.WriteLine("Top-level directories:");
foreach (var byDirectory in sortedPaths
             .GroupBy(packagePath => "/" + string.Join("/", packagePath.Split('/').Take(3)))
             .OrderByDescending(byDirectory => byDirectory.Count())
             .Take(25))
    Console.WriteLine($"{byDirectory.Count(),7}  {byDirectory.Key}");

return 0;
