using NameCheck;
using Xunit;

namespace NameCheck.Tests;

/// <summary>
/// Тесты парсера refs.lua. Fixture повторяет форму реального файла:
/// вложенные блоки, строковые литералы, владельцы в Members.
/// </summary>
public class RefsParserTests
{
    private const string Fixture = """
        local Refs = {}

        Refs.EngineClasses = {
            GameSession = "/Script/Engine.GameSession",
            PlayerController = "/Script/Engine.PlayerController",
        }

        Refs.Hooks = {
            GameSessionCreated = "/Script/Engine.GameSession",
            GameSessionBeginPlay = "/Script/Engine.GameSession:ReceiveBeginPlay",
            CanPlayerJoin = {
                "/Script/Engine.GameSession:CanPlayerJoin",
                "/Script/Engine.GameModeBase:CanPlayerJoin",
            },
        }

        Refs.Assets = {
            PlayerSave = "/Game/Ride/Game/BP_SaveGamePlayer",
            CheatManager = "/Game/Ride/Cheats/BP_CheatManager",
        }

        Refs.ShortClasses = {
            GameInstance = "GameInstance",
            PlayerSave = "BP_SaveGamePlayer_C",
        }

        Refs.Members = {
            GameSession = {
                "MaxPlayers",
            },
            BP_SaveGamePlayer = {
                "GetUnlockedCosmetics",
                "AsyncSaveGameToSlotForLocalPlayer",
            },
        }

        Refs.CosmeticTags = {
            "Cosmetic.Hat",
            "Cosmetic.Glasses",
        }

        Refs.LevelTags = {
            "Level.JungleLevel",
        }

        return Refs
        """;

    [Fact]
    public void ExtractBlockFindsNestedBraces()
    {
        var hooks = RefsParser.ExtractBlock(Fixture, "Refs.Hooks");
        Assert.NotNull(hooks);
        Assert.Contains("CanPlayerJoin", hooks);
        // вложенный блок закрыт правильно: хвост файла не захвачен
        Assert.DoesNotContain("Refs.Assets", hooks);
    }

    [Fact]
    public void ParseCollectsAllSections()
    {
        var parsed = RefsParser.Parse(Fixture);

        Assert.Contains(parsed, r => r.Section == "Assets" && r.Value == "/Game/Ride/Game/BP_SaveGamePlayer");
        Assert.Contains(parsed, r => r.Section == "EngineClasses" && r.Value == "/Script/Engine.GameSession");
        Assert.Contains(parsed, r => r.Section == "Hooks" && r.Value == "/Script/Engine.GameSession:ReceiveBeginPlay");
        Assert.Contains(parsed, r => r.Section == "ShortClasses" && r.Value == "BP_SaveGamePlayer_C");
        Assert.Contains(parsed, r => r.Section == "CosmeticTags" && r.Value == "Cosmetic.Glasses");
        Assert.Contains(parsed, r => r.Section == "LevelTags" && r.Value == "Level.JungleLevel");
    }

    [Fact]
    public void MembersKeepTheirOwner()
    {
        var parsed = RefsParser.Parse(Fixture);

        var maxPlayers = parsed.Single(r => r.Value == "MaxPlayers");
        Assert.Equal("Members", maxPlayers.Section);
        Assert.Equal("GameSession", maxPlayers.Owner);

        var saveMembers = parsed.Where(r => r.Section == "Members" && r.Owner == "BP_SaveGamePlayer").ToList();
        Assert.Equal(2, saveMembers.Count);
        Assert.Contains(saveMembers, r => r.Value == "GetUnlockedCosmetics");
    }

    [Fact]
    public void StringsExtractsLiterals()
    {
        var block = RefsParser.ExtractBlock(Fixture, "Refs.Assets");
        Assert.NotNull(block);
        var strings = RefsParser.Strings(block).ToList();
        Assert.Equal(2, strings.Count);
        Assert.Contains("/Game/Ride/Cheats/BP_CheatManager", strings);
    }

    [Fact]
    public void ParseOfEmptyTextYieldsNothing()
    {
        Assert.Empty(RefsParser.Parse("local x = 1"));
    }
}
