# Release v1.0.3 — Denarmo's Warfarer Revamped

**Denarmo's Warfarer Revamped** is an all-in-one REFramework modification for *Dragon's Dogma 2*, updated with full support for the *Dragon's Dogma 2: Dark Arisen* expansion.

---

### 🚀 What's New in v1.0.3

1. **Fixed & Enhanced Combat Damage Log (HUD Chat Overlay):**
   - **Reliable Damage Capture:** Fixed entity and projectile resolution in the IL2CPP damage hook (`app.HitController:updateDamage`). Attacking with any weapon type, arrow, magick bolt, spell, or pawn attack now reliably logs damage dealt to monsters and bosses.
   - **Foreground Overlay Rendering:** The combat log is now drawn via a dedicated transparent overlay window on the top ImGui layer, eliminating issues where DirectX 12 or scene post-processing occluded background draw calls.
   - **Font & Glyph Safety:** Eliminated multi-byte UTF-8 glyphs in favor of ASCII labels (`[Combat Log]`, `->`, `[WEAKPOINT!]`), preventing font renderer crashes or silent text drops on standard REFramework font configurations.
   - **Live HUD Preview Mode:** Added a "Preview Damage Log in HUD" toggle in the REFramework menu so you can keep sample entries on screen while adjusting screen corner, margins X/Y, width, and background opacity.
   - **Enabled by Default:** Fresh installations now have the Combat Damage Log enabled by default.

2. **Restore Defaults for Each Setting & Category:**
   - **Individual Setting Reset:** Every single setting (sliders, checkboxes, combos) now features a dedicated `[Reset]` button right next to it, allowing you to instantly revert any individual setting back to its factory default without touching the rest of your setup.
   - **Section Restore Buttons:** Added one-click restore buttons for every major category:
     - *Restore General Defaults*
     - *Restore Slow Motion Defaults*
     - *Restore Controller Defaults*
     - *Restore Look Defaults*
     - *Restore Mouse Defaults*
     - *Restore Skillset Settings Defaults*
     - *Restore Damage Log Defaults*
   - **Master Restore:** Added a top-level *Restore All Mod Settings to Defaults* button for a complete, clean reset.

---

### 📦 Release Asset
- `Denarmo's Warfarer Revamped v1.0.3.zip` (located in the `build/` folder)

### 💻 Installation
- **Fluffy Mod Manager:** Place `Denarmo's Warfarer Revamped v1.0.3.zip` in `<Fluffy Mod Manager>\Games\DragonsDogma2\Mods\`, refresh the mod list, and enable it.
- **Manual:** Extract `reframework/` to your Dragon's Dogma 2 game directory. Requires [REFramework](https://github.com/praydog/REFramework).
