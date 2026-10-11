# Release v1.0.6 — Denarmo's Warfarer Revamped

**Denarmo's Warfarer Revamped** is an all-in-one REFramework modification for *Dragon's Dogma 2*, combining radial weapon switching, dynamic vocations & 6-slot skillsets, Dark Arisen DLC integration, combat analytics, and configurable gameplay enhancements.

---

### 🚀 What's New in v1.0.6

1. **Combat Damage Log On-Screen Text & Ultrawide Fix:**
   - **Guaranteed On-Screen Rendering:** Resolved an issue where REFramework's DirectX 12 backend failed to draw text using legacy drawing calls. The combat log is now rendered using a dedicated transparent, input-passthrough ImGui fullscreen overlay window (`dl:add_rect_filled`, `dl:add_text`, with Palatino Linotype or REFramework font scaling) identical to the proven Warfarer Arsenal wheel pipeline.
   - **Ultrawide & Multi-Monitor Support (21:9, 32:9):** Added a new setting `Constrain to 16:9 HUD Area (Ultrawide displays)` (enabled by default). When enabled, coordinates dynamically anchor relative to Dragon's Dogma 2's native 16:9 pillarbox safe area (`Wide.ox()`) rather than the monitor's outer physical edge, keeping the combat log perfectly visible within the player's primary vision. Can be toggled off to push the log to the monitor bezel if preferred.

2. **New Settings Tab: "Gameplay Tweaks (Incantation Speed & Fall Damage)":**
   - **Incantation Speed Multiplier:**
     - Allows fine-tuning the casting and preparation speed of spells for Mage, Sorcerer, and magic vocations.
     - Smooth slider from `1.0x` (Vanilla) to `5.0x` (Instant) with steps of `0.05x`.
     - Convenient one-click quick presets: `1.0x (Normal)`, `1.5x`, `2.0x (Fast)`, `3.0x (Very Fast)`, and `5.0x (Instant)`.
     - Safely hooks into character magic controllers and parameters (`app.HumanMagicController`, `app.HumanMagicParameter`, `app.Job03Parameter`, `app.Job06Parameter`).
   - **Disable Fall Damage:**
     - Checkbox toggle to completely eliminate fatal fall heights and fall impact damage for the Arisen.
     - Multi-layer protection: sets `CharacterFallParam` damage and fatal thresholds to immune heights, suppresses `calcFallDamage` calculations on fall controllers, and intercepts fall damage in `app.HitController:updateDamage`.
   - **Restore Defaults:**
     - Includes individual `[Reset]` buttons for each setting, plus a one-click `Restore Gameplay Defaults` button.

---

### 📦 Release Asset
- `Denarmo's Warfarer Revamped v1.0.6.zip` (located in the `build/` folder)

### 💻 Installation
- **Fluffy Mod Manager:** Place `Denarmo's Warfarer Revamped v1.0.6.zip` into `<Fluffy Mod Manager>\Games\DragonsDogma2\Mods\`, refresh the mod list, and enable it.
- **Manual:** Extract `reframework/` to your Dragon's Dogma 2 game directory (`D:\SteamLibrary\steamapps\common\Dragons Dogma 2`). Requires [REFramework](https://github.com/praydog/REFramework).
