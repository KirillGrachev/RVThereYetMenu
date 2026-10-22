# RVThereYetMenu architecture

A trainer for **RV There Yet?** (Unreal Engine 5.6, Shipping, IoStore,
EOS+Steam multiplayer). The modding platform is **UE4SS** (Lua) - the same
one on which MoreRVers verifiably raises this game's player cap.

The project follows the conventions of RiskOfRainMenu (RoR2SandboxMenu),
ported from BepInEx/Harmony to UE4SS/UMG:

| RiskOfRainMenu (Unity)      | RVThereYetMenu (UE5)               |
|-----------------------------|------------------------------------|
| BepInEx plugin, IMGUI       | UE4SS Lua mod, UMG built from pure Lua |
| Harmony patches             | RegisterHook / NotifyOnNewObject   |
| GameApi (reflection wrappers) | `core/engine.lua` + `core/guard.lua` |
| GameRefs + GameRefsTests    | `core/refs.lua` + `tools/NameCheck` |
| CheatState / CheatFlag      | `core/state.lua`                   |
| SandboxActions (dispatcher) | `actions.lua` (registry id -> run) |
| MenuUI / Theme / Widgets / Tabs | `menu/` + `tabs/` (UMG widgets) |
| Protocol (client -> host)   | not needed in v0.1: host actions   |
|                             | are server-side anyway; client     |
|                             | actions are local                  |
| lang.tsv                    | `lang/lang.tsv` (same format)      |

## Layers

```
main.lua                thin entry: config, lang, hotkey, LoadMap hook
actions.lua             dispatcher: id -> action (game thread, status)
tabs/*.lua              menu tabs: Build/Refresh, UI only
menu/menuui.lua         window: UMG assembly, tabs, cursor, refresh loop
menu/widgets.lua        widget factory (StaticConstructObject + WidgetTree)
menu/theme.lua          colors/fonts/visibility
hooks/session.lua       slots: MaxPlayers on instance + CDO, hooks
hooks/unlocks.lua       cosmetics/tapes/checkpoints + save-to-slot
hooks/cheats.lua        BP_CheatManager wrapper
core/engine.lua         object access (GameInstance, GameSession, ...)
core/guard.lua          ApiGuard: pcall wrappers, error anti-flood
core/state.lua          CheatState: flags, mirrors (applied/original), metrics
core/refs.lua           ALL reflection strings (data, not code)
core/config.lua         INI: parse/normalize/clamp/save
core/lang.lua           lang.tsv: translation with en -> key degradation
core/log.lua            levels, prefix, English message text
```

Layer rules (contracts):

1. **Game access only through Guard.** Any reflection call can throw (a
   game patch, a client without a session, the frontend without a
   GameSession); an exception in the game thread takes the user's game
   down with it.
2. **Names only from refs.lua.** No string reflection paths in other
   modules: NameCheck validates one file instead of the whole codebase.
3. **The menu never touches the game directly.** Buttons call
   `Actions.Run(id)`, which moves into `ExecuteInGameThread` and writes a
   single status line.
4. **Values are clamped at the entrance** (Config), not at the points of
   use.
5. **The original value is remembered once** (State.Mirror): Release
   honestly restores what existed before the first application.

## Multiplayer model

The game is a listen server (host + clients, EOS/Steam). As in MoreRVers:
the slot cap and the unlocks apply **on the host**; clients do not need
the mod. Client-side actions (waypoint teleports of the own pawn, UI) are
local. A full client->host protocol (like NetProtocol in RoR) was not
ported in v0.1: for a UE session, guest-initiated actions can be added
later through server RPCs of the game classes (the material appears after
the CXX dumps).

## Name validation (the GameRefsTests equivalent)

The offline reverse-engineering pipeline, no game launch required (all
tools are C#/.NET 10 and run on a Linux server):

```
Ride-Windows.utoc/.ucas
   -> tools/AssetIndex  -> assets.txt (19101 packages; CUE4Parse, Mount())
   -> tools/AssetDump   -> dumps/*.txt (name batch from the Zen header:
                          LoadNameBatch@60, no .usmap needed)
scripts/core/refs.lua + assets.txt + dumps/
   -> tools/NameCheck   -> OK / ENGINE (whitelist) / UNKNOWN (exit 1)
```

NameCheck resolves each refs.lua string against its own source: assets
against the mounted package list, members of game owners against **their
owner's** dump (dump files are named by full package path, so the owner is
matched by the `_Owner` suffix; a wrong attribution is UNKNOWN, not a
lucky union hit), engine names against an explicit whitelist until an
object dump exists.

Once the maintainer runs the game with UE4SS (Info tab -> Dump objects /
Dump CXX headers / Dump .usmap):
- `Mappings.usmap` enables AssetDump FULL mode (properties with values);
- `UE4SS_ObjectDump.txt` retires the ENGINE whitelist (engine names such
  as GameSession.MaxPlayers and PlayerController.* get checked for real).

## Tests

- `tests/lua/run_tests.lua` - pure logic without UE4SS: config (parse/
  clamp/roundtrip/defaults), lang (translation/degradation/format), state
  (flags/original mirrors/metrics), refs (data shape), actions (registry
  completeness, labelKey <-> lang.tsv, dangerous flags).
- `tests/NameCheck.Tests` - xunit: the refs.lua section parser (nested
  blocks, Members owners) and the owner-dump suffix matching.
- `tests/fixtures` - an end-to-end NameCheck run in CI (synthetic
  assets/dumps of the same formats, tracked in the repository).
- luacheck (`.luacheckrc`) - UE4SS globals declared explicitly.

## Release build

On a release tag, CI packs `mod/` into
`RVThereYetMenu-vX.Y.Z-ModOnly.zip` (the MoreRVers layout:
Mods/RVThereYetMenu + UE4SS_Signatures). UE4SS itself is not bundled -
the user either has it already or installs it once (see INSTALL.md).
