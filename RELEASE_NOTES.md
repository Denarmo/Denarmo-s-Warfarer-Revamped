# Release v1.0.1 — Denarmo's Warfarer Revamped

**Denarmo's Warfarer Revamped** is an all-in-one REFramework modification for *Dragon's Dogma 2*, updated with full support for the *Dragon's Dogma 2: Dark Arisen* expansion.

This release fuses the radial weapon switching mechanics of **Warfarer's Arsenal** with the dynamic per-weapon skill palette system of **Enhanced Warfarer Vocation**, expanding to support all 6 custom skill slots and newly introduced DLC abilities.

---

### 🚀 Highlights & Features

- **Intuitive Radial Weapon Wheel:**
  - Hold your trigger button/hotkey to bring up a slow-motion radial HUD wheel displaying all carried weapons.
  - Steer with either controller analog sticks or the mouse cursor, with customizable deadzone and sensitivity.
  - Seamless weapon equipping routines bypass inventory delays.
- **Dynamic 6-Slot Skill Palettes:**
  - Automatically loads and equips your custom skill palette when switching weapons.
  - Full support for **6 custom skill slots** (Slot 1: Left X/□, Slot 2: Top Y/△, Slot 3: Bottom A/✕, Slot 4: Right B/○, plus extended Slots 5 & 6).
- **Dragon's Dogma 2: Dark Arisen DLC Native Compatibility:**
  - Dynamic IL2CPP reflection over `CustomSkillJobDefineDictionary` and `ExCustomSkillJobDefineDictionary`.
  - Full support for all new Dark Arisen vocational skill tiers (CS13 / CS14 / CS15 and Obelisk abilities) across all vocations (Fighter, Archer, Mage, Thief, Warrior, Sorcerer, Mystic Spearhand, Magick Archer, Trickster, and Warfarer).
- **Multiple Loadout Presets & Combat Cycling:**
  - Save and name distinct skill builds per weapon/vocation.
  - Cycle presets on the fly during combat using customizable controller combinations or keyboard hotkeys.
  - Guild editing mode allows safe configuration of presets directly at vocation guilds and inns.
- **Deep Controller & Input Customization:**
  - Dual-button combinations (e.g., `LB + RB`, `L1 + R1`), hold timing thresholds, and automatic Xbox/PS layout detection.
  - In-game diagnostics overlay to inspect controller button inputs and stick axes.
- **Automated Packaging & Fluffy Mod Manager Ready:**
  - One-click installation zip generated directly into `build/` with forward-slash POSIX archive formatting.

---

### 📦 Release Asset
- `Denarmo's Warfarer Revamped v1.0.1.zip` (located in the `build/` folder)

### 💻 Installation
- **Fluffy Mod Manager:** Place `Denarmo's Warfarer Revamped v1.0.1.zip` in `<Fluffy Mod Manager>\Games\DragonsDogma2\Mods\`, refresh the mod list, and enable it.
- **Manual:** Extract `reframework/` to your Dragon's Dogma 2 game directory. Requires [REFramework](https://github.com/praydog/REFramework).
