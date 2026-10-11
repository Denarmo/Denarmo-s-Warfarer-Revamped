# Release v1.0.9 — Denarmo's Warfarer Revamped

**Denarmo's Warfarer Revamped** is an all-in-one REFramework modification for *Dragon's Dogma 2*, combining radial weapon switching, dynamic vocations & 6-slot skillsets, Dark Arisen DLC integration, combat analytics, and configurable gameplay enhancements.

---

### 🚀 What's New in v1.0.9

1. **Re-engineered Combat Damage & Floating Numbers (Based on Nexus Mod 148 by xyzkljl1):**
   - **Battle-Tested Architecture:** Rebuilt the combat damage logging and detection engine based on the open-source architecture of *Damage Number* (Nexus mod 148 / xyzkljl1):
     - **Reliable Attacker Resolution:** Direct comparison of `damageInfo["<AttackOwnerObject>k__BackingField"]` against the Arisen's `GameObject` (`app.CharacterManager:get_ManualPlayer():get_GameObject()`), avoiding pointer comparison quirks.
     - **Floating 3D World Damage Numbers:** Added floating numbers rendered directly above targets in 3D world space using `draw.world_text`, featuring vertical drift physics, alpha fadeout, and color-coded criticals/weakpoints.
     - **Knockdown & Stagger Reaction Hooks:** Real-time logging of combat reactions by hooking `app.CommonDamageReaction` (`selectDamageActionShrink`, `selectDamageActionHitdown`, `selectDamageActionBlown`, `selectDamageActionLargeCharaDown`).
     - **Skill / Action Name Extraction:** Automatically inspects `damageInfo["<AttackUserData>k__BackingField"]` to identify and display the skill or attack name (e.g. `Heavensward`, `Burst Strike`, `Slash`).
     - **Hit Multipliers:** Tracks the exact damage rate (e.g. `x1.50`) on weakpoints and critical hits.
   - **Dual Display Modes:** Use the HUD Chat Overlay log, 3D floating damage numbers over enemy heads, or both simultaneously.

2. **Expanded Combat Log UI Settings:**
   - Added settings checkboxes for:
     - *Enable Floating 3D Damage Numbers (Over Enemy)*
     - *Show Skill / Action Name in Log*
     - *Show Damage Multiplier (e.g. x1.50)*
     - *Show Knockdown Reactions (Shrink, Blown, Down)*
   - Added instant one-click "Restore Damage Log Defaults" covering all new settings.
   - Updated interactive "Send Test Log Entries" to showcase skill names, multipliers, and knockdown reaction lines.

3. **Fall Damage & Combat Integrity:**
   - Fall damage negation remains surgically hooked to landing handlers (`Chara_DamageFromFallHandler`, `callDamageFromFallHandlerIfNeeded`, `requestFallDead`), ensuring normal enemy combat damage is completely unaffected.

---

### 📦 Release Asset
- `Denarmo's Warfarer Revamped v1.0.9.zip` (located in the `build/` folder)

### 💻 Installation
- **Fluffy Mod Manager:** Place `Denarmo's Warfarer Revamped v1.0.9.zip` into `<Fluffy Mod Manager>\Games\DragonsDogma2\Mods\`, refresh the mod list, and enable it.
- **Manual Install:** Extract the zip into your *Dragon's Dogma 2* game root folder (where `DD2.exe` is located).
