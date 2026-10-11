# Denarmo's Warfarer Revamped

A comprehensive REFramework mod for **Dragon's Dogma 2** (including full support for the **Dark Arisen** expansion).

This mod merges and enhances the functionality of two essential Warfarer mods:
- **Warfarer's Arsenal** (by LeyDWeMvc / nexusmods)
- **Enhanced Warfarer Vocation** (by mue3UufKW / nexusmods)

---

## Features

### 1. Radial Weapon Selection Wheel
- Hold the trigger button or hotkey to open an intuitive radial HUD wheel displaying all your carried/equipped weapons.
- Dynamic slow-motion effect while the wheel is open (fully customizable slow-mo factor and duration).
- Seamless controller stick steering or mouse selection with configurable deadzones.
- Instant, fluid weapon switching without opening inventory menus.

### 2. Dynamic Weapon Skillsets (6 Custom Skill Slots)
- Automatically switches your active weapon skill palette whenever you equip or switch weapons.
- Supports all **6 skill slots** (Slots 1–4 standard diamond + Slots 5–6 extended slots).
- Full compatibility with the **Dark Arisen DLC** expansion, including all new vocational skills (CS13 / CS14 / CS15 and Obelisk abilities) across all vocations:
  - Fighter, Archer, Mage, Thief, Warrior, Sorcerer, Mystic Spearhand, Magick Archer, Trickster, and Warfarer.

### 3. Multiple Presets & Hotkey Cycling
- Save and edit multiple skill presets per weapon and vocation.
- Cycle through presets in real time during combat using hotkeys or controller combinations.
- Guild editing mode to configure skill presets directly at inns and vocation guilds.

### 4. Controller & Keyboard Customization
- Built-in controller button configuration supporting Xbox and PlayStation glyphs/layouts.
- Support for dual-button combos, hold duration tuning, and stick direction selection.
- Full keyboard/mouse hotkey remapping.
- In-game REFramework diagnostics and controller button test overlay.

---

## Installation

### Via Fluffy Mod Manager (Recommended)
1. Download the release archive or create a zip containing `modinfo.ini`, `screenshot.png`, and the `reframework/` folder.
2. Place the zip file in `<Fluffy Mod Manager>/Games/DragonsDogma2/Mods/`.
3. Open Fluffy Mod Manager, refresh the mod list, and enable **Denarmo's Warfarer Revamped**.

### Manual Installation
1. Ensure [REFramework](https://github.com/praydog/REFramework) is installed in your Dragon's Dogma 2 directory.
2. Copy the contents of this repository into your game directory:
   - Copy `reframework/` to `<Dragon's Dogma 2 Directory>/reframework/`
3. Launch Dragon's Dogma 2 and press `Insert` to open the REFramework overlay to configure settings.

---

## Structure

```
├── .gitignore
├── modinfo.ini
├── screenshot.png
├── README.md
└── reframework/
    ├── autorun/
    │   └── WarfarerRevamped.lua
    ├── fonts/
    │   └── pala.ttf
    └── images/
        ├── dd2-archer.png
        ├── dd2-fighter.png
        ├── dd2-mage.png
        ├── dd2-magick_archer.png
        ├── dd2-mystic_spearhand.png
        ├── dd2-sorcerer.png
        ├── dd2-thief.png
        ├── dd2-trickster.png
        ├── dd2-warrior.png
        └── *-50.png (small icons)
```

---

## Credits & Acknowledgements
- **praydog** for [REFramework](https://github.com/praydog/REFramework).
- **LeyDWeMvc** for the original [Warfarer's Arsenal](https://www.nexusmods.com/dragonsdogma2/mods/1717).
- **mue3UufKW** for the original [Enhanced Warfarer Vocation](https://www.nexusmods.com/dragonsdogma2/mods/1142).
- Capcom for Dragon's Dogma 2 & Dark Arisen expansion.
