# Release v1.1.1 — Denarmo's Warfarer Revamped

**Denarmo's Warfarer Revamped** is an all-in-one REFramework modification for *Dragon's Dogma 2*, combining radial weapon switching, dynamic vocations & 6-slot skillsets, Dark Arisen DLC integration, combat analytics, and configurable gameplay enhancements.

---

### 🚀 What's New in v1.1.1

1. **Re-engineered Damage UI Using the Weapon Swapping Menu's Architecture:**
   - **Full UI Engine Alignment:** Analyzed and ported the exact rendering pipeline used by the radial weapon wheel to generate combat UI elements:
     - **Invisible Fullscreen Overlay Window:** Opened with `OVERLAY_FLAGS` (`NoTitleBar`, `NoResize`, `NoMove`, `NoInputs`, `NoSavedSettings`, `NoFocusOnAppearing`), giving an input-transparent, borderless drawing canvas directly in `re.on_frame`.
     - **Window Draw List:** Retrieves `imgui.get_window_draw_list()` with fullscreen clipping (`dl:push_clip_rect_fullscreen()`), matching the weapon wheel's rendering system.
     - **Built-in `font_for(size)` Pipeline:** Utilizes the mod's bundled `pala.ttf` font and cached sizes, expanded up to size 72 for large, crisp floating combat numbers.
     - **Drop Shadow & Centering (`text_c` / `measure`):** Draws drop-shadowed, centered numbers identical to the wheel's vocation badges and center text for clean legibility against any background.
   - **3D-to-2D World Projection:**
     - Uses REFramework's `draw.world_to_screen(worldPos)` to project 3D entity hit positions directly to 2D screen coordinates, rendering floating numbers via the weapon wheel's UI engine while rising upwards (`worldPos.y = worldPos.y + 0.016`).
     - Includes direct 2D screen coordinate fallback (`DamageLog.add_floating_screen`) ensuring numbers always render on screen.
   - **Theme-Integrated HUD Combat Log Panel:**
     - Rendered on the overlay draw list with rounded background (`{ 20, 18, 14, bgAlpha }`), gold Arisen trim border (`T("accent")`), and soft trim divider (`T("accent_soft")`).
     - Uses Lua pattern matching to safely translate internal Capcom Japanese action names (`Sprint Light Attack`, `Heavy Attack`, `Plunging Attack`, etc.).
   - **Interactive Live In-Menu Test:**
     - Clicking "Send Test Log Entries" now displays HUD log entries AND spawns both a world-space 3D floating damage number over the Arisen and a screen-space floating critical number (`1450!`) for immediate visual verification.

---

### 📦 Release Asset
- `Denarmo's Warfarer Revamped v1.1.1.zip` (located in the `build/` folder)

### 💻 Installation
- **Fluffy Mod Manager:** Place `Denarmo's Warfarer Revamped v1.1.1.zip` into `<Fluffy Mod Manager>\Games\DragonsDogma2\Mods\`, refresh the mod list, and enable it.
- **Manual Install:** Extract the zip into your *Dragon's Dogma 2* game root folder (where `DD2.exe` is located).
