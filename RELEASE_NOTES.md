# Release v1.1.0 — Denarmo's Warfarer Revamped

**Denarmo's Warfarer Revamped** is an all-in-one REFramework modification for *Dragon's Dogma 2*, combining radial weapon switching, dynamic vocations & 6-slot skillsets, Dark Arisen DLC integration, combat analytics, and configurable gameplay enhancements.

---

### 🚀 What's New in v1.1.0

1. **Fixed Damage Numbers & Combat Log Rendering On-Screen:**
   - **Root Cause Resolution:** Previously, the damage hook successfully intercepted combat hits (as verified in the REFramework log), but numbers failed to appear on screen because:
     1. In `re.on_frame` during regular gameplay (when the REFramework menu is closed), ImGui draw lists are discarded and not presented.
     2. `draw.world_text` for 3D floating damage numbers requires an explicitly loaded and pushed large font (size ~60–85); without it, numbers render at microscopic 13px world scale and become invisible.
     3. Capcom's internal skill names in Dragon's Dogma 2 are in Japanese (`ダッシュ 弱攻撃`, `通常攻撃`), which caused default font render calls to fail without CJK glyph ranges.
   - **REFramework Native `draw` Engine:** Switched both the HUD Combat Log and 3D Floating Damage Numbers exclusively to REFramework's native DirectX 12 backbuffer `draw` API (`draw.filled_rect`, `draw.outline_rect`, `draw.text`, `draw.world_text`), ensuring guaranteed rendering on every frame whether the REFramework menu is open or closed.
   - **Font System Integration:**
     - `times.ttf` / `arial.ttf` at size 60 (normal hits) and size 85 (criticals & >= 1000 damage) for clean, bold 3D world text drifting above monsters.
     - `msgothic.ttc` (with fallback to `segoeui.ttf` and `arial.ttf`) with full CJK glyph ranges for the HUD Combat Log.
   - **Action & Skill Name Translation:** Added automatic translation for common Japanese attack names (e.g. `ダッシュ 弱攻撃` -> `Sprint Light Attack`, `兜割り` -> `Helm Splitter`, `弱攻撃` -> `Light Attack`).
   - **Vibrant ARGB Color Palette:**
     - White (`0xFFFFFFFF`) for standard hits
     - Bright Orange-Red (`0xFFFF3020`) for weakpoints and criticals
     - Radiant Gold (`0xFFFFD700`) for heavy hits (>= 1,000 damage)
     - Sky Blue (`0xFF60D0FF`) for Pawns
     - Amber Orange (`0xFFFFA500`) for Staggers and Knockdowns
   - **Interactive Live In-Menu Test:** Clicking "Send Test Log Entries" now displays test combat log entries AND instantly spawns a floating 3D critical damage number (`1450!`) right above the Arisen for visual verification.

2. **Attacker & Player Object Reference Fix:**
   - Corrected attacker reference matching from `P.go` to `P.player_go` alongside `mainplayerGO`, ensuring Warfarer hits are always correctly credited.

---

### 📦 Release Asset
- `Denarmo's Warfarer Revamped v1.1.0.zip` (located in the `build/` folder)

### 💻 Installation
- **Fluffy Mod Manager:** Place `Denarmo's Warfarer Revamped v1.1.0.zip` into `<Fluffy Mod Manager>\Games\DragonsDogma2\Mods\`, refresh the mod list, and enable it.
- **Manual Install:** Extract the zip into your *Dragon's Dogma 2* game root folder (where `DD2.exe` is located).
