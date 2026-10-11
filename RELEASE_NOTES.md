# Release v1.0.7 — Denarmo's Warfarer Revamped

**Denarmo's Warfarer Revamped** is an all-in-one REFramework modification for *Dragon's Dogma 2*, combining radial weapon switching, dynamic vocations & 6-slot skillsets, Dark Arisen DLC integration, combat analytics, and configurable gameplay enhancements.

---

### 🚀 What's New in v1.0.7

1. **Direct2D Hardware-Accelerated Combat Damage Log Overlay:**
   - **Native DirectX 12 Presentation Rendering:** Migrated the combat damage log from ImGui to native Direct2D (`d2d.register`) via the industry-standard `reframework-d2dx` plugin (the same technology utilized by popular combat meters like *Team Damage Meter* and *Damage Number*).
   - **Renders During Active Gameplay:** Direct2D renders directly into the swapchain every single game frame, ensuring damage numbers, enemy hit tags, and DPS statistics remain fully visible while fighting, roaming, and exploring without requiring the REFramework menu (Insert key) to be open.
   - **Ultrawide & High-Resolution Display Support (21:9, 32:9, 3440x1440):** 
     - Queries `d2d.surface_size()` for pixel-exact monitor dimensions.
     - With `Constrain to 16:9 HUD Area` enabled, dynamically centers the combat log within the 16:9 gameplay safe zone (e.g. 2560x1440 centered on 3440x1440) for immediate peripheral visibility.
     - Supports all four screen corners (Bottom-Left, Top-Left, Bottom-Right, Top-Right) with customizable X/Y margins and width.
   - **Rich Color & Typography Hierarchy:**
     - Header: Warm Arisen Gold (`#D8C08A`) with real-time encounter DPS and total damage.
     - Arisen Damage: Crisp White.
     - Weakpoint Hits: Fiery Orange-Red with `[WEAKPOINT!]` indicator.
     - High Impact Hits (>=1,000 damage): Radiant Gold.
     - Pawn Damage: Soft Cyan.
     - Dynamic 1-second alpha fadeout as hits expire.
   - **Immediate In-Menu Verification:** "Send Test Log Entries" and HUD Preview toggle let you position and test the log anywhere on screen instantly.
   - **ImGui Fallback:** Gracefully falls back to ImGui drawing if the Direct2D plugin is ever absent.

2. **Complete Fall Damage Elimination Fix:**
   - **Airtight Player Entity Pointer Resolution:** Fixed an issue where REFramework Lua wrapper userdata references caused `targetChara == pChar` comparisons to fail. Implemented raw 64-bit native pointer matching (`:get_address()`) across character entities and GameObjects.
   - **Zero-Damage & Original Call Suppression:** In `app.HitController:updateDamage`, when the Arisen suffers non-enemy damage (fall impact, gravity, or environmental impact), damage, damage points, and loss damage are zeroed out and `sdk.PreHookResult.SKIP_ORIGINAL` is returned, preventing health loss and loss gauge penalties entirely.
   - **Dynamic Engine Fall & Fatal Height Hooking:** Broadened dynamic reflection across all IL2CPP candidate types (`app.Human`, `app.HumanFallController`, `app.FallController`, `app.HumanFallParam`, `app.HumanDamageController`, `app.LossGaugeController`, etc.) to eliminate fatal landing states and override fatal fall heights to 99,999m.

3. **Spell Incantation Speed Multiplier Dynamic Reflection:**
   - Dynamically discovers and hooks magic preparation and chant rate methods across magic vocations (Mage, Sorcerer, Magic Archer, Warfarer) with customizable multipliers from `1.0x` (Vanilla) up to `5.0x` (Instant).

---

### 📦 Release Asset
- `Denarmo's Warfarer Revamped v1.0.7.zip` (located in the `build/` folder)

### 💻 Installation
- **Fluffy Mod Manager:** Place `Denarmo's Warfarer Revamped v1.0.7.zip` into `<Fluffy Mod Manager>\Games\DragonsDogma2\Mods\`, refresh the mod list, and enable it.
- **Prerequisites:** [REFramework](https://github.com/praydog/REFramework) and [D2DX (reframework-d2d)](https://github.com/cursey/reframework-d2d) (included with standard Fluffy mod setups).
- **Manual:** Extract `reframework/` to your Dragon's Dogma 2 game directory (`D:\SteamLibrary\steamapps\common\Dragons Dogma 2`).
