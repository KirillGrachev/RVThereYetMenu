# RVThereYetMenu

One Lua mod, host-side trainer menu for RV There Yet?: session slots up to
24, cosmetics and tape unlocks, vehicle repair, boarding and winch,
teleports with three waypoint slots, golf helpers and the game's own dev
cheats behind a single in-game menu - and an offline name validator that
runs in CI on every push, so a game update fails the build instead of your
lobby.

The game is Unreal Engine 5.6 (Shipping, IoStore), so there is no BepInEx
and no Harmony here: the mod runs on UE4SS, and its UMG widget tree is
built from pure Lua (StaticConstructObject + WidgetTree, the SupraTools
technique). Every reflection name the mod touches lives in one file,
`scripts/core/refs.lua`, confirmed against offline dumps of the game
containers; the same names are re-checked by `tools/NameCheck` in CI.

---

## Why

Trainer mods for this game tend to break in the same places:

| What a naive trainer does | How it ends |
|---|---|
| Assumes Unity because nothing says otherwise | The game is UE 5.6; there is no BepInEx to patch and no Harmony to hook |
| Scatters reflection strings through the code | A game update renames one blueprint member and a button silently dies |
| Raises the player cap on the session instance only | The next level load recreates GameSession and the cap is back to 4 |
| Calls `FText(...)` the pre-5.4 way | The constructor needs a signature file; every widget label renders empty |
| Lets guests press host-side buttons | Nothing happens and nothing is logged, so nobody knows why |

This mod pins each of those down: the cap is applied to the instance and
to the class default object and re-applied on every new GameSession (the
mechanic MoreRVers proved on this game); all names sit in one validated
file; FText degrades through three documented levels with an explicit
warning; every action returns a status line to the menu and to the log,
and refuses to run outside the game thread.

---

## Tabs

| Tab | What it touches |
|---|---|
| Session | Player cap 1..24: apply to the live GameSession + CDO, release back to the remembered original, auto-apply on every new session |
| Unlocks | All cosmetics (base + Mabutts + Snow variants), all tapes, checkpoint progression written into the save |
| Vehicle | Repair (all / engine / frame / wheels), board the Winnebago or the closest JetSki, winch grab and reset (front / rear), ice studs add and wear |
| Run | Teleport to the nearest checkpoint or the player start, golf ball to the aim point, three waypoint slots that remember their level |
| Players | Session player list, EpiPens, remove inactive players, ignore actors with players attached, DamageAll behind a two-click confirm |
| Info | Mod / UE4SS / engine versions, object availability diagnostics, dump buttons (objects, CXX headers, usmap) |

---

## Install

Requirements: RV There Yet? (Steam, checked against the 2026-09 build),
UE4SS experimental 3.0.1+, Windows 10/11 x64. Step-by-step with the exact
folder layout: [INSTALL.md](INSTALL.md).

```bash
# 1. UE4SS goes into the game binaries folder: dwmapi.dll next to the game
#    executable, the rest under ue4ss\.

# 2. The mod folder goes into ue4ss\Mods\ and gets enabled in mods.txt:
#    add the line "RVThereYetMenu : 1" above "Keybinds : 1".
cp -r mod/Mods/RVThereYetMenu "<game>/Ride/Binaries/Win64/ue4ss/Mods/"

# 3. The FText signature is required on UE 5.4+, otherwise all menu text
#    renders empty.
cp mod/UE4SS_Signatures/FText_Constructor.lua "<game>/Ride/Binaries/Win64/ue4ss/UE4SS_Signatures/"
```

The menu opens with `INSERT` (`Menu.ToggleKey` in the mod's config.ini).
Most features are host-side: in a co-op session only the host needs the
mod, clients join without it.

---

## Menu behavior

- The widget tree is built lazily on first open, in the game thread, and
  lives on the GameInstance; a level change invalidates it and the next
  open rebuilds from scratch instead of hunting stale widgets.
- The active tab refreshes once per second while the menu is open
  (LoopAsync stops itself on close).
- Every button press goes through the action dispatcher: execution strictly
  in the game thread, one status line per action, double-run protection.
- Destructive actions (DamageAll) arm on the first click and fire on the
  second within 3 s.
- Waypoint slots store the level name with the position and refuse to
  apply on a different map - the RiskOfRainMenu rule against void falls.

## Multiplayer model

The game is a listen server (host + clients over EOS/Steam). As in
MoreRVers, the player cap and the unlocks apply **on the host**; clients
need nothing installed. Client-local actions (own-pawn teleports,
waypoints, UI) run on the pressing client. A full client->host request
protocol (the NetProtocol of RiskOfRainMenu) is deliberately not part of
v0.1: host actions are already server-side, and guest-initiated actions
wait for the CXX header dumps to pick reliable RPC paths.

---

## Name validation

Blueprint members cannot be checked at compile time, so they are checked
offline instead - no game launch needed, all tools are C#/.NET 10 and run
on Linux:

```
Ride-Windows.utoc/.ucas
   -> tools/AssetIndex  -> assets.txt (19101 packages; CUE4Parse mount)
   -> tools/AssetDump   -> dumps/*.txt (name batch straight from the Zen
                           package header, no .usmap required)
scripts/core/refs.lua + assets.txt + dumps/
   -> tools/NameCheck   -> OK / ENGINE (whitelist) / UNKNOWN (exit 1)
```

- Assets resolve against the mounted package list; member names resolve
  against **their owner's** dump (a name attributed to the wrong owner is
  UNKNOWN, not a lucky union hit); engine-side names stay on a whitelist
  until a `UE4SS_ObjectDump.txt` exists to check them for real.
- CI runs the same validator end-to-end over synthetic fixtures in
  `tests/fixtures`, so the check itself is tested without game data.
- The Info tab has the three dump buttons (objects / CXX headers / usmap):
  with a `Mappings.usmap`, AssetDump switches to FULL mode (exports and
  property values), and the object dump retires the ENGINE whitelist.

## Tests

- `tests/lua/run_tests.lua` (lua5.4, no UE4SS): config parsing, clamps and
  save/load roundtrip, translation fallbacks, state mirrors, refs data
  shape, action registry completeness and every labelKey present in
  lang.tsv with non-empty ru and en. 17 tests.
- `tests/NameCheck.Tests` (xunit): the refs.lua section parser (nested
  blocks, member owners) and the owner-dump suffix matching. 9 tests.
- luacheck over all Lua with the UE4SS globals declared explicitly
  (`.luacheckrc`): a typo in an API name is a lint error, not a runtime
  surprise.

## Builds and releases

`.github/workflows/build.yml` runs on every push: `luac -p` + luacheck +
the Lua suite, then the .NET tools build + xunit + the fixture NameCheck.
On a published release, the `release` job packs `mod/` into
`RVThereYetMenu-<tag>-ModOnly.zip` (Mods + UE4SS_Signatures, the MoreRVers
layout: unpack into Win64 and it works) and attaches it to the release.
UE4SS itself is not bundled - the user already has it or installs it once.

## Configuration

`ue4ss/Mods/RVThereYetMenu/config.ini` (the menu rewrites this file when
you change values in-game):

| Key | Default | Meaning |
|---|---|---|
| `Menu.ToggleKey` | `INSERT` | Menu hotkey, any name from the UE4SS Key table |
| `Menu.Language` | `ru` | Menu language: `ru` or `en` |
| `Session.MaxPlayers` | `8` | Host player cap, clamped 1..24, vanilla is 4 |
| `Session.AutoApplySlots` | `true` | Re-apply the cap to every newly created GameSession |
| `Logging.Level` | `INFO` | DEBUG / INFO / WARN / ERROR |

---

## Limits (v0.1)

- No god mode / speed hacks yet: survivability and vehicle physics live in
  engine-side structs, and touching them safely needs the CXX header dump
  (VehicleBase / AdvancedVehicleSystem) - that is the first step after the
  dumps arrive.
- 19 engine-side names (GameSession.MaxPlayers, PlayerController members,
  the /Script/ hook signatures) ride the ENGINE whitelist until the first
  object dump; the whitelist is explicit in `tools/NameCheck`, not a skip.
- Unlocks go through the game's own dev functions: achievements for
  cosmetics intentionally do not fire - `CheatGiveCosmeticsWithout-
  UnlockingAchievement` is the name and the contract.
- The cap is host-only by design; a client running the mod cannot raise
  the cap of someone else's session.
- Names are validated against the 2026-09 containers. After a game update,
  re-run AssetIndex/AssetDump and NameCheck: a renamed member is exit 1,
  not a silent miss.

## Architecture

Module map, layer contracts and the correspondence with RiskOfRainMenu:
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## License

MIT, see [LICENSE.txt](LICENSE.txt).
