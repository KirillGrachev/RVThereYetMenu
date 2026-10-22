using NameCheck;
using Xunit;

namespace NameCheck.Tests;

/// <summary>
/// Поиск дампа владельца по суффиксу имени файла: AssetDump называет файлы
/// полным путём пакета (Ride_Content_Ride_Game_BP_SaveGamePlayer.txt),
/// а владельцы в refs.lua — короткие имена классов.
/// </summary>
public class OwnerDumpTests
{
    private static Dictionary<string, HashSet<string>> Dumps() => new()
    {
        ["Ride_Content_Ride_Game_BP_SaveGamePlayer"] = new() { "GetUnlockedCosmetics" },
        ["BP_CheatManager"] = new() { "AddAllTapes" },
    };

    [Fact]
    public void ExactKeyWins()
    {
        var dump = Program.FindOwnerDump(Dumps(), "BP_CheatManager");
        Assert.NotNull(dump);
        Assert.Contains("AddAllTapes", dump);
    }

    [Fact]
    public void MatchesByPackagePathSuffix()
    {
        var dump = Program.FindOwnerDump(Dumps(), "BP_SaveGamePlayer");
        Assert.NotNull(dump);
        Assert.Contains("GetUnlockedCosmetics", dump);
    }

    [Fact]
    public void NoDumpForUnknownOrEmptyOwner()
    {
        Assert.Null(Program.FindOwnerDump(Dumps(), "RideGameInstance"));
        Assert.Null(Program.FindOwnerDump(Dumps(), ""));
    }

    [Fact]
    public void SuffixMustStartOnUnderscoreBoundary()
    {
        // "GamePlayer" — подстрока середины имени, а не суффикс пакета:
        // граница подчёркивания защищает от ложных владельцев.
        Assert.Null(Program.FindOwnerDump(Dumps(), "GamePlayer"));
    }
}
