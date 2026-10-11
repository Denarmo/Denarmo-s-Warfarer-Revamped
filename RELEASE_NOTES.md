# Release v1.1.5 — Denarmo's Warfarer Revamped

- Adds saved text-size sliders for the combat chat log (12–40 px) and floating 3D damage numbers (16–72 px).
- Scales the log header and row spacing with the selected text size. Extends the log width slider to 1200 px.
- Applies floating font sizes to the native world-text renderer and screen-space test number, with larger text for big hits.
- Replaces raw target object identifiers with game display names, NPC names, or a species name from the character ID. Damage and reaction entries share the resolver.
- Retains the syntax and ImGui cleanup fixes from v1.1.3 and v1.1.4.

Enemy ID/name reference: [xyzkljl1/MyDD2Mod](https://github.com/xyzkljl1/MyDD2Mod/blob/main/enemy_dump.csv).

## Validation

The full script compiles with Lua 5.4. Tests cover target-name resolution, size limits, normal drawing, and cleanup after simulated drawing errors. In-game display has not yet been verified.

## Package

`Denarmo's Warfarer Revamped v1.1.5.zip`

Copy the ZIP into Fluffy Mod Manager's `Games\DragonsDogma2\Mods` folder, refresh the mod list, and enable the updated version.
