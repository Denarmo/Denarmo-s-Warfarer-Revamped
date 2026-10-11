# Denarmo's Warfarer Revamped

[![Version](https://img.shields.io/badge/version-1.1.5-blue.svg)](https://github.com/Denarmo/Denarmo-s-Warfarer-Revamped/releases)
[![Game](https://img.shields.io/badge/Dragon's%20Dogma%202-Dark%20Arisen%20DLC-orange.svg)](https://www.dragonsdogma.com/)
[![Framework](https://img.shields.io/badge/REFramework-Compatible-green.svg)](https://github.com/praydog/REFramework)
[![Mod Manager](https://img.shields.io/badge/Fluffy%20Mod%20Manager-Ready-purple.svg)](https://www.fluffymodmanager.com/)

An all-in-one, next-generation **REFramework** enhancement for the Warfarer vocation in **Dragon's Dogma 2**, built with native compatibility for the **Dragon's Dogma 2: Dark Arisen** expansion.

This mod merges and refines the core capabilities of two beloved Warfarer mods:
- **Warfarer's Arsenal** (by [LeyDWeMvc](https://www.nexusmods.com/dragonsdogma2/mods/1717)) — Fluid radial weapon selection wheel, slow-motion steering, and responsive weapon switching.
- **Enhanced Warfarer Vocation** (by [mue3UufKW](https://www.nexusmods.com/dragonsdogma2/mods/1142)) — Dynamic per-weapon skill palettes, multiple loadout presets, and hotkey preset cycling.

---

## 🌟 Key Features

### 1. Intuitive Radial Weapon Selection Wheel
- **Native HUD Integration:** Renders a clean, high-resolution radial wheel displaying all carried weapons using the game's authentic GUI pipeline.
- **Customizable Slow-Motion:** Slow down time while selecting weapons to execute split-second tactical switches in the heat of combat.
- **Dual Steering Support:** Navigate the wheel effortlessly with either your controller analog stick or mouse pointer, with configurable deadzones and sensitivity.
- **Fast Indexed Weapon Switching:** Direct equip routines bypass inventory menus for seamless, fluid combos.

### 2. Auto-Load Guild Class Skills (Seamless Vocation Switching)
- **Zero Config Required:** Set your desired skills at any Vocation Guild or Inn for each individual class (Fighter, Archer, Mage, etc.). When playing as Warfarer, swapping to any weapon automatically equips that class's guild skills!
- **Rearmament Not Required:** Because weapon switching is handled directly by the radial wheel and equip engine, **Rearmament is no longer required to take up a custom skill slot**. All 4 (or 6) slots are 100% available for combat skills.
- **Unlock Any Skill:** Unlock all weapon skills directly through the REFramework preset menu—even skills you have not yet purchased or learned at the guild are immediately available for use.

### 3. Dynamic Weapon Skillsets (Expanded to 6 Skill Slots)
- **Automatic Palette Swapping:** Automatically replaces your active custom skill palette the moment a weapon is equipped or switched.
- **Full 6-Skill Support:** Extends beyond the default 4-skill limitation to support all 6 custom skill slots (Diamond face buttons + Slots 5 & 6) used by extended skill frameworks and modern overhauls.
- **Dark Arisen DLC Native Compatibility:** Comprehensive support for all new Dark Arisen expansion abilities, including CS13, CS14, CS15 skill tiers, and Obelisk abilities across all vocations (Fighter, Archer, Mage, Thief, Warrior, Sorcerer, Mystic Spearhand, Magick Archer, Trickster, and Warfarer) via dynamic reflection.

### 4. Combat Damage Log UI (HUD Chatbox Style)
- **Real-time Combat Log:** Displays damage numbers in an RPG-style on-screen chat overlay whenever you or your pawns damage enemies.
- **Custom Screen Corner & Live Preview:** Position the log in any corner of the screen (**Bottom-Left**, **Top-Left**, **Bottom-Right**, or **Top-Right**) with configurable margins, width, and background opacity. Includes a **Live HUD Preview** toggle to easily position the box on your screen.
- **Combat Stats & DPS:** Real-time encounter DPS calculations, encounter total damage, and smooth alpha fadeout for older hits.
- **Hit Highlights:** Distinct color coding for standard hits, high-damage hits, Pawn attacks, and weakpoint/critical strikes.
- **Text Size Controls:** Separate sliders for chat log text (12–40 px) and floating damage numbers (16–72 px), with log spacing that grows with the font size.
- **Readable Enemy Names:** Uses game display names with a character-ID species-name fallback for damage and reaction entries.

### 5. Loadout Presets & Combat Cycling
- **Multiple Presets Per Weapon:** Configure and save distinct skill builds for individual weapons (e.g., Elemental Mage vs. Support Mage, Burst Dagger vs. Counter Dagger).
- **On-The-Fly Hotkey Cycling:** Cycle through your saved presets mid-battle using customizable controller combinations or keyboard hotkeys.
- **Guild & Inn Customizer:** In-game guild editing mode allows you to fine-tune presets directly at vocation guilds and inns.

### 6. Comprehensive Controller & Input Customization
- **Xbox & PlayStation Glyphs:** Supports native Xbox and DualShock/DualSense button prompts with automatic layout detection.
- **Dual-Button Combos & Hold Timing:** Bind wheel triggers to single buttons or multi-button combinations (e.g., `LB + RB`, `L1 + R1`), with customizable hold thresholds.
- **In-Game Diagnostic Overlay:** Real-time controller button monitor and stick axis visualizer built right into the REFramework menu.

### 7. Restore Defaults for Each Setting & Category
- **Per-Setting Reset:** Every slider, combo, and toggle in the REFramework menu includes an individual `[Reset]` button to instantly restore just that setting to factory default.
- **Section Restore:** Dedicated buttons for every section (*General*, *Slow Motion*, *Controller*, *Look*, *Mouse*, *Skillsets*, *Damage Log*) to reset categories with one click.
- **Master Reset:** A top-level *Restore All Mod Settings to Defaults* button to revert the entire mod back to default.

---

## 📦 Installation

### Option A: Fluffy Mod Manager (Recommended)
1. Download the latest release package: `Denarmo's Warfarer Revamped v1.1.5.zip` from the [Releases](https://github.com/Denarmo/Denarmo-s-Warfarer-Revamped/releases) tab or `build/` folder.
2. Drop the `.zip` file directly into your Fluffy Mod Manager mod directory:
   ```
   <Fluffy Mod Manager Path>\Games\DragonsDogma2\Mods\
   ```
3. Open Fluffy Mod Manager, click **Refresh mod list**, and toggle **Denarmo's Warfarer Revamped** to **ON**.

### Option B: Manual Installation
1. Ensure [REFramework](https://github.com/praydog/REFramework) is installed in your Dragon's Dogma 2 installation folder (where `DD2.exe` is located).
2. Copy the `reframework/` folder from this repository directly into your game root directory:
   ```
   <Dragon's Dogma 2 Directory>\reframework\
       ├── autorun\
       │   └── WarfarerRevamped.lua
       ├── fonts\
       │   └── pala.ttf
       └── images\
           └── dd2-*.png
   ```

---

## 🎮 How to Use & In-Game Controls

### Default Controls
| Action | Controller (Xbox / PS) | Keyboard & Mouse |
| :--- | :--- | :--- |
| **Open Radial Wheel** | Hold `Left Bumper` (`LB` / `L1`) | Hold `Middle Mouse Button` (or custom hotkey) |
| **Select Weapon** | Right Stick / Left Stick direction | Mouse cursor direction |
| **Confirm & Switch** | Release Trigger Button | Release Hotkey |
| **Cycle Skill Presets** | Dual-button combo (Configurable) | Customizable Keybind |
| **Open REFramework Menu**| — | `Insert` key |

### Configuring the Mod
1. Launch Dragon's Dogma 2 and press `Insert` on your keyboard to open the REFramework overlay.
2. Under **Script Generated UI**, navigate to **Denarmo's Warfarer Revamped**.
3. Here you can:
   - **Radial Settings:** Adjust slow-motion factor, wheel radius, icon scaling, and animation speed.
   - **Controller Settings:** Remap trigger buttons, set hold duration, deadzone, and select stick steering mode.
   - **Preset Manager:** Assign custom skills for each weapon, customize slot 1 through slot 6, and configure presets.

---

## 🛠️ Repository Structure

```
Denarmo's Warfarer Revamped/
├── .github/                     # Issue templates and workflows
├── .githooks/                   # Git automation hooks (auto-versioning)
├── build/                       # Packaged distribution archives (.zip)
│   ├── Denarmo's Warfarer Revamped v1.0.4.zip
│   └── Denarmo's Warfarer Revamped v1.0.5.zip
├── reframework/
│   ├── autorun/
│   │   └── WarfarerRevamped.lua # Unified Lua engine
│   ├── fonts/
│   │   └── pala.ttf             # Palatino Linotype font for HUD text
│   └── images/
│       └── dd2-*.png            # High-resolution vocation icons
├── source_mods/                 # (Ignored) Original reference mod archives
├── build.ps1                    # Automated versioning and packaging script
├── modinfo.ini                  # Fluffy Mod Manager manifest
├── screenshot.png               # Mod Manager preview thumbnail
└── README.md                    # Project documentation
```

### Building from Source
To package a new release build with an automatically incremented version:
```powershell
.\build.ps1
```
Or specify an explicit version tag:
```powershell
.\build.ps1 -Version "1.1.0"
```

---

## 🤝 Credits & Acknowledgements

This project stands on the shoulders of the talented Dragon's Dogma 2 modding community. Immense gratitude and credit go to:

- **[LeyDWeMvc](https://www.nexusmods.com/dragonsdogma2/mods/1717)** — Original creator of **Warfarer's Arsenal**, whose innovative radial wheel architecture, HUD GUI cloning, and smooth stick steering form the basis of the weapon switching system.
- **[mue3UufKW](https://www.nexusmods.com/dragonsdogma2/mods/1142)** — Original creator of **Enhanced Warfarer Vocation**, whose dynamic skill swap logic, preset architecture, and stamina toggle laid the groundwork for multi-weapon skillsets.
- **[praydog](https://github.com/praydog/REFramework)** — For the indispensable **REFramework** tool, runtime IL2CPP API, and hook system.
- **[xyzkljl1](https://github.com/xyzkljl1/MyDD2Mod)** — Damage Number rendering reference and the enemy character-ID/name data used by the combat log.
- **[Capcom](https://www.capcom.com/)** — For creating Dragon's Dogma 2 and the Dark Arisen expansion.

---

## ⚖️ Legal Disclaimer & Notice

> [!NOTE]
> Please read the following legal notices carefully.

1. **Unofficial Fan Creation:**
   *Denarmo's Warfarer Revamped* is a free, open-source, non-commercial fan modification created strictly for personal enjoyment, study, and educational enhancement of *Dragon's Dogma 2*. It is not produced, authorized, supported, or endorsed by **CAPCOM CO., LTD.**

2. **Intellectual Property Rights:**
   - *Dragon's Dogma*, *Dragon's Dogma 2*, *Dragon's Dogma 2: Dark Arisen*, Capcom, and all associated names, character designs, logos, images, audio, and game assets are trademarks, registered trademarks, and/or copyrighted property of **CAPCOM CO., LTD.**
   - All rights belong to their respective owners. No copyright or trademark infringement is intended.

3. **No Commercial Exploitation:**
   This modification is distributed entirely free of charge. No payment, paywall, donation gate, or commercial license is required to download or use this software.

4. **"As-Is" Software Disclaimer:**
   THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS, CONTRIBUTORS, OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

5. **Save Game & User Responsibility:**
   Modding video games always carries inherent risks. Users are strongly advised to create backup copies of their Dragon's Dogma 2 save files prior to installing or running any third-party modifications. The authors assume no liability for lost saves, corrupted data, or software conflicts.
