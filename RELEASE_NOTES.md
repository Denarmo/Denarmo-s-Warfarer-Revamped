# Release v1.0.2 — Steam Cloud settings sync

- Sync mod settings and skill presets between devices through Steam Cloud.
- Include the native REFramework Steam Cloud plugin in the release package.
- Import existing local settings when no cloud copy exists; retain local settings as an offline fallback.
- Preserve offline edits across restarts and retry pending uploads.
- Show Cloud status in the mod settings menu and preserve malformed or newer cloud settings.
- Build and test the native plugin automatically before packaging and deployment.

Install the complete package on each device, enable Steam Cloud for Dragon's Dogma 2, and restart the game after installing the DLL. After playing, exit the game and wait for Steam to finish syncing before switching devices. If Steam was unavailable when the script started, reconnect and reload scripts. Concurrent offline edits use the last uploaded copy.

Validation: native Windows x64 build, DLL load/Lua bridge smoke test, and settings migration/offline/error recovery tests passed. Sync between two devices still needs in-game verification.

---

# Release v1.0.0 — Denarmo's Warfarer Revamped

Initial official release of **Denarmo's Warfarer Revamped** for *Dragon's Dogma 2*, featuring native compatibility with the *Dragon's Dogma 2: Dark Arisen* expansion.

## 🌟 Key Features

- **Radial Weapon Selection Wheel:**
  - Smooth HUD radial weapon wheel rendering carried weapons with slow-motion steering and responsive switching.
  - Dual steering support via controller analog sticks or mouse cursor with configurable deadzones and sensitivity.

- **Dynamic Skillsets (Up to 6 Slots):**
  - Automatic skillset assignment upon switching weapons.
  - Full support for all 6 custom skill slots and Dark Arisen DLC vocational abilities (CS13/CS14/CS15 tiers and Obelisk skills).

- **Auto-Load Guild Skills:**
  - Seamlessly equips your guild-assigned skills when drawing or swapping weapons.
  - Rearmament is no longer required to occupy an active skill slot.

- **Combat Damage Log HUD & Floating Numbers:**
  - Real-time on-screen RPG-style combat chat log with hit highlights, DPS calculation, and corner positioning.
  - 3D floating damage numbers with customizable font size sliders and readable target/enemy names.

- **Loadout Presets & Combat Cycling:**
  - Multiple skill build presets per weapon with mid-combat cycling hotkeys.
  - Safe guild and inn preset configuration mode.

- **Diagnostics & Settings Restore:**
  - Real-time controller button and stick visualizer.
  - Per-setting reset buttons, category restore, and master factory reset.

## 📦 Package

`Denarmo's Warfarer Revamped v1.0.0.zip`

Copy the ZIP into Fluffy Mod Manager's `Games\DragonsDogma2\Mods` folder, refresh the mod list, and enable the mod.
