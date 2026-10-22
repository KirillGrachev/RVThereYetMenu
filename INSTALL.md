# Installing RVThereYetMenu

A trainer for **RV There Yet?** (Unreal Engine 5) built on **UE4SS** (Lua
mod). It is installed on the player's machine only, and for most features
only the host of a session needs it.

## Requirements

- RV There Yet? (Steam), current version (checked against the 2026-09
  build, UE 5.6);
- UE4SS experimental 3.0.1+ (the snapshot bundled with MoreRVers is known
  to work with this game; any `experimental-latest` release is fine);
- Windows 10/11 x64.

## Step 1. UE4SS

Unpack UE4SS into the game folder if it is not installed yet:

```
<Steam>\steamapps\common\Ride\Ride\Binaries\Win64\
    dwmapi.dll            <- proxy loader
    ue4ss\
        UE4SS.dll
        UE4SS-settings.ini
        Mods\ ...
```

Sources: the `experimental-latest` release of
https://github.com/UE4SS-RE/RE-UE4SS/releases, or the "WithUE4SS" package
of https://github.com/alex-nardozzi/MoreRVers.

## Step 2. The mod

1. Copy the `mod/Mods/RVThereYetMenu` folder from this repository into
   `...\Win64\ue4ss\Mods\`, so that you get:

   ```
   ue4ss\Mods\RVThereYetMenu\
       scripts\main.lua
       config.ini
       lang\lang.tsv
   ```

2. Add the mod to `ue4ss\Mods\mods.txt` **above the `Keybinds : 1` line**:

   ```
   RVThereYetMenu : 1
   ```

3. Copy `mod/UE4SS_Signatures/FText_Constructor.lua` into
   `...\Win64\ue4ss\UE4SS_Signatures\` (create the folder if missing).
   Without this file UE 5.4+ cannot construct FText and the menu text
   renders empty.

## Step 3. Launch

1. Start the game. The UE4SS console should show
   `[RVThereYetMenu] [INFO] RVThereYetMenu v0.1.0 loaded ...`.
2. The menu opens with **INSERT** (configurable in `config.ini`).

## Configuration (config.ini)

| Key | Value | Meaning |
|---|---|---|
| `Menu.ToggleKey` | `INSERT` | Menu key, a name from the UE4SS Key table |
| `Menu.Language` | `ru` / `en` | Interface language |
| `Session.MaxPlayers` | `8` (1..24) | Player cap for the host |
| `Session.AutoApplySlots` | `true` | Re-apply the cap to every new session |
| `Logging.Level` | `INFO` | DEBUG / INFO / WARN / ERROR |

Values changed in the menu (slot slider, language) are written back to
this file immediately.

## Dumps for development (Info tab)

The `Dump objects / Dump CXX headers / Dump .usmap` buttons write into
`ue4ss\`: `UE4SS_ObjectDump.txt`, `CXXHeaderDump\`, `Mappings.usmap`.
These files feed `tools/NameCheck` (validation of the mod's reflection
names): after a game update, run the dumps and send them to the
maintainer - the offline validator will tell exactly which names moved.

## Uninstall

Remove `dwmapi.dll`, the `ue4ss\` folder and the line from `mods.txt`.
The mod does not modify game files.

## Safety

- The game is cooperative (PvE) with no anti-cheat; still, test the
  destructive features (Players tab, "For developers" section) in your own
  session first.
- Unlocks are written into your save through the game's own dev functions;
  achievements for cosmetics intentionally do not fire (that is how the
  game's cheat functions work).
