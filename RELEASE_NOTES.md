# Release v1.0.8 — Denarmo's Warfarer Revamped

**Denarmo's Warfarer Revamped** is an all-in-one REFramework modification for *Dragon's Dogma 2*, combining radial weapon switching, dynamic vocations & 6-slot skillsets, Dark Arisen DLC integration, combat analytics, and configurable gameplay enhancements.

---

### 🚀 What's New in v1.0.8

1. **Fixed God Mode / Combat Damage Isolation (Fall Damage Toggle):**
   - **Zero Combat Damage Suppression:** Completely removed all fall damage suppression logic from `app.HitController:updateDamage`. In previous versions, unresolved enemy attacker references caused enemy hits on the Arisen to be mistakenly classified as environmental damage, triggering unintentional invulnerability (god mode).
   - **Vanilla Enemy Damage Restored:** Hits from enemies, bosses, spells, monster grabs, and projectiles now deal regular damage to the player exactly as designed by Capcom.
   - **Surgical Fall Damage Negation:** Directly and exclusively hooked the game's dedicated fall mechanics:
     - `app.Human:Chara_DamageFromFallHandler` (bypasses fall landing damage and loss gauge penalty).
     - `app.Character:callDamageFromFallHandlerIfNeeded` (suppresses fall damage dispatching on landing).
     - `app.Character:requestFallDead` (prevents fatal splat animations).
     - `app.Character:get_IsArisenFallDead` & `set_IsArisenFallDead` (negates Arisen fall death checks).
     - `app.Character:get_HeightDamageFromFallProp` & `get_HeightDieFromFallProp` (overrides fall threshold to 999,999m).
     - `app.Human:get_IsDamageFallHeight` & `app.Character:get_IsDamageFall` (returns false for all fall damage state checks).

2. **Guaranteed On-Screen Combat Damage Log Rendering:**
   - **Direct Draw List Pipeline:** Replaced `imgui.begin_window` with REFramework's direct foreground and background draw lists (`imgui.get_foreground_draw_list()` / `imgui.get_background_draw_list()`). This guarantees that combat damage numbers, weakpoint callouts, and DPS stats are visible in the HUD during regular gameplay without requiring the REFramework Insert menu to be open.
   - **Native Hardware Fallback:** If draw lists are unavailable, smoothly falls back to REFramework's native `draw` backbuffer rendering (`draw.filled_rect`, `draw.outline_rect`, `draw.text`).
   - **Auto-Retrying Direct2D Registration:** `re.on_frame` now periodically retries `d2d.register` when the `reframework-d2dx` plugin initializes, enabling hardware-accelerated fonts seamlessly when installed.
   - **Full Ultrawide & 3440x1440 Support:** Supports positioning in all four corners (Bottom-Left, Top-Left, Bottom-Right, Top-Right) with `Constrain to 16:9 HUD Area` toggle to center the overlay within the player's primary field of view on 21:9 and 32:9 displays.
   - **Interactive Live In-Menu Test:** "Send Test Log Entries" and "Preview Damage Log in HUD" provide immediate visual verification and positioning feedback.

3. **Spell Incantation Speed Multiplier Optimization:**
   - Hooked `app.Job06Parameter:getPrepareSpellTime` (Sorcerer) and `app.Job03Parameter` movement preparation rates (Mage), plus dynamic reflection across all spell preparation types for customizable casting speed multipliers (`1.0x` to `5.0x`).

---

### 📦 Release Asset
- `Denarmo's Warfarer Revamped v1.0.8.zip` (located in the `build/` folder)

### 💻 Installation
- **Fluffy Mod Manager:** Place `Denarmo's Warfarer Revamped v1.0.8.zip` into `<Fluffy Mod Manager>\Games\DragonsDogma2\Mods\`, refresh the mod list, and enable it.
- **Manual Install:** Extract the zip into your *Dragon's Dogma 2* game root folder (where `DD2.exe` is located).
