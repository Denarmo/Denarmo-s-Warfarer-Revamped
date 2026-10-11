--[[
  Warfarer's Arsenal 1.1.5 - a weapon / vocation wheel for the Warfarer (Dragon's Dogma 2).
  Needs REFramework (no other plugins).

  Install:  <DD2 folder>/reframework/autorun/WarfarerArsenal.lua
  Font:     the wheel uses Palatino Linotype (pala.ttf) when that file is in <DD2 folder>/reframework/fonts, else REFramework's font
  Settings: REFramework menu (Insert) > Script Generated UI > Warfarer's Arsenal; saved in <DD2 folder>/reframework/data/WarfarerArsenal/config.json

  Use:      hold the hotkey (default: Mouse 4, the Back side button) or the controller button (default: View, held for a moment), steer
            with the mouse or the stick, release to pick. The wheel lists the Warfarer's Rearmament weapons, in slow motion while it is
            open. Optionally the wheel also opens when the Rearmament skill itself is held (a short tap stays a normal Rearmament).
            A tap of the controller button reaches the game as usual (View opens the map): bind a button that does nothing in the
            game, or two buttons together, to avoid that.
            The GUI copies (icons, menu background) are placed from measurements taken while the game runs, inside the game's own
            picture (Geo), so any resolution and aspect ratio works (16:9, 21:9, 21:10, 32:9 ...) without settings.

  How a pick works
    The game keeps the Rearmament slot it is on as an index and a Rearmament press equips the slot after it. The mod calls the
    game's own ItemManager.setNextArisenWeapon() until the index sits on the slot before the wanted one, then makes one normal
    Rearmament press: the game itself equips the wanted slot, main weapon and off-hand. Nothing is recorded or rewritten.
    Every switch is checked. If the weapon does not land on the wanted slot the mod tries again; if that keeps failing the route is
    dropped for the session and the wheel cycles with ordinary Rearmaments, one per weapon in between.

  How the wheel is drawn
    * The vocation icons are the game's own: copies of the HUD GUI (ui022601) with only the job icon left, one per slice.
      A game GUI is drawn before REFramework's overlay, so the wheel cuts round holes into its dim background and slices.
    * The slices' background is the game's own system menu background, cut to the wheel's shape from GUI copies of it.
    * Everything else (slices, trim, text, dimmer) is drawn with REFramework's imgui draw list.
]]
local MOD, VERSION, CFG_VERSION = "Denarmo's Warfarer Revamped", "1.0.8", 46
local CFG_FILE = "WarfarerRevamped/config.json"
local TAU = math.pi * 2
local BF_INDEX = "<CurrentArisenWeaponIndex>k__BackingField"

-- timings (frames)
local MIN_FRAMES_AFTER_SWAP, MIN_FRAMES_BETWEEN_SWITCHES = 30, 45
local STEP_SETTLE, STEP_VERIFY, INSTANT_VERIFY, SLOW_RAMP_FRAMES = 2, 90, 8, 6
local SAFETY_SETTLE = 30             -- frames the wheel stays shut after the Rearmament equipment changed

local JOBS = {
  [1]  = { name = "Fighter",          weapon = "Sword & Shield", abbr = "FI" },
  [2]  = { name = "Archer",           weapon = "Bow",            abbr = "AR" },
  [3]  = { name = "Mage",             weapon = "Staff",          abbr = "MA" },
  [4]  = { name = "Thief",            weapon = "Daggers",        abbr = "TH" },
  [5]  = { name = "Warrior",          weapon = "Two-Hander",     abbr = "WA" },
  [6]  = { name = "Sorcerer",         weapon = "Archistaff",     abbr = "SO" },
  [7]  = { name = "Mystic Spearhand", weapon = "Duospear",       abbr = "MS" },
  [8]  = { name = "Magick Archer",    weapon = "Magick Bow",     abbr = "MK" },
  [9]  = { name = "Trickster",        weapon = "Censer",         abbr = "TR" },
  [10] = { name = "Warfarer",         weapon = "Any",            abbr = "WF" },
}

------------------------------------------------------------------------------------------------
-- Config
------------------------------------------------------------------------------------------------
local THEME_DEFAULT = {
  slice       = { 20, 18, 14, 210 },
  slice_hover = { 108, 82, 38, 240 },
  slice_off   = { 20, 18, 14, 140 },
  backdrop    = { 0, 0, 0, 110 },
  bg_fill     = { 33, 28, 27, 255 },
  center      = { 12, 10, 8, 235 },
  accent      = { 214, 178, 98, 255 },
  accent_soft = { 214, 178, 98, 110 },
  accent_hi   = { 255, 226, 150, 255 },
  text        = { 236, 228, 210, 255 },
  text_dim    = { 165, 155, 135, 255 },
  equipped    = { 120, 200, 140, 255 },
}
local THEME_LABELS = {
  { "slice", "Slice" }, { "slice_hover", "Slice hovered" }, { "slice_off", "Slice (not switchable)" },
  { "backdrop", "Ring backdrop" }, { "bg_fill", "Menu background fill (circle edge)" }, { "center", "Centre disc" }, { "accent", "Trim" }, { "accent_soft", "Trim (faint)" },
  { "accent_hi", "Trim (highlight)" }, { "text", "Text" }, { "text_dim", "Text (dim)" }, { "equipped", "Weapon in hand marker" },
}

local DEFAULTS = {
  cfg_version = CFG_VERSION,
  enabled = true,
  hotkey = { 0x05 },
  order_mode = 1,                       -- 1 Rearmament order, 2 vocation order
  -- look
  scale = 1.0, auto_scale = true,
  wheel_radius = 240, inner_radius = 115, center_radius = 92, slice_gap_deg = 2.0,
  dim_enabled = true, dim_alpha = 0.55,
  hide_center_weapon = false,           -- the weapon name in the wheel's inner circle
  hide_center_job = false,              -- the vocation name in the wheel's inner circle
  skill_wheel = false,                  -- the wheel opens while the player holds the Rearmament skill
  skill_hold = 0.25,                    -- how long (seconds) before it opens; a shorter tap is a normal Rearmament
  show_name = false,                    -- the hovered slice's vocation name next to the wheel (off by default)
  game_icons = true, icon_size_k = 1.0, icon_art_k = 0.9,
  font_file = "pala.ttf",               -- the font that ships with the mod; "" = REFramework's own font; or another file in <game>/reframework/fonts
  font_gen = 1,                         -- raised whenever a font may be stuck as "not found" in REFramework's font cache (see Fonts)
  theme = THEME_DEFAULT,
  -- slow motion
  slowmo_enabled = true, slowmo_scale = 0.3,
  block_input_while_open = false,
  -- controller
  pad_enabled = true, pad_getter = "get_Button", pad_button = 0, pad_combo = false, pad_button2 = 0, pad_type = 1, pad_inited = false, pad_hold = 0.4, pad_stick = 1, pad_dead = 35, pad_flip_y = false,
  -- mouse
  select_mode = 1, mouse_source = 1, mouse_sens = 1.0, deadzone = 12, stick_max = 100, cancel_rmb = true,
  -- the vocation the wheel works on (Warfarer)
  warfarer_job = 10,
  -- Vocation Skillsets & Presets (Enhanced Warfarer + Dark Arisen DLC)
  skill_swap_enabled = true,
  skill_swap_mode = "Toggle",
  max_presets_toggle = 5,
  max_presets_hold = 2,
  hotkey_skill_swap = { 0xA4 }, -- L-Alt
  show_swap_notification = true,
  rearmament_stamina_consumption = true,
  filter_guild_skills_by_weapon = true,
  load_guild_class_skills = true,
  unlock_all_skills_in_presets = true,
  free_rearmament_slot = true,
  -- Combat Damage Log UI
  damage_log_enabled = true,
  damage_log_preview = false,
  damage_log_corner = 1, -- 1: Bottom-Left, 2: Top-Left, 3: Bottom-Right, 4: Top-Right
  damage_log_max_lines = 8,
  damage_log_duration = 5.0,
  damage_log_offset_x = 35,
  damage_log_offset_y = 60,
  damage_log_width = 380,
  damage_log_bg_opacity = 0.70,
  damage_log_player_only = true,
  damage_log_include_pawns = true,
  damage_log_show_weakpoint = true,
  damage_log_show_dps = true,
  damage_log_ultrawide_constrain = true,
  -- Gameplay Tweaks (Incantation Speed & Fall Damage)
  incantation_speed_mult = 1.0,
  no_fall_damage = false,
  vocation_presets = {},
  ico_path = {},                        -- child indices from the icon GUI's root to tex_Job00 (found once, then reused)
  game_bg = true,                       -- the game's own menu background replaces the dark fills of the wheel
  bg_path = {},                         -- child indices from the background GUI's root to its tex_ control
  bg_tol = 26,                          -- widest flat-fill crescent at the shape's edges (GUI units); lower = more GUI copies
  hl_alpha = 120,                       -- opacity of the highlight over the whole hovered slice
  bg_grain = 0,                         -- brightness variation of the flat fill (it showed as streaks; 0 = flat)
  bg_follow_hover = false,              -- a hovered slice takes its background pieces along (its old place is dimmed like the other gaps)
  bg_max = 64,                          -- never more GUI copies than this (each is a full copy of the menu GUI)
  bg_blocks = true,                     -- slices of four or more: five big rectangles each (the layout drawn by hand in the slice editor)
  bg_outline = 3,                       -- thickness of the yellow outline of the slices (px at scale 1)
  bg_hover_cover = true,                -- the selected slice gets a flat base and a thicker border in the background colour (when the pieces do not follow it)
  bg_border = 6,                        -- thick foreground border round slices and disc (px at scale 1): hides the edges of rectangles that reach past the outline
  bg_fan = true,                        -- slices: a fan of strips that each run from the inner to the outer arc (false: rows across the slice)
  bg_pivot_center = false,              -- the strips turn around their centre instead of their top-left corner (only if they come out displaced)
  bg_rot_flip = false,                  -- turn the background strips the other way (only if the strips come out scattered)
  bg_cover_frames = 3,                  -- frames the overlay covers the background pieces after the wheel opens (a GUI change shows up later than the overlay)
  bg_close_frames = 3,                  -- the same after the wheel closed (the pieces vanish later than the overlay; 0 = no cover)
}
local INT_KEYS = { "order_mode", "wheel_radius", "inner_radius", "center_radius", "select_mode", "mouse_source", "deadzone",
  "stick_max", "warfarer_job", "bg_tol", "bg_max", "hl_alpha", "bg_grain", "bg_cover_frames", "bg_close_frames", "bg_border", "bg_outline", "pad_button", "pad_button2", "pad_type", "pad_stick", "pad_dead", "damage_log_corner", "damage_log_max_lines", "damage_log_offset_x", "damage_log_offset_y", "damage_log_width" }

local cfg, frame, dirty = {}, 0, false
local SCALE_BASE = 1.2                      -- the wheel's size at "scale 1.0" is what 1.2 used to be
local last_error = nil                   -- shown at the bottom of the settings window

local function deep_copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = deep_copy(x) end
  return t
end

local function load_cfg()
  for k, v in pairs(DEFAULTS) do cfg[k] = deep_copy(v) end
  local ok, saved = pcall(json.load_file, CFG_FILE)
  if ok and type(saved) == "table" then
    for k, v in pairs(saved) do
      if DEFAULTS[k] ~= nil and type(v) == type(DEFAULTS[k]) and k ~= "theme" then cfg[k] = v end
    end
    if type(saved.theme) == "table" then
      for k in pairs(THEME_DEFAULT) do
        local c = saved.theme[k]
        if type(c) == "table" and #c == 4 then cfg.theme[k] = { tonumber(c[1]) or 0, tonumber(c[2]) or 0, tonumber(c[3]) or 0, tonumber(c[4]) or 255 } end
      end
    end
    if (cfg.bg_max or 0) > 140 then cfg.bg_max = 140 end              -- the game breaks above about 141 GUI copies
  end
  if ok and type(saved) == "table" and (tonumber(saved.cfg_version) or 0) < 40 and cfg.icon_art_k >= 0.99 then
    cfg.icon_art_k = DEFAULTS.icon_art_k            -- the shield's tip was trimmed by the ring at 1.0: the art now fits inside the hole
  end
  if ok and type(saved) == "table" and (tonumber(saved.cfg_version) or 0) < 41 and cfg.bg_close_frames == 6 then
    cfg.bg_close_frames = DEFAULTS.bg_close_frames     -- the flat cover after the wheel closed lingered a little too long
  end
  cfg.cfg_version = CFG_VERSION
  for _, k in ipairs({ "wide_mode", "bg_wide_mode", "pic_mode", "pic_aspect", "gui_scale", "ico_off_x", "ico_off_y", "bg_off_x", "bg_off_y", "dbg_no_tint", "dbg_no_cover", "dbg_no_border" }) do cfg[k] = nil end
  for _, k in ipairs(INT_KEYS) do cfg[k] = math.floor(tonumber(cfg[k]) or DEFAULTS[k]) end
  local hk = {}
  for _, vk in ipairs(cfg.hotkey) do hk[#hk + 1] = math.floor(tonumber(vk) or 0) end
  cfg.hotkey = hk
end
local function save_cfg() pcall(json.dump_file, CFG_FILE, cfg); dirty = false end
local function mark_dirty() dirty = true end
load_cfg()

local function log_act(msg) pcall(log.info, "[WarfarerArsenal] " .. msg) end
local logged_once = {}
local function log_once(key, msg) if not logged_once[key] then logged_once[key] = true; log_act(msg) end end

------------------------------------------------------------------------------------------------
-- Reflection helpers
------------------------------------------------------------------------------------------------
local function scall(obj, name, ...)
  if obj == nil then return false, "nil object" end
  local args = table.pack(...)
  return pcall(function() return obj:call(name, table.unpack(args, 1, args.n)) end)
end
local function mcall(obj, name, ...)
  local ok, r = scall(obj, name, ...)
  if ok then return r end
  return nil
end
local function mfield(obj, name)
  if obj == nil then return nil end
  local ok, r = pcall(function() return obj:get_field(name) end)
  if ok then return r end
  return nil
end
local function xy(v)
  if v == nil then return nil end
  local ok, x, y = pcall(function() return v.x, v.y end)
  if ok and type(x) == "number" and type(y) == "number" then return x, y end
  ok, x, y = pcall(function() return v:get_field("x"), v:get_field("y") end)
  if ok and type(x) == "number" and type(y) == "number" then return x, y end
  return nil
end
local function rd_num(v, k)
  local ok, x = pcall(function() return v[k] end)
  if ok and type(x) == "number" then return x end
  ok, x = pcall(function() return v:get_field(k) end)
  if ok and type(x) == "number" then return x end
  return nil
end
local function addr_of(o)
  local ok, a = pcall(function() return o:get_address() end)
  return ok and a or nil
end

------------------------------------------------------------------------------------------------
-- Player and wheel state
------------------------------------------------------------------------------------------------
local P = { char = nil, human = nil, jobctx = nil, job = nil, player_go = nil, char_addr = nil, go_addr = nil }
local W = { open = false, pinned = false, options = {}, sel = nil, sx = 0, sy = 0, angle = nil, prev_held = false, equipped = nil }

local function is_same_ptr(a, b)
  if not a or not b then return false end
  if a == b then return true end
  local okA, addrA = pcall(function() return a:get_address() end)
  local okB, addrB = pcall(function() return b:get_address() end)
  return (okA and okB and addrA and addrB and addrA ~= 0 and addrA == addrB)
end

local function is_player_entity(entity)
  if not entity then return false end
  if P.char_addr then
    local ok, addr = pcall(function() return entity:get_address() end)
    if ok and addr and addr == P.char_addr then return true end
  end
  if P.go_addr then
    local ok, addr = pcall(function() return entity:get_address() end)
    if ok and addr and addr == P.go_addr then return true end
    local ok2, entGO = pcall(function() return entity:get_GameObject() end)
    if ok2 and entGO then
      local ok3, goAddr = pcall(function() return entGO:get_address() end)
      if ok3 and goAddr and goAddr == P.go_addr then return true end
    end
  end
  if is_same_ptr(entity, P.char) or is_same_ptr(entity, P.human) then return true end
  local isP = false
  pcall(function() isP = entity:call("isPlayer") end)
  if isP == true then return true end
  pcall(function() isP = entity:call("get_IsPlayer") end)
  if isP == true then return true end
  return false
end

local function is_pawn_entity(entity)
  if not entity then return false end
  local isPw = false
  pcall(function() isPw = entity:call("isPawn") end)
  if isPw == true then return true end
  pcall(function() isPw = entity:call("get_IsPawn") end)
  if isPw == true then return true end
  return false
end

local function refresh_player()
  local cm = sdk.get_managed_singleton("app.CharacterManager")
  P.char = mcall(cm, "get_ManualPlayer()")
  P.human = mcall(P.char, "get_Human()")
  P.jobctx = mcall(P.human, "get_JobContext()")
  P.job = tonumber(mfield(P.jobctx, "CurrentJob"))
  P.player_go = P.char and mcall(P.char, "get_GameObject()")
  local okA, addrA = pcall(function() return P.char and P.char:get_address() end)
  P.char_addr = okA and addrA or nil
  local okG, addrG = pcall(function() return P.player_go and P.player_go:get_address() end)
  P.go_addr = okG and addrG or nil
end
local function gui_mgr() return sdk.get_managed_singleton("app.GuiManager") end
local function is_paused() return mcall(gui_mgr(), "isPausedGUI()") == true end
local function is_loading() return mcall(gui_mgr(), "get_IsLoadGui()") == true end
local function stamina() return tonumber(mcall(mcall(P.char, "get_StaminaManager()"), "get_RemainingAmount()")) end
-- the vocation of the weapon in hand (1..9)
local function read_weapon_job()
  local v = tonumber(mfield(P.char, "WeaponJob"))
  if v and v >= 1 and v <= 9 then return math.floor(v) end
  return nil
end

------------------------------------------------------------------------------------------------
-- Input: hotkey and key binding
------------------------------------------------------------------------------------------------
local VK_NAMES = {
  [1] = "Mouse Left", [2] = "Mouse Right", [4] = "Mouse Middle", [5] = "Mouse 4 (Back)", [6] = "Mouse 5 (Forward)",
  [8] = "Backspace", [9] = "Tab", [13] = "Enter", [16] = "Shift", [17] = "Ctrl", [18] = "Alt", [20] = "Caps Lock",
  [27] = "Esc", [32] = "Space", [33] = "Page Up", [34] = "Page Down", [35] = "End", [36] = "Home",
  [37] = "Left", [38] = "Up", [39] = "Right", [40] = "Down", [45] = "Insert", [46] = "Delete",
  [0xA0] = "L-Shift", [0xA1] = "R-Shift", [0xA2] = "L-Ctrl", [0xA3] = "R-Ctrl", [0xA4] = "L-Alt", [0xA5] = "R-Alt",
  [0xC0] = "`",
}
for i = 0, 9 do VK_NAMES[0x30 + i] = tostring(i); VK_NAMES[0x60 + i] = "Num " .. i end
for i = 0, 25 do VK_NAMES[0x41 + i] = string.char(65 + i) end
for i = 1, 12 do VK_NAMES[0x6F + i] = "F" .. i end
local function vk_name(vk) return VK_NAMES[vk] or string.format("VK_0x%02X", vk) end

local MOUSE_IMGUI = { [1] = 0, [2] = 1, [4] = 2, [5] = 3, [6] = 4 }
local function is_vk_down(vk)
  local ok, r = pcall(function() return reframework:is_key_down(vk) end)
  if ok and r then return true end
  local mi = MOUSE_IMGUI[vk]
  if mi then
    local ok2, r2 = pcall(imgui.is_mouse_down, mi)
    if ok2 and r2 then return true end
  end
  return false
end
local function hotkey_str(keys)
  keys = keys or cfg.hotkey
  if #keys == 0 then return "(none)" end
  local t = {}
  for _, vk in ipairs(keys) do t[#t + 1] = vk_name(vk) end
  return table.concat(t, " + ")
end
local function hotkey_held()
  if #cfg.hotkey == 0 then return false end
  for _, vk in ipairs(cfg.hotkey) do if not is_vk_down(vk) then return false end end
  return true
end
local function hotkey_contains(vk)
  for _, k in ipairs(cfg.hotkey) do if k == vk then return true end end
  return false
end

local Bind = { state = nil, peak = {}, timer = 0 }
local function scan_down()
  local down, set = {}, {}
  for vk = 1, 254 do if is_vk_down(vk) then down[#down + 1] = vk; set[vk] = true end end
  for _, p in ipairs({ { 0x10, 0xA0, 0xA1 }, { 0x11, 0xA2, 0xA3 }, { 0x12, 0xA4, 0xA5 } }) do
    if set[p[1]] then set[p[2]] = nil; set[p[3]] = nil end
  end
  local out = {}
  for _, vk in ipairs(down) do if set[vk] then out[#out + 1] = vk end end
  return out
end
function Bind.start() Bind.state = "release"; Bind.peak = {}; Bind.timer = 0 end
function Bind.update()
  if not Bind.state then return end
  Bind.timer = Bind.timer + 1
  if Bind.timer > 900 then Bind.state = nil; return end
  local down = scan_down()
  if Bind.state == "release" then
    if #down == 0 then Bind.state = "capture" end
    return
  end
  if #down > 0 then
    for _, vk in ipairs(down) do
      if vk == 0x1B then Bind.state = nil; return end
    end
    if #down > #Bind.peak then Bind.peak = down end
  elseif #Bind.peak > 0 then
    if #Bind.peak == 1 and Bind.peak[1] == 1 then
      log_act("Left mouse alone can't be the hotkey (combine it with another key)")
      Bind.peak = {}
      return
    end
    cfg.hotkey = Bind.peak
    mark_dirty()
    Bind.state = nil
    log_act("Hotkey set: " .. hotkey_str())
  end
end

------------------------------------------------------------------------------------------------
-- Mouse movement (GTA style)
------------------------------------------------------------------------------------------------
local Mouse = { delta_m = nil, pos_m = nil, probed = false, last_hid = nil, last_im = nil }
local function hid_device()
  local td = sdk.find_type_definition("via.hid.Mouse")
  if not td then return nil end
  local m = td:get_method("get_Device")
  if m then
    local ok, d = pcall(function() return m:call(nil) end)
    if ok and d then return d end
  end
  local s = sdk.get_native_singleton("via.hid.Mouse")
  if s then
    local ok, d = pcall(sdk.call_native_func, s, td, "get_Device")
    if ok and d then return d end
  end
  return nil
end
function Mouse.init()
  Mouse.probed = true
  local dev = hid_device()
  if not dev then return end
  local ok, td = pcall(function() return dev:get_type_definition() end)
  if not ok or not td then return end
  for _, n in ipairs({ "get_DeltaPosition", "get_PosDelta", "get_DeltaPos", "get_Delta", "get_MoveDelta" }) do
    if td:get_method(n) then Mouse.delta_m = n; break end
  end
  for _, n in ipairs({ "get_Position", "get_Pos", "get_CursorPosition", "get_ClientPosition" }) do
    if td:get_method(n) then Mouse.pos_m = n; break end
  end
end
local function imgui_mouse()
  local ok, v = pcall(imgui.get_mouse)
  if not ok or v == nil then return nil end
  local x, y = xy(v)
  if x == nil or math.abs(x) > 1e6 or math.abs(y) > 1e6 then return nil end
  return x, y
end
function Mouse.read()
  if not Mouse.probed then Mouse.init() end
  local dev = (Mouse.delta_m or Mouse.pos_m) and hid_device() or nil
  local hdx, hdy, pdx, pdy, idx, idy = 0, 0, 0, 0, 0, 0
  if dev and Mouse.delta_m then
    local x, y = xy(mcall(dev, Mouse.delta_m))
    if x then hdx, hdy = x, y end
  end
  if dev and Mouse.pos_m then
    local x, y = xy(mcall(dev, Mouse.pos_m))
    if x then
      if Mouse.last_hid then pdx, pdy = x - Mouse.last_hid[1], y - Mouse.last_hid[2] end
      Mouse.last_hid = { x, y }
    end
  end
  local mx, my = imgui_mouse()
  if mx then
    if Mouse.last_im then idx, idy = mx - Mouse.last_im[1], my - Mouse.last_im[2] end
    Mouse.last_im = { mx, my }
  end
  local src = cfg.mouse_source
  if src == 2 then return hdx, hdy end
  if src == 3 then return pdx, pdy end
  if src == 4 then return idx, idy end
  if hdx ~= 0 or hdy ~= 0 then return hdx, hdy end
  if pdx ~= 0 or pdy ~= 0 then return pdx, pdy end
  if idx ~= 0 or idy ~= 0 then return idx, idy end
  return 0, 0
end
function Mouse.reset() Mouse.last_hid = nil; Mouse.last_im = nil; Mouse.read() end

------------------------------------------------------------------------------------------------
-- Slow motion. Two levers (REFramework's own "Scene" panel has the same two): via.Scene time scale and
-- via.Application global speed. Both are re-applied at the engine's update entries, because the game and other
-- scripts write them as well. (REFramework's menu: Scene > "Timescale" / "Use Application Timescale" should be OFF.)
------------------------------------------------------------------------------------------------
local Slow = { active = false, releasing = false, cur = 1.0 }
local function current_scene()
  local sm = sdk.get_native_singleton("via.SceneManager")
  local td = sdk.find_type_definition("via.SceneManager")
  if not sm or not td then return nil end
  local ok, s = pcall(sdk.call_native_func, sm, td, "get_CurrentScene")
  if ok and s then return s end
  ok, s = pcall(sdk.call_native_func, sm, td, "get_CurrentScene()")
  if ok then return s end
  return nil
end
local function ts_set(v)
  scall(current_scene(), "set_TimeScale", v)
  local a = sdk.get_native_singleton("via.Application")
  local td = sdk.find_type_definition("via.Application")
  if a and td then pcall(sdk.call_native_func, a, td, "set_GlobalSpeed", v) end
end
local function slow_apply() if Slow.active then ts_set(Slow.cur) end end
function Slow.start()
  if not cfg.slowmo_enabled then return end
  if not Slow.active then Slow.cur = 1.0 end
  Slow.active, Slow.releasing = true, false
end
function Slow.stop() if Slow.active then Slow.releasing = true end end
function Slow.force_restore()
  if Slow.active then ts_set(1.0) end
  Slow.active, Slow.releasing, Slow.cur = false, false, 1.0
end
function Slow.update()
  if not Slow.active then return end
  local target = Slow.releasing and 1.0 or cfg.slowmo_scale
  local step = math.max(0.001, (1.0 - cfg.slowmo_scale) / SLOW_RAMP_FRAMES)
  if Slow.cur < target then Slow.cur = math.min(target, Slow.cur + step) else Slow.cur = math.max(target, Slow.cur - step) end
  slow_apply()
  if Slow.releasing and Slow.cur >= 1.0 then
    ts_set(1.0)
    Slow.active, Slow.releasing = false, false
  end
end
for _, entry in ipairs({ "UpdateBehavior", "LateUpdateBehavior", "BeginRendering" }) do
  pcall(function() re.on_pre_application_entry(entry, function() pcall(slow_apply) end) end)
end

------------------------------------------------------------------------------------------------
-- Camera freeze while the wheel is open
------------------------------------------------------------------------------------------------
local Cam = { skip = false }
do
  local td = sdk.find_type_definition("app.RotateCameraControllerBase")
  local m = td and td:get_method("getInputRotationSpeedRate")
  if m then
    pcall(sdk.hook, m, function(args)
      Cam.skip = false
      if W.open then
        Cam.skip = true
        return sdk.PreHookResult.SKIP_ORIGINAL
      end
    end, function(retval)
      if Cam.skip then Cam.skip = false; return sdk.float_to_ptr(0.0) end
      return retval
    end)
  end
end

------------------------------------------------------------------------------------------------
-- The Warfarer's weapon list
------------------------------------------------------------------------------------------------
local Arisen = { list = {}, index = nil, equip = nil, at = -10000, total = 0 }

local function item_of(w)
  if w == nil then return nil end
  local ep = mcall(w, "get_EquipParam()")
  local wp = mcall(w, "get_WeaponParam()")
  if not ep or not wp then return nil end
  return { job = tonumber(mcall(ep, "getJob()")), item = tonumber(mcall(w, "get_ItemId()")),
           name = tostring(mcall(w, "get_Name()") or ""), equipNo = tonumber(mcall(w, "get_ArisenEquipNo()")) }
end

function Arisen.refresh()
  Arisen.at = frame
  local list, index, equip = {}, nil, nil
  local im = sdk.get_managed_singleton("app.ItemManager")
  local cid = mcall(P.char, "get_CharaID()")
  if not im or cid == nil then Arisen.list = {}; return end
  local ok = pcall(function()
    equip = mcall(im, "getEquipData", cid)
    if equip == nil then equip = im:getEquipData(cid) end
    local data = equip:get_field("Data")
    index = tonumber(data:get_field(BF_INDEX))
    local arr = mcall(equip, "get_ArisenWeaponList")
    if arr == nil then arr = equip:get_ArisenWeaponList() end
    local arr_n, max_no = arr:get_size(), 0
    for i = 0, arr_n - 1 do
      local el = arr:get_element(i)
      if el then
        local main, sub = item_of(mfield(el, "Main")), item_of(mfield(el, "Sub"))
        local e = main or sub
        if e and e.job and JOBS[e.job] and e.job <= 9 then
          e.main_obj, e.sub_obj = mfield(el, "Main"), mfield(el, "Sub")
          e.main_item, e.sub_item_id = main and main.item or nil, sub and sub.item or nil
          e.sub_item = (main and sub) and sub.item or nil      -- the off-hand of a slot that has both
          e.key = "e" .. tostring(e.equipNo or i)
          e.pos0 = i                                           -- the place in the game's list (0-based)
          if e.equipNo and e.equipNo > max_no then max_no = e.equipNo end
          list[#list + 1] = e
        end
      end
    end
    Arisen.total = math.max(arr_n, max_no)                    -- how many slots the game's cycle runs through
  end)
  if not ok then list = {} end
  Arisen.list, Arisen.index, Arisen.equip = list, index, equip
end

-- weapon change tracking. hand_wid: the weapon id of the main weapon the game equipped last (from equipWeapon). A weapon id belongs
-- to one weapon whatever slot it sits in, so it stays right when the loadout changes.
local Track = { prev = nil, last_change = -10000, hand_wid = nil, prev_wid = nil, map = {}, map_at = nil, guessed = false }

-- the slot of the weapon in hand. The vocation alone can't tell two slots of the same vocation apart (and the game's own index can be
-- ahead of the weapon in hand after a switch), so the slot of the weapon the game equipped last comes first; else by vocation, else by the
-- game's index (EquipNo == index + 1)
local function current_entry()
  local wj = read_weapon_job()
  if Track.hand_wid and wj then
    local e = Track.hand_slot()
    if e and e.job == wj then return e end
  end
  local by_job, by_index = nil, nil
  for _, e in ipairs(Arisen.list) do
    if Arisen.index and e.equipNo == Arisen.index + 1 then by_index = e end
    if wj and e.job == wj and (by_job == nil or e == by_index) then by_job = e end
  end
  return by_job or by_index
end
local function opt_in_hand(opt)
  local cur = current_entry()
  if cur then return cur.key == opt.key end
  return read_weapon_job() == opt.job
end
local function list_pos(entry)
  for i, e in ipairs(Arisen.list) do if e.key == entry.key then return i end end
  return nil
end
-- Rearmaments from the weapon in hand to opt, in list order (the order the game cycles)
local function steps_to(opt)
  local n = #Arisen.list
  if n < 2 then return nil, "the weapon list has fewer than 2 weapons" end
  local tp = list_pos(opt)
  if not tp then return nil, "not in the weapon list" end
  local cur = current_entry()
  local cp = cur and list_pos(cur)
  if not cp then return nil, "can't tell which weapon is in hand" end
  return (tp - cp) % n, nil, cp, tp
end

----------------------------------------------------------------------------------------------------
-- Dark Arisen DLC & Comprehensive Skills Database
----------------------------------------------------------------------------------------------------
local REARMAMENT_SKILL_ID = 100

local VOCATION_SKILL_DATABASE = {
  -- Fighter (Job 1)
  [1] = {
    skills = {
      { id = 1,  name = "Burst Strike" },
      { id = 2,  name = "Shield Bash" },
      { id = 3,  name = "Blink Strike" },
      { id = 4,  name = "Compass Slash" },
      { id = 5,  name = "Airward Slash" },
      { id = 6,  name = "Shield Pummel" },
      { id = 7,  name = "Springboard" },
      { id = 8,  name = "Gouge" },
      { id = 9,  name = "Hindsight Slash" },
      { id = 10, name = "Divine Defense" },
      { id = 11, name = "Flawless Guard" },
      { id = 12, name = "Riotous Hole" },       -- Maister
      { id = 13, name = "Whirlwind Strike" },   -- Dark Arisen DLC
      { id = 14, name = "Shield Precision" },   -- Dark Arisen DLC
    }
  },
  -- Archer (Job 2)
  [2] = {
    skills = {
      { id = 13, name = "Barrage Shoot" },
      { id = 14, name = "Sweep Shoot" },
      { id = 15, name = "Tarring Shot" },
      { id = 16, name = "Incriminating Shot" },
      { id = 17, name = "Exploding Shot" },
      { id = 18, name = "Blighting Shot" },
      { id = 19, name = "Deathly Arrow" },
      { id = 20, name = "Erupting Shot" },
      { id = 21, name = "Torrent Shot" },
      { id = 22, name = "Spiral Arrow" },
      { id = 23, name = "Heavenly Shot" },     -- Maister
      { id = 24, name = "Falcon Arrow" },      -- Dark Arisen DLC
      { id = 25, name = "Kite Arrow" },        -- Dark Arisen DLC
    }
  },
  -- Mage (Job 3)
  [3] = {
    skills = {
      { id = 24, name = "Flagration" },
      { id = 25, name = "Levin" },
      { id = 26, name = "Frigor" },
      { id = 27, name = "Halidom" },
      { id = 28, name = "Fire Boon" },
      { id = 29, name = "Ice Boon" },
      { id = 30, name = "Lightning Boon" },
      { id = 31, name = "Palladium" },
      { id = 32, name = "Argent Succor" },
      { id = 33, name = "Solemnity" },
      { id = 34, name = "Celerity" },
      { id = 35, name = "Empyrean" },
      { id = 36, name = "Spellscreen" },
      { id = 37, name = "Celestial Paean" },   -- Maister
      { id = 110, name = "Virtuous Bolt" },    -- Dark Arisen DLC
      { id = 111, name = "Exalted Bolt" },     -- Dark Arisen DLC
    }
  },
  -- Thief (Job 4)
  [4] = {
    skills = {
      { id = 38, name = "Biting Wind" },
      { id = 39, name = "Shadow Cloak" },
      { id = 40, name = "Ensnare" },
      { id = 41, name = "Helm Splitter" },
      { id = 42, name = "Powder Blast" },
      { id = 43, name = "Draw and Quarter" },
      { id = 44, name = "Smoke Screen" },
      { id = 45, name = "Pilfer" },
      { id = 46, name = "Ignition" },
      { id = 47, name = "Reset" },
      { id = 48, name = "Blades of Pyre" },
      { id = 49, name = "Gut and Run" },
      { id = 101, name = "Formless Feint" },   -- Maister
      { id = 112, name = "Fanged Schism" },    -- Dark Arisen DLC
      { id = 113, name = "Fanged Rift" },      -- Dark Arisen DLC
    }
  },
  -- Warrior (Job 5)
  [5] = {
    skills = {
      { id = 50, name = "Brawn" },
      { id = 51, name = "Rending Sweep" },
      { id = 52, name = "Skyward Sunder" },
      { id = 53, name = "Tidal Fury" },
      { id = 54, name = "Lash" },
      { id = 55, name = "Savage Lunge" },
      { id = 56, name = "Mountain Breaker" },
      { id = 57, name = "Knoll Breaker" },
      { id = 58, name = "Roar" },
      { id = 59, name = "Inspire" },
      { id = 60, name = "Goring Sweep" },
      { id = 61, name = "Arc of Might" },      -- Maister
      { id = 114, name = "Iron Cleave" },      -- Dark Arisen DLC
      { id = 115, name = "Steel Cleave" },     -- Dark Arisen DLC
    }
  },
  -- Sorcerer (Job 6)
  [6] = {
    skills = {
      { id = 24, name = "Flagration" },
      { id = 25, name = "Levin" },
      { id = 26, name = "Frigor" },
      { id = 27, name = "Salamander" },
      { id = 62, name = "Thundermine" },
      { id = 63, name = "Hagol" },
      { id = 64, name = "Decanter" },
      { id = 65, name = "Augural Flare" },
      { id = 66, name = "Prescience" },
      { id = 67, name = "Seism" },
      { id = 68, name = "Meteoron" },          -- Maister
      { id = 69, name = "Maelstrom" },         -- Maister
      { id = 104, name = "Brontide" },         -- Dark Arisen DLC
      { id = 116, name = "High Brontide" },    -- Dark Arisen DLC
    }
  },
  -- Mystic Spearhand (Job 7)
  [7] = {
    skills = {
      { id = 70, name = "Dragons Foin" },
      { id = 71, name = "Mirour Vesture" },
      { id = 72, name = "Skiedragons Feste" },
      { id = 73, name = "Devout Offertory" },
      { id = 74, name = "Thefths Hond" },
      { id = 75, name = "Ravening Hond" },
      { id = 76, name = "Swift Charge" },
      { id = 77, name = "Unto Heven" },
      { id = 78, name = "Humble Offertory" },
      { id = 79, name = "Wild Furie" },        -- Maister
      { id = 117, name = "Bataille Twinne" },  -- Dark Arisen DLC
      { id = 118, name = "Bataille Idole" },   -- Dark Arisen DLC
    }
  },
  -- Magick Archer (Job 8)
  [8] = {
    skills = {
      { id = 80, name = "Frosthunter Bolt" },
      { id = 81, name = "Ricochet Hunter" },
      { id = 82, name = "Irradiant Orb" },
      { id = 83, name = "Sagittate Downpour" },
      { id = 84, name = "Remedy Arrow" },
      { id = 85, name = "Lifetaker Arrow" },
      { id = 86, name = "Sparkchain Bolt" },
      { id = 87, name = "Blazefang Arrow" },
      { id = 88, name = "Hailstone Bolt" },
      { id = 89, name = "Vimtaking Arrow" },
      { id = 90, name = "Candent Orb" },
      { id = 91, name = "Martyrs Bolt" },      -- Maister
      { id = 119, name = "Shadebind Bolt" },   -- Dark Arisen DLC
      { id = 120, name = "Shadefetter Bolt" }, -- Dark Arisen DLC
    }
  },
  -- Trickster (Job 9)
  [9] = {
    skills = {
      { id = 92, name = "Sweeping Shroud" },
      { id = 93, name = "Suffocating Shroud" },
      { id = 94, name = "Fickle Floor" },
      { id = 95, name = "Delusory Screen" },
      { id = 96, name = "Illusive Divider" },
      { id = 97, name = "Fragrant Alarum" },
      { id = 98, name = "Tricky Terrace" },
      { id = 99, name = "Dragons Delusion" },  -- Maister
      { id = 121, name = "Curing Cloud" },     -- Dark Arisen Obelisk
      { id = 122, name = "Vitalizing Vapor" }, -- Dark Arisen Obelisk
      { id = 123, name = "Diverting Fume" },   -- Dark Arisen Obelisk
      { id = 124, name = "Rousing Aroma" },    -- Dark Arisen Obelisk
    }
  },
  -- Warfarer (Job 10)
  [10] = {
    skills = {
      { id = REARMAMENT_SKILL_ID, name = "Rearmament" }
    }
  }
}

local Presets = {
  last_vocation = nil,
  active_skills_by_job = {},
  gui_base = nil,
  notification_text = "",
  notification_timer = 0,
  swap_key_down = false,
}

function Presets.get_gui_base()
  if not Presets.gui_base then
    pcall(function()
      Presets.gui_base = sdk.create_instance("app.GUIBase"):add_ref()
    end)
  end
  return Presets.gui_base
end

function Presets.resolve_skill_name(jobId, skillId, levelNo)
  levelNo = levelNo or 1
  local gb = Presets.get_gui_base()
  if gb then
    local ok, name = pcall(function()
      return gb:call("getCustomSkillName(app.Character.JobEnum, app.HumanCustomSkillID, app.HumanCustomSkillLevelNo)", jobId, skillId, levelNo)
    end)
    if ok and name and name ~= "" then
      local lower = string.lower(name)
      if lower:find("ref") then
        local jobMatch = lower:match("job(%d+)")
        if jobMatch then
          local altJob = tonumber(jobMatch)
          local ok2, altName = pcall(function()
            return gb:call("getCustomSkillName(app.Character.JobEnum, app.HumanCustomSkillID, app.HumanCustomSkillLevelNo)", altJob, skillId, levelNo)
          end)
          if ok2 and altName and altName ~= "" then return altName end
        end
      end
      return name
    end
  end

  local jobDb = VOCATION_SKILL_DATABASE[jobId]
  if jobDb then
    for _, sk in ipairs(jobDb.skills) do
      if sk.id == skillId then return sk.name end
    end
  end
  if skillId == REARMAMENT_SKILL_ID then return "Rearmament" end
  return "Skill " .. tostring(skillId)
end

function Presets.refresh_database()
  local gm = gui_mgr()
  local human = P.human
  local skillCtx = human and mcall(human, "get_SkillContext()")

  for j = 1, 10 do
    Presets.active_skills_by_job[j] = {}
    local knownMap = {}

    if VOCATION_SKILL_DATABASE[j] then
      for _, sk in ipairs(VOCATION_SKILL_DATABASE[j].skills) do
        local entry = { id = sk.id, name = sk.name, level = { "NA" }, currentLevel = 0 }
        table.insert(entry.level, Presets.resolve_skill_name(j, sk.id, 1))
        table.insert(entry.level, Presets.resolve_skill_name(j, sk.id, 2))
        entry.name = entry.level[2] or sk.name
        table.insert(Presets.active_skills_by_job[j], entry)
        knownMap[sk.id] = entry
      end
    end

    if gm then
      pcall(function()
        local dict = gm.CustomSkillJobDefineDictionary
        if dict and dict.ContainsKey and dict:ContainsKey(j) then
          local jobSkills = dict[j]
          if jobSkills then
            for _, def in pairs(jobSkills) do
              if def and def.CustomSkillID then
                local sid = def.CustomSkillID
                if not knownMap[sid] then
                  local sname = Presets.resolve_skill_name(j, sid, 1)
                  local entry = { id = sid, name = sname, level = { "NA", sname, Presets.resolve_skill_name(j, sid, 2) }, currentLevel = 0 }
                  table.insert(Presets.active_skills_by_job[j], entry)
                  knownMap[sid] = entry
                end
              end
            end
          end
        end
      end)

      pcall(function()
        local exDict = gm.ExCustomSkillJobDefineDictionary
        if exDict and exDict.ContainsKey and exDict:ContainsKey(j) then
          local exJobSkills = exDict[j]
          if exJobSkills then
            for _, def in pairs(exJobSkills) do
              if def and def.CustomSkillID then
                local sid = def.CustomSkillID
                if not knownMap[sid] then
                  local sname = Presets.resolve_skill_name(j, sid, 1)
                  local entry = { id = sid, name = sname, level = { "NA", sname, Presets.resolve_skill_name(j, sid, 2) }, currentLevel = 0 }
                  table.insert(Presets.active_skills_by_job[j], entry)
                  knownMap[sid] = entry
                end
              end
            end
          end
        end
      end)
    end

    if skillCtx then
      pcall(function()
        local enabledItems = skillCtx:get_field("EnabledCustomSkills"):get_field("_items")
        for _, entry in ipairs(Presets.active_skills_by_job[j]) do
          for _, item in pairs(enabledItems) do
            if item and item.CustomSkillID == entry.id then
              entry.currentLevel = item.Level
              break
            end
          end
        end
      end)
    end
  end
end

-- Initialize presets structure in config if missing
local function ensure_vocation_presets()
  cfg.vocation_presets = cfg.vocation_presets or {}
  for j = 1, 9 do
    if not cfg.vocation_presets[j] then
      cfg.vocation_presets[j] = {
        id = j,
        name = JOBS[j].name:lower(),
        safeName = JOBS[j].name,
        currentPresetIndex = 1,
        presets = {
          { name = "Preset 1", skills = { REARMAMENT_SKILL_ID, REARMAMENT_SKILL_ID, REARMAMENT_SKILL_ID, REARMAMENT_SKILL_ID, REARMAMENT_SKILL_ID, REARMAMENT_SKILL_ID } }
        }
      }
    else
      local vp = cfg.vocation_presets[j]
      vp.presets = vp.presets or {}
      if #vp.presets == 0 then
        table.insert(vp.presets, { name = "Preset 1", skills = { REARMAMENT_SKILL_ID, REARMAMENT_SKILL_ID, REARMAMENT_SKILL_ID, REARMAMENT_SKILL_ID, REARMAMENT_SKILL_ID, REARMAMENT_SKILL_ID } })
      end
      -- Ensure each preset has 6 skills
      for _, pr in ipairs(vp.presets) do
        pr.skills = pr.skills or {}
        while #pr.skills < 6 do table.insert(pr.skills, REARMAMENT_SKILL_ID) end
      end
      vp.currentPresetIndex = vp.currentPresetIndex or 1
    end
  end
end

function Presets.ensure_skill_available(skillCtx, skillId)
  if not skillCtx or not skillId or skillId <= 0 or skillId == REARMAMENT_SKILL_ID then return end
  pcall(function()
    if skillCtx.isCustomSkillEnable and not skillCtx:isCustomSkillEnable(skillId) then
      if skillCtx.setCustomSkillEnable then
        skillCtx:setCustomSkillEnable(skillId, true)
      end
    end
  end)
  pcall(function()
    local lvl = skillCtx:getCustomSkillLevel(skillId)
    if (not lvl or lvl == 0) and skillCtx.setCustomSkillLevel then
      skillCtx:setCustomSkillLevel(skillId, 1)
    end
  end)
  pcall(function()
    local list = skillCtx:get_field("EnabledCustomSkills")
    if list then
      local items = list:get_field("_items")
      if items then
        for _, it in pairs(items) do
          if it and it.CustomSkillID == skillId then
            if it.Level == 0 then it.Level = 1 end
            break
          end
        end
      end
    end
  end)
end

function Presets.import_guild_skills()
  if not P.human then return 0 end
  local skillCtx = mcall(P.human, "get_SkillContext()")
  if not skillCtx then return 0 end

  ensure_vocation_presets()
  local imported = 0
  for j = 1, 9 do
    local vp = cfg.vocation_presets[j]
    if vp and vp.presets and #vp.presets > 0 then
      local pr = vp.presets[1]
      for slot = 0, 5 do
        local ok, sid = pcall(function() return skillCtx:getSkillID(j, slot) end)
        if ok and sid and sid > 0 and sid ~= REARMAMENT_SKILL_ID then
          pr.skills[slot + 1] = sid
          imported = imported + 1
        end
      end
    end
  end
  return imported
end

function Presets.apply(jobId)
  if not cfg.skill_swap_enabled or not jobId or jobId == 10 then return end
  if not P.human then return end
  local skillCtx = mcall(P.human, "get_SkillContext()")
  if not skillCtx then return end

  ensure_vocation_presets()

  local numSlots = 6
  local skills_to_set = {}
  local hasGuildSkills = false

  -- 1. If auto-load guild class skills is enabled, read directly from the game's class skill assignments
  if cfg.load_guild_class_skills then
    for slot = 0, numSlots - 1 do
      local ok, sid = pcall(function() return skillCtx:getSkillID(jobId, slot) end)
      if ok and sid and sid > 0 and sid ~= REARMAMENT_SKILL_ID then
        skills_to_set[slot + 1] = sid
        hasGuildSkills = true
      end
    end
  end

  -- 2. If guild skills were not found or setting is disabled, use configured preset
  if not hasGuildSkills then
    local vp = cfg.vocation_presets[jobId]
    if vp and vp.presets and #vp.presets > 0 then
      local pIdx = vp.currentPresetIndex or 1
      if pIdx < 1 or pIdx > #vp.presets then pIdx = 1 end
      local preset = vp.presets[pIdx]
      if preset and preset.skills then
        for slot = 1, numSlots do
          local sid = preset.skills[slot]
          if sid and sid > 0 and sid ~= REARMAMENT_SKILL_ID then
            skills_to_set[slot] = sid
          end
        end
      end
    end
  else
    -- If guild had 4 skills (slots 1-4), check if preset has slots 5 & 6 configured
    local vp = cfg.vocation_presets[jobId]
    if vp and vp.presets and #vp.presets > 0 then
      local pIdx = vp.currentPresetIndex or 1
      local preset = vp.presets[pIdx]
      if preset and preset.skills then
        for slot = 5, numSlots do
          if not skills_to_set[slot] and preset.skills[slot] and preset.skills[slot] > 0 and preset.skills[slot] ~= REARMAMENT_SKILL_ID then
            skills_to_set[slot] = preset.skills[slot]
          end
        end
      end
    end
  end

  -- 3. Equip skills to Warfarer (job 10). Rearmament is NOT required to swap weapons.
  local bQ = nil
  pcall(function() bQ = skillCtx:getEquipList(10) end)
  for slot = 1, numSlots do
    local skId = skills_to_set[slot]
    if cfg.free_rearmament_slot == false and slot == 4 then
      skId = REARMAMENT_SKILL_ID
    end
    if skId and skId > 0 then
      if cfg.unlock_all_skills_in_presets and skId ~= REARMAMENT_SKILL_ID then
        Presets.ensure_skill_available(skillCtx, skId)
      end
      pcall(function() skillCtx:setSkill(10, skId, slot - 1) end)
      if bQ then pcall(function() bQ:setSkill(skId, slot - 1) end) end
    end
  end

  local gm = gui_mgr()
  if gm then pcall(function() gm:call("setupKeyGuideCustomSkill()") end) end
  Presets.last_vocation = jobId
end

function Presets.cycle(jobId)
  ensure_vocation_presets()
  local vp = cfg.vocation_presets[jobId]
  if not vp or not vp.presets or #vp.presets <= 1 then return end

  vp.currentPresetIndex = (vp.currentPresetIndex % #vp.presets) + 1
  Presets.apply(jobId)

  if cfg.show_swap_notification then
    local p = vp.presets[vp.currentPresetIndex]
    Presets.notification_text = "Warfarer: " .. (JOBS[jobId] and JOBS[jobId].name or "Vocation") .. " - " .. (p.name or "Preset")
    Presets.notification_timer = 180
  end
  mark_dirty()
end

function Presets.on_weapon_change(jobId)
  if jobId and jobId ~= Presets.last_vocation then
    Presets.apply(jobId)
  end
end

-- Hook Stamina consumption on Rearmament
pcall(function()
  local stmCtrl = sdk.find_type_definition("app.HumanStaminaController")
  if stmCtrl then
    local mStm = stmCtrl:get_method("Chara_OnConsumeStaminaHandler(System.Single, app.StaminaParameterBase.Parameter)")
    if mStm then
      sdk.hook(mStm, function(args)
        if not cfg.enabled or cfg.rearmament_stamina_consumption then return end
        if P.human and tonumber(mcall(P.human, "get_CustomSkillState")) == REARMAMENT_SKILL_ID then
          return sdk.PreHookResult.SKIP_ORIGINAL
        end
      end, nil)
    end
  end
end)

-- Hook Vocation Guild skill contents filtering
pcall(function()
  local uiGuild = sdk.find_type_definition("app.ui040101_00")
  if uiGuild then
    local mFilter = uiGuild:get_method("addCustomSkillContentsList")
    if mFilter then
      sdk.hook(mFilter, function(args)
        if not cfg.filter_guild_skills_by_weapon then return end
        local targetJob = sdk.to_int64(args[3])
        local jobCtx = sdk.to_managed_object(args[4])
        local curJob = jobCtx and jobCtx:get_field("CurrentJob")
        local curWpJob = read_weapon_job()
        if curJob == 10 and curWpJob then
          if targetJob ~= curWpJob and targetJob ~= 10 then
            return sdk.PreHookResult.SKIP_ORIGINAL
          end
        end
      end, nil)
    end
  end
end)

-- Safe Menu Rearmament Bridge:
-- When the player is in the Pause Menu / Equipment screen, temporarily equips Rearmament in slot 4
-- so the game's native equipment UI allows selecting and editing the Warfarer weapon loadout.
-- When returning to gameplay, immediately restores the 4th class skill for full combat power.
local MenuEquipState = {
  active = false,
  saved_slot3_skill = nil,
}

local function update_menu_equip_rearm()
  if not cfg.enabled or not cfg.free_rearmament_slot or P.job ~= 10 then
    if MenuEquipState.active then
      local skillCtx = P.human and mcall(P.human, "get_SkillContext()")
      if skillCtx and MenuEquipState.saved_slot3_skill then
        local skId = MenuEquipState.saved_slot3_skill
        pcall(function() skillCtx:setSkill(10, skId, 3) end)
        local bQ = nil
        pcall(function() bQ = skillCtx:getEquipList(10) end)
        if bQ then pcall(function() bQ:setSkill(skId, 3) end) end
      end
      MenuEquipState.saved_slot3_skill = nil
      MenuEquipState.active = false
    end
    return
  end

  local paused = is_paused()
  if paused and not MenuEquipState.active then
    local skillCtx = P.human and mcall(P.human, "get_SkillContext()")
    if skillCtx then
      local ok, curSkill = pcall(function() return skillCtx:getSkillID(10, 3) end)
      if ok and curSkill and curSkill > 0 and curSkill ~= REARMAMENT_SKILL_ID then
        MenuEquipState.saved_slot3_skill = curSkill
        pcall(function() skillCtx:setSkill(10, REARMAMENT_SKILL_ID, 3) end)
        local bQ = nil
        pcall(function() bQ = skillCtx:getEquipList(10) end)
        if bQ then pcall(function() bQ:setSkill(REARMAMENT_SKILL_ID, 3) end) end
        MenuEquipState.active = true
      end
    end
  elseif not paused and MenuEquipState.active then
    local skillCtx = P.human and mcall(P.human, "get_SkillContext()")
    if skillCtx and MenuEquipState.saved_slot3_skill then
      local skId = MenuEquipState.saved_slot3_skill
      pcall(function() skillCtx:setSkill(10, skId, 3) end)
      local bQ = nil
      pcall(function() bQ = skillCtx:getEquipList(10) end)
      if bQ then pcall(function() bQ:setSkill(skId, 3) end) end
      local gm = gui_mgr()
      if gm then pcall(function() gm:call("setupKeyGuideCustomSkill()") end) end
    end
    MenuEquipState.saved_slot3_skill = nil
    MenuEquipState.active = false
  end
end

function Track.update()
  local wj = read_weapon_job()
  if wj == nil then return end
  local prev = Track.prev
  Track.prev = wj
  if prev ~= nil and prev ~= wj then
    Track.last_change = frame
    pcall(function() Presets.on_weapon_change(wj) end)
  end
  -- a swap between two slots of the same vocation does not change the vocation: the weapon id of the last equipped weapon shows it
  if Track.prev_wid ~= nil and Track.hand_wid ~= Track.prev_wid then Track.last_change = frame end
  Track.prev_wid = Track.hand_wid
  if not Track.guessed then pcall(Track.guess, wj) end
end

local function weapon_id_of(obj)
  local ok, v = pcall(function()
    local prm = obj:call("get_WeaponParam()")
    return prm and tonumber(prm:get_field("_WeaponId"))
  end)
  return ok and v or nil
end

-- the listed slot whose main weapon has the weapon id hand_wid (the weapon ids of the listed main weapons are all different);
-- the map is made again whenever the weapon list was read again
function Track.hand_slot()
  if Track.map_at ~= Arisen.at then
    Track.map_at, Track.map = Arisen.at, {}
    for _, e in ipairs(Arisen.list) do
      local w = e.main_obj and weapon_id_of(e.main_obj)
      if w then Track.map[w] = e end
    end
  end
  return Track.hand_wid and Track.map[Track.hand_wid] or nil
end
function Track.equipped(wid)
  local old = Track.hand_wid
  Track.map_at, Track.hand_wid = nil, wid
  if not Track.hand_slot() then Track.hand_wid = old end             -- an off-hand weapon or something not in the list: ignored
end
-- Once per scene, before the game has equipped anything: the game's own index is right until the first switch, so the slot it
-- names (if its vocation is the weapon in hand) is the weapon in hand.
function Track.guess(wj)
  if Track.hand_wid or P.job ~= cfg.warfarer_job or #Arisen.list == 0 or Arisen.index == nil then return end
  Track.guessed = true
  for _, e in ipairs(Arisen.list) do
    if e.equipNo == Arisen.index + 1 and e.job == wj and e.main_obj then
      local w = weapon_id_of(e.main_obj)
      if w then Track.hand_wid = w end
    end
  end
end

-- The game announces every weapon it puts in the Warfarer's hand through Job10WeaponManager.equipWeapon(WeaponID); the id says
-- which slot's weapon is in hand. Nothing is changed here, the call only gets noted.
do
  local td = sdk.find_type_definition("app.Job10WeaponManager")
  local m
  pcall(function()
    for _, x in ipairs(td:get_methods() or {}) do
      if x:get_name() == "equipWeapon" and x:get_num_params() == 1 then m = x; break end
    end
  end)
  if m then
    pcall(sdk.hook, m, function(args)
      pcall(Track.equipped, (sdk.to_int64(args[3]) or 0) & 0xFFFFFFFF)
    end, function(r) return r end)
  end
end

------------------------------------------------------------------------------------------------
-- Index route: the game's own way of choosing the next weapon.
-- The game keeps the slot it is on in the equip data of ItemManager (Data.CurrentArisenWeaponIndex; the slot's EquipNo is index + 1).
-- A Rearmament press calls ItemManager.setNextArisenWeapon() (the index goes up by one, wrapping) and equips the slot the index
-- now points at - main weapon and off-hand, built by the game itself. The equip data that getEquipData hands out is a read-only
-- view, so the index can't be written; instead the game's own setNextArisenWeapon() is called as often as needed to bring the
-- index to the slot BEFORE the wanted one, and one normal press then lands on the wanted slot. Nothing is recorded or rewritten.
-- Every press is checked: an unproven route is dropped at the first miss, a proven one at the second (the wheel then cycles with
-- ordinary Rearmaments, one per weapon in between).
------------------------------------------------------------------------------------------------
local Route = { fails = 0, wrote = nil, state = 0 }      -- state: 0 not proven yet, 1 works, -1 given up (until the script is reloaded)

-- the index as the game's own data holds it, from a fresh fetch
local function route_fresh()
  local im = sdk.get_managed_singleton("app.ItemManager")
  local cid = mcall(P.char, "get_CharaID()")
  if not im or cid == nil then return nil end
  local ok, v = pcall(function()
    local eq = mcall(im, "getEquipData", cid)
    if eq == nil then eq = im:getEquipData(cid) end
    return tonumber(eq:get_field("Data"):get_field(BF_INDEX))
  end)
  if ok then return v end
  return nil
end

function Route.usable()
  return Route.state >= 0 and Arisen.equip ~= nil and (Arisen.total or 0) >= 2
end

-- call setNextArisenWeapon() until the index is p; each call must move it
local function route_advance(p, n)
  local im = sdk.get_managed_singleton("app.ItemManager")
  local cur = route_fresh()
  if not im or cur == nil then return false, "the index can not be read" end
  for _ = 1, (p - cur) % n do
    local before = route_fresh()
    local ok = pcall(function() return im:call("setNextArisenWeapon()") end)
    local after = route_fresh()
    if not ok or after == nil or after == before then return false, "ItemManager.setNextArisenWeapon did not move the index" end
  end
  if route_fresh() ~= p then return false, "the index did not end on the wanted value (" .. tostring(route_fresh()) .. " instead of " .. p .. ")" end
  return true
end

function Route.prime(opt)
  Arisen.refresh()
  local e
  for _, x in ipairs(Arisen.list) do if x.key == opt.key then e = x end end
  if not e or not e.equipNo then return false, "the slot has no equip number" end
  local n = Arisen.total or 0
  local tidx = math.floor(e.equipNo) - 1
  if n < 2 or tidx < 0 or tidx >= n then return false, "the slot number is outside the game's list" end
  local from = route_fresh()
  if from == nil then return false, "the index can not be read" end
  local ce = current_entry()
  local p = (tidx - 1) % n                                  -- the slot before the wanted one
  local okadv, why = route_advance(p, n)
  if not okadv then
    Route.wrote, Route.state = nil, -1
    log_act("Index route: " .. tostring(why) .. " - the route is switched off")
    return false, why
  end
  Route.wrote = { p = p, tidx = tidx, n = n, from = from, hand = ce and ce.equipNo and (math.floor(ce.equipNo) - 1) or nil }
  return true
end

-- a switch that landed on the wanted slot. It only proves the route when the calls made the difference (the wanted slot was not
-- simply the one the game would have used anyway).
function Route.success()
  local rec = Route.wrote
  Route.wrote, Route.fails = nil, 0
  if rec and Route.state ~= 1 and rec.tidx ~= (rec.from + 1) % rec.n then
    Route.state = 1
    log_act("Index route: the game switched to the wanted slot - it works")
  end
end

-- the press did not land on the wanted slot
function Route.miss()
  local rec = Route.wrote
  Route.wrote = nil
  if not rec then return end
  local c = current_entry()
  local landed = c and c.equipNo and (math.floor(c.equipNo) - 1) or nil
  local msg = string.format("Index route missed: prepared slot %d, wanted slot %d", rec.p, rec.tidx)
  if landed ~= nil and landed ~= rec.hand then
    msg = msg .. string.format(", the game equipped slot %d", landed)
  else
    msg = msg .. ", nothing changed"
  end
  Route.fails = Route.fails + 1
  if Route.fails >= (Route.state == 1 and 2 or 1) then
    Route.state = -1
    msg = msg .. " - giving up on the index route"
  end
  log_act(msg)
end

-- Rearmament key held by the player: the wheel opens (Skill.on_press is set further down)
local Skill = { own = false, on_press = nil, down = {}, pad = {}, pend = nil, replay = false, msg = nil }
pcall(function()
  local td = sdk.find_type_definition("app.HumanActionSelector")
  local m = td and td:get_method("requestJob10CustomSkill()")
  if m then
    sdk.hook(m, function(args)
      if Skill.on_press and not Skill.own and Skill.on_press() then return sdk.PreHookResult.SKIP_ORIGINAL end
    end, function(r) return r end)
  end
end)

------------------------------------------------------------------------------------------------
-- Switching
------------------------------------------------------------------------------------------------
-- SW.want: the switch in progress {opt, mode = "step" | "indexed", stage = fire | wait | settle | final, ...}
-- SW.inst: a switch waiting for LateUpdateBehavior (where the index route is prepared)
local SW = { want = nil, inst = nil, last = -10000 }

local function switch_guard(continuing)
  if P.job ~= cfg.warfarer_job then return "not a Warfarer" end
  if is_paused() or is_loading() then return "game paused/loading" end
  if not continuing and frame - Track.last_change < MIN_FRAMES_AFTER_SWAP then return "weapon still swapping" end
  return nil
end
local function sw_fail(w, msg)
  log_act(string.format("%s: %s", JOBS[w.opt.job].name, msg))
  SW.want = nil
end

local start_steps
-- Runs inside the app.CharacterInput.updateDerived pre-hook (the input phase)
local function fire_rearm()
  local w = SW.want
  if not w or w.stage ~= "fire" then return end
  if Slow.active then return end                      -- wait until the slow-motion ramp is over
  w.stage = "busy"
  local why = switch_guard(w.done > 0 or w.force_continue)
  local st = stamina()
  if not why and st ~= nil and st <= 0 then why = "no stamina for Rearmament" end
  if why then sw_fail(w, "skipped: " .. why); return end
  local sel = mcall(P.human, "get_HumanActionSelector()")
  if not sel then sw_fail(w, "no HumanActionSelector"); return end
  w.fired_at = frame
  if w.mode == "indexed" then
    local okp, whyp = Route.prime(w.opt)
    if not okp then
      log_act("Index route skipped: " .. tostring(whyp))
      SW.want = nil
      start_steps(w.opt, STEP_SETTLE)
      return
    end
  end
  Skill.own = true
  local ok, err = scall(sel, "requestJob10CustomSkill()")
  if not ok or ok == false then
    local im = sdk.get_managed_singleton("app.ItemManager")
    if im then pcall(function() im:call("setNextArisenWeapon()") end) end
    local ok2 = pcall(function()
      sel:call("requestCustomSkill(app.CustomSkillDef.Job10_CustomSkill, System.Int32)", 100, 0)
    end)
    if not ok2 then
      pcall(function() sel:call("requestCustomSkill", 100, 0) end)
    end
    ok = true
  end
  Skill.own = false
  if not ok then sw_fail(w, "the press failed: " .. tostring(err)); return end
  SW.last = frame
  w.presses = (w.presses or 0) + 1
  w.stage = "wait"
end
do
  local td = sdk.find_type_definition("app.CharacterInput")
  local m = td and td:get_method("updateDerived(System.Boolean)")
  if m then
    pcall(sdk.hook, m, function(args)
      if W.open and cfg.block_input_while_open then return sdk.PreHookResult.SKIP_ORIGINAL end
      if Skill.replay then
        -- a short tap of the Rearmament key that the wheel option held back: the game gets it now
        Skill.replay = false
        local sel0 = mcall(P.human, "get_HumanActionSelector()")
        if sel0 then
          Skill.own = true
          local ok = scall(sel0, "requestJob10CustomSkill()")
          if not ok or ok == false then
            local im = sdk.get_managed_singleton("app.ItemManager")
            if im then pcall(function() im:call("setNextArisenWeapon()") end) end
            local ok2 = pcall(function()
              sel0:call("requestCustomSkill(app.CustomSkillDef.Job10_CustomSkill, System.Int32)", 100, 0)
            end)
            if not ok2 then
              pcall(function() sel0:call("requestCustomSkill", 100, 0) end)
            end
          end
          Skill.own = false
        end
      end
      if SW.want and SW.want.stage == "fire" then
        local okf = pcall(fire_rearm)
        if not okf then SW.want = nil end
      end
    end, function(r) return r end)
  end
end

-- plain Rearmaments, one per weapon in between (the game's own cycle)
function start_steps(opt, delay)
  Arisen.refresh()
  local steps, why, cp, tp = steps_to(opt)
  if not steps then log_act(JOBS[opt.job].name .. ": " .. tostring(why)); return false end
  if steps == 0 then return true end
  SW.want = { opt = opt, mode = "step", stage = "fire", stage_at = frame, frame = frame, steps = steps, done = 0, pos = cp, target_pos = tp }
  if delay then SW.want.stage, SW.want.settle_until, SW.want.force_continue = "settle", frame + delay, true end
  return true
end

-- the index route: runs from LateUpdateBehavior. false = could not even try (the caller falls back to steps)
local function run_instant(w)
  Arisen.refresh()
  local steps, why, cp, tp = steps_to(w.opt)
  if not steps then log_act(JOBS[w.opt.job].name .. ": " .. tostring(why)); return true end
  if steps == 0 then return true end
  if not Route.usable() then return false end
  SW.want = { opt = w.opt, mode = "indexed", stage = "fire", stage_at = frame, frame = frame, steps = 1, done = 0,
    pos = cp, target_pos = tp, retries = w.retries, force_continue = true }
  return true
end

-- the press did not land on the wanted weapon: try again, or fall back to plain Rearmaments
local function inst_miss(w)
  SW.want = nil
  Route.miss()
  if Route.usable() and (w.retries or 0) < 2 then
    SW.inst = { opt = w.opt, frame = frame, retries = (w.retries or 0) + 1, again = true }
  else
    start_steps(w.opt, STEP_SETTLE)
  end
end

local function do_switch(opt)
  local nm = JOBS[opt.job].name
  local why = switch_guard(false)
  if why then log_act(nm .. " skipped: " .. why); return end
  if frame - SW.last < MIN_FRAMES_BETWEEN_SWITCHES then return end
  if SW.want or SW.inst then return end
  if opt_in_hand(opt) then return end
  if Route.usable() then
    SW.inst = { opt = opt, frame = frame }            -- executed in LateUpdateBehavior
  else
    start_steps(opt)
  end
end

-- per frame: the state machine of the switch in progress
function SW.update()
  local w = SW.want
  if not w then return end
  if w.stage == "fire" then
    if frame - w.stage_at > 90 then sw_fail(w, "the input hook did not run - cancelled") end
    return
  end
  if w.stage == "wait" then
    local n = #Arisen.list
    local cur, nxt = Arisen.list[w.pos], Arisen.list[w.pos % math.max(1, n) + 1]
    local blind = cur and nxt and cur.job == nxt.job   -- same vocation next: WeaponJob can't show the swap
    if Track.last_change >= w.fired_at or (blind and frame - w.fired_at >= STEP_SETTLE + 10) then
      w.done, w.pos = w.done + 1, w.pos % math.max(1, n) + 1
      w.stage_at = frame
      w.settle_until = frame + STEP_SETTLE
      w.stage = (w.done >= w.steps) and "final" or "settle"
    elseif w.mode == "indexed" and frame - w.fired_at > INSTANT_VERIFY then
      inst_miss(w)                                        -- nothing changed
    elseif frame - w.fired_at > STEP_VERIFY then
      sw_fail(w, string.format("no weapon change %d frames after Rearmament %d of %d", STEP_VERIFY, w.done + 1, w.steps))
    end
    return
  end
  if w.stage == "settle" then
    if frame >= w.settle_until then w.stage, w.stage_at = "fire", frame end
    return
  end
  if w.stage == "final" then
    if opt_in_hand(w.opt) then
      if w.mode == "indexed" then Route.success() end
      SW.want = nil
    elseif frame - w.stage_at > 40 then
      if w.mode == "indexed" then inst_miss(w)
      else
        local c = current_entry()
        sw_fail(w, string.format("ended on %s after %d action%s", c and JOBS[c.job].name or "?", w.done, w.done == 1 and "" or "s"))
      end
    end
  end
end

-- The index route is prepared and fired from LateUpdateBehavior (calls into the game's managers do not work reliably from on_frame).
pcall(function()
  re.on_application_entry("LateUpdateBehavior", function()
    local w = SW.inst
    if not w then return end
    -- a repeat right after a press that still moved the weapon: let that swap finish first
    local waiting = w.again and (frame - Track.last_change < MIN_FRAMES_AFTER_SWAP) and (frame - w.frame < 120)
    if Slow.active then
      if frame - w.frame > 120 then SW.inst = nil end
    elseif not waiting then
      SW.inst = nil
      local why = switch_guard(false)
      if why then
        log_act(JOBS[w.opt.job].name .. " skipped: " .. why)
      else
        local ok, res = pcall(run_instant, w)
        if not ok or res == false then start_steps(w.opt) end
      end
    end
  end)
end)

------------------------------------------------------------------------------------------------
-- Drawing: an invisible full-screen imgui window and its draw list (REFramework only)
------------------------------------------------------------------------------------------------
local function c8(x) return math.max(0, math.min(255, math.floor(x))) end
local function abgr(c) return (c8(c[4]) << 24) | (c8(c[3]) << 16) | (c8(c[2]) << 8) | c8(c[1]) end
local function T(name) return cfg.theme[name] or THEME_DEFAULT[name] end
local function with_alpha(c, a) return { c[1], c[2], c[3], a } end
local function v2(x, y) return Vector2f.new(x, y) end

-- Fonts: imgui.load_font must run at load time, one handle per size. REFramework's Lua can only load a font file that lies in
-- <game>/reframework/fonts (no full path, no ".."), and its sandbox can not copy files there, so a Windows font has to be copied
-- from C:\Windows\Fonts into that folder by hand. load_font does not fail for a missing file, it quietly hands back the default font:
-- whether the file was really found is checked by measuring a text with both fonts (Fonts.check).
-- REFramework remembers every (file, size) it was asked for until the game is closed: a file that was missing at that moment stays
-- the default font even after it was copied in and the scripts were reset. The sizes are therefore shifted by a hair (Fonts' gen,
-- raised when the font is changed or came out as not found), which makes every load a new request.
-- (A name from an older version of this setting - a full path, or "default" - is reduced to the file name.)
cfg.font_file = cfg.font_file == "default" and "" or (cfg.font_file:match("([^/\\]+)$") or "")
local Fonts = { list = {}, sizes = {}, loaded_for = cfg.font_file, found = nil, ref = nil }
for sz = 9, 24 do Fonts.sizes[#Fonts.sizes + 1] = sz end           -- every pixel size from 9 to 24 (the centre text shrinks to fit), then coarser
for sz = 26, 40, 2 do Fonts.sizes[#Fonts.sizes + 1] = sz end
Fonts.CHOICES = {
  { "Palatino Linotype", "pala.ttf", "Palatino Linotype - included with the mod (pala.ttf)" }, { "Georgia", "georgia.ttf" }, { "Times New Roman", "times.ttf" }, { "Constantia", "constan.ttf" },
  { "Cambria", "cambria.ttc" }, { "Book Antiqua", "BKANT.TTF" }, { "Garamond", "GARA.TTF" }, { "Bookman Old Style", "BOOKOS.TTF" },
  { "Baskerville Old Face", "BASKVILL.TTF" }, { "Century Schoolbook", "CENSCBK.TTF" }, { "Sylfaen", "sylfaen.ttf" },
  { "Gabriola", "gabriola.ttf" }, { "Monotype Corsiva", "MTCORSVA.TTF" }, { "Trebuchet MS", "trebuc.ttf" }, { "Tahoma", "tahoma.ttf" },
  { "Arial", "arial.ttf" }, { "Verdana", "verdana.ttf" }, { "Calibri", "calibri.ttf" }, { "Segoe UI", "segoeui.ttf" },
}
do
  local file = cfg.font_file ~= "" and cfg.font_file or nil
  local shift = file and (cfg.font_gen % 9) * 0.11 or 0
  for _, sz in ipairs(Fonts.sizes) do                 -- no file: REFramework's own font, still at the proper sizes
    local ok, f = pcall(imgui.load_font, file, sz + shift)
    if ok and f then Fonts.list[sz] = f end
  end
  local okr, ref = pcall(imgui.load_font, nil, 20)    -- the default font, to compare the chosen one with
  if okr then Fonts.ref = ref end
end
local FONT_SAMPLE = "Warfarer's Arsenal - Sorcerer, Fighter, Strider 0123456789"
local function sample_width(handle)
  if not pcall(imgui.push_font, handle, 20) then return nil end
  local ok, sz = pcall(imgui.calc_text_size, FONT_SAMPLE)
  pcall(imgui.pop_font)
  return ok and sz and sz.x or nil
end
-- true: the chosen font file is in use; false: the text measures like the default font (the file is not in reframework/fonts)
function Fonts.check()
  Fonts.found = nil
  if cfg.font_file == "" or Fonts.list[20] == nil or Fonts.ref == nil then return end
  local w1, w2 = sample_width(Fonts.list[20]), sample_width(Fonts.ref)
  if w1 and w2 then Fonts.found = math.abs(w1 - w2) > 0.5 end
  if Fonts.found == false and not Fonts.bumped then       -- the next reset asks for fresh sizes
    Fonts.bumped = true
    cfg.font_gen = cfg.font_gen + 1
    mark_dirty()
  end
end
-- the entries of the font dropdown: REFramework's font, then the common Windows fonts (by file name)
function Fonts.menu()
  local items, files = { "REFramework default font" }, { "" }
  for _, e in ipairs(Fonts.CHOICES) do items[#items + 1] = e[3] or string.format("%s (%s)", e[1], e[2]); files[#files + 1] = e[2] end
  local idx
  for i, f in ipairs(files) do if f:lower() == cfg.font_file:lower() then idx = i; break end end
  if not idx then items[#items + 1] = "Other: " .. cfg.font_file; files[#files + 1] = cfg.font_file; idx = #items end
  return { items = items, files = files, index = idx }
end
local function font_for(size)
  local best, bd = nil, 1e9
  for _, s in ipairs(Fonts.sizes) do
    if Fonts.list[s] and math.abs(s - size) < bd then best, bd = Fonts.list[s], math.abs(s - size) end
  end
  return best
end

local Screen = { w = 1920, h = 1080, next = 0 }
local function screen_size()
  if frame < Screen.next then return Screen.w, Screen.h end
  Screen.next = frame + 60
  local ok, v = pcall(imgui.get_display_size)
  if ok and v then
    local w, h = xy(v)
    if w and w > 0 then Screen.w, Screen.h = w, h end
  end
  return Screen.w, Screen.h
end

-- GUI space to screen. The game lays a GUI out on a canvas 1080 units high and scales it by the picture height (k = height / 1080);
-- the canvas is 1920 units wide and centred in the picture. The game's menu background is laid out on the same centred canvas.
-- The game's picture (Geo). The display imgui draws on and the picture the game renders are not always the same rectangle: on a very
-- wide window the game letterboxes its picture (bars above and below) while the overlay still covers the whole display. A GUI is laid
-- out on the picture, so the GUI canvas, the wheel's size and its centre are taken from the picture's rectangle: the view's render
-- size fitted into the display. On an ordinary screen the picture is the display and nothing changes.
local Geo = { x = 0, y = 0, w = 1920, h = 1080, sw = nil, sh = nil, next = 0 }
local function view_size()
  local sm = sdk.get_native_singleton("via.SceneManager")
  local td = sdk.find_type_definition("via.SceneManager")
  if not sm or not td then return nil end
  local view
  for _, nm in ipairs({ "get_MainView()", "get_MainView" }) do
    local ok, v = pcall(sdk.call_native_func, sm, td, nm)
    if ok and v then view = v; break end
  end
  if not view then return nil end
  for _, nm in ipairs({ "get_WindowSize()", "get_Size()" }) do
    local v = mcall(view, nm)
    local w = rd_num(v, "w") or rd_num(v, "x")
    local h = rd_num(v, "h") or rd_num(v, "y")
    if w and h and w > 0 and h > 0 then return w, h, nm, view end
  end
  return nil, nil, nil, view
end
function Geo.get()
  local sw, sh = screen_size()
  if Geo.sw == sw and Geo.sh == sh and frame < Geo.next then return Geo end
  Geo.next, Geo.sw, Geo.sh = frame + 60, sw, sh
  local rw, rh = view_size()
  local x, y, w, h = 0, 0, sw, sh
  if rw and rh then                                   -- the view's picture, as large as the display allows, centred
    local f = math.min(sw / rw, sh / rh)
    w, h = rw * f, rh * f
    if math.abs(w - sw) < 2 and math.abs(h - sh) < 2 then w, h = sw, sh end
  end
  local nx, ny = (sw - w) / 2, (sh - h) / 2
  if nx ~= Geo.x or ny ~= Geo.y or w ~= Geo.w or h ~= Geo.h then
    Geo.x, Geo.y, Geo.w, Geo.h = nx, ny, w, h
    log_act(string.format("Game picture: %.0fx%.0f at %.0f,%.0f inside the %.0fx%.0f display", w, h, nx, ny, sw, sh))
  end
  return Geo
end

local Wide = {}
function Wide.k() return Geo.get().h / 1080 end                               -- screen pixels per GUI unit (the picture is 1080 units high)
function Wide.ox() local g = Geo.get(); return g.x + (g.w - 1920 * (g.h / 1080)) / 2 end   -- screen x of the centred 1920-unit canvas' left edge

local R = { dl = nil, draws = 0 }

local function poly(pts, c)
  R.draws = R.draws + 1
  local n = #pts
  if n < 3 then return end
  local col = abgr(c)
  if R.dl then
    local ok = pcall(function()
      if n == 3 then R.dl:add_triangle_filled(v2(pts[1][1], pts[1][2]), v2(pts[2][1], pts[2][2]), v2(pts[3][1], pts[3][2]), col)
      elseif n == 4 then R.dl:add_quad_filled(v2(pts[1][1], pts[1][2]), v2(pts[2][1], pts[2][2]), v2(pts[3][1], pts[3][2]), v2(pts[4][1], pts[4][2]), col)
      else
        R.dl:path_clear()
        for i = 1, n do R.dl:path_line_to(v2(pts[i][1], pts[i][2])) end
        R.dl:path_fill_convex(col)
      end
    end)
    if ok then return end
  end
  for i = 2, n - 1 do
    pcall(draw.filled_quad, pts[1][1], pts[1][2], pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], pts[i + 1][1], pts[i + 1][2], col)
  end
end
local function line(x1, y1, x2, y2, c, t)
  if R.dl then
    if pcall(function() R.dl:add_line(v2(x1, y1), v2(x2, y2), abgr(c), t or 1) end) then return end
  end
  pcall(draw.line, x1, y1, x2, y2, abgr(c))
end
local function circle_line(x, y, r, c, t)
  if R.dl then
    if pcall(function() R.dl:add_circle(v2(x, y), r, abgr(c), 64, t or 1) end) then return end
  end
  pcall(draw.outline_circle, x, y, r, abgr(c), 64)
end
local function measure_raw(s, size, f)
  local pushed = f and pcall(imgui.push_font, f)
  local ok, v = pcall(imgui.calc_text_size, s)
  if pushed then pcall(imgui.pop_font) end
  if ok and v then
    local w, h = xy(v)
    if w then return w, h end
  end
  return #s * size * 0.5, size
end
-- text sizes are remembered (a size changes only with the text, the font or the font size)
local measure_cache, measure_n = {}, 0
local function measure(s, size)
  local f = font_for(size)
  local ck = s .. "\0" .. size .. (f and "f" or "-") .. (cfg.font_gen or 0)
  local hit = measure_cache[ck]
  if hit then return hit[1], hit[2] end
  local w, h = measure_raw(s, size, f)
  if measure_n > 400 then measure_cache, measure_n = {}, 0 end
  measure_cache[ck] = { w, h }; measure_n = measure_n + 1
  return w, h
end
local function text(s, x, y, c, size)
  local f = font_for(size)
  if R.dl then
    local pushed = f and pcall(imgui.push_font, f)
    local ok = pcall(function() R.dl:add_text(v2(x, y), abgr(c), s) end)
    if pushed then pcall(imgui.pop_font) end
    if ok then return end
  end
  pcall(draw.text, s, x, y, abgr(c))
end
local function text_c(s, x, y, c, size)
  local w, h = measure(s, size)
  text(s, x - w / 2 + 1, y - h / 2 + 1, { 0, 0, 0, 200 }, size)
  text(s, x - w / 2, y - h / 2, c, size)
end

-- a filled shape is a list of convex polygons
local function fill_shape(polys, c)
  for _, p in ipairs(polys) do poly(p, c) end
end
local function polar(cx, cy, r, a) return cx + math.sin(a) * r, cy - math.cos(a) * r end
local function ring_cells(cx, cy, r0, r1, a0, a1)
  local cells = {}
  local steps = math.max(2, math.ceil((a1 - a0) / (math.pi / 36)))
  for s = 0, steps - 1 do
    local t0, t1 = a0 + (a1 - a0) * s / steps, a0 + (a1 - a0) * (s + 1) / steps
    local x1, y1 = polar(cx, cy, r0, t0)
    local x2, y2 = polar(cx, cy, r1, t0)
    local x3, y3 = polar(cx, cy, r1, t1)
    local x4, y4 = polar(cx, cy, r0, t1)
    if r0 <= 0.01 then cells[#cells + 1] = { { cx, cy }, { x2, y2 }, { x3, y3 } }
    else cells[#cells + 1] = { { x1, y1 }, { x2, y2 }, { x3, y3 }, { x4, y4 } } end
  end
  return cells
end
local function rect_poly(x, y, w, h) return { { x, y }, { x + w, y }, { x + w, y + h }, { x, y + h } } end
local function arc(cx, cy, r, a0, a1, c, t)
  local steps = math.max(2, math.ceil((a1 - a0) / (math.pi / 48)))
  local px, py = polar(cx, cy, r, a0)
  for s = 1, steps do
    local x, y = polar(cx, cy, r, a0 + (a1 - a0) * s / steps)
    line(px, py, x, y, c, t)
    px, py = x, y
  end
end

-- Vocation icons: drawn with the draw list (REFramework imgui only - no textures, no plugins). One pictogram per weapon,
-- laid out on a unit square (-0.5..0.5), styled like the guild menu's gold-on-dark job badges.
local function glyph(id, x, y, size)
  local steel, gold = T("text"), T("accent_hi")
  local u = size
  local th = math.max(2, size * 0.055)
  local function P(px, py) return x + px * u, y + py * u end
  local function L(x1, y1, x2, y2, c, t) local a, b = P(x1, y1); local e, f = P(x2, y2); line(a, b, e, f, c or steel, t or th) end
  local function C(cx, cy, r, c, t) local a, b = P(cx, cy); circle_line(a, b, r * u, c or steel, t or th) end
  local function D(cx, cy, r, c) local a, b = P(cx, cy); fill_shape(ring_cells(a, b, 0, r * u, 0, TAU), c or steel) end
  local function Pg(pts, c)
    local q = {}
    for i, pt in ipairs(pts) do local a, b = P(pt[1], pt[2]); q[i] = { a, b } end
    poly(q, c or steel)
  end
  local function Curve(fn, n, c, t)
    local px, py
    for i = 0, n do
      local ax, ay = fn(i / n)
      if px then L(px, py, ax, ay, c, t) end
      px, py = ax, ay
    end
  end
  local function bow(cx, c)
    Curve(function(t) return cx - 0.2 * math.sin(math.pi * t), -0.38 + 0.76 * t end, 14, c or steel, th * 1.2)
    L(cx, -0.38, cx, 0.38, steel, math.max(1, th * 0.5))
  end
  if id == 1 then          -- Fighter: sword and shield
    C(-0.14, 0.06, 0.21); D(-0.14, 0.06, 0.06, gold)
    L(0.2, 0.32, 0.2, -0.32, steel, th * 1.2); L(0.1, 0.1, 0.3, 0.1, gold, th * 1.2)
    Pg({ { 0.16, -0.3 }, { 0.24, -0.3 }, { 0.2, -0.42 } }); D(0.2, 0.38, 0.035, gold)
  elseif id == 2 then      -- Archer: bow and arrow
    bow(-0.14)
    L(-0.14, 0, 0.34, 0, steel, th); Pg({ { 0.33, -0.06 }, { 0.33, 0.06 }, { 0.44, 0 } }, gold)
    L(-0.14, 0, -0.2, -0.06, gold, th * 0.8); L(-0.14, 0, -0.2, 0.06, gold, th * 0.8)
  elseif id == 3 then      -- Mage: staff with an orb
    L(-0.24, 0.4, 0.2, -0.18, steel, th * 1.3); D(0.25, -0.25, 0.1, gold); C(0.25, -0.25, 0.15, gold, th * 0.7)
    L(0.4, -0.42, 0.4, -0.32, gold, th * 0.7); L(0.35, -0.37, 0.45, -0.37, gold, th * 0.7)
  elseif id == 4 then      -- Thief: crossed daggers
    L(-0.28, 0.3, 0.22, -0.3, steel, th * 1.1); L(0.28, 0.3, -0.22, -0.3, steel, th * 1.1)
    L(-0.3, 0.2, -0.18, 0.3, gold, th * 1.1); L(0.3, 0.2, 0.18, 0.3, gold, th * 1.1)
    Pg({ { 0.2, -0.24 }, { 0.26, -0.3 }, { 0.26, -0.4 } }); Pg({ { -0.2, -0.24 }, { -0.26, -0.3 }, { -0.26, -0.4 } })
  elseif id == 5 then      -- Warrior: great sword
    Pg({ { -0.08, 0.12 }, { 0.08, 0.12 }, { 0.08, -0.3 }, { 0, -0.44 }, { -0.08, -0.3 } })
    L(-0.2, 0.14, 0.2, 0.14, gold, th * 1.5); L(0, 0.14, 0, 0.34, steel, th * 1.3); D(0, 0.39, 0.04, gold)
  elseif id == 6 then      -- Sorcerer: archistaff
    L(0, 0.42, 0, -0.1, steel, th * 1.3); C(0, -0.25, 0.15); D(0, -0.25, 0.06, gold)
    L(-0.15, -0.25, -0.23, -0.42, gold, th); L(0.15, -0.25, 0.23, -0.42, gold, th)
  elseif id == 7 then      -- Mystic Spearhand: duospear
    L(0.3, 0.3, -0.3, -0.3, steel, th * 1.2)
    Pg({ { -0.22, -0.36 }, { -0.36, -0.22 }, { -0.44, -0.44 } }, gold); Pg({ { 0.22, 0.36 }, { 0.36, 0.22 }, { 0.44, 0.44 } }, gold)
    C(0, 0, 0.08, gold, th * 0.9)
  elseif id == 8 then      -- Magick Archer: bow with a magic ring
    bow(-0.2); C(0.14, 0, 0.17, gold, th * 0.8); D(0.14, 0, 0.05, gold); L(-0.2, 0, 0.44, 0, gold, th * 0.8)
  elseif id == 9 then      -- Trickster: censer
    L(0, -0.44, 0, -0.2, steel, th * 0.8); C(0, 0, 0.2); L(-0.2, 0, 0.2, 0, steel, th * 0.7)
    D(-0.08, -0.08, 0.025, gold); D(0.08, -0.08, 0.025, gold); D(0, 0.09, 0.025, gold)
    Curve(function(t) return 0.05 * math.sin(t * 9), 0.22 + 0.2 * t end, 10, gold, th * 0.6)
  else                     -- Warfarer / anything else: compass diamond
    L(0, -0.32, 0.32, 0, steel); L(0.32, 0, 0, 0.32, steel); L(0, 0.32, -0.32, 0, steel); L(-0.32, 0, 0, -0.32, steel)
    D(0, 0, 0.08, gold)
  end
end
local function emblem(id, x, y, size)
  fill_shape(ring_cells(x, y, 0, size * 0.46, 0, TAU), { 26, 22, 18, 235 })
  circle_line(x, y, size * 0.46, T("accent"), 2)
  circle_line(x, y, size * 0.40, T("accent_soft"), 1)
  local ok, e = pcall(glyph, id, x, y, size * 0.8)
  if not ok then text_c(JOBS[id] and JOBS[id].abbr or "?", x, y, T("accent_hi"), math.max(13, size * 0.32)) end
end

------------------------------------------------------------------------------------------------
-- Game icons. A game GUI is drawn BEFORE the overlay, so each icon sits under the wheel: the wheel cuts a round hole into
-- its dim background, backdrop and slice, and frames the icon with a drawn medallion.
-- Measured on the game's data: the HUD job icon is ui022601 / PNL_job / tex_Job00 (a 64x64 cell of the atlas
-- Gui/ui01/Common/job/UVS_job_01.uvs); UVPatternNo = vocation id - 1 (9 = Warfarer); the panel's GlobalPosition is the centre
-- of the art; only a Control (the panel) has a scale, the texture has none; the shield fills ~94 % of the cell height.
------------------------------------------------------------------------------------------------
-- Draw order. The game draws its GUIs in ascending Segment order; the party's name plates and health bars and the vocation icons over
-- the pawns' heads are GUIs of their own that lie above the wheel's copies, so they showed through the wheel when a pawn stood behind
-- it. The wheel's GUIs are put one and two segments above the highest segment any other GUI has (looked up before a copy is made and
-- every time the wheel opens).
local Layers = { top = 11, at = -1000, bg_seg = 12, ico_seg = 13 }
function Layers.scan()
  Layers.at = frame
  local scene = current_scene()
  if not scene then return end
  local arr = mcall(scene, "findComponents(System.Type)", sdk.typeof("via.gui.GUI"))
  if arr == nil then return end
  local ok, els = pcall(function() return arr:get_elements() end)
  if not ok or not els then return end
  local top = 11                                                    -- the HUD GUI the icons are copied from
  for _, g in ipairs(els) do
    local go = mcall(g, "get_GameObject")
    local name = go and tostring(mcall(go, "get_Name") or "") or ""
    if name:sub(1, 15) ~= "WarfarerArsenal" then
      local seg = mcall(g, "get_Segment")
      if type(seg) == "number" and seg > top then top = seg end
    end
  end
  Layers.top = top
end
function Layers.icons() if frame - Layers.at > 600 then Layers.scan() end; return Layers.top + 2 end
function Layers.bg() return Layers.icons() - 1 end

local Ico = { holes = {}, cells = {}, center_hole = nil, shown = false, retry_at = 0, dead = 0, res = nil }
Ico.CELL, Ico.ART_H = 64, 0.94
Ico.HOLE = 0.54                                  -- hole radius = slot icon size x this (x the icon size setting)
Ico.GUI = { RenderOutputID = 1, GUICameraTargetID = 0, Segment = 13 }   -- like the HUD GUI; the segment is set from Layers when a copy is made

function Ico.pattern(job) return math.max(0, job - 1) end

-- a filled rectangle without anti-aliasing (anti-aliased neighbours leave hairlines), snapped to whole pixels
local RV1, RV2 = Vector2f.new(0, 0), Vector2f.new(0, 0)       -- reused for every rectangle: no new object per call
function Ico.rect(x, y, w, h, c)
  if w <= 0 or h <= 0 then return end
  R.draws = R.draws + 1
  local x0, y0 = math.floor(x + 0.5), math.floor(y + 0.5)
  local x1, y1 = math.floor(x + w + 0.5), math.floor(y + h + 0.5)
  if R.dl then
    RV1.x = x0; RV1.y = y0; RV2.x = x1; RV2.y = y1
    if Ico.fast then R.dl:add_rect_filled(RV1, RV2, abgr(c), 0, 0); return end      -- proven to work: no pcall and closure per rectangle
    if pcall(function() R.dl:add_rect_filled(RV1, RV2, abgr(c), 0, 0) end) then
      Ico.fast_n = (Ico.fast_n or 0) + 1
      if Ico.fast_n > 30 then Ico.fast = true end
      return
    end
  end
  fill_shape({ rect_poly(x0, y0, x1 - x0, y1 - y0) }, c)
end
-- a rectangle with the round icon holes cut out
function Ico.fill_rect_holes(x, y, w, h, c)
  local holes = Ico.holes
  if #holes == 0 then Ico.rect(x, y, w, h, c); return end
  local ranges = {}
  for _, hl in ipairs(holes) do
    local a, b = math.max(y, hl.y - hl.r), math.min(y + h, hl.y + hl.r)
    if b > a and hl.x + hl.r > x and hl.x - hl.r < x + w then ranges[#ranges + 1] = { a, b } end   -- only holes this rectangle touches
  end
  table.sort(ranges, function(p, q) return p[1] < q[1] end)
  local merged = {}
  for _, rg in ipairs(ranges) do
    local last = merged[#merged]
    if last and rg[1] <= last[2] then last[2] = math.max(last[2], rg[2]) else merged[#merged + 1] = { rg[1], rg[2] } end
  end
  local cursor = y
  for _, rg in ipairs(merged) do
    if rg[1] > cursor then Ico.rect(x, cursor, w, rg[1] - cursor, c) end
    local yy = rg[1]
    while yy < rg[2] do
      local y2 = math.min(rg[2], yy + 4)
      local yc = (yy + y2) / 2
      local iv = {}
      for _, hl in ipairs(holes) do
        local dy = yc - hl.y
        if math.abs(dy) < hl.r then
          local dx = math.sqrt(hl.r * hl.r - dy * dy)
          iv[#iv + 1] = { hl.x - dx, hl.x + dx }
        end
      end
      table.sort(iv, function(p, q) return p[1] < q[1] end)
      local xcur = x
      for _, seg in ipairs(iv) do
        if seg[2] > x and seg[1] < x + w then                       -- a hole beside the rectangle must not stretch it
          if seg[1] > xcur then Ico.rect(xcur, yy, math.min(seg[1], x + w) - xcur, y2 - yy, c) end
          xcur = math.max(xcur, seg[2])
        end
      end
      if xcur < x + w then Ico.rect(xcur, yy, x + w - xcur, y2 - yy, c) end
      yy = y2
    end
    cursor = rg[2]
  end
  if cursor < y + h then Ico.rect(x, cursor, w, y + h - cursor, c) end
end
-- a ring sector with one round hole: a grid of small cells, those whose centre lies inside the hole (+ half the medallion
-- width) are dropped. Opaque callers get half a pixel of overlap so neighbours leave no hairline.
function Ico.ring_cells_hole(cx, cy, r0, r1, a0, a1, hl)
  local cells = {}
  local na = math.max(2, math.ceil((a1 - a0) / (math.pi / 90)))
  local nr = 12
  local cut = hl.r + hl.w * 0.5
  for i = 0, na - 1 do
    local t0, t1 = a0 + (a1 - a0) * i / na, a0 + (a1 - a0) * (i + 1) / na
    local run = nil
    for j = 0, nr do
      local keep = false
      if j < nr then
        local ra, rb = r0 + (r1 - r0) * j / nr, r0 + (r1 - r0) * (j + 1) / nr
        local mx, my = polar(cx, cy, (ra + rb) / 2, (t0 + t1) / 2)
        local dx, dy = mx - hl.x, my - hl.y
        keep = dx * dx + dy * dy > cut * cut
      end
      if keep then
        if not run then run = j end
      elseif run then                               -- a run of kept cells is one quad
        local ra, rb = r0 + (r1 - r0) * run / nr, r0 + (r1 - r0) * j / nr
        local rm = (ra + rb) / 2
        local ea = 0.6 / math.max(rm, 1)
        local x1, y1 = polar(cx, cy, math.max(0, ra - 0.6), t0 - ea)
        local x2, y2 = polar(cx, cy, rb + 0.6, t0 - ea)
        local x3, y3 = polar(cx, cy, rb + 0.6, t1 + ea)
        local x4, y4 = polar(cx, cy, math.max(0, ra - 0.6), t1 + ea)
        cells[#cells + 1] = { { x1, y1 }, { x2, y2 }, { x3, y3 }, { x4, y4 } }
        run = nil
      end
    end
  end
  return cells
end
-- a ring with any number of holes (the backdrop)
function Ico.fill_ring_holes(cx, cy, r0, r1, c)
  if #Ico.holes == 0 then fill_shape(ring_cells(cx, cy, r0, r1, 0, TAU), c); return end
  local cells = {}
  local na, nr = 180, 14
  for i = 0, na - 1 do
    local t0, t1 = TAU * i / na, TAU * (i + 1) / na
    local run = nil
    for j = 0, nr do
      local keep = false
      if j < nr then
        local ra, rb = r0 + (r1 - r0) * j / nr, r0 + (r1 - r0) * (j + 1) / nr
        local mx, my = polar(cx, cy, (ra + rb) / 2, (t0 + t1) / 2)
        keep = true
        for _, hl in ipairs(Ico.holes) do
          local dx, dy = mx - hl.x, my - hl.y
          local cut = hl.r + hl.w * 0.5
          if dx * dx + dy * dy <= cut * cut then keep = false; break end
        end
      end
      if keep then
        if not run then run = j end
      elseif run then
        local ra, rb = r0 + (r1 - r0) * run / nr, r0 + (r1 - r0) * j / nr
        local x1, y1 = polar(cx, cy, ra, t0)
        local x2, y2 = polar(cx, cy, rb, t0)
        local x3, y3 = polar(cx, cy, rb, t1)
        local x4, y4 = polar(cx, cy, ra, t1)
        cells[#cells + 1] = { { x1, y1 }, { x2, y2 }, { x3, y3 }, { x4, y4 } }
        run = nil
      end
    end
  end
  fill_shape(cells, c)
end
function Ico.medallion(hl)
  circle_line(hl.x, hl.y, hl.r + hl.w * 0.5, { 20, 18, 14, 238 }, hl.w)      -- the band between r and r + w, one call
  circle_line(hl.x, hl.y, hl.r + hl.w, T("accent"), 2)
  circle_line(hl.x, hl.y, hl.r, T("accent_soft"), 1)
end

-- a copied GUI is invisible by default (the HUD fades its panels in): force every control of the icon's chain visible
function Ico.force_visible(go, gui, view, tex)
  pcall(function() go:call("set_DrawSelf", true) end)
  pcall(function() go:call("set_UpdateSelf", true) end)
  pcall(function() gui:call("set_Enabled", true) end)
  pcall(function() view:call("set_ForceInvisible", false); view:call("set_Visible", true) end)
  local c, guard = tex, 0
  while c ~= nil and guard < 30 do
    guard = guard + 1
    pcall(function() c:call("set_ForceInvisible", false); c:call("set_Visible", true) end)
    pcall(function()
      local cs = mcall(c, "get_ColorScale")
      if cs ~= nil then
        pcall(function() cs.x = 1 end); pcall(function() cs.y = 1 end); pcall(function() cs.z = 1 end); pcall(function() cs.w = 1 end)
        c:call("set_ColorScale", cs)
      end
    end)
    c = mcall(c, "get_Parent")
  end
end
-- The first copy walks the whole GUI tree to find the wanted control and records its path (child indices from the root).
-- Every later copy - and every later session, the path is kept in config.json - follows that path and hides only the
-- siblings along it: a hidden control hides its whole subtree (the same reason force_visible has to un-hide the
-- ancestors), so no walk through thousands of controls is needed.
function Ico.follow_path(view, path, check)
  if type(path) ~= "table" or #path == 0 then return nil end
  local c, tex = mcall(view, "get_Child"), nil
  for depth, idx in ipairs(path) do
    local target, n = nil, 0
    while c ~= nil and n < 4000 do
      n = n + 1
      if n == idx then target = c else pcall(function() c:call("set_ForceInvisible", true) end) end
      c = mcall(c, "get_Next")
    end
    if not target then return nil end
    if depth == #path then tex = target else c = mcall(target, "get_Child") end
  end
  if tex and check(tex) then return tex end
  return nil
end
function Ico.walk_tree(view, match)
  local tex, visits, found = nil, 0, nil
  local trail = {}
  local function walk(c)
    local keep, idx = false, 0
    while c ~= nil and visits < 4000 do
      visits = visits + 1
      idx = idx + 1
      local is_tex = match(c)
      if is_tex then
        tex = c
        found = {}
        for i, v in ipairs(trail) do found[i] = v end
        found[#found + 1] = idx
      end
      local child = mcall(c, "get_Child")
      local has = is_tex
      if child ~= nil then
        trail[#trail + 1] = idx
        if walk(child) then has = true end
        trail[#trail] = nil
      end
      if not has then pcall(function() c:call("set_ForceInvisible", true) end) end
      keep = keep or has
      c = mcall(c, "get_Next")
    end
    return keep
  end
  walk(mcall(view, "get_Child"))
  return tex, found
end
function Ico.kill(go)
  local gotd = sdk.find_type_definition("via.GameObject")
  local m = gotd and gotd:get_method("destroy(via.GameObject)")
  if m and go then pcall(function() m:call(nil, go) end) end
end
-- a new GameObject with a GUI component showing `res`; the view can still be nil while the asset loads
function Ico.spawn(goname, res, props)
  local gotd = sdk.find_type_definition("via.GameObject")
  local create = gotd and gotd:get_method("create(System.String)")
  if not create then return nil, nil, nil, "via.GameObject.create not found" end
  local go = create:call(nil, goname)
  if not go then return nil, nil, nil, "GameObject.create returned nil" end
  if props.start_hidden then pcall(function() go:call("set_DrawSelf", false) end) end   -- no flash of the whole GUI before it is trimmed
  local gui = go:call("createComponent(System.Type)", sdk.typeof("via.gui.GUI"))
  if not gui then return nil, nil, nil, "createComponent(via.gui.GUI) returned nil" end
  local holder = res:create_holder("via.gui.GUIResourceHolder")
  if not holder then return nil, nil, nil, "create_holder returned nil" end
  gui:call("set_Asset", holder)
  for nm, v in pairs(props) do
    if nm ~= "start_hidden" then pcall(function() gui:call("set_" .. nm, v) end) end
  end
  return go, gui, mcall(gui, "get_View")
end
function Ico.is_job(c) return tostring(mcall(c, "get_Name") or "") == "tex_Job00" end
-- one spawned copy of the HUD GUI with everything hidden except the tex_Job00 chain
function Ico.make_cell()
  local res = Ico.res
  if not res then
    res = sdk.create_resource("via.gui.GUIResource", "Gui/ui02/ui0226/ui022601.gui")
    if not res then return nil, "create_resource returned nil" end
    pcall(function() res:add_ref() end)
    Ico.res = res                                             -- one resource for all copies, each copy gets its own holder
  end
  Ico.GUI.Segment = Layers.icons()
  local go, gui, view, err = Ico.spawn("WarfarerArsenalIcon" .. (#Ico.cells + 1), res, Ico.GUI)
  if not go then return nil, err end
  if not view then Ico.kill(go); return nil, "the new GUI has no view yet" end
  local tex = Ico.follow_path(view, cfg.ico_path, Ico.is_job)
  if not tex then
    local t, path = Ico.walk_tree(view, Ico.is_job)          -- first copy ever, or the game's GUI changed
    tex = t
    if t and path then cfg.ico_path = path; mark_dirty() end
  end
  if not tex then return nil, "tex_Job00 not found in the new GUI" end
  Ico.force_visible(go, gui, view, tex)
  pcall(function() tex:call("set_ForceInvisible", true) end)
  local pnl = mcall(tex, "get_Parent")                       -- PNL_job: a Control, so it has a scale; the texture has none
  pcall(function() tex:call("set_Position", Vector2f.new(0, 0)) end)   -- the art's centre sits on the panel's origin
  return { go = go, gui = gui, tex = tex, pnl = pnl, hidden = true, ix = #Ico.cells + 1 }
end
-- Calibration (while the wheel is closed, a few frames after a copy is made): the chain between the panel's own position and its
-- GlobalPosition is a gain and an origin per axis (global = origin + gain * own; gain 1 on 16:9, 0.5 horizontally at 32:9). The
-- game updates GlobalPosition a frame or two after a write, so two test positions are written a few frames apart and both are read
-- back after the wait. Placement then needs no read of GlobalPosition at all: the icon is put straight at the right place on the
-- first frame, instead of walking there while the reading catches up. Done again when the screen size changes.
function Ico.calibrate(cell)
  local sw, sh = screen_size()
  if cell.Og and (cell.cal_w ~= sw or cell.cal_h ~= sh) then cell.Og, cell.cal, cell.cal_failed = nil, nil, false end
  if cell.Og or cell.cal_failed then return end
  local pnl = cell.pnl or cell.tex
  local st = cell.cal
  if not st then
    pcall(function() pnl:call("set_Position", Vector2f.new(100, 50)) end)
    cell.cal = { step = 1, at = frame, w = sw, h = sh }
    return
  end
  if frame - st.at < 4 then return end
  local p, g = mcall(pnl, "get_Position"), mcall(pnl, "get_GlobalPosition")
  local px, py, gx, gy = rd_num(p, "x"), rd_num(p, "y"), rd_num(g, "x"), rd_num(g, "y")
  if not (px and py and gx and gy) then
    cell.cal_tries = (cell.cal_tries or 0) + 1
    cell.cal = nil
    if cell.cal_tries >= 3 then cell.cal_failed = true; log_act("Icons: calibration failed (positions can not be read) - using the slower search") end
    return
  end
  if st.step == 1 then
    st.p1, st.step, st.at = { px, py, gx, gy }, 2, frame
    pcall(function() pnl:call("set_Position", Vector2f.new(300, 250)) end)
    return
  end
  local a = st.p1
  local dx, dy = px - a[1], py - a[2]
  local mx, my = dx ~= 0 and (gx - a[3]) / dx or 0, dy ~= 0 and (gy - a[4]) / dy or 0
  if mx > 0.15 and mx < 6 and my > 0.15 and my < 6 then
    cell.gain, cell.gain_fixed, cell.Og, cell.cal_w, cell.cal_h, cell.cal = { mx, my }, true, { gx - mx * px, gy - my * py }, st.w, st.h, nil
    if not Ico.cal_logged then
      Ico.cal_logged = true
      log_act(string.format("Icons: chain calibrated, gain %.3f / %.3f", mx, my))
    end
  else
    cell.cal_tries = (cell.cal_tries or 0) + 1
    cell.cal = nil
    if cell.cal_tries >= 3 then
      cell.cal_failed = true
      log_act(string.format("Icons: calibration failed (gain read %.2f / %.2f) - using the slower search", mx, my))
    end
  end
end
function Ico.hide(cell)
  if cell and not cell.hidden then
    pcall(function() cell.tex:call("set_ForceInvisible", true) end)
    cell.hidden = true
  end
end
function Ico.hide_all()
  for _, c in ipairs(Ico.cells) do Ico.hide(c) end
  Ico.shown = false
end
-- show a cell's art centred on (cx, cy) in GUI units at `scale` times its native 64 px
function Ico.place(cell, cx, cy, scale, pattern)
  local tex = cell.tex
  local pnl = cell.pnl or tex
  if not cell.Og and not cell.cal_failed then return false end          -- not calibrated yet (see Ico.calibrate)
  local ok = pcall(function()
    if cell.hidden then tex:call("set_ForceInvisible", false); cell.hidden = false end
    if cell.pat ~= pattern then tex:call("set_UVPatternNo", pattern); cell.pat = pattern end
    -- The panel's scale is read back and written again whenever it differs (the game rewrites it). On a very wide screen the game
    -- stretches the GUI horizontally by the inverse of the chain's gain (see below), so the drawn size is the plain scale.
    local wx, wy = scale, scale
    local sc = mcall(pnl, "get_Scale")
    local cx0, cy0 = rd_num(sc, "x"), rd_num(sc, "y")
    if not (cx0 and cy0 and math.abs(cx0 - wx) < 1e-4 and math.abs(cy0 - wy) < 1e-4) then
      local done = false
      if sc ~= nil then
        local okm = pcall(function() sc.x = wx; sc.y = wy end)
        if okm then done = pcall(function() pnl:call("set_Scale", sc) end) end
      end
      if not done then
        done = pcall(function() pnl:call("set_Scale", Vector3f.new(wx, wy, 1)) end)
        if not done then pcall(function() pnl:call("set_Scale", Vector2f.new(wx, wy)) end) end
      end
      cell.scale_writes = (cell.scale_writes or 0) + 1
    end
    cell.scale_read = cx0
    if cell.Og then
      -- global = origin + gain * own, and the game stretches the GUI about the canvas centre by 1 / gain (see below), so the global
      -- point that lands on the wanted screen point is the canvas centre plus the wanted offset times the gain
      local gn, og = cell.gain, cell.Og
      local nx = (960 + (cx - 960) * gn[1] - og[1]) / gn[1]
      local ny = (540 + (cy - 540) * gn[2] - og[2]) / gn[2]
      local pc = mcall(pnl, "get_Position")
      local qx, qy = rd_num(pc, "x"), rd_num(pc, "y")
      if not (qx and qy and math.abs(qx - nx) < 0.05 and math.abs(qy - ny) < 0.05) then pnl:call("set_Position", Vector2f.new(nx, ny)) end
      return
    end
    local g, p = mcall(pnl, "get_GlobalPosition"), mcall(pnl, "get_Position")
    local gx0, gy0, px0, py0 = rd_num(g, "x"), rd_num(g, "y"), rd_num(p, "x"), rd_num(p, "y")
    if gx0 and gy0 and px0 and py0 then
      -- Closed loop: a move of the control's own position may move it on screen by another amount (a parent that is scaled, as the
      -- HUD canvas is on a wide screen: icons at the middle land right, icons farther out do not). The gain (screen move per unit of
      -- own position) is measured from the previous move and used for the next one, so the icon walks to the wanted place.
      local gn = cell.gain or { 1, 1 }
      local L = cell.last
      if L and L.frame < frame and frame - L.frame <= 3 then
        local dlx, dly = L.pset_x - L.px, L.pset_y - L.py
        local function learn(i, dl, dg_now, dg_old)
          if math.abs(dl) > 2 then
            local m = (dg_now - dg_old) / dl
            if m > 0.15 and m < 6 then gn[i] = gn[i] * 0.5 + m * 0.5 end     -- screen move per unit of the control's own position
          end
        end
        if not cell.gain_fixed then learn(1, dlx, gx0, L.gx); learn(2, dly, gy0, L.gy) end
        cell.gain = gn
      end
      -- The chain's gain (global move per unit of own position) is below 1 on a very wide screen (0.5 at 32:9): the game stretches the
      -- GUI about the canvas centre by 1 / gain, which cancels the chain's scale for sizes and rotations but not for GlobalPosition.
      -- So the global point that lands on the wanted screen point is the canvas centre plus the wanted offset times the gain.
      -- With gain 1 (16:9, 21:9) this is the wanted point itself.
      local gtx, gty = 960 + (cx - 960) * gn[1], 540 + (cy - 540) * gn[2]
      local nx, ny = px0 + (gtx - gx0) / gn[1], py0 + (gty - gy0) / gn[2]
      if math.abs(gtx - gx0) > 0.4 or math.abs(gty - gy0) > 0.4 or not L then
        pnl:call("set_Position", Vector2f.new(nx, ny))
        cell.last = { frame = frame, px = px0, py = py0, gx = gx0, gy = gy0, pset_x = nx, pset_y = ny }
      end
    end
  end)
  if not ok then cell.errs = (cell.errs or 0) + 1 end
  return ok
end
-- put a cell's icon at screen point (sx, sy) inside a hole of radius r; returns the hole or nil
function Ico.show_at(cell, sx, sy, r, job)
  if not cell or (cell.errs or 0) >= 8 then return nil end
  local sw, sh = screen_size()
  local k = Wide.k()                                     -- GUI space is 1080 units high, scaled by screen height (see Wide for the width)
  local ox = Wide.ox()
  local oy = Geo.y
  local art_h = 2 * r * cfg.icon_art_k                   -- the shield is a little smaller than the hole, so the ring does not trim its tip
  local cell_screen = art_h / Ico.ART_H
  local scale = cell_screen / (Ico.CELL * k)
  if not Ico.place(cell, (sx - ox) / k, (sy - oy) / k, scale, Ico.pattern(job)) then return nil end
  return { x = sx, y = sy, r = r, w = math.max(10, r * 0.2) }
end
-- every frame while the wheel is up: position the slice icons and collect the holes
function Ico.update(items)
  Ico.holes = {}
  for i, it in ipairs(items) do
    local cell = Ico.cells[i]
    it.hole = nil
    if cell then
      local hl = Ico.show_at(cell, it.ix, it.iy, it.isz * Ico.HOLE * cfg.icon_size_k * (it.hov and 1.1 or 1.0), it.opt.job)
      if hl then
        it.hole = hl
        Ico.holes[#Ico.holes + 1] = hl
      end
    end
  end
  for i = #items + 1, 9 do Ico.hide(Ico.cells[i]) end
  Ico.shown = true
end
-- the Warfarer's own icon in the middle of the wheel (cell 10)
function Ico.update_center(icon)
  Ico.center_hole = nil
  local hl = Ico.show_at(Ico.cells[10], icon.x, icon.y, icon.size * Ico.HOLE * 0.567 * cfg.icon_size_k, cfg.warfarer_job)
  if hl then
    Ico.center_hole = hl
    Ico.holes[#Ico.holes + 1] = hl
    Ico.shown = true
  end
end
-- per frame: create the missing cells while the wheel is closed (as many as fit in a few milliseconds, so all ten are up
-- within a handful of frames after a reload), hide them all when it closes. A failed copy waits 20 frames before a retry.
Ico.BUDGET = 0.006
function Ico.tick()
  if not cfg.game_icons then
    if Ico.shown then Ico.hide_all() end
    return
  end
  if not (W.open or W.pinned) and Ico.shown then Ico.hide_all() end
  for _, c in ipairs(Ico.cells) do pcall(Ico.calibrate, c) end
  if #Ico.cells < 10 and not W.open and frame >= Ico.retry_at and P.char and not is_loading() and Ico.dead < 3 then
    local t0 = os.clock()
    repeat
      local ok, cell = pcall(Ico.make_cell)
      if ok and cell then
        Ico.cells[#Ico.cells + 1] = cell
      else
        Ico.dead = Ico.dead + 1
        Ico.retry_at = frame + 20
        break
      end
    until #Ico.cells >= 10 or os.clock() - t0 > Ico.BUDGET
  end
end
function Ico.destroy_all()
  local gotd = sdk.find_type_definition("via.GameObject")
  local m = gotd and gotd:get_method("destroy(via.GameObject)")
  for _, c in ipairs(Ico.cells) do
    if m then pcall(function() m:call(nil, c.go) end) end
  end
  Ico.cells, Ico.shown = {}, false
end

------------------------------------------------------------------------------------------------
-- The game's own menu background, cut to the wheel's shape
------------------------------------------------------------------------------------------------
-- The background is one 2560x1080 Texture control (tex_) in Gui/ui06/ui0608/ui060804. The engine does not let Lua read that
-- control's texture or clone the control, so the only way to put a piece of it on screen is a copy of the whole GUI: every
-- copy carries its own tex_, which is moved, sized and cropped (normalised UV) to one piece of the wheel, so the pieces
-- together show one continuous picture, exactly where it sits on the menu.
-- With two or more slices every slice gets its own pieces, so the gaps between the slices and the gap around the centre disc
-- stay transparent (the world shows through, dimmed); with fewer slices the texture covers one ring instead. The pieces are
-- rectangles that lie entirely inside a slice (or the disc): bands whose height adapts to how fast the outline moves, each
-- band cut to the part that fits in every row of it. What the rectangles do not reach (a thin crescent along the outlines, at
-- its widest the "edge tolerance") is filled by the overlay with one flat colour (Colours > "Menu background fill"), measured
-- from the texture so the two blend. A slice that is pushed out when hovered takes its pieces and its fill with it.
-- Slices (two or more) are cut differently: every slice gets a column of strips that are TURNED to its middle axis (a Texture
-- control has a Rotation, in degrees, around its top-left corner), each as wide as the slice is at that distance; the picture in
-- a strip is just whatever the texture shows there, the strips do not line up with each other. The rest of the slice is flat fill.
-- A smaller tolerance means more copies and thinner crescents. Everything is read back; when something fails the old dark
-- fills are used (see the debug box).
local Bg = { res = nil, cells = {}, ctls = {}, pending = nil, thid = {}, count = 0, list = nil, groups = nil, key = nil, s = 1, n = 0, slice_mode = false,
  done_key = nil, next_i = 1, shown = false, on = false, broken = false, dead = 0, retry_at = 0,
  seen = {}, modes = false, checked = 0, pre_at = 2, pre_tries = 0, on_age = 0, tail = 0, org = {}, queue = {}, serial = 0, vac = nil,
  t0 = os.clock() }
Bg.PATH = "Gui/ui06/ui0608/ui060804.gui"
Bg.GUI = { RenderOutputID = 1, GUICameraTargetID = 0, Segment = 12, start_hidden = true }    -- one segment behind the icon GUIs (see Layers)
Bg.TEX_W, Bg.TEX_H, Bg.TEX_X = 2560, 1080, -320
Bg.EDGE = 6                                       -- the backdrop ring reaches this far (x scale) past the slices
Bg.BUDGET = 0.012                                 -- seconds per frame for making and trimming copies (a hitch for a second after a reload)
Bg.LOOK = 10                                      -- copies that wait for their view at the same time

function Bg.note(msg) log_act("background: " .. msg) end
function Bg.note_once(key, msg) if not Bg.seen[key] then Bg.seen[key] = true; Bg.note(msg) end end
function Bg.fail(msg) Bg.broken = true; Bg.last_fail = msg; Bg.note("FAILED: " .. msg) end

local function pair_of(v, a, b)
  local x, y = rd_num(v, a), rd_num(v, b)
  if x == nil or y == nil then x, y = rd_num(v, "x"), rd_num(v, "y") end
  return x, y
end
function Bg.is_tex(c)
  if tostring(mcall(c, "get_Name") or "") ~= "tex_" then return false end
  local w, h = pair_of(mcall(c, "get_Size"), "w", "h")
  return w ~= nil and h ~= nil and math.abs(w - Bg.TEX_W) < 2 and math.abs(h - Bg.TEX_H) < 2
end

function Bg.reset()                               -- new scene / reset: the spawned GUIs are gone
  Bg.res, Bg.cells, Bg.ctls, Bg.pending, Bg.thid, Bg.count = nil, {}, {}, nil, {}, 0
  Bg.queue, Bg.vac = {}, nil
  Bg.list, Bg.groups, Bg.key, Bg.done_key, Bg.next_i = nil, nil, nil, nil, 1
  Bg.shown, Bg.on, Bg.broken, Bg.dead, Bg.retry_at, Bg.modes = false, false, false, 0, 0, false
  Bg.gain, Bg.last_fail = { 1, 1 }, nil
  Bg.pos_tpl, Bg.size_tpl, Bg.last_begin, Bg.checked = nil, nil, nil, 0
  Bg.pre_at, Bg.pre_tries, Bg.on_age, Bg.tail, Bg.org = frame + 30, 0, 0, 0, {}
end
function Bg.destroy()
  for _, c in ipairs(Bg.cells) do Ico.kill(c.go) end
  for _, p in ipairs(Bg.queue) do Ico.kill(p.go) end
  Bg.reset()
end

-- show / hide every piece (leftover pieces of a bigger layout stay hidden for good)
function Bg.set_hidden(h)
  if h then
    -- a GUI change shows up a few frames after the overlay: the overlay keeps covering the pieces for that long (render_cover)
    if Bg.shown and Bg.on and (cfg.bg_close_frames or 0) > 0 then Bg.tail, Bg.tail_t0 = cfg.bg_close_frames, os.clock() end
    Bg.on_age = 0
  end
  -- Switching the whole GameObject's drawing is immediate; a control's ForceInvisible only takes effect when the GUI updates,
  -- which can be several frames later (the game is still in slow motion while the wheel closes). Only after the first layout
  -- is done: the first pieces are read back while the copy still draws.
  if Bg.done_key then
    for _, c in ipairs(Bg.cells) do pcall(function() c.go:call("set_DrawSelf", not h) end) end
  end
  for i, t in ipairs(Bg.ctls) do
    if not Bg.thid[i] then pcall(function() t:call("set_ForceInvisible", h) end) end
  end
  Bg.shown = not h
end

-- Start loading the menu GUI (and tex_'s texture once its path is known) as soon as the script runs, and again right after a scene
-- change: the assets stream in while the game is still loading, so the first copy finds its view ready. A copy that has to draw
-- itself while its textures are still missing is what makes the game print "texture ... not found" in yellow.
function Bg.prefetch()
  if frame < Bg.pre_at then return end
  if not Bg.res then
    Bg.pre_at = frame + 60
    local ok, res = pcall(sdk.create_resource, "via.gui.GUIResource", Bg.PATH)
    if ok and res then
      pcall(function() res:add_ref() end)
      Bg.res = res
    end
  end
end
-- one more copy of the GUI; the view can still be nil while the asset loads
function Bg.spawn()
  local res = Bg.res
  if not res then
    res = sdk.create_resource("via.gui.GUIResource", Bg.PATH)
    if not res then return nil, "create_resource returned nil" end
    pcall(function() res:add_ref() end)
    Bg.res = res
  end
  Bg.serial = Bg.serial + 1
  Bg.GUI.Segment = Layers.bg()
  local go, gui, _, err = Ico.spawn("WarfarerArsenalBackground" .. Bg.serial, res, Bg.GUI)
  if not go then return nil, err end
  return { go = go, gui = gui, born = frame, next_try = frame + 1 }
end
-- true when the copy is usable and its tex_ is the only thing left visible; false while the asset is still loading.
-- The first copy walks the whole tree and records the path to tex_ (config.json); later copies follow that path.
function Bg.finish(p)
  local view = mcall(p.gui, "get_View")
  if not view then return false end
  local first = #Bg.cells == 0
  local tex = Ico.follow_path(view, cfg.bg_path, Bg.is_tex)
  if not tex then
    local t, path = Ico.walk_tree(view, Bg.is_tex)
    tex = t
    if t and path then cfg.bg_path = path; mark_dirty() end
  end
  if not tex then return false end
  Ico.force_visible(p.go, p.gui, view, tex)
  pcall(function() tex:call("set_ForceInvisible", true) end)
  Bg.cells[#Bg.cells + 1] = { go = p.go, gui = p.gui, tex = tex, view = view }
  Bg.ctls[#Bg.cells] = tex
  Bg.pending = nil
  if first then
    Bg.pos_tpl, Bg.size_tpl = mcall(tex, "get_Position"), mcall(tex, "get_Size")
    Bg.note(string.format("first GUI copy ready after %d frames (%.1f s after the script started)", frame - p.born, os.clock() - Bg.t0))
  end
  return true
end

-- ---------------------------------------------------------------------------------------------
-- geometry. Screen pixels, the wheel centred on the screen.
-- strips: for each row of pixels the intervals covered by the ring and the centre disc (also used by the dimmer)
-- pieces: the rectangles that lie inside that shape, one or two per band of rows
-- slivers: the strips minus the pieces, what the flat fill has to cover
-- ---------------------------------------------------------------------------------------------
function Bg.mode_n() return #(Arisen.list or {}) end
-- radii in screen pixels: for slices the slices themselves, for the single ring a small margin around it
function Bg.radii(s)
  if Bg.slice_mode then
    local r_in, r_out = cfg.inner_radius * s, cfg.wheel_radius * s
    return r_in, r_out, math.min(cfg.center_radius * s, r_in - 1)
  end
  local R1 = math.max(0, (cfg.inner_radius - Bg.EDGE) * s)
  return R1, (cfg.wheel_radius + Bg.EDGE) * s, math.min(cfg.center_radius * s, R1 - 1)
end

-- Row functions: for a horizontal line y (absolute pixels) the intervals {lo, hi} of the shape on that line, left to right.
local function chord(R, y) local v = R * R - y * y; return v > 0 and math.sqrt(v) or 0 end
function Bg.disc_rowfn(cx, cy, Rc)
  return function(y)
    local w = chord(Rc, y - cy)
    if w > 0 then return { { cx - w, cx + w } } end
    return {}
  end
end
function Bg.ring_rowfn(cx, cy, R1, R2, Rc)
  return function(y)
    local dy, out = y - cy, {}
    local d2 = chord(R2, dy)
    if d2 > 0 then
      local d1 = chord(R1, dy)
      if d1 > 0 then
        out[#out + 1] = { cx - d2, cx - d1 }
        out[#out + 1] = { cx + d1, cx + d2 }
      else
        out[#out + 1] = { cx - d2, cx + d2 }
      end
    end
    local dc = chord(Rc, dy)
    if dc > 0 then out[#out + 1] = { cx - dc, cx + dc } end
    table.sort(out, function(p, q) return p[1] < q[1] end)
    return out
  end
end
-- an annular sector (a slice): two half-planes for the radial edges (the span is below 180 degrees), the outer circle, and the
-- inner circle cut out. Angles run clockwise from straight up, like polar() in the drawing code.
function Bg.sector_rowfn(ox, oy, r0, r1, a0, a1)
  local s0, c0, s1, c1 = math.sin(a0), math.cos(a0), math.sin(a1), math.cos(a1)
  return function(y)
    local dy = y - oy
    if math.abs(dy) >= r1 then return {} end
    local lo, hi = -math.huge, math.huge
    local function lim(A, B)                                    -- A * dx >= B
      if A > 1e-9 then lo = math.max(lo, B / A)
      elseif A < -1e-9 then hi = math.min(hi, B / A)
      elseif B > 0 then lo, hi = 1, 0 end
    end
    lim(c0, -dy * s0)
    lim(-c1, dy * s1)
    local w1 = math.sqrt(r1 * r1 - dy * dy)
    lo, hi = math.max(lo, -w1), math.min(hi, w1)
    if hi - lo <= 0 then return {} end
    local out = {}
    if math.abs(dy) < r0 then
      local w0 = math.sqrt(r0 * r0 - dy * dy)
      if lo < -w0 then out[#out + 1] = { ox + lo, ox + math.min(hi, -w0) } end
      if hi > w0 then out[#out + 1] = { ox + math.max(lo, w0), ox + hi } end
    else
      out[1] = { ox + lo, ox + hi }
    end
    return out
  end
end
local function intersect_lists(A, B)
  local out = {}
  for _, a in ipairs(A) do
    for _, b in ipairs(B) do
      local lo, hi = math.max(a[1], b[1]), math.min(a[2], b[2])
      if hi > lo then out[#out + 1] = { lo, hi } end
    end
  end
  table.sort(out, function(p, q) return p[1] < q[1] end)
  return out
end
-- Pieces and fill for one shape. Rows `hs` pixels high are grouped greedily into bands: a band keeps growing while the
-- rectangle that fits in every row of it (intersection of the rows' top and bottom edges, so it never leaves the shape) is
-- at most `tol` narrower than the shape on either side in any row, and has the same number of parts. Each part of a band
-- with at least 6 px width becomes a piece. What is left of the shape (the crescents between the pieces and the outline) is
-- returned as quadrilaterals with horizontal top and bottom on whole-pixel rows, so two of them that meet leave no seam; their
-- slanted or curved sides follow the true outline (the sides are split where a straight line would stray more than half a
-- pixel), so the edge of the shape is smooth instead of a staircase of pixel rows.
Bg.MAXH = 400
function Bg.plan_region(rowfn, y_from, y_to, hs, tol)
  local rows = {}
  for y = y_from, y_to - 1, hs do
    local h = math.min(hs, y_to - y)
    rows[#rows + 1] = { y = y, h = h, mid = rowfn(y + h / 2), cons = intersect_lists(rowfn(y), rowfn(y + h)) }
  end
  local pieces, spans = {}, {}
  local i = 1
  while i <= #rows do
    local r = rows[i]
    if #r.cons == 0 then
      if #r.mid > 0 then                              -- a run of rows where the shape exists but no piece fits: all flat fill
        local k, j = #r.mid, i
        while j < #rows and #rows[j + 1].cons == 0 and #rows[j + 1].mid == k do j = j + 1 end
        spans[#spans + 1] = { y0 = rows[i].y, y1 = rows[j].y + rows[j].h, tiles = {} }
        i = j + 1
      else
        i = i + 1
      end
    else
      local k = #r.cons
      local inl, inh = {}, {}
      for q = 1, k do inl[q], inh[q] = r.cons[q][1], r.cons[q][2] end
      local j = i
      while j < #rows and #rows[j + 1].cons == k and rows[j + 1].y + rows[j + 1].h - rows[i].y <= Bg.MAXH do
        local nr, nl, nh, ok = rows[j + 1], {}, {}, true
        for q = 1, k do
          nl[q], nh[q] = math.max(inl[q], nr.cons[q][1]), math.min(inh[q], nr.cons[q][2])
          if nh[q] - nl[q] < 6 then ok = false end
        end
        if ok then
          for t = i, j + 1 do
            local m = rows[t].mid
            if #m ~= k then ok = false; break end
            for q = 1, k do
              if nl[q] - m[q][1] > tol or m[q][2] - nh[q] > tol then ok = false end
            end
            if not ok then break end
          end
        end
        if not ok then break end
        inl, inh, j = nl, nh, j + 1
      end
      local tiles, y0, y1 = {}, rows[i].y, rows[j].y + rows[j].h
      for q = 1, k do
        local x0, x1 = math.ceil(inl[q]), math.floor(inh[q])                 -- inward
        if x1 - x0 >= 6 then
          tiles[#tiles + 1] = { x0, x1 }
          pieces[#pieces + 1] = { x = x0, y = y0, w = x1 - x0, h = y1 - y0 }
        end
      end
      spans[#spans + 1] = { y0 = y0, y1 = y1, tiles = tiles }
      i = j + 1
    end
  end
  local quads = {}
  local function addq(lo0, hi0, ya, lo1, hi1, yb)
    if hi0 < lo0 then hi0 = lo0 end
    if hi1 < lo1 then hi1 = lo1 end
    if hi0 - lo0 < 0.05 and hi1 - lo1 < 0.05 then return end
    quads[#quads + 1] = { { lo0, ya }, { hi0, ya }, { hi1, yb }, { lo1, yb } }
  end
  local emit
  emit = function(sp, ya, yb)
    local A, B = rowfn(ya + 0.01), rowfn(yb - 0.01)
    if #A ~= #B or #A == 0 then
      if yb - ya > 1 then                             -- the shape changes its number of parts inside this span: split until it is one row
        local ym = math.floor((ya + yb) / 2)
        if ym <= ya then ym = ya + 1 end
        emit(sp, ya, ym); emit(sp, ym, yb)
        return
      end
      local M = rowfn((ya + yb) / 2)
      if #M == 0 then return end
      A, B = M, M
    end
    if yb - ya > 4 then
      local ym = math.floor((ya + yb) / 2)
      local Mi = rowfn(ym)
      if #Mi == #A and ym > ya and ym < yb then
        for q = 1, #A do
          if math.abs(Mi[q][1] - (A[q][1] + B[q][1]) / 2) > 0.5 or math.abs(Mi[q][2] - (A[q][2] + B[q][2]) / 2) > 0.5 then
            emit(sp, ya, ym); emit(sp, ym, yb)
            return
          end
        end
      end
    end
    for q = 1, #A do
      local inside = {}                                -- the pieces that sit in this part of the shape, left to right
      for _, t in ipairs(sp.tiles) do
        local c = (t[1] + t[2]) / 2
        if c > A[q][1] and c < A[q][2] and c > B[q][1] and c < B[q][2] then inside[#inside + 1] = t end
      end
      if #inside == 0 then
        addq(A[q][1], A[q][2], ya, B[q][1], B[q][2], yb)                  -- no piece in this part: all of it
      else
        addq(A[q][1], inside[1][1], ya, B[q][1], inside[1][1], yb)        -- left of the first piece
        for m = 1, #inside - 1 do                                         -- between two pieces of the same part
          addq(inside[m][2], inside[m + 1][1], ya, inside[m][2], inside[m + 1][1], yb)
        end
        local last = inside[#inside]
        addq(last[2], A[q][2], ya, last[2], B[q][2], yb)                  -- right of the last piece
      end
    end
  end
  for _, sp in ipairs(spans) do emit(sp, sp.y0, sp.y1) end
  return pieces, quads
end
-- One slice as strips turned to its middle axis. Frame: x runs outward along the axis, t across it (right = clockwise).
-- A strip is a rectangle x in [xa, xb], t in [-w, w] that lies inside the slice (w = what the radial edges and the outer circle
-- allow). What the strips leave over is returned as trapezoids - columns of that frame - for the flat fill. The fill overlaps the
-- strips and its own neighbours by about half a pixel, so no seams show.
function Bg.plan_slice(cx, cy, r0, R, ac, h, K, outer)
  local ux, uy, vx, vy = math.sin(ac), -math.cos(ac), math.cos(ac), math.sin(ac)
  local th = math.tan(h)
  local function P(x, t) return { cx + ux * x + vx * t, cy + uy * x + vy * t } end
  local function Y(x)                                   -- half the width of the slice at distance x along the axis
    local a, q = x * th, R * R - x * x
    local b = q > 0 and math.sqrt(q) or 0
    return a < b and a or b
  end
  local function Yin(x) if x >= r0 then return 0 end return math.sqrt(r0 * r0 - x * x) end   -- the hole of the inner circle
  local pieces, bands = {}, {}
  local x_lo, x_hi = r0 + 0.5, R * (outer or 0.97)
  if x_hi - x_lo >= 12 then
    for i = 1, K do
      local xa, xb = x_lo + (x_hi - x_lo) * (i - 1) / K, x_lo + (x_hi - x_lo) * i / K
      local qb = R * R - xb * xb
      local w = math.min(xa * th, qb > 0 and math.sqrt(qb) or 0) - 0.5
      if w >= 3 then
        local xe = xb + 1.2                              -- a little over its outer neighbour: no hairline between strips
        local tl = P(xe, -w)                             -- the corner the control turns around: outer end, one side
        local W, H = 2 * w, xe - xa
        local ex, ey, fx, fy = vx * W, vy * W, -ux * H, -uy * H     -- the control's x axis (across) and y axis (inward)
        local mx, my = tl[1] + (ex + fx) / 2, tl[2] + (ey + fy) / 2                 -- the strip's centre
        local px, py = tl[1], tl[2]                                                -- where the control is placed (its Position)
        if cfg.bg_pivot_center then px, py = mx - W / 2, my - H / 2 end            -- turning around the centre: the centre stays put
        pieces[#pieces + 1] = { x = px, y = py, w = W, h = H, rot = ac, cx = mx, cy = my,
          corners = { tl, { tl[1] + ex, tl[2] + ey }, { tl[1] + ex + fx, tl[2] + ey + fy }, { tl[1] + fx, tl[2] + fy } } }
        -- the flat fill overlaps the strip by 1.5 px along its sides: the edges of a turned control are not anti-aliased
        bands[#bands + 1] = { xa + (i == 1 and 1.2 or 0), xb, w - 1.5 }
      end
    end
  end
  -- column edges: the strips' ends, and the two circles sampled by angle (a chord is only a hair off the arc that way)
  local xs = { r0, R * math.cos(h) }
  for _, b in ipairs(bands) do xs[#xs + 1] = b[1]; xs[#xs + 1] = b[2] end
  for i = 0, 8 do xs[#xs + 1] = r0 * math.cos(h * (1 - i / 8)) end
  local m = math.max(4, math.ceil(h / 0.05))
  for i = 0, m do xs[#xs + 1] = R * math.cos(h * (1 - i / m)) end
  table.sort(xs)
  local quads = {}
  local xmin = xs[1]
  local function emit(xa, xb, wex)
    xa = math.max(xa - 0.7, xmin)                        -- overlaps the column before it (not the one after: the circles are steep there)
    local xe = xb
    local loa, lob = math.max(wex, Yin(xa)), math.max(wex, Yin(xe))
    local hia, hib = Y(xa), Y(xe)
    if hia - loa <= 0.05 and hib - lob <= 0.05 then return end
    if hia < loa then hia = loa end
    if hib < lob then hib = lob end
    if loa <= 0.05 and lob <= 0.05 then                  -- no strip and no hole here: one piece across the whole width
      quads[#quads + 1] = { P(xa, -hia), P(xa, hia), P(xe, hib), P(xe, -hib) }
    else
      quads[#quads + 1] = { P(xa, loa), P(xa, hia), P(xe, hib), P(xe, lob) }
      quads[#quads + 1] = { P(xa, -loa), P(xa, -hia), P(xe, -hib), P(xe, -lob) }
    end
  end
  local prev = nil
  local function column(x)
    local xm, wex = (prev + x) / 2, 0
    for _, b in ipairs(bands) do if xm >= b[1] and xm <= b[2] then wex = b[3]; break end end
    emit(prev, x, wex)
  end
  for _, x in ipairs(xs) do
    if x > R + 0.01 then break end
    if prev == nil then prev = x
    elseif x - prev > 0.6 then column(x); prev = x end    -- columns narrower than that add polygons, not accuracy
  end
  if prev and R - prev > 0.05 then column(R) end
  return pieces, quads
end
-- One slice as five big rectangles, the layout that was drawn by hand in the slice editor: a centre rectangle over the whole radial
-- thickness (as wide as the slice is at its inner end), two caps on top of it that fill the crescent under the outer arc, and
-- two strips that lie along the radial edges and reach over the centre rectangle. Nothing is cut exactly: a rectangle may reach
-- `tau` px past the outline, the thick border drawn over the slice hides that, and no flat fill is needed. The pieces overlap
-- freely (they all show the same texture). Everything is measured from the radii, so it fits any wheel size and slice count.
function Bg.plan_blocks(cx, cy, r0, R, ac, h, caps)
  local th, ch, sh = math.tan(h), math.cos(h), math.sin(h)
  local tau = math.max(2, 0.0125 * R)
  local ux, uy, vx, vy = math.sin(ac), -math.cos(ac), math.cos(ac), math.sin(ac)
  local pieces = {}
  -- centre (x, t) in the slice frame (x outward, t across, clockwise), W across and H along x when rot = 0, rot in degrees
  local function rect(x, t, W, H, rotdeg)
    local ang = ac + math.rad(rotdeg)
    local cxp, cyp = cx + ux * x + vx * t, cy + uy * x + vy * t
    local ca, sa = math.cos(ang), math.sin(ang)
    local ex, ey, fx, fy = ca * W / 2, sa * W / 2, -sa * H / 2, ca * H / 2
    local tl = { cxp - ex - fx, cyp - ey - fy }                  -- the corner the control turns around
    local px, py = tl[1], tl[2]
    if cfg.bg_pivot_center then px, py = cxp - W / 2, cyp - H / 2 end
    pieces[#pieces + 1] = { x = px, y = py, w = W, h = H, rot = ang, cx = cxp, cy = cyp,
      corners = { tl, { cxp + ex - fx, cyp + ey - fy }, { cxp + ex + fx, cyp + ey + fy }, { cxp - ex + fx, cyp - ey + fy } } }
  end
  local xa = r0 - tau * 0.5
  local wc = xa * th                                            -- exactly as wide as the slice: no overshoot into the gap beside it
  local Ro = R + tau * 0.5
  local xb = math.sqrt(math.max(Ro * Ro - wc * wc, 0))
  rect((xa + xb) / 2, 0, 2 * wc, xb - xa, 0)
  for _, f in ipairs(caps and { 0.5, 0.82 } or {}) do
    local wk = wc * f
    local xt = math.sqrt(math.max(Ro * Ro - wk * wk, 0))
    local x0 = xb - tau * 2
    if xt - x0 > 3 then rect((x0 + xt) / 2, 0, 2 * wk, xt - x0, 0) end
  end
  local gap = (xb * th - wc) * ch                                -- how far the edge is from the centre rectangle at its top
  local wE = math.max(gap + 1.5 * tau, 4)
  local da, db = r0 - tau * 0.5, math.sqrt(math.max(Ro * Ro - wE * wE, 0))
  local dc = (da + db) / 2
  for side = -1, 1, 2 do                                         -- -1: the edge on the left (t < 0), 1: on the right
    local ex_, et_ = dc * ch, side * dc * sh                     -- the point of the edge at the middle of the strip
    rect(ex_ + sh * wE / 2, et_ - side * ch * wE / 2, wE, db - da, side * math.deg(h))
  end
  return pieces
end
-- all the groups of the layout: one per slice plus the disc, or a single ring plus the disc
function Bg.plan_all(sw, sh, s, tol, hs, n, cap)
  local cx, cy = sw / 2, sh / 2
  local r_in, r_out, Rc = Bg.radii(s)
  local groups, list = {}, {}
  local function add(kind, i, pieces, quads)
    local g = { kind = kind, i = i, pieces = pieces, quads = quads, dx = 0, dy = 0 }
    groups[#groups + 1] = g
    for _, p in ipairs(pieces) do p.g = #groups; list[#list + 1] = p; p.idx = #list end
  end
  if n >= 2 then
    local step, gap = TAU / n, math.rad(cfg.slice_gap_deg)
    local dp, dq = {}, {}                                         -- the centre disc: a few upright pieces, the rest flat
    if Rc > 0 then dp, dq = Bg.plan_region(Bg.disc_rowfn(cx, cy, Rc), math.floor(cy - Rc), math.ceil(cy + Rc), hs, Rc * 0.12) end            -- about a dozen pieces: nine tenths of the disc is texture
    local K = math.max(2, math.min(16, math.floor(((cap or 64) - #dp) / n)))   -- strips per slice: what the piece limit leaves
    local half = (step - gap) / 2
    local per = math.floor(((cap or 64) - #dp) / n)               -- pieces per slice the limit leaves
    -- the fan is laid in rings when the piece limit allows: every ring is an annular sector of its own (same shape ratio, so the
    -- same share of texture), which makes the strips follow the curved edges instead of leaving a wide flat crescent at each arc
    local M = K >= 9 and 3 or (K >= 4 and 2 or 1)
    local N = math.max(M == 1 and 3 or 2, math.min(8, math.floor(K / M)))      -- strips per ring
    for i = 1, n do
      local ac = (i - 1) * step
      if cfg.bg_blocks and per >= 3 then
        -- The block layout fits a narrow slice almost exactly, but leaves more of a wide one uncovered (the fewer the slices, the
        -- wider each). A wide slice is therefore laid out as m narrow ones side by side, as many as the piece limit allows.
        local m = math.max(1, math.min(math.ceil(half / 0.32), math.floor(per / 3)))
        local sub, ps = half / m, math.floor(per / m)
        local pieces = {}
        for j = 1, m do
          for _, p in ipairs(Bg.plan_blocks(cx, cy, r_in, r_out, ac - half + (2 * j - 1) * sub, sub, ps >= 5 and sub > 0.42)) do
            pieces[#pieces + 1] = p
          end
        end
        add("slice", i, pieces, {})
      elseif cfg.bg_fan then
        -- a single row of strips, side by side across the slice, each running from the inner to the outer arc: the slice is split
        -- into N equal wedges and every wedge gets one strip turned to its own middle axis (as wide as the wedge is at the inner arc)
        local pieces, quads = {}, {}
        local q = (r_out / r_in) ^ (1 / M)
        for m = 1, M do
          local ra = r_in * q ^ (m - 1)
          local rb = (m == M) and r_out or (r_in * q ^ m + 0.7)       -- a ring reaches 0.7 px into the next: no seam between rings
          for j = 1, N do
            local pp, qq = Bg.plan_slice(cx, cy, ra, rb, ac - half + (2 * j - 1) * half / N, half / N, 1, 0.99)
            for _, x in ipairs(pp) do pieces[#pieces + 1] = x end
            for _, x in ipairs(qq) do quads[#quads + 1] = x end
          end
        end
        add("slice", i, pieces, quads)
      else
        local pieces, quads = Bg.plan_slice(cx, cy, r_in, r_out, ac, half, K)
        add("slice", i, pieces, quads)
      end
    end
    if Rc > 0 then add("disc", 0, dp, dq) end
  else
    local pieces, quads = Bg.plan_region(Bg.ring_rowfn(cx, cy, r_in, r_out, Rc), math.floor(cy - r_out), math.ceil(cy + r_out), hs, tol)
    add("ring", 0, pieces, quads)
  end
  return groups, list
end
function Bg.key_now(sw, sh, s)
  local m = Bg.keymemo
  if m and m.frame == frame and m.sw == sw and m.sh == sh and m.s == s then return m.key end     -- asked twice per frame
  local n = Bg.mode_n()
  if n < 2 then n = 0 end
  local key = string.format("%d|%d|%.3f|%d|%d|%d|%d/%d|%d|%.2f|%d|%.0f,%.0f,%.0f,%.0f", sw, sh, s, cfg.wheel_radius, cfg.inner_radius, cfg.center_radius, cfg.bg_tol, cfg.bg_max,
    n, n >= 2 and cfg.slice_gap_deg or 0, (cfg.bg_rot_flip and 1 or 0) + (cfg.bg_pivot_center and 2 or 0) + (cfg.bg_fan and 4 or 0) + (cfg.bg_blocks and 8 or 0),
    Geo.x, Geo.y, Geo.w, Geo.h)
  Bg.keymemo = { frame = frame, sw = sw, sh = sh, s = s, key = key }
  return key
end
function Bg.begin(sw, sh, s)
  local hs = math.max(3, math.floor(3 * s + 0.5))                   -- row height of the planning grid (the staircase is as fine as the screen)
  local n = Bg.mode_n()
  if n < 2 then n = 0 end
  Bg.slice_mode = n >= 2
  local tol = math.max(3, cfg.bg_tol) * s
  local cap = cfg.bg_max
  local groups, list = Bg.plan_all(sw, sh, s, tol, hs, n, cap)
  if #list > cap then
    -- the smallest tolerance whose piece count still fits the limit (bisection), so that the whole budget of GUI copies is
    -- used and the flat crescents come out as thin as the limit allows
    local lo, hi = tol, tol
    local hg, hl
    for _ = 1, 40 do                                -- a bracket: hi fits, lo (the wanted tolerance) does not
      hi = hi * 1.5
      hg, hl = Bg.plan_all(sw, sh, s, hi, hs, n, cap)
      if #hl <= cap or hi > 300 * s then break end
      lo = hi
    end
    for _ = 1, 7 do
      local mid = (lo + hi) / 2
      local mg, ml = Bg.plan_all(sw, sh, s, mid, hs, n, cap)
      if #ml <= cap then hi, hg, hl = mid, mg, ml else lo = mid end
    end
    tol, groups, list = hi, hg, hl
  end
  Bg.groups, Bg.list = groups, list
  Bg.next_i, Bg.key, Bg.done_key, Bg.sw, Bg.sh, Bg.s, Bg.n = 1, Bg.key_now(sw, sh, s), nil, sw, sh, s, n
  Bg.last_begin = frame
  local fills = 0
  for _, g in ipairs(groups) do fills = fills + #g.quads end
  Bg.note(string.format("layout: %s, %s, %d pieces, flat-fill crescents up to %.0f px, %d fill polygons",
    Bg.slice_mode and (n .. (cfg.bg_blocks and " slices of rectangle blocks + centre disc" or (cfg.bg_fan and " slices of fanned strips + centre disc" or " slices of rows + centre disc"))) or "ring + centre disc", "GUI-copy mode", #list, tol, fills))
end

-- ---------------------------------------------------------------------------------------------
-- writing a piece
-- ---------------------------------------------------------------------------------------------
local POS_SET = {
  function(t, x, y) local p = Bg.pos_tpl; p.x = x; p.y = y; t:call("set_Position", p) end,
  function(t, x, y) t:call("set_Position", Vector3f.new(x, y, 0)) end,
  function(t, x, y) t:call("set_Position", Vector2f.new(x, y)) end,
}
local SIZE_SET = {
  function(t, w, h) local z = Bg.size_tpl; z.w = w; z.h = h; t:call("set_Size", z) end,
  function(t, w, h) local z = Bg.size_tpl; z.x = w; z.y = h; t:call("set_Size", z) end,
  function(t, w, h) t:call("set_Size", Vector2f.new(w, h)) end,
}
local function close(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < 0.6 end
-- the first piece decides which way of writing Position / Size works, by reading the values back
function Bg.pick_modes(t, g)
  Bg.pos_mode, Bg.size_mode = nil, nil
  for i, f in ipairs(POS_SET) do
    if pcall(f, t, g.x, g.y) then
      local x, y = pair_of(mcall(t, "get_Position"), "x", "y")
      if close(x, g.x) and close(y, g.y) then Bg.pos_mode = i; break end
    end
  end
  for i, f in ipairs(SIZE_SET) do
    if pcall(f, t, g.w, g.h) then
      local w, h = pair_of(mcall(t, "get_Size"), "w", "h")
      if close(w, g.w) and close(h, g.h) then Bg.size_mode = i; break end
    end
  end
  Bg.note(string.format("position write mode %s, size write mode %s", tostring(Bg.pos_mode), tostring(Bg.size_mode)))
  if not Bg.pos_mode or not Bg.size_mode then
    Bg.fail(string.format("could not write Position/Size (wanted %.1f,%.1f %.1fx%.1f)", g.x, g.y, g.w, g.h))
    return false
  end
  Bg.modes = true
  return true
end
-- where the control's parent sits in GUI space (global minus local position)
function Bg.origin(t)
  local gx, gy = pair_of(mcall(t, "get_GlobalPosition"), "x", "y")
  local px, py = pair_of(mcall(t, "get_Position"), "x", "y")
  local G = Bg.gain
  if gx and gy and px and py then return gx - px * G[1], gy - py * G[2] end
  return 0, 0
end
-- How far the control moves on screen (in GUI units) for one unit of its own position: 1 when no parent is scaled. Measured with two
-- test moves, so a GUI whose parents are scaled (a canvas that is stretched to a wide screen) still lands where it is put.
Bg.gain = { 1, 1 }
function Bg.measure_gain(t)
  local function glob() return pair_of(mcall(t, "get_GlobalPosition"), "x", "y") end
  local ok = pcall(POS_SET[Bg.pos_mode], t, 0, 0)
  local x0, y0 = glob()
  ok = ok and pcall(POS_SET[Bg.pos_mode], t, 100, 100)
  local x1, y1 = glob()
  if ok and x0 and x1 and y0 and y1 then
    local gx, gy = (x1 - x0) / 100, (y1 - y0) / 100
    if gx > 0.05 and gx < 20 and gy > 0.05 and gy < 20 then
      Bg.gain = { gx, gy }
      Bg.note(string.format("chain gain %.3f / %.3f (screen move per unit of the control's own position)", gx, gy))
      return
    end
  end
  Bg.note(string.format("chain gain could not be measured (global %s,%s -> %s,%s), using 1", tostring(x0), tostring(y0), tostring(x1), tostring(y1)))
end
-- a piece's Rotation: DEGREES (a radian value showed up as a turn of a degree or two), around its top-left corner = its Position
function Bg.set_rot(t, ang)
  local ok = pcall(function()
    local cur = t:call("get_Rotation")
    cur.z = ang
    t:call("set_Rotation", cur)
  end)
  if not ok then pcall(function() t:call("set_Rotation", Vector3f.new(0, 0, ang)) end) end
end
function Bg.rect_of(p, g)
  return { x = p.x + g.dx, y = p.y + g.dy, w = p.w, h = p.h, rot = p.rot, cx = p.cx and (p.cx + g.dx), cy = p.cy and (p.cy + g.dy) }
end
function Bg.set_tile(t, r, k, ox, oy)
  oy = oy or 0
  if not Bg.modes then
    if not Bg.pick_modes(t, { x = 10, y = 10, w = 20, h = 20 }) then return false end
    Bg.measure_gain(t)
  end
  local ax, ay, w, h = (r.x - ox) / k, (r.y - oy) / k, r.w / k, r.h / k      -- the piece in GUI units
  local o = Bg.org[t]                                                    -- read before the first rotation, then kept
  if not o then o = { Bg.origin(t) }; Bg.org[t] = o end
  local ofx, ofy = o[1], o[2]
  local G = Bg.gain
  local gax, gay = 960 + (ax - 960) * G[1], 540 + (ay - 540) * G[2]   -- the global point (see Ico.place)
  local g = { x = (gax - ofx) / G[1], y = (gay - ofy) / G[2], w = w, h = h }   -- in the control's own units (+ the manual shift; the UV part stays true)
  local ok1 = pcall(POS_SET[Bg.pos_mode], t, g.x, g.y)
  local ok2 = pcall(SIZE_SET[Bg.size_mode], t, g.w, g.h)
  Bg.set_rot(t, r.rot and ((cfg.bg_rot_flip and -1 or 1) * math.deg(r.rot)) or 0)
  local uvx, uvy = ax, ay                                                -- which part of the texture the piece shows
  if r.rot then uvx, uvy = (r.cx - ox) / k - w / 2, (r.cy - oy) / k - h / 2 end  -- a turned strip: the upright rectangle round its centre
  local u, v = (uvx - Bg.TEX_X) / Bg.TEX_W, uvy / Bg.TEX_H
  u, v = math.max(0, math.min(1, u)), math.max(0, math.min(1, v))
  local uw, vh = math.max(0, math.min(1 - u, w / Bg.TEX_W)), math.max(0, math.min(1 - v, h / Bg.TEX_H))
  local ok3 = pcall(function()
    t:call("set_UVU", u); t:call("set_UVV", v); t:call("set_UVW", uw); t:call("set_UVH", vh)
  end)
  if not (ok1 and ok2 and ok3) then
    Bg.fail(string.format("a piece write failed (pos %s, size %s, uv %s)", tostring(ok1), tostring(ok2), tostring(ok3)))
    return false
  end
  if Bg.checked < 3 then                                                  -- the first pieces: read everything back
    Bg.checked = Bg.checked + 1
    local rgx, rgy = pair_of(mcall(t, "get_GlobalPosition"), "x", "y")
    local rw, rh = pair_of(mcall(t, "get_Size"), "w", "h")
    Bg.note(string.format("piece %d: wanted gui %.1f,%.1f %.1fx%.1f uv %.3f,%.3f %.3fx%.3f | read back global %s,%s size %sx%s uvType=%s uvw=%s controlPoint=%s",
      Bg.checked, ax, ay, w, h, u, v, uw, vh, tostring(rgx), tostring(rgy), tostring(rw), tostring(rh), tostring(mcall(t, "get_UVType")),
      tostring(mcall(t, "get_UVW")), tostring(mcall(t, "get_ControlPoint"))))
    local egx, egy = ofx + G[1] * g.x, ofy + G[2] * g.y            -- where the chain model says the global position ends up
    if not r.rot and not (rgx and math.abs(rgx - egx) < 2 and math.abs(rgy - egy) < 2) then
      Bg.fail(string.format("a piece did not end up where the chain model puts it: expected global %.1f,%.1f, read %s,%s (chain gain %.3f/%.3f)", egx, egy, tostring(rgx), tostring(rgy), G[1], G[2]))
      return false
    end
    local ruw = mcall(t, "get_UVW")
    if type(ruw) == "number" and math.abs(ruw - uw) > 0.01 then Bg.fail("the UV rectangle did not stick (UVType is not the normalised mode?)"); return false end
  end
  return true
end
function Bg.apply_some()
  if Bg.broken or not Bg.list or Bg.done_key then return end
  local k = Wide.k()
  local ox = Wide.ox()
  local t0, n = os.clock(), #Bg.list
  while Bg.next_i <= n do
    local i = Bg.next_i
    local t = Bg.ctls[i]
    if not t then return end                      -- waits for the copy to be made
    local p = Bg.list[i]
    local g = Bg.groups[p.g]
    if not Bg.set_tile(t, Bg.rect_of(p, g), k, ox, Geo.y) then return end
    pcall(function() t:call("set_ForceInvisible", not Bg.shown) end)              -- visible only while the wheel is up
    Bg.thid[i] = nil
    Bg.next_i = i + 1
    if os.clock() - t0 > Bg.BUDGET then return end
  end
  for i = n + 1, #Bg.ctls do                      -- pieces left over from a bigger layout
    if not Bg.thid[i] then pcall(function() Bg.ctls[i]:call("set_ForceInvisible", true) end); Bg.thid[i] = true end
  end
  Bg.count = n
  Bg.done_key = Bg.key
  Bg.note(string.format("%d pieces ready, %d GUI copies (%.1f s after the script started)", n, #Bg.cells, os.clock() - Bg.t0))
end

-- Making the copies. Spawning one is cheap, but its view only exists a few frames later (the first one waits for the asset), so up
-- to Bg.LOOK copies are spawned ahead and wait together, and every frame all the ones whose view is there are trimmed, within the
-- time budget. (One copy at a time, each waiting several frames for its view, took many seconds for all of them.)
function Bg.pump(need)
  local t0 = os.clock()
  while #Bg.cells + #Bg.queue < need and #Bg.queue < Bg.LOOK and frame >= Bg.retry_at and os.clock() - t0 < Bg.BUDGET do
    local ok, p, err = pcall(Bg.spawn)
    if ok and p then
      p.next_try = frame + 1
      Bg.queue[#Bg.queue + 1] = p
    else
      Bg.dead = Bg.dead + 1
      Bg.retry_at = frame + 30
      Bg.note("spawn failed: " .. tostring(ok and err or p))
      break
    end
  end
  local i = 1
  while i <= #Bg.queue and os.clock() - t0 < Bg.BUDGET do
    local p = Bg.queue[i]
    if frame >= p.next_try then
      local ok, done = pcall(Bg.finish, p)
      if not ok then Bg.note("finish error: " .. tostring(done)) end
      if ok and done then
        table.remove(Bg.queue, i)
      else
        -- Drawing is only switched on for the oldest copy when it still has no view after a while: a copy that draws before it is
        -- trimmed shows the whole menu GUI, and while its textures are missing the game prints "texture ... not found".
        if i == 1 and #Bg.cells == 0 and frame - p.born > 150 and not p.drawing then
          p.drawing = true
          pcall(function() p.go:call("set_DrawSelf", true) end)
          Bg.note("no view yet with drawing off - letting the copy draw while it loads")
        end
        if frame - p.born > 900 then
          Ico.kill(p.go)
          table.remove(Bg.queue, i)
          Bg.dead = Bg.dead + 1
          Bg.retry_at = frame + 60
          Bg.note("a GUI copy never showed tex_ - trying again")
        else
          p.next_try = frame + 1
          i = i + 1
        end
      end
    else
      i = i + 1
    end
  end
  Bg.pending = Bg.queue[1]
end

-- per frame (wheel closed): plan the layout, make the missing copies within a time budget, place the pieces; hide all when it closes
function Bg.tick()
  if not cfg.game_bg then
    if Bg.shown then Bg.set_hidden(true) end
    Bg.on = false
    return
  end
  pcall(Bg.prefetch)
  local open = W.open or W.pinned
  if not open and Bg.shown then Bg.set_hidden(true) end
  if Bg.broken then return end
  local sw, sh = screen_size()
  local s = cfg.scale * SCALE_BASE * (cfg.auto_scale and (Geo.get().h / 1080) or 1)
  if Bg.key ~= Bg.key_now(sw, sh, s) and (Bg.last_begin == nil or frame - Bg.last_begin >= 6) then Bg.begin(sw, sh, s) end
  local need = Bg.list and #Bg.list or 0
  if #Bg.cells < need and not open and P.char and not is_loading() and Bg.dead < 12 then
    Bg.pump(need)
  end
  local ok, err = pcall(Bg.apply_some)
  if not ok then Bg.fail("apply error: " .. tostring(err)) end
end
-- a slice that is pushed out when hovered takes its pieces with it (whole pixels, so pieces and fill keep matching)
function Bg.place_group(gi)
  local g = Bg.groups[gi]
  local k = Wide.k()
  local ox = Wide.ox()
  for _, p in ipairs(g.pieces) do
    local t = Bg.ctls[p.idx]
    if t then Bg.set_tile(t, Bg.rect_of(p, g), k, ox, Geo.y) end
  end
end
function Bg.sync_hover(items, cx, cy)
  if not (Bg.slice_mode and Bg.done_key and Bg.groups) then return end
  for gi, g in ipairs(Bg.groups) do
    if g.kind == "slice" then
      local it = items[g.i]
      if it then
        local dx, dy = math.floor(it.ox - cx + 0.5), math.floor(it.oy - cy + 0.5)
        if dx ~= g.dx or dy ~= g.dy then g.dx, g.dy = dx, dy; Bg.place_group(gi) end
      end
    end
  end
end
-- from render_wheel: true when the background can stand in for the dark fills
function Bg.update(sw, sh, s)
  Bg.on, Bg.tail = false, 0
  if not cfg.game_bg or Bg.broken or not Bg.list then Bg.on_age = 0; return false end
  if Bg.done_key ~= Bg.key_now(sw, sh, s) then Bg.on_age = 0; return false end
  if not Bg.shown then Bg.set_hidden(false) end
  Bg.on = true
  Bg.on_age = Bg.on_age + 1
  return true
end
-- The pieces are GUI controls: a change to them shows up a few frames after the overlay (which is drawn at once). For the first
-- frames after the wheel opens, and for the same number of frames after it closes, the overlay therefore covers the pieces with the
-- flat fill (the pieces plus the crescents = the whole shape) instead of letting bare rectangles show.
function Bg.covering() return Bg.on and Bg.on_age <= (cfg.bg_cover_frames or 0) end
function Bg.fill_pieces(c)
  for _, p in ipairs(Bg.list or {}) do
    local g = Bg.groups and Bg.groups[p.g]
    local dx, dy = g and g.dx or 0, g and g.dy or 0
    if p.corners then
      local q = {}
      for i, pt in ipairs(p.corners) do q[i] = { pt[1] + dx, pt[2] + dy } end
      poly(q, c)
    else
      Ico.rect(p.x + dx, p.y + dy, p.w, p.h, c)
    end
  end
end
-- The screen dimmer for the background mode: a thick circle stroke from the wheel's outer edge to beyond the screen corners,
-- one for the gap between the disc and the slices, and a thin quad for each gap between two slices, so the world shows
-- through all of them dimmed like the rest of the screen. A handful of draw calls, smooth edges.
function Bg.dim(sw, sh, c)
  local cx, cy = sw / 2, sh / 2
  local r_in, r_out, Rc = Bg.radii(Bg.s)
  local far = math.sqrt(cx * cx + cy * cy) + 4
  local col = abgr(c)
  -- The dim outside the wheel is a thick circle stroke. A game icon that reaches past the wheel's outer edge (a hovered slice that
  -- grew, an icon moved by the offset) lies under the overlay and would be dimmed by it: then the dim is drawn as rows around the
  -- icons' holes instead.
  local holes_out = false
  for _, hl in ipairs(Ico.holes) do
    local ddx, ddy = hl.x - cx, hl.y - cy
    if math.sqrt(ddx * ddx + ddy * ddy) + hl.r + hl.w * 0.5 > r_out - 1 then holes_out = true; break end
  end
  if holes_out then
    local saved, h2 = Ico.holes, {}
    for i, hl in ipairs(saved) do h2[i] = hl end
    h2[#h2 + 1] = { x = cx, y = cy, r = r_out, w = 0 }
    Ico.holes = h2
    pcall(Ico.fill_rect_holes, 0, 0, sw, sh, c)
    Ico.holes = saved
  end
  local ok = R.dl ~= nil and pcall(function()
    if not holes_out then R.dl:add_circle(v2(cx, cy), (r_out + far) / 2, col, 128, far - r_out) end
    if r_in - Rc > 1 then R.dl:add_circle(v2(cx, cy), (Rc + r_in) / 2, col, 96, r_in - Rc) end
  end)
  if not ok then Bg.note_once("dimfail", "the thick circle stroke for the dimmer failed: the screen is not dimmed in background mode") end
  if Bg.slice_mode and Bg.n >= 2 and cfg.slice_gap_deg > 0.05 then
    local step, gap = TAU / Bg.n, math.rad(cfg.slice_gap_deg)
    for i = 1, Bg.n do
      local mid = (i - 1) * step + step / 2
      local x1, y1 = polar(cx, cy, r_in, mid - gap / 2)
      local x2, y2 = polar(cx, cy, r_out, mid - gap / 2)
      local x3, y3 = polar(cx, cy, r_out, mid + gap / 2)
      local x4, y4 = polar(cx, cy, r_in, mid + gap / 2)
      poly({ { x1, y1 }, { x2, y2 }, { x3, y3 }, { x4, y4 } }, c)
    end
  end
end
-- the flat fill for the crescents the pieces do not reach (the icons sit well inside the pieces)
function Bg.fill_slivers(c)
  local a = cfg.bg_grain
  for _, g in ipairs(Bg.groups or {}) do
    local moved = g.dx ~= 0 or g.dy ~= 0
    for _, q in ipairs(g.quads) do
      local col = c
      if a > 0 then                                   -- a fixed pseudo-random brightness per polygon (off by default)
        local v = math.sin(q[1][1] * 12.9898 + q[1][2] * 78.233) * 43758.5453
        local j = ((v - math.floor(v)) * 2 - 1) * a
        col = { c[1] + j, c[2] + j * 0.95, c[3] + j * 0.95, c[4] }
      end
      if moved then
        poly({ { q[1][1] + g.dx, q[1][2] + g.dy }, { q[2][1] + g.dx, q[2][2] + g.dy }, { q[3][1] + g.dx, q[3][2] + g.dy }, { q[4][1] + g.dx, q[4][2] + g.dy } }, col)
      else
        poly(q, col)
      end
    end
  end
end
-- A ring sector (a slice) as horizontal pixel rows: each row is the intersection of two half-planes (the sector's radial
-- edges) with the outer circle, minus the inner circle. Rows are plain rectangles, so a translucent tint has no seams (cells
-- made of anti-aliased polygons show their joins as lines). Icon holes are cut out. The staircase at the radial edges is
-- covered by the slice's outline.
local function sector_rows(fr, ox, oy, r0, r1, a0, a1, c)
  local step = 1                                    -- one pixel rows: the slanted sides and the arcs have no visible stairs
  local s0, c0, s1, c1 = math.sin(a0), math.cos(a0), math.sin(a1), math.cos(a1)
  for y = math.floor(oy - r1), math.ceil(oy + r1) - 1, step do
    local dy = (y + step / 2) - oy
    if math.abs(dy) < r1 then
      local lo, hi = -math.huge, math.huge
      local function lim(A, B)                                  -- A * dx >= B
        if A > 1e-9 then lo = math.max(lo, B / A)
        elseif A < -1e-9 then hi = math.min(hi, B / A)
        elseif B > 0 then lo, hi = 1, 0 end
      end
      lim(c0, -dy * s0)
      lim(-c1, dy * s1)
      local w1 = math.sqrt(r1 * r1 - dy * dy)
      lo, hi = math.max(lo, -w1), math.min(hi, w1)
      if hi - lo > 0.5 then
        if math.abs(dy) < r0 then
          local w0 = math.sqrt(r0 * r0 - dy * dy)
          if lo < -w0 then fr(ox + lo, y, math.min(hi, -w0) - lo, step, c) end
          if hi > w0 then fr(ox + math.max(lo, w0), y, hi - math.max(lo, w0), step, c) end
        else
          fr(ox + lo, y, hi - lo, step, c)
        end
      end
    end
  end
end
-- where the icon holes are (changes only when an icon moves); one string per frame
function Ico.holes_key()
  if Ico.hk_frame == frame then return Ico.hk end
  local t = {}
  for i, hl in ipairs(Ico.holes) do t[i] = string.format("%.0f,%.0f,%.0f", hl.x, hl.y, hl.r) end
  Ico.hk, Ico.hk_frame = table.concat(t, ";"), frame
  return Ico.hk
end
-- the rectangles a drawing function produces, collected instead of drawn
function Ico.collect(fn)
  local saved, rects, n = Ico.rect, {}, 0
  Ico.rect = function(x, y, w, h) n = n + 1; rects[n] = { x, y, w, h } end
  local ok = pcall(fn)
  Ico.rect = saved
  return ok and rects or nil
end
-- The cut-out rectangles of a sector are worked out once and replayed (the same shape on the next frames, the colour may change).
function Bg.fill_sector(ox, oy, r0, r1, a0, a1, c)
  Bg.sec = Bg.sec or { n = 0 }
  local key = string.format("%.2f|%.2f|%.2f|%.2f|%.4f|%.4f|", ox, oy, r0, r1, a0, a1) .. Ico.holes_key()
  local rects = Bg.sec[key]
  if not rects then
    rects = Ico.collect(function() sector_rows(Ico.fill_rect_holes, ox, oy, r0, r1, a0, a1) end)
    if not rects then sector_rows(Ico.fill_rect_holes, ox, oy, r0, r1, a0, a1, c); return end
    if Bg.sec.n > 48 then Bg.sec = { n = 0 } end
    Bg.sec[key] = rects; Bg.sec.n = Bg.sec.n + 1
  end
  local rect = Ico.rect
  for i = 1, #rects do local r = rects[i]; rect(r[1], r[2], r[3], r[4], c) end
end
-- The socket a pushed-out slice leaves behind (its old shape minus its new one), filled with the flat background colour so it looks
-- like the base the slice came out of. The rectangles are cached: they only change with the slice, the size or the screen.
function Bg.fill_minus(tag, key, fa, fb, y0, y1, c)
  Bg.vac = Bg.vac or {}
  local cache = Bg.vac[tag]
  if not cache or cache.key ~= key then
    local rects, step = {}, 4
    for y = y0, y1 - 1, step do
      local A, B = fa(y + step / 2), fb(y + step / 2)
      for _, a in ipairs(A) do
        local cur = a[1]
        for _, b in ipairs(B) do
          if b[2] > cur and b[1] < a[2] then
            if b[1] > cur then rects[#rects + 1] = { cur, y, b[1] - cur, step } end
            cur = math.max(cur, b[2])
          end
        end
        if cur < a[2] then rects[#rects + 1] = { cur, y, a[2] - cur, step } end
      end
    end
    cache = { key = key, rects = rects }
    Bg.vac[tag] = cache
  end
  for _, r in ipairs(cache.rects) do Ico.fill_rect_holes(r[1], r[2], r[3], r[4], c) end      -- the game's icons lie under the overlay: they keep their holes
end
-- The shield of a job icon (half its width at a height, in units of the icon's height, y down from the centre): the part of the
-- hole the game's icon really covers. The flat cover below is laid round it.
local SHIELD = { { -0.47, 0.38 }, { -0.40, 0.40 }, { 0.05, 0.40 }, { 0.20, 0.34 }, { 0.35, 0.20 }, { 0.50, 0.0 } }
local function shield_hw(u)
  if u < SHIELD[1][1] or u > SHIELD[#SHIELD][1] then return -1 end
  for i = 2, #SHIELD do
    local a, b = SHIELD[i - 1], SHIELD[i]
    if u <= b[1] then return a[2] + (b[2] - a[2]) * (u - a[1]) / (b[1] - a[1]) end
  end
  return -1
end
local function hover_key(cx, cy, it, r_out)
  return string.format("%d|%.2f|%.1f|%.1f|%.2f|%.2f|%.3f|%.3f|%.2f", it.i or 0, r_out, cx, cy, it.ox - cx, it.oy - cy, it.a0, it.a1, it.ro)
end
-- the old shape of a pushed-out slice minus its new one
function Bg.fill_vacated(cx, cy, it, r_out, c)
  local f0 = Bg.sector_rowfn(cx, cy, it.r_in, r_out, it.a0, it.a1)
  local f1 = Bg.sector_rowfn(it.ox, it.oy, it.r_in, it.ro, it.a0, it.a1)
  Bg.fill_minus("vac", hover_key(cx, cy, it, r_out), f0, f1, math.floor(cy - r_out), math.ceil(cy + r_out), c)
end
-- The same cover inside the icon's own hole (the ring's inside shows the world there): the part of the hole that lies in what the slice
-- grew into, without the shield itself, which is the game's icon and has to stay in front of the cover.
function Bg.fill_hole_cover(cx, cy, it, r_out, hl, c)
  local f_new = Bg.sector_rowfn(it.ox, it.oy, it.r_in, it.ro, it.a0, it.a1)
  local f_old = Bg.sector_rowfn(cx, cy, it.r_in, r_out, it.a0, it.a1)
  local H = 2 * hl.r * (cfg.icon_art_k or 1)
  local function sub(A, B)
    local out = {}
    for _, a in ipairs(A) do
      local cur = a[1]
      for _, b in ipairs(B) do
        if b[2] > cur and b[1] < a[2] then
          if b[1] > cur then out[#out + 1] = { cur, b[1] } end
          cur = math.max(cur, b[2])
        end
      end
      if cur < a[2] then out[#out + 1] = { cur, a[2] } end
    end
    return out
  end
  for y = math.floor(hl.y - hl.r), math.ceil(hl.y + hl.r) - 1 do
    local ym = y + 0.5
    local dy = ym - hl.y
    local chord2 = hl.r * hl.r - dy * dy
    if chord2 > 0 then
      local ch = math.sqrt(chord2) + 0.5
      local iv = sub(f_new(ym), f_old(ym))
      local hw = shield_hw(dy / H) * H
      for _, a in ipairs(iv) do
        local lo, hi = math.max(a[1], hl.x - ch), math.min(a[2], hl.x + ch)
        if hi > lo then
          if hw > 0 then
            if lo < hl.x - hw then Ico.rect(lo, y, math.min(hi, hl.x - hw) - lo, 1, c) end
            if hi > hl.x + hw then Ico.rect(math.max(lo, hl.x + hw), y, hi - math.max(lo, hl.x + hw), 1, c) end
          else
            Ico.rect(lo, y, hi - lo, 1, c)
          end
        end
      end
    end
  end
end
-- the new shape minus the old one: where the slice grew into and the pieces are not
function Bg.fill_grown(cx, cy, it, r_out, c)
  local f0 = Bg.sector_rowfn(cx, cy, it.r_in, r_out, it.a0, it.a1)
  local f1 = Bg.sector_rowfn(it.ox, it.oy, it.r_in, it.ro, it.a0, it.a1)
  Bg.fill_minus("grown", hover_key(cx, cy, it, r_out), f1, f0, math.floor(it.oy - it.ro), math.ceil(it.oy + it.ro), c)
end

------------------------------------------------------------------------------------------------
-- The two lines in the middle of the wheel: the vocation and the weapon
------------------------------------------------------------------------------------------------
local Center = {}
-- A name that is wider than the centre disc at its height gets a smaller font until it fits (down to about half the size);
-- a name that is still too wide at that size is cut short with "..".
function Center.fit_text(str, size, dy, r, s)
  local reach = dy + size * 0.6                                     -- the lower edge of the text decides the chord
  local chord = 2 * math.sqrt(math.max(r * r - reach * reach, 0)) - 12 * s
  if chord <= 0 or measure(str, size) <= chord then return str, size end
  local min_size = math.max(9, size * 0.5)
  local sz = size
  while sz > min_size do
    sz = math.max(min_size, sz - 1)
    if measure(str, sz) <= chord then return str, sz end
  end
  local n = utf8.len(str) or #str
  while n > 2 do
    n = n - 1
    local cut = str:sub(1, (utf8.offset(str, n + 1) or (#str + 1)) - 1) .. ".."
    if measure(cut, sz) <= chord then return cut, sz end
  end
  return str, sz
end
-- { text, x, y, size, colour } for each of the two lines
function Center.lines(cx, cy, r, s)
  local opt = W.sel and W.options[W.sel]
  if opt then
    local dy1, dy2 = r * 0.46, r * 0.46 + 20 * s
    local hj, hw = cfg.hide_center_job, cfg.hide_center_weapon
    if hj and hw then return nil, nil end
    local t1, z1 = Center.fit_text(JOBS[opt.job].name, 20 * s, dy1, r, s)
    local t2, z2 = Center.fit_text((opt.name and opt.name ~= "") and opt.name or JOBS[opt.job].weapon, 15 * s, hj and dy1 or dy2, r, s)
    if hj then return { t2, cx, cy + dy1, z2, T("text_dim") }, nil end
    if hw then return { t1, cx, cy + dy1, z1, T("accent_hi") }, nil end
    return { t1, cx, cy + dy1, z1, T("accent_hi") },
           { t2, cx, cy + dy2, z2, T("text_dim") }
  elseif #W.options == 0 then
    return { "No weapons found", cx, cy + r * 0.46, 17 * s, T("text_dim") }, { "Equip Rearmament weapons", cx, cy + r * 0.46 + 18 * s, 15 * s, T("text_dim") }
  end
  return { "WARFARER", cx, cy + r * 0.5, 20 * s, T("accent") }, nil
end

------------------------------------------------------------------------------------------------
-- Controller (via.hid.GamePad)
-- The merged pad device gives the pressed buttons as a bit mask (via.hid.GamePadButton) and both sticks. The default button is
-- Select / View, found by name in that enum; it can be rebound by pressing the button(s) (Controller > Bind). A tap of Select /
-- View opens the game's map, so the wheel opens only after the button has been held for a moment, and the release picks.
------------------------------------------------------------------------------------------------
local Pad = { text = "(press Dump)", diag = {}, next_search = 0, get = nil, ok = false, btn = 0, rx = 0, ry = 0, lx = 0, ly = 0, frame = -1, enum = nil, since = nil, bind = nil, peak = 0,
  bind_t = 0, ready_prev = false, note = "" }
-- Finds the pad device and remembers the call that worked. Every attempt is written to Pad.diag (shown in the dump), so a failure
-- says which step failed instead of just "no device". Searched again every second while nothing works.
local function pad_device()
  if Pad.get then
    local ok, d = pcall(Pad.get)
    if ok and d then return d end
    Pad.get = nil
  end
  if frame < Pad.next_search then return nil end
  Pad.next_search = frame + 60
  local diag = {}
  local mgr = sdk.get_native_singleton("via.hid.GamePad")
  local td = sdk.find_type_definition("via.hid.GamePad")
  diag[#diag + 1] = "singleton via.hid.GamePad: " .. (mgr and "found" or "NOT found") .. " | type: " .. (td and "found" or "NOT found")
  -- this game has no getMergedDevice(i) / getDevice(i): the pad devices are the zero-argument property getters of via.hid.GamePad
  local attempts = {}
  if mgr and td then
    for _, name in ipairs({ "get_MergedDevice", "get_Device", "get_LastInputDevice" }) do
      attempts[#attempts + 1] = { name .. " native call", function() return sdk.call_native_func(mgr, td, name) end }
      local okm, m = pcall(function() return td:get_method(name) end)
      if okm and m then
        attempts[#attempts + 1] = { name .. " method call", function() return m:call(mgr) end }
        attempts[#attempts + 1] = { name .. " static call", function() return m:call(nil) end }
      end
    end
  end
  for _, at in ipairs(attempts) do
    local ok, d = pcall(at[2])
    diag[#diag + 1] = string.format("%s: %s", at[1], ok and (d ~= nil and "device" or "nil") or ("error: " .. tostring(d)))
    if ok and d ~= nil then
      Pad.get, Pad.diag = at[2], diag
      return d
    end
  end
  Pad.diag = diag
  return nil
end
function Pad.read()
  if Pad.frame == frame then return Pad.btn end
  Pad.frame = frame
  local dev = pad_device()
  Pad.ok = dev ~= nil
  if dev and (Pad.detect_at == nil or frame - Pad.detect_at >= 180) then pcall(Pad.detect, dev) end
  if not dev then Pad.btn, Pad.rx, Pad.ry, Pad.lx, Pad.ly = 0, 0, 0, 0, 0; return 0 end
  local b = tonumber(mcall(dev, cfg.pad_getter or "get_Button")) or 0
  Pad.btn = math.floor(b)
  return Pad.btn
end
-- the sticks are read only when something asks (every frame the wheel is steered, or the settings page shows them)
function Pad.sticks()
  if Pad.sframe == frame then return end
  Pad.sframe = frame
  local dev = pad_device()
  if not dev then Pad.rx, Pad.ry, Pad.lx, Pad.ly = 0, 0, 0, 0; return end
  -- get_AnalogL / get_AnalogR are plain numbers on this device: the sticks are the vectors get_AxisL / get_AxisR (raw ones as fallback)
  Pad.rx, Pad.ry = xy(mcall(dev, "get_AxisR"))
  if not Pad.rx then Pad.rx, Pad.ry = xy(mcall(dev, "get_RawAxisR")) end
  Pad.lx, Pad.ly = xy(mcall(dev, "get_AxisL"))
  if not Pad.lx then Pad.lx, Pad.ly = xy(mcall(dev, "get_RawAxisL")) end
  Pad.rx, Pad.ry, Pad.lx, Pad.ly = Pad.rx or 0, Pad.ry or 0, Pad.lx or 0, Pad.ly or 0
end
function Pad.load_enum()
  if Pad.enum then return Pad.enum end
  local list = {}
  local td = sdk.find_type_definition("via.hid.GamePadButton")
  if td then
    local ok, fields = pcall(function() return td:get_fields() end)
    if ok and fields then
      for _, f in ipairs(fields) do
        local okn, name = pcall(function() return f:get_name() end)
        local okv, v = pcall(function() return f:get_data(nil) end)
        if okn and okv and type(v) == "number" and v ~= 0 and name ~= "value__" then list[#list + 1] = { name = name, value = math.floor(v) } end
      end
    end
  end
  table.sort(list, function(a, b) return a.value < b.value end)
  Pad.enum = list
  return list
end
function Pad.names(mask)
  local t, lab = {}, Pad.OFFICIAL[Pad.kind()]
  for _, e in ipairs(Pad.load_enum()) do
    if mask & e.value == e.value and (e.value & (e.value - 1)) == 0 then t[#t + 1] = lab[e.name] or e.name end      -- single-bit entries only
  end
  return #t > 0 and table.concat(t, " + ") or (mask ~= 0 and string.format("0x%X", mask) or "(none)")
end
-- the button that opens the map: Select / View (by name; the enum is read from the game)
function Pad.default_button()
  local list = Pad.load_enum()
  for _, key in ipairs({ "select", "back", "view", "share" }) do
    for _, e in ipairs(list) do if e.name:lower() == key then return e.value, e.name end end
  end
  for _, key in ipairs({ "select", "back", "view", "share" }) do
    for _, e in ipairs(list) do if e.name:lower():find(key, 1, true) then return e.value, e.name end end
  end
  -- this game's list has no Select / View by name: its three centre buttons are CLeft, CCenter, CRight (View, Xbox, Menu on an Xbox pad)
  for _, e in ipairs(list) do if e.name == "CLeft" then return e.value, e.name end end
  return nil
end
-- the entries of the button dropdown: the single buttons of the game's own list
-- Official button names. The game's own list (via.hid.GamePadButton) names the buttons by position; these are the names printed on
-- the controllers. The centre buttons of a PlayStation pad are the best match by position (Create / Options / PS button).
Pad.OFFICIAL = {
  xbox = { LUp = "D-pad Up", LDown = "D-pad Down", LLeft = "D-pad Left", LRight = "D-pad Right",
    RUp = "Y", RDown = "A", RLeft = "X", RRight = "B",
    LTrigTop = "LB (left bumper)", RTrigTop = "RB (right bumper)", LTrigBottom = "LT (left trigger)", RTrigBottom = "RT (right trigger)",
    LStickPush = "LS (left stick click)", RStickPush = "RS (right stick click)",
    CLeft = "View", CRight = "Menu", CCenter = "Xbox button" },
  ps = { LUp = "D-pad Up", LDown = "D-pad Down", LLeft = "D-pad Left", LRight = "D-pad Right",
    RUp = "Triangle", RDown = "Cross", RLeft = "Square", RRight = "Circle",
    LTrigTop = "L1", RTrigTop = "R1", LTrigBottom = "L2", RTrigBottom = "R2",
    LStickPush = "L3 (left stick click)", RStickPush = "R3 (right stick click)",
    CLeft = "Create / Share", CRight = "Options", CCenter = "PS button" },
}
Pad.ORDER = { "CLeft", "CRight", "CCenter", "LTrigTop", "RTrigTop", "LTrigBottom", "RTrigBottom", "LStickPush", "RStickPush",
  "RDown", "RRight", "RLeft", "RUp", "LUp", "LDown", "LLeft", "LRight" }
-- Xbox or PlayStation names: set in the menu, or (Auto) found from the connected controller's name and kind
function Pad.kind()
  if cfg.pad_type == 2 then return "xbox" elseif cfg.pad_type == 3 then return "ps" end
  return Pad.detected or "xbox"
end
local function pad_enum_name(dev, getter)
  local v = mcall(dev, getter)
  if type(v) ~= "number" then return nil end
  local ok, name = pcall(function()
    local t = dev:get_type_definition():get_method(getter):get_return_type()
    for _, f in ipairs(t:get_fields()) do
      local okv, fv = pcall(function() return f:get_data(nil) end)
      if okv and fv == v then return f:get_name() end
    end
  end)
  return ok and name or nil
end
function Pad.detect(dev)
  Pad.detect_at = frame
  local cands = { dev }
  local mgr = sdk.get_native_singleton("via.hid.GamePad")
  local td = sdk.find_type_definition("via.hid.GamePad")
  if mgr and td then
    for _, g in ipairs({ "get_LastInputDevice", "get_Device" }) do
      local ok, d = pcall(sdk.call_native_func, mgr, td, g)
      if ok and d then cands[#cands + 1] = d end
    end
  end
  local parts = {}
  for _, d in ipairs(cands) do
    parts[#parts + 1] = string.format("%s %s %s", tostring(mcall(d, "get_Name") or ""),
      tostring(pad_enum_name(d, "get_DeviceKindDetails") or ""), tostring(pad_enum_name(d, "get_DeviceType") or ""))
  end
  local text = table.concat(parts, " | ")
  local low = text:lower()
  local ps = false
  for _, key in ipairs({ "dual", "playstation", "ps4", "ps5", "ds4", "sony", "wireless controller" }) do
    if low:find(key, 1, true) then ps = true end
  end
  Pad.detected, Pad.detect_text = ps and "ps" or "xbox", text
end
function Pad.menu_items()
  local kind = Pad.kind()
  if Pad.menu and Pad.menu.kind == kind and #Pad.menu.vals > 1 then return Pad.menu end
  local have = {}
  for _, e in ipairs(Pad.load_enum()) do have[e.name] = e.value end
  local items, vals = { "(none)" }, { 0 }
  for _, name in ipairs(Pad.ORDER) do
    if have[name] then
      items[#items + 1] = Pad.OFFICIAL[kind][name]
      vals[#vals + 1] = have[name]
    end
  end
  Pad.menu = { items = items, vals = vals, kind = kind }
  return Pad.menu
end
function Pad.held(mask)
  if not mask or mask == 0 then return false end
  return Pad.read() & mask == mask
end
-- the buttons that open the wheel: the main button, plus the second one when a combination is switched on (both held)
function Pad.open_mask()
  if cfg.pad_button == 0 then return 0 end
  return cfg.pad_combo and (cfg.pad_button | cfg.pad_button2) or cfg.pad_button
end
-- the zero-argument getters of the pad device (get_Button, get_ButtonDown, ...): the names, along the whole inheritance chain
function Pad.device_getters(dev)
  if Pad.getters then return Pad.getters end
  local list, seen = {}, {}
  local td
  pcall(function() td = dev:get_type_definition() end)
  local guard = 0
  while td and guard < 8 do
    guard = guard + 1
    local ok, ms = pcall(function() return td:get_methods() end)
    if ok and ms then
      for _, m in ipairs(ms) do
        local okn, nm = pcall(function() return m:get_name() end)
        local okp, np = pcall(function() return m:get_num_params() end)
        if okn and okp and np == 0 and nm:sub(1, 4) == "get_" and not seen[nm] then seen[nm] = true; list[#list + 1] = nm end
      end
    end
    local okp, parent = pcall(function() return td:get_parent_type() end)
    td = okp and parent or nil
  end
  table.sort(list)
  Pad.getters = list
  return list
end
function Pad.label(mask, getter)
  mask, getter = mask or cfg.pad_button, getter or cfg.pad_getter or "get_Button"
  if mask == 0 then return "(none)" end
  if getter == "get_Button" then return Pad.names(mask) end
  return string.format("%s & 0x%X", getter, mask)
end
function Pad.dump()
  local lines = {}
  local function add(x) lines[#lines + 1] = x end
  add("controller dump " .. os.date("%H:%M:%S") .. " (hold the button while pressing 'Dump' to see where it shows up)")
  local dev = pad_device()
  for _, d in ipairs(Pad.diag) do add("  " .. d) end
  local td = sdk.find_type_definition("via.hid.GamePad")
  if td then
    local okm, ms = pcall(function() return td:get_methods() end)
    local names = {}
    if okm and ms then
      for _, m in ipairs(ms) do
        local okn, nm = pcall(function() return m:get_name() end)
        local okp, np = pcall(function() return m:get_num_params() end)
        if okn then names[#names + 1] = nm .. "/" .. (okp and np or "?") end
      end
    end
    table.sort(names)
    add("via.hid.GamePad methods (name/params): " .. table.concat(names, " "))
  end
  if not dev then
    add("no device found by any attempt")
  else
    local okn, n = pcall(function() return dev:get_type_definition():get_full_name() end)
    add("merged device: " .. (okn and n or "?"))
    for _, nm in ipairs(Pad.device_getters(dev)) do
      local v = mcall(dev, nm)
      local str
      if type(v) == "number" then
        str = (v == math.floor(v)) and string.format("%d (0x%X)", v, v) or string.format("%.3f", v)
      else
        local x, y = xy(v)
        str = x and string.format("(%.2f, %.2f)", x, y) or tostring(v)
      end
      add(string.format("  %s = %s", nm, str))
    end
  end
  local parts = {}
  for _, e in ipairs(Pad.load_enum()) do parts[#parts + 1] = string.format("%s=0x%X", e.name, e.value) end
  add("via.hid.GamePadButton: " .. (#parts > 0 and table.concat(parts, " ") or "not found"))
  add(string.format("controller type: %s (setting %d: 1 auto, 2 Xbox, 3 PlayStation) | detected from: %s", Pad.kind(), cfg.pad_type, tostring(Pad.detect_text)))
  add(string.format("configured: getter %s, mask 0x%X (%s)", tostring(cfg.pad_getter), cfg.pad_button, Pad.label(cfg.pad_button, cfg.pad_getter)))
  Pad.text = table.concat(lines, "\n")
end
-- the stick that steers the wheel (x right, y up; nil while it rests in the dead zone)
function Pad.stick()
  if not (cfg.pad_enabled and Pad.read() ~= nil and Pad.ok) then return nil end
  Pad.sticks()
  local x, y = Pad.rx, Pad.ry
  local function mag(a, b) return math.sqrt(a * a + b * b) end
  if cfg.pad_stick == 2 then x, y = Pad.lx, Pad.ly
  elseif cfg.pad_stick == 3 and mag(Pad.lx, Pad.ly) > mag(Pad.rx, Pad.ry) then x, y = Pad.lx, Pad.ly end
  if mag(x, y) < cfg.pad_dead / 100 then return nil end
  if cfg.pad_flip_y then y = -y end
  return x, y
end
-- a ring that fills while the button is held, so it is clear that holding is what opens the wheel
function Pad.progress(t)
  if t < 0.12 then return end
  local sw, sh = screen_size()
  local f = math.min(1, t / math.max(cfg.pad_hold, 0.05))
  local cx, cy, r = sw / 2, sh / 2, 34 * (sh / 1080)
  local a0, steps = -math.pi / 2, math.max(2, math.floor(48 * f))
  local c = abgr(T("accent"))
  local px, py = cx + math.cos(a0) * r, cy + math.sin(a0) * r
  for i = 1, steps do
    local a = a0 + TAU * f * i / steps
    local x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
    pcall(draw.line, px, py, x, y, c)
    px, py = x, y
  end
end

------------------------------------------------------------------------------------------------
-- The wheel
------------------------------------------------------------------------------------------------
local function build_options()
  local out = {}
  for _, e in ipairs(Arisen.list) do out[#out + 1] = e end
  if cfg.order_mode == 2 then table.sort(out, function(a, b) return a.job < b.job end) end
  return out
end
local function update_selection(cx, cy)
  local n = #W.options
  if n == 0 then W.sel = nil; return end
  if cfg.select_mode == 2 then
    Mouse.read()
    local mx, my = imgui_mouse()
    if mx then W.sx, W.sy = mx - cx, my - cy end
  else
    local dx, dy = Mouse.read()
    W.sx, W.sy = W.sx + dx * cfg.mouse_sens, W.sy + dy * cfg.mouse_sens
    local len = math.sqrt(W.sx * W.sx + W.sy * W.sy)
    if len > cfg.stick_max then W.sx, W.sy = W.sx / len * cfg.stick_max, W.sy / len * cfg.stick_max end
  end
  local px, py = Pad.stick()
  if px then W.sx, W.sy = px * cfg.stick_max, -py * cfg.stick_max end       -- the stick points at a slice (screen y goes down)
  local len = math.sqrt(W.sx * W.sx + W.sy * W.sy)
  if len >= cfg.deadzone then
    local a = math.atan(W.sx, -W.sy)
    if a < 0 then a = a + TAU end
    local step = TAU / n
    W.sel = math.floor((a + step / 2) / step) % n + 1
    W.angle = a
  end
end
-- when the wheel opens: the other GUIs may have changed (pawns came and went), so the segments are looked up again
function Layers.on_open()
  Layers.scan()
  local ico, bg = Layers.top + 2, Layers.top + 1
  if ico == Layers.ico_seg and bg == Layers.bg_seg then return end
  Layers.ico_seg, Layers.bg_seg, Ico.GUI.Segment, Bg.GUI.Segment = ico, bg, ico, bg
  for _, c in ipairs(Ico.cells) do pcall(function() c.gui:call("set_Segment", ico) end) end
  for _, c in ipairs(Bg.cells) do pcall(function() c.gui:call("set_Segment", bg) end) end
  log_act(string.format("GUI layers: the other GUIs reach segment %d, the wheel draws at %d (background) and %d (icons)", Layers.top, bg, ico))
end
local function prepare_wheel()
  pcall(Layers.on_open)
  Arisen.refresh()
  W.options = build_options()
  local cur = current_entry()
  W.equipped = cur and cur.key or nil
  W.sx, W.sy, W.sel, W.angle = 0, 0, nil, nil
  for i, o in ipairs(W.options) do
    if W.equipped and o.key == W.equipped then W.sel = i end
  end
  Mouse.reset()
end
local function open_wheel()
  prepare_wheel()
  W.open = true
  Slow.start()
end
local function close_wheel(commit)
  if not W.open then return end
  W.open = false
  Slow.stop()
  if commit and W.sel and W.options[W.sel] then
    local opt = W.options[W.sel]
    if opt.key ~= W.equipped then do_switch(opt) end
  end
end
-- Equipment safety. Changing the Rearmament equipment makes the game rebuild the Warfarer's weapon list. Opening the wheel (and above
-- all picking a weapon) right then can crash the game, so the wheel stays shut for a moment after the list changed and while a
-- switch is in progress.
local Safety = { sig = nil, settle_until = 0, notice_until = -1 }
function Safety.signature()
  local parts = {}
  for _, e in ipairs(Arisen.list) do
    parts[#parts + 1] = string.format("%s:%s:%s", tostring(e.key), tostring(e.main_item), tostring(e.sub_item_id))
  end
  return table.concat(parts, "|")
end
function Safety.update()
  if P.job ~= cfg.warfarer_job or #Arisen.list == 0 then return end
  local sig = Safety.signature()
  if sig == Safety.sig then return end
  local first = Safety.sig == nil
  Safety.sig = sig
  if first then return end                                          -- the first reading after loading: nothing was changed
  -- The game re-reads the weapon list while a weapon is being swapped (the animation of the switch the wheel just made, or of any
  -- other weapon change): that is not a change of the equipment, so the new reading is simply taken over.
  if frame - SW.last < 240 or frame - Track.last_change < 150 or SW.want or SW.inst then return end
  Safety.settle_until = frame + SAFETY_SETTLE
  log_act("Rearmament equipment changed")
end
function Safety.blocked()
  if SW.want or SW.inst then return "a switch is in progress" end
  if frame < Safety.settle_until then return "the equipment has just changed" end
  return nil
end
local function can_open()
  if P.char == nil or is_paused() or is_loading() then return false end
  if P.job == nil then
    log_once("nojob", "Can't read the current vocation yet")
    return false
  end
  if P.job ~= cfg.warfarer_job then return false end
  if frame - Arisen.at > 2 then pcall(Arisen.refresh) end            -- the list as it is right now, not as it was up to half a second ago
  Safety.update()
  local why = Safety.blocked()
  if why then
    -- the note says the equipment changed, so it is shown only for that; while the mod's own switch is still running the wheel just stays shut
    if frame < Safety.settle_until then Safety.notice_until = frame + 150 end
    log_act("Wheel not opened: " .. why)
    return false
  end
  return true
end

local function pie_layout(cx, cy, s)
  local n = #W.options
  local step = TAU / n
  local r_in, r_out = cfg.inner_radius * s, cfg.wheel_radius * s
  local gap = (n > 1) and math.rad(cfg.slice_gap_deg) or 0
  local items = {}
  for i, opt in ipairs(W.options) do
    local ac = (i - 1) * step
    local hov = W.sel == i
    local push_out = hov and 12 * s or 0
    local it = { opt = opt, hov = hov, ac = ac, a0 = ac - step / 2 + gap / 2, a1 = ac + step / 2 - gap / 2,
                 ox = cx + math.sin(ac) * push_out, oy = cy - math.cos(ac) * push_out, r_in = r_in,
                 ro = r_out + (hov and 8 * s or 0) }
    local rm = (it.r_in + it.ro) / 2
    local px, py = polar(it.ox, it.oy, rm, ac)
    -- The icon's medallion has to fit inside the slice: its radius may not exceed half the slice's thickness, nor the distance
    -- from the slice's axis to its radial edges at that radius (a thick ring, a high inner radius or many slices make the slice
    -- smaller than the icon, and the border drawn over the slice then cut the medallion off).
    local limit = (it.ro - it.r_in) / 2 - 4 * s
    if n > 1 then limit = math.min(limit, rm * math.sin(math.max(0.05, step / 2 - gap / 2)) - 4 * s) end
    local rmax = (limit - 10 <= 50) and (limit - 10) or (limit / 1.2)        -- the medallion band is max(10, 0.2 r) wide (Ico.show_at)
    local per_isz = Ico.HOLE * cfg.icon_size_k * (hov and 1.1 or 1.0)        -- hole radius per unit of isz (Ico.update)
    it.ix, it.iy, it.isz = px, py, math.max(8 * s, math.min((hov and 56 or 46) * s, rmax / per_isz))
    items[i] = it
  end
  return items
end

-- an arc that leaves out the stretches inside an icon's hole: the game's icons lie under the overlay, so a thick flat arc drawn
-- across one (the old outer edge of a slice that grew when hovered, the border strips) cut a piece off the icon
local function line_h(x1, y1, x2, y2, c, t)
  if #Ico.holes == 0 then line(x1, y1, x2, y2, c, t); return end
  local dx, dy = x2 - x1, y2 - y1
  local n = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / 6))
  for i = 1, n do
    local ax, ay, bx, by = x1 + dx * (i - 1) / n, y1 + dy * (i - 1) / n, x1 + dx * i / n, y1 + dy * i / n
    local mx, my, inside = (ax + bx) / 2, (ay + by) / 2, false
    for _, hl in ipairs(Ico.holes) do
      local ex, ey = mx - hl.x, my - hl.y
      local cut = hl.r + hl.w * 0.5 + (t or 1) * 0.5
      if ex * ex + ey * ey < cut * cut then inside = true; break end
    end
    if not inside then line(ax, ay, bx, by, c, t) end
  end
end
local function arc_h(cx, cy, r, a0, a1, c, t)
  if #Ico.holes == 0 then arc(cx, cy, r, a0, a1, c, t); return end
  local steps = math.max(2, math.ceil((a1 - a0) / (math.pi / 48)))
  local px, py = polar(cx, cy, r, a0)
  for i = 1, steps do
    local x, y = polar(cx, cy, r, a0 + (a1 - a0) * i / steps)
    local mx, my, inside = (px + x) / 2, (py + y) / 2, false
    for _, hl in ipairs(Ico.holes) do
      local dx, dy = mx - hl.x, my - hl.y
      local cut = hl.r + hl.w * 0.5 + t * 0.5
      if dx * dx + dy * dy < cut * cut then inside = true; break end
    end
    if not inside then line(px, py, x, y, c, t) end
    px, py = x, y
  end
end
local function render_pie(cx, cy, s, items)
  local r_in, r_out = cfg.inner_radius * s, cfg.wheel_radius * s
  local ow = Bg.on and math.max(1, (cfg.bg_outline or 1) * s / SCALE_BASE) or 1      -- thickness of the yellow outline
  if Bg.on then
    -- the game's background is the fill; a thin outline hides the stair-steps where the flat fill meets the world
    if Bg.covering() then Bg.fill_pieces(T("bg_fill")) end
    Bg.fill_slivers(T("bg_fill"))
    local oc = Bg.slice_mode and T("accent") or T("accent_soft")       -- the solid trim colour, like the circle in the middle
    local bw = (cfg.bg_border or 0) * s
    if Bg.slice_mode and Bg.done_key then
      for i, it in ipairs(items) do
        if it.hov then
          it.i = i
          local moved = it.ox ~= cx or it.oy ~= cy
          -- The outer edge the pieces ended at (where they stand now): hairline gaps there let the world show through, and under
          -- the highlight they read as a faint gold line. The thick border normally hides them, but it moves with the slice.
          if moved and (cfg.bg_follow_hover or cfg.bg_hover_cover) then
            local pcx, pcy = cx, cy
            if cfg.bg_follow_hover then pcx, pcy = it.ox, it.oy end
            arc_h(pcx, pcy, r_out, it.a0, it.a1, T("bg_fill"), math.max(5 * s, bw))
          end
          if cfg.bg_follow_hover then
            -- the pieces moved with the slice; the part it grew outwards and the place it left are filled with the flat background
            -- colour (a dim there showed as a black spot next to the dimmed ring)
            if it.ro > r_out + 0.5 then Bg.fill_sector(it.ox, it.oy, r_out, it.ro, it.a0, it.a1, T("bg_fill")) end
            if moved then Bg.fill_vacated(cx, cy, it, r_out, T("bg_fill")) end
          elseif cfg.bg_hover_cover then
            -- the pieces stay where they were: the place the slice left and the part it grew into are covered with the flat
            -- background colour, so the highlight sits on a clean base instead of on the edges of the pieces
            if moved then Bg.fill_vacated(cx, cy, it, r_out, T("bg_fill")) end
            if moved or it.ro > r_out + 0.5 then
              Bg.fill_grown(cx, cy, it, r_out, T("bg_fill"))
              if it.hole then pcall(Bg.fill_hole_cover, cx, cy, it, r_out, it.hole, T("bg_fill")) end
            end
          end
        end
      end
    end
    -- A radial side of a slice faces the next slice: its border and outline are drawn INSIDE the slice (shifted by half their
    -- thickness along the arc direction), so they never reach into the gap between two slices. The arcs stay centred on the outline.
    local function side(it, a, w, col, sign)
      local x1, y1 = polar(it.ox, it.oy, it.r_in, a); local x2, y2 = polar(it.ox, it.oy, it.ro, a)
      local dx, dy = math.cos(a) * sign * w / 2, math.sin(a) * sign * w / 2
      line_h(x1 + dx, y1 + dy, x2 + dx, y2 + dy, col, w)
    end
    if Bg.slice_mode then                                    -- the thick border in the foreground: covers what sticks out of the outline
      local bc = T("bg_fill")
      for _, it in ipairs(items) do
        -- the selected slice gets a thicker one, behind its highlight
        local w = (it.hov and cfg.bg_hover_cover) and math.max(bw, 3 * s) * 1.8 or bw
        if w > 0.5 then
          arc_h(it.ox, it.oy, it.r_in, it.a0, it.a1, bc, w)
          arc_h(it.ox, it.oy, it.ro, it.a0, it.a1, bc, w)
          side(it, it.a0, w, bc, 1); side(it, it.a1, w, bc, -1)
        end
      end
    end
    if Bg.slice_mode then
      for _, it in ipairs(items) do
        if not it.hov then
          arc_h(it.ox, it.oy, it.r_in, it.a0, it.a1, oc, ow)
          side(it, it.a0, ow, oc, 1); side(it, it.a1, ow, oc, -1)
        end
      end
    else
      circle_line(cx, cy, r_out + Bg.EDGE * s, oc, 2)
      circle_line(cx, cy, r_in - Bg.EDGE * s, oc, 2)
    end
  else
    Ico.fill_ring_holes(cx, cy, r_in - 6 * s, r_out + 6 * s, T("backdrop"))
  end
  for _, it in ipairs(items) do
    local ok_sw = it.opt.equipNo ~= nil or it.opt.item ~= nil
    local scol = it.hov and T("slice_hover") or (ok_sw and T("slice") or T("slice_off"))
    if Bg.on then
      local tint = nil                                -- over the background only the hovered / unavailable slices get a tint
      if it.hov then tint = with_alpha(T("slice_hover"), cfg.hl_alpha)
      elseif not ok_sw then tint = with_alpha(T("slice_off"), 150) end
      if tint then
        if #items > 1 then Bg.fill_sector(it.ox, it.oy, it.r_in, it.ro, it.a0, it.a1, tint)
        else fill_shape(ring_cells(it.ox, it.oy, it.r_in, it.ro, it.a0, it.a1), tint) end
      end
    elseif it.hole then fill_shape(Ico.ring_cells_hole(it.ox, it.oy, it.r_in, it.ro, it.a0, it.a1, it.hole), { scol[1], scol[2], scol[3], 255 })
    else fill_shape(ring_cells(it.ox, it.oy, it.r_in, it.ro, it.a0, it.a1), scol) end
    if it.hov then
      local pulse = 0.5 + 0.5 * math.sin(frame * 0.18)
      arc_h(it.ox, it.oy, it.ro + 3 * s, it.a0, it.a1, with_alpha(T("accent_hi"), 90 + 120 * pulse), math.max(2, 4 * s))
      arc_h(it.ox, it.oy, it.ro, it.a0, it.a1, T("accent_hi"), 3)
      arc_h(it.ox, it.oy, it.r_in, it.a0, it.a1, T("accent"), 2)
      local x1, y1 = polar(it.ox, it.oy, it.r_in, it.a0); local x2, y2 = polar(it.ox, it.oy, it.ro, it.a0)
      local x3, y3 = polar(it.ox, it.oy, it.r_in, it.a1); local x4, y4 = polar(it.ox, it.oy, it.ro, it.a1)
      line_h(x1, y1, x2, y2, T("accent_hi"), 2); line_h(x3, y3, x4, y4, T("accent_hi"), 2)
    else
      arc_h(cx, cy, r_out, it.a0, it.a1, Bg.on and T("accent") or T("accent_soft"), ow)
    end
    if it.opt.key == W.equipped then arc_h(it.ox, it.oy, it.r_in + 4 * s, it.a0 + 0.05, it.a1 - 0.05, T("equipped"), 2) end
    if it.hole then Ico.medallion(it.hole) else emblem(it.opt.job, it.ix, it.iy, it.isz) end
  end
  -- the hovered vocation's name sits OUTSIDE the ring, radially in line with its slice: it never meets a slice edge
  if cfg.show_name then
    for _, it in ipairs(items) do
      if it.hov then
        local name = JOBS[it.opt.job].name
        local size = 22 * s
        local w, h = measure(name, size)
        local lx, ly = polar(it.ox, it.oy, it.ro + 22 * s, it.ac)
        text_c(name, lx + math.sin(it.ac) * (w / 2), ly - math.cos(it.ac) * (h / 2), T("accent_hi"), size)
      end
    end
  end
end

local function render_center(cx, cy, s, icon)
  local r = cfg.center_radius * s
  if Bg.on then
    -- the background shows through the disc
    local bw = (cfg.bg_border or 0) * s
    if bw > 0.5 then circle_line(cx, cy, r, T("bg_fill"), bw) end
  elseif Ico.center_hole then
    local cc = T("center")
    fill_shape(Ico.ring_cells_hole(cx, cy, 0, r, 0, TAU, Ico.center_hole), { cc[1], cc[2], cc[3], 255 })
  else
    fill_shape(ring_cells(cx, cy, 0, r, 0, TAU), T("center"))
  end
  circle_line(cx, cy, r, T("accent"), 2)
  circle_line(cx, cy, r + 5 * s, T("accent_soft"), 1)
  if W.angle and #W.options > 0 then
    local pr = cfg.inner_radius * s - 12 * s
    local tx, ty = polar(cx, cy, pr + 8 * s, W.angle)
    local lx, ly = polar(cx, cy, pr - 4 * s, W.angle - 0.06)
    local rx, ry = polar(cx, cy, pr - 4 * s, W.angle + 0.06)
    poly({ { tx, ty }, { rx, ry }, { lx, ly } }, T("accent_hi"))
  end
  if Ico.center_hole then Ico.medallion(Ico.center_hole) else emblem(cfg.warfarer_job, icon.x, icon.y, icon.size) end
  local l1, l2 = Center.lines(cx, cy, r, s)
  if l1 then text_c(l1[1], l1[2], l1[3], l1[5], l1[4]) end
  if l2 then text_c(l2[1], l2[2], l2[3], l2[5], l2[4]) end
end

-- The dimmer fades in when the wheel opens and out after it closed (real time) instead of switching on and off in one frame.
local Dim = { k = 0, t = os.clock() }
function Dim.step(open)
  local now = os.clock()
  local dt = math.min(now - Dim.t, 0.1)
  Dim.t = now
  if open then Dim.k = math.min(1, Dim.k + dt / 0.12) else Dim.k = math.max(0, Dim.k - dt / 0.2) end
end
local function draw_background(sw, sh, closing)
  if not cfg.dim_enabled or Dim.k <= 0 then return end
  local c = { 0, 0, 0, cfg.dim_alpha * 255 * Dim.k }
  if closing then
    Ico.holes = {}                                  -- the game's icons are hidden by now: nothing to leave undimmed
    Ico.rect(0, 0, sw, sh, c)
  elseif Bg.on then Bg.dim(sw, sh, c) else Ico.fill_rect_holes(0, 0, sw, sh, c) end
end

local OVERLAY_FLAGS = 1 | 2 | 4 | 8 | 16 | 32 | 128 | 256 | 512 | 4096 | 8192
local function render_wheel()
  local t_start = os.clock()
  R.draws = 0
  local sw, sh = screen_size()
  local cx, cy = sw / 2, sh / 2
  local s = cfg.scale * SCALE_BASE * (cfg.auto_scale and (Geo.get().h / 1080) or 1)
  update_selection(cx, cy)
  Bg.update(sw, sh, s)

  local items = (#W.options > 0) and pie_layout(cx, cy, s) or nil
  if items and Bg.on and cfg.bg_follow_hover then pcall(Bg.sync_hover, items, cx, cy) end
  local r = cfg.center_radius * s
  local cicon = { x = cx, y = cy - r * 0.2, size = r * 1.1 }
  Ico.holes, Ico.center_hole = {}, nil
  local t_ico = os.clock()
  if cfg.game_icons then
    if items then pcall(Ico.update, items) end
    pcall(Ico.update_center, cicon)
  end

  pcall(imgui.set_next_window_pos, v2(0, 0), 1)
  pcall(imgui.set_next_window_size, v2(sw, sh), 1)
  local began = pcall(imgui.begin_window, "##WarfarerArsenalOverlay", nil, OVERLAY_FLAGS)
  if began then
    local okd, dl = pcall(imgui.get_window_draw_list)
    R.dl = okd and dl or nil
    if R.dl then pcall(function() R.dl:push_clip_rect_fullscreen() end) end
  end
  local ok, err = pcall(function()
    draw_background(sw, sh)
    if items then render_pie(cx, cy, s, items) end
    render_center(cx, cy, s, cicon)
  end)
  if not ok then last_error = tostring(err) end
  if began then
    if R.dl then pcall(function() R.dl:pop_clip_rect() end) end
    pcall(imgui.end_window)
  end
  R.dl = nil
end

-- the frames after the wheel closed: the pieces of the game's background take a few frames to disappear, so the overlay keeps
-- the wheel's flat silhouette and the dimmer for that long (Bg.tail) instead of exposing them bare
local function render_cover()
  if Bg.tail > 0 and os.clock() - (Bg.tail_t0 or 0) > 0.045 then Bg.tail = 0 end      -- never longer than ~3 frames at 60 fps, whatever the frame rate
  local cover = Bg.tail > 0 and Bg.on and Bg.list and Bg.groups
  if Bg.tail > 0 then Bg.tail = Bg.tail - 1 end
  if not cover then Bg.tail = 0 end
  if not cover and not (cfg.dim_enabled and Dim.k > 0) then return end
  R.draws = 0
  local sw, sh = screen_size()
  pcall(imgui.set_next_window_pos, v2(0, 0), 1)
  pcall(imgui.set_next_window_size, v2(sw, sh), 1)
  local began = pcall(imgui.begin_window, "##WarfarerArsenalOverlay", nil, OVERLAY_FLAGS)
  if began then
    local okd, dl = pcall(imgui.get_window_draw_list)
    R.dl = okd and dl or nil
    if R.dl then pcall(function() R.dl:push_clip_rect_fullscreen() end) end
  end
  local ok, err = pcall(function()
    draw_background(sw, sh, true)
    if cover then
      Bg.fill_pieces(T("bg_fill"))
      Bg.fill_slivers(T("bg_fill"))
    end
  end)
  if not ok then last_error = tostring(err) end
  if began then
    if R.dl then pcall(function() R.dl:pop_clip_rect() end) end
    pcall(imgui.end_window)
  end
  R.dl = nil
end

-- a short note in the middle of the screen when the wheel was asked for while the weapon data is being updated
local function render_notice()
  local sw, sh = screen_size()
  pcall(imgui.set_next_window_pos, v2(0, 0), 1)
  pcall(imgui.set_next_window_size, v2(sw, sh), 1)
  local began = pcall(imgui.begin_window, "##WarfarerArsenalOverlay", nil, OVERLAY_FLAGS)
  if began then
    local okd, dl = pcall(imgui.get_window_draw_list)
    R.dl = okd and dl or nil
  end
  local ok, err = pcall(function()
    text_c("The Rearmament equipment changed...", sw / 2, sh * 0.72, T("accent_hi"), math.max(14, 22 * sh / 1080))
  end)
  if not ok then last_error = tostring(err) end
  if began then pcall(imgui.end_window) end
  R.dl = nil
end

-- The Rearmament key (keyboard or pad, whatever the player has bound) is found when it is pressed: the game's press hook asks
-- Skill.on_press, which looks at which keys / buttons went down this very moment. While they stay down the press is held back; after
-- the hold time the wheel opens, and letting go picks. A tap shorter than that gives the held-back press to the game afterwards.
function Skill.track()
  for vk = 1, 254 do
    if is_vk_down(vk) then Skill.down[vk] = Skill.down[vk] or frame else Skill.down[vk] = nil end
  end
  local b = cfg.pad_enabled and Pad.read() or 0
  for bit = 0, 31 do
    if (b >> bit) & 1 == 1 then Skill.pad[bit] = Skill.pad[bit] or frame else Skill.pad[bit] = nil end
  end
end
function Skill.on_press()
  if not (cfg.skill_wheel and cfg.enabled) then return false end
  if Skill.pend then return true end                       -- key repeats while it is held stay held back too
  if W.open then return false end
  if P.job ~= cfg.warfarer_job or SW.want or SW.inst or is_paused() or is_loading() then return false end
  local keys, pads = {}, {}
  for vk = 1, 254 do
    if is_vk_down(vk) and (Skill.down[vk] == nil or Skill.down[vk] >= frame - 1) then keys[#keys + 1] = vk end
  end
  local b = cfg.pad_enabled and Pad.read() or 0
  for bit = 0, 31 do
    if (b >> bit) & 1 == 1 and (Skill.pad[bit] == nil or Skill.pad[bit] >= frame - 1) then pads[#pads + 1] = bit end
  end
  if #keys + #pads == 0 or #keys + #pads > 4 then
    Skill.msg = "the Rearmament key could not be told apart (" .. (#keys + #pads) .. " new keys / buttons) - the press went through normally"
    log_once("skill_nokey", "Rearmament wheel: " .. Skill.msg)
    return false
  end
  Skill.pend = { t0 = os.clock(), frame = frame, keys = keys, pads = pads }
  Skill.msg = "holding back the press (keys " .. table.concat(keys, ",") .. " / pad bits " .. table.concat(pads, ",") .. ")"
  return true
end
function Skill.tick(en)
  if not (cfg.skill_wheel and en) then
    if Skill.pend then Skill.pend = nil end
    return
  end
  if P.job == cfg.warfarer_job then pcall(Skill.track) end
  local p = Skill.pend
  if not p then return end
  local held = true
  for _, vk in ipairs(p.keys) do if not is_vk_down(vk) then held = false end end
  if #p.pads > 0 then
    local b = Pad.read()
    for _, bit in ipairs(p.pads) do if (b >> bit) & 1 == 0 then held = false end end
  end
  local age = os.clock() - p.t0
  if not held then
    Skill.pend = nil
    if W.open and W.src == "skill" then close_wheel(true)
    else Skill.replay = true end
  elseif not W.open and age >= cfg.skill_hold then
    if can_open() then
      W.src = "skill"
      open_wheel()
    else
      Skill.pend = nil
      Skill.replay = true
    end
  elseif age > 60 then
    Skill.pend = nil
    if W.open and W.src == "skill" then close_wheel(false) end
  end
end

local function handle_hotkey()
  local en = cfg.enabled and Bind.state == nil
  local keyheld = en and hotkey_held()
  -- the controller button must be held for cfg.pad_hold seconds (a tap opens the game's map); real time, not game time
  local padraw = en and cfg.pad_enabled and Pad.held(Pad.open_mask())
  local now = os.clock()
  if padraw then Pad.since = Pad.since or now else Pad.since = nil end
  local padready = padraw and (now - Pad.since >= cfg.pad_hold)
  if not W.open then
    if keyheld and not W.prev_held then
      if can_open() then W.src = "key"; open_wheel() end
    elseif padready and not Pad.ready_prev then
      if can_open() then W.src = "pad"; open_wheel() end
    end
    if padraw and not padready and not is_paused() then Pad.progress(now - Pad.since) end
  else
    if W.src == "pad" then
      if not padraw then close_wheel(true) end
    elseif W.src == "skill" then
      -- closed by Skill.tick when the Rearmament key is let go
    elseif not keyheld then
      close_wheel(true)
    end
  end
  Pad.ready_prev = padready
  pcall(Skill.tick, en)
  local held = keyheld
  if W.open and is_paused() then close_wheel(false) end
  if W.open and cfg.cancel_rmb and not hotkey_contains(2) and is_vk_down(2) then
    close_wheel(false)
    log_act("Wheel cancelled (right mouse)")
  end
  W.prev_held = held
end

------------------------------------------------------------------------------------------------
-- Combat Damage Log System (HUD Chat Overlay)
------------------------------------------------------------------------------------------------
local function format_number(n)
  local s = tostring(math.floor(math.abs(n or 0)))
  local left, num, right = string.match(s, '^([^%d]*%d)(%d*)(.-)$')
  if not left then return tostring(math.floor(n or 0)) end
  return left .. (num:reverse():gsub('(%d%d%d)', '%1,'):reverse()) .. right
end

local function extract_damage(info)
  if not info then return 0 end
  local val = nil
  pcall(function()
    if type(info.Damage) == "number" then
      val = info.Damage
    elseif type(info.Damage) == "function" then
      val = info:Damage()
    end
  end)
  if val and tonumber(val) and tonumber(val) > 0 then return math.floor(tonumber(val)) end

  pcall(function()
    if info.get_Damage then val = info:get_Damage() end
  end)
  if val and tonumber(val) and tonumber(val) > 0 then return math.floor(tonumber(val)) end

  pcall(function()
    val = info:call("get_Damage")
  end)
  if val and tonumber(val) and tonumber(val) > 0 then return math.floor(tonumber(val)) end

  pcall(function()
    val = info:get_field("Damage")
  end)
  if val and tonumber(val) and tonumber(val) > 0 then return math.floor(tonumber(val)) end

  pcall(function()
    val = info["<Damage>k__BackingField"]
  end)
  if val and tonumber(val) and tonumber(val) > 0 then return math.floor(tonumber(val)) end

  pcall(function()
    val = info:get_field("<Damage>k__BackingField")
  end)
  if val and tonumber(val) and tonumber(val) > 0 then return math.floor(tonumber(val)) end

  pcall(function()
    val = info:get_field("HitDamage") or (info.get_HitDamage and info:get_HitDamage())
  end)
  if val and tonumber(val) and tonumber(val) > 0 then return math.floor(tonumber(val)) end

  return 0
end

local function is_weakpoint(info)
  if not info then return false end
  local res = false
  pcall(function()
    if type(info.IsWeakPoint) == "boolean" then
      res = info.IsWeakPoint
    elseif type(info.IsWeakPoint) == "function" then
      res = info:IsWeakPoint()
    end
  end)
  if res then return true end

  pcall(function()
    if info.get_IsWeakPoint then res = info:get_IsWeakPoint() end
  end)
  if res then return true end

  pcall(function()
    res = info:call("get_IsWeakPoint")
  end)
  if res then return true end

  pcall(function()
    res = info:get_field("IsWeakPoint") or info["<IsWeakPoint>k__BackingField"] or info:get_field("<IsWeakPoint>k__BackingField")
  end)
  if res then return true end

  return false
end

local function get_character_from_hit_ctrl(ctrl)
  if not ctrl then return nil end
  local ch = nil
  pcall(function()
    ch = ctrl:get_CachedCharacter() or ctrl:get_Character() or ctrl:get_OwnerCharacter()
  end)
  if ch then return ch end
  pcall(function()
    ch = ctrl:call("get_CachedCharacter") or ctrl:call("get_Character") or ctrl:call("get_OwnerCharacter")
  end)
  if ch then return ch end
  pcall(function()
    ch = ctrl:get_field("CachedCharacter") or ctrl:get_field("<CachedCharacter>k__BackingField")
  end)
  if ch then return ch end
  pcall(function()
    local go = ctrl:get_GameObject()
    if go then
      local cType = sdk.find_type_definition("app.Character")
      if cType then ch = go:get_Component(cType) end
    end
  end)
  return ch
end

local DamageLog = {
  entries = {},
  total_damage = 0,
  recent_damage = 0,
  combat_start_time = 0,
  last_hit_time = 0,
  d2d_active = false,
  last_rendered_frame = 0,
}

local d2d_font_title = nil
local d2d_font_line = nil
local d2d_available = false

local function to_argb(a, r, g, b)
  local alpha = math.floor(clamp(a or 255, 0, 255))
  local red = math.floor(clamp(r or 255, 0, 255))
  local green = math.floor(clamp(g or 255, 0, 255))
  local blue = math.floor(clamp(b or 255, 0, 255))
  return (alpha << 24) | (red << 16) | (green << 8) | blue
end

function DamageLog.add(dmg, target, isWeakPoint, isPawn)
  local now = os.clock()
  if now - DamageLog.last_hit_time > 8.0 then
    DamageLog.combat_start_time = now
    DamageLog.recent_damage = 0
  end
  DamageLog.last_hit_time = now
  DamageLog.total_damage = DamageLog.total_damage + dmg
  DamageLog.recent_damage = DamageLog.recent_damage + dmg

  table.insert(DamageLog.entries, {
    damage = dmg,
    target = target or "Enemy",
    isWeakPoint = isWeakPoint or false,
    isPawn = isPawn or false,
    time = now,
  })

  while #DamageLog.entries > 30 do
    table.remove(DamageLog.entries, 1)
  end
end

-- Native Direct2D rendering loop (runs every frame in DX12 presentation, whether REFramework menu is open or closed)
function DamageLog.render_d2d()
  if not cfg.damage_log_enabled then return end
  local now = os.clock()
  local duration = cfg.damage_log_duration or 5.0
  local maxLines = cfg.damage_log_max_lines or 8

  local active = {}
  for i = #DamageLog.entries, 1, -1 do
    local e = DamageLog.entries[i]
    local age = now - e.time
    if age < duration then
      table.insert(active, 1, e)
      if #active >= maxLines then break end
    end
  end

  -- Preview mode: display sample lines if no active hits
  if cfg.damage_log_preview and #active == 0 then
    table.insert(active, { damage = 380, target = "Goblin", isWeakPoint = false, isPawn = false, time = now })
    table.insert(active, { damage = 1450, target = "Cyclops", isWeakPoint = true, isPawn = false, time = now })
    if cfg.damage_log_include_pawns then
      table.insert(active, { damage = 210, target = "Harpy", isWeakPoint = false, isPawn = true, time = now })
    end
  end

  if #active == 0 then return end

  -- Screen resolution (with ultrawide 3440x1440 support)
  local sw, sh = 1920, 1080
  if d2d and d2d.surface_size then
    local dsw, dsh = d2d.surface_size()
    if dsw and dsh and dsw > 0 and dsh > 0 then
      sw, sh = dsw, dsh
    end
  else
    local scrw, scrh = screen_size()
    if scrw and scrh and scrw > 0 and scrh > 0 then
      sw, sh = scrw, scrh
    end
  end

  local bounds_x = 0
  local bounds_y = 0
  local bounds_w = sw
  local bounds_h = sh

  -- Ultrawide 16:9 safe frame centering (e.g. 2560x1440 centered on 3440x1440)
  if cfg.damage_log_ultrawide_constrain ~= false and (sw / sh) > 1.8 then
    local safe_w = sh * (16.0 / 9.0)
    bounds_x = (sw - safe_w) * 0.5
    bounds_w = safe_w
  end

  local w = cfg.damage_log_width or 380
  local lineH = 22
  local headerH = 26
  local pad = 8
  local h = headerH + (#active * lineH) + pad

  local offX = cfg.damage_log_offset_x or 35
  local offY = cfg.damage_log_offset_y or 60

  local corner = cfg.damage_log_corner or 1
  local x, y
  if corner == 2 then -- Top-Left
    x = bounds_x + offX
    y = bounds_y + offY
  elseif corner == 4 then -- Top-Right
    x = bounds_x + bounds_w - w - offX
    y = bounds_y + offY
  elseif corner == 3 then -- Bottom-Right
    x = bounds_x + bounds_w - w - offX
    y = bounds_y + bounds_h - h - offY
  else -- 1: Bottom-Left
    x = bounds_x + offX
    y = bounds_y + bounds_h - h - offY
  end

  x = math.max(0, math.min(sw - w, x))
  y = math.max(0, math.min(sh - h, y))

  local bgAlpha = math.floor(clamp(cfg.damage_log_bg_opacity or 0.70, 0.0, 1.0) * 255)
  local bgColor = to_argb(bgAlpha, 18, 18, 22)
  local borderColor = to_argb(bgAlpha, 214, 178, 98) -- Warfarer Gold
  local sepColor = to_argb(math.min(180, bgAlpha), 100, 160, 180)

  -- Header text with live DPS
  local dps = 0
  local combatDuration = math.max(1.0, now - DamageLog.combat_start_time)
  if (now - DamageLog.last_hit_time) < 8.0 and combatDuration > 0 then
    dps = math.floor(DamageLog.recent_damage / combatDuration)
  end

  local headerStr = "[Combat Log]"
  if cfg.damage_log_show_dps and dps > 0 then
    headerStr = string.format("[Combat Log]  DPS: %s  Total: %s", format_number(dps), format_number(DamageLog.recent_damage))
  elseif cfg.damage_log_preview and #DamageLog.entries == 0 then
    headerStr = "[Combat Log]  (Preview Mode)"
  end

  -- Background box and gold border
  if d2d.fill_rounded_rect then
    d2d.fill_rounded_rect(x, y, w, h, 6.0, 6.0, bgColor)
  elseif d2d.fill_rect then
    d2d.fill_rect(x, y, w, h, bgColor)
  end

  if d2d.rounded_rect then
    d2d.rounded_rect(x, y, w, h, 6.0, 6.0, 1.5, borderColor)
  elseif d2d.outline_rect then
    d2d.outline_rect(x, y, w, h, 1.5, borderColor)
  end

  if d2d.line then
    d2d.line(x + 6, y + headerH, x + w - 6, y + headerH, 1.0, sepColor)
  end

  -- Header text
  if d2d_font_title and d2d.text then
    d2d.text(d2d_font_title, headerStr, x + 10, y + 5, to_argb(255, 216, 192, 138))
  end

  -- Damage lines with smooth fading and color highlights
  if d2d_font_line and d2d.text then
    for idx, entry in ipairs(active) do
      local lineY = y + headerH + 4 + ((idx - 1) * lineH)
      local age = now - entry.time
      local alphaK = 1.0
      if age > (duration - 1.0) then
        alphaK = math.max(0.0, duration - age)
      end
      local aByte = math.floor(alphaK * 255)
      if aByte > 0 then
        local tag = entry.isPawn and "[Pawn]" or "[Warfarer]"
        local dmgStr = format_number(entry.damage)
        if entry.isWeakPoint and cfg.damage_log_show_weakpoint then
          dmgStr = dmgStr .. " [WEAKPOINT!]"
        end
        local lineText = string.format("%s -> %s: %s", tag, entry.target, dmgStr)

        local lineCol = to_argb(aByte, 255, 255, 255)
        if entry.isWeakPoint then
          lineCol = to_argb(aByte, 255, 69, 0) -- Fire OrangeRed
        elseif entry.damage >= 1000 then
          lineCol = to_argb(aByte, 255, 215, 0) -- Radiant Gold
        elseif entry.isPawn then
          lineCol = to_argb(aByte, 160, 208, 255) -- Soft Cyan
        end

        d2d.text(d2d_font_line, lineText, x + 10, lineY, lineCol)
      end
    end
  end

  DamageLog.d2d_active = true
  DamageLog.d2d_last_rendered = os.clock()
  DamageLog.last_rendered_frame = frame
end

-- Multi-tier rendering loop (runs every frame in re.on_frame, always visible whether REFramework menu is open or closed)
function DamageLog.render_imgui()
  if not cfg.damage_log_enabled then return end
  local now = os.clock()
  -- If Direct2D is active and actively rendering in this exact session, avoid duplicate overlay
  if d2d_available and DamageLog.d2d_active and (now - (DamageLog.d2d_last_rendered or 0) < 0.2) then
    return
  end

  local duration = cfg.damage_log_duration or 5.0
  local maxLines = cfg.damage_log_max_lines or 8

  local active = {}
  for i = #DamageLog.entries, 1, -1 do
    local e = DamageLog.entries[i]
    local age = now - e.time
    if age < duration then
      table.insert(active, 1, e)
      if #active >= maxLines then break end
    end
  end

  if cfg.damage_log_preview and #active == 0 then
    table.insert(active, { damage = 380, target = "Goblin", isWeakPoint = false, isPawn = false, time = now })
    table.insert(active, { damage = 1450, target = "Cyclops", isWeakPoint = true, isPawn = false, time = now })
    if cfg.damage_log_include_pawns then
      table.insert(active, { damage = 210, target = "Harpy", isWeakPoint = false, isPawn = true, time = now })
    end
  end

  if #active == 0 then return end

  local sw, sh = screen_size()
  if not sw or not sh or sw <= 0 or sh <= 0 then sw, sh = 1920, 1080 end

  local bounds_x = 0
  local bounds_y = 0
  local bounds_w = sw
  local bounds_h = sh

  if cfg.damage_log_ultrawide_constrain ~= false and (sw / sh) > 1.8 then
    local safe_w = sh * (16.0 / 9.0)
    bounds_x = (sw - safe_w) * 0.5
    bounds_w = safe_w
  end

  local w = cfg.damage_log_width or 380
  local lineH = 22
  local headerH = 26
  local pad = 8
  local h = headerH + (#active * lineH) + pad

  local offX = cfg.damage_log_offset_x or 35
  local offY = cfg.damage_log_offset_y or 60

  local corner = cfg.damage_log_corner or 1
  local x, y
  if corner == 2 then x = bounds_x + offX; y = bounds_y + offY
  elseif corner == 4 then x = bounds_x + bounds_w - w - offX; y = bounds_y + offY
  elseif corner == 3 then x = bounds_x + bounds_w - w - offX; y = bounds_y + bounds_h - h - offY
  else x = bounds_x + offX; y = bounds_y + bounds_h - h - offY end

  x = math.max(0, math.min(sw - w, x))
  y = math.max(0, math.min(sh - h, y))

  local bgAlpha = math.floor(clamp(cfg.damage_log_bg_opacity or 0.70, 0.0, 1.0) * 255)
  -- ImGui uses ABGR (alpha << 24 | b << 16 | g << 8 | r)
  local bgColor = (bgAlpha << 24) | (22 << 16) | (18 << 8) | 18
  local borderColor = (bgAlpha << 24) | (98 << 16) | (178 << 8) | 214 -- Gold
  local sepColor = (math.min(180, bgAlpha) << 24) | (180 << 16) | (160 << 8) | 100

  local dps = 0
  local combatDuration = math.max(1.0, now - DamageLog.combat_start_time)
  if (now - DamageLog.last_hit_time) < 8.0 and combatDuration > 0 then
    dps = math.floor(DamageLog.recent_damage / combatDuration)
  end

  local headerStr = "[Combat Log]"
  if cfg.damage_log_show_dps and dps > 0 then
    headerStr = string.format("[Combat Log]  DPS: %s  Total: %s", format_number(dps), format_number(DamageLog.recent_damage))
  elseif cfg.damage_log_preview and #DamageLog.entries == 0 then
    headerStr = "[Combat Log]  (Preview Mode)"
  end

  -- Retrieve ImGui DrawList directly without requiring any window to be open
  local dl = nil
  if imgui.get_foreground_draw_list then
    local okf, fdl = pcall(imgui.get_foreground_draw_list)
    if okf and fdl then dl = fdl end
  end
  if not dl and imgui.get_background_draw_list then
    local okb, bdl = pcall(imgui.get_background_draw_list)
    if okb and bdl then dl = bdl end
  end

  local headerCol = 0xFFD8C08A -- Soft Arisen Gold

  if dl then
    pcall(function()
      dl:add_rect_filled(Vector2f.new(x, y), Vector2f.new(x + w, y + h), bgColor, 6.0)
      dl:add_rect(Vector2f.new(x, y), Vector2f.new(x + w, y + h), borderColor, 6.0, 0, 1.5)
      dl:add_line(Vector2f.new(x + 6, y + headerH), Vector2f.new(x + w - 6, y + headerH), sepColor, 1.0)
      dl:add_text(Vector2f.new(x + 10, y + 5), headerCol, headerStr)

      for idx, entry in ipairs(active) do
        local lineY = y + headerH + 4 + ((idx - 1) * lineH)
        local age = now - entry.time
        local alphaK = 1.0
        if age > (duration - 1.0) then alphaK = math.max(0.0, duration - age) end
        local aByte = math.floor(alphaK * 255)
        if aByte > 0 then
          local tag = entry.isPawn and "[Pawn]" or "[Warfarer]"
          local dmgStr = format_number(entry.damage)
          if entry.isWeakPoint and cfg.damage_log_show_weakpoint then
            dmgStr = dmgStr .. " [WEAKPOINT!]"
          end
          local lineText = string.format("%s -> %s: %s", tag, entry.target, dmgStr)
          local lineCol = (aByte << 24) | 0x00FFFFFF
          if entry.isWeakPoint then lineCol = (aByte << 24) | (0 << 16) | (69 << 8) | 255
          elseif entry.damage >= 1000 then lineCol = (aByte << 24) | (0 << 16) | (215 << 8) | 255
          elseif entry.isPawn then lineCol = (aByte << 24) | (255 << 16) | (208 << 8) | 160 end

          dl:add_text(Vector2f.new(x + 10, lineY), lineCol, lineText)
        end
      end
    end)
  else
    -- Fallback to native REFramework draw functions if draw list is unavailable
    pcall(draw.filled_rect, x, y, w, h, bgColor)
    pcall(draw.outline_rect, x, y, w, h, borderColor)
    pcall(draw.line, x + 6, y + headerH, x + w - 6, y + headerH, sepColor)
    pcall(draw.text, headerStr, x + 10, y + 5, headerCol)
    for idx, entry in ipairs(active) do
      local lineY = y + headerH + 4 + ((idx - 1) * lineH)
      local age = now - entry.time
      local alphaK = 1.0
      if age > (duration - 1.0) then alphaK = math.max(0.0, duration - age) end
      local aByte = math.floor(alphaK * 255)
      if aByte > 0 then
        local tag = entry.isPawn and "[Pawn]" or "[Warfarer]"
        local dmgStr = format_number(entry.damage)
        if entry.isWeakPoint and cfg.damage_log_show_weakpoint then
          dmgStr = dmgStr .. " [WEAKPOINT!]"
        end
        local lineText = string.format("%s -> %s: %s", tag, entry.target, dmgStr)
        local lineCol = (aByte << 24) | 0x00FFFFFF
        if entry.isWeakPoint then lineCol = (aByte << 24) | (0 << 16) | (69 << 8) | 255
        elseif entry.damage >= 1000 then lineCol = (aByte << 24) | (0 << 16) | (215 << 8) | 255
        elseif entry.isPawn then lineCol = (aByte << 24) | (255 << 16) | (208 << 8) | 160 end
        pcall(draw.text, lineText, x + 10, lineY, lineCol)
      end
    end
  end

  DamageLog.last_rendered_frame = frame
end

-- Backward compatibility alias
function DamageLog.render()
  if not cfg.damage_log_enabled then return end
  local now = os.clock()
  if d2d_available and DamageLog.d2d_active and (now - (DamageLog.d2d_last_rendered or 0) < 0.2) then
    return
  end
  DamageLog.render_imgui()
end

-- Register Direct2D Hardware Drawing Loop
local function setup_d2d()
  if d2d_available then return end
  if not d2d or not d2d.register then return end
  pcall(function()
    d2d.register(
      function()
        pcall(function()
          pcall(function() d2d_font_title = d2d.Font.new("Arial", 15) end)
          if not d2d_font_title then pcall(function() d2d_font_title = d2d.Font.new("Tahoma", 15) end) end
          pcall(function() d2d_font_line = d2d.Font.new("Arial", 13) end)
          if not d2d_font_line then pcall(function() d2d_font_line = d2d.Font.new("Tahoma", 13) end) end
          d2d_available = true
          log_act("Combat Damage Log: Direct2D registered with native fonts")
        end)
      end,
      function()
        pcall(function()
          DamageLog.render_d2d()
        end)
      end
    )
  end)
end
pcall(setup_d2d)

-- Hook into game damage calculation via app.HitController:updateDamage
local damage_hook_initialized = false
local function init_damage_hook()
  if damage_hook_initialized then return end
  local ok, err = pcall(function()
    local hitCtrlType = sdk.find_type_definition("app.HitController")
    if not hitCtrlType then return end
    local mUpdate = hitCtrlType:get_method("updateDamage")
    if not mUpdate then return end

    damage_hook_initialized = true
    log_act("Combat Damage hook initialized on app.HitController:updateDamage")

    local curHitInfo = nil
    local curHitCtrl = nil
    local preDamage = 0

    sdk.hook(mUpdate,
      function(args)
        if not cfg.damage_log_enabled then
          curHitInfo = nil
          curHitCtrl = nil
          preDamage = 0
          return
        end

        curHitCtrl = sdk.to_managed_object(args[2])
        curHitInfo = sdk.to_managed_object(args[3])
        if not curHitCtrl or not curHitInfo then return end

        preDamage = extract_damage(curHitInfo)
      end,
      function(retval)
        if not cfg.damage_log_enabled or not curHitInfo or not curHitCtrl then
          curHitInfo = nil
          curHitCtrl = nil
          preDamage = 0
          return retval
        end

        local hitCtrl = curHitCtrl
        local hitInfo = curHitInfo
        local preDmg = preDamage
        curHitInfo = nil
        curHitCtrl = nil
        preDamage = 0

        pcall(function()
          local targetChara = get_character_from_hit_ctrl(hitCtrl)
          if not targetChara or is_player_entity(targetChara) then return end

          local dmg = extract_damage(hitInfo)
          if dmg <= 0 and preDmg > 0 then
            dmg = preDmg
          end
          if dmg <= 0 and retval then
            local rNum = tonumber(sdk.to_int64(retval))
            if rNum and rNum > 0 and rNum < 10000000 then
              dmg = rNum
            end
          end
          if dmg <= 0 then return end

          -- Player and pawn references
          local isPlayer = false
          local isPawn = false

          local atkObj = nil
          pcall(function() atkObj = hitInfo:get_AttackOwnerObject() or hitInfo:get_field("AttackOwnerObject") end)
          local atkChara = nil
          pcall(function() atkChara = hitInfo:get_AttackOwnerCharacter() or hitInfo:get_field("AttackOwnerCharacter") end)

          if is_player_entity(atkChara) or is_player_entity(atkObj) then
            isPlayer = true
          elseif is_pawn_entity(atkChara) or is_pawn_entity(atkObj) then
            isPawn = true
          else
            -- Attribute to player
            isPlayer = true
          end

          if not isPlayer and not (cfg.damage_log_include_pawns and isPawn) then
            return
          end

          -- Resolve target enemy name
          local targetName = "Enemy"
          pcall(function()
            local n = targetChara:get_Name()
            if n and n ~= "" and n ~= "GameObject" then targetName = n end
          end)
          local targetGO = mcall(targetChara, "get_GameObject()")
          if targetName == "Enemy" and targetGO then
            pcall(function()
              local gn = targetGO:get_Name()
              if gn and gn ~= "" and gn ~= "GameObject" then targetName = gn end
            end)
          end
          targetName = targetName:gsub("^em%d+_", ""):gsub("^ch%d+_", ""):gsub("_", " ")

          local isWeak = is_weakpoint(hitInfo)

          DamageLog.add(dmg, targetName, isWeak, isPawn)
          log_once("first_dmg_logged", "Combat damage logged: " .. dmg .. " to " .. targetName .. (isWeak and " [WEAKPOINT]" or ""))
        end)

        return retval
      end
    )
  end)
  if not ok and err then
    log_act("init_damage_hook error: " .. tostring(err))
  end
end
init_damage_hook()

------------------------------------------------------------------------------------------------
-- Gameplay Tweaks: Incantation Speed & Fall Damage Disabler
------------------------------------------------------------------------------------------------
local gameplay_tweaks_initialized = false
local function init_gameplay_tweaks()
  if gameplay_tweaks_initialized then return end
  local ok, err = pcall(function()
    gameplay_tweaks_initialized = true

    -- Dedicated Fall Damage & Fall Death hooks (Surgically hook only fall methods so combat damage is 100% normal)
    local hook_fall_method = function(type_name, method_name, is_void_skip, is_height, is_bool_false)
      local td = sdk.find_type_definition(type_name)
      if not td then return end
      local m = td:get_method(method_name)
      if not m then return end
      log_act("Hooking fall method: " .. type_name .. ":" .. method_name)
      pcall(function()
        if is_void_skip then
          sdk.hook(m, function(args)
            if cfg.no_fall_damage then
              local thisObj = sdk.to_managed_object(args[2])
              if not thisObj or is_player_entity(thisObj) then
                return sdk.PreHookResult.SKIP_ORIGINAL
              end
            end
          end, nil)
        elseif is_height then
          sdk.hook(m, nil, function(retval)
            if cfg.no_fall_damage then
              return sdk.float_to_ptr(999999.0)
            end
            return retval
          end)
        elseif is_bool_false then
          sdk.hook(m, nil, function(retval)
            if cfg.no_fall_damage then
              return sdk.to_ptr(0)
            end
            return retval
          end)
        end
      end)
    end

    -- Landing damage handlers (skip original execution on player so fall impacts deal 0 damage & no loss gauge)
    hook_fall_method("app.Human", "Chara_DamageFromFallHandler", true, false, false)
    hook_fall_method("app.Character", "callDamageFromFallHandlerIfNeeded", true, false, false)
    hook_fall_method("app.Character", "requestFallDead", true, false, false)
    hook_fall_method("app.Character", "set_IsArisenFallDead", true, false, false)
    hook_fall_method("app.Character", "set_IsFallDead", true, false, false)
    hook_fall_method("app.Character", "set_IsDamageFall", true, false, false)
    hook_fall_method("app.Human", "set_IsDamageFromFall", true, false, false)

    -- Fall height thresholds (override to 999,999m so fall height is never considered lethal or damaging)
    hook_fall_method("app.Character", "get_HeightDamageFromFallProp", false, true, false)
    hook_fall_method("app.Character", "get_HeightDieFromFallProp", false, true, false)

    -- Fall status & boolean queries (return false so player never enters fall-damaged / fall-dead state)
    hook_fall_method("app.Character", "get_IsArisenFallDead", false, false, true)
    hook_fall_method("app.Character", "get_IsFallDead", false, false, true)
    hook_fall_method("app.Character", "get_IsDamageFall", false, false, true)
    hook_fall_method("app.Character", "get_IsDamageFallAction", false, false, true)
    hook_fall_method("app.Human", "get_IsDamageFallHeight", false, false, true)
    hook_fall_method("app.Human", "get_IsDamageFromFall", false, false, true)

    -- Dedicated Magic Incantation Speed hooks
    local hook_spell_speed = function(type_name, method_name, is_time)
      local td = sdk.find_type_definition(type_name)
      if not td then return end
      local m = td:get_method(method_name)
      if not m then return end
      log_act("Hooking spellcasting method: " .. type_name .. ":" .. method_name)
      pcall(function()
        sdk.hook(m, nil, function(retval)
          if cfg.incantation_speed_mult and cfg.incantation_speed_mult > 1.001 then
            local v = sdk.to_float(retval)
            if v and v > 0 then
              if is_time then
                return sdk.float_to_ptr(v / cfg.incantation_speed_mult)
              else
                return sdk.float_to_ptr(v * cfg.incantation_speed_mult)
              end
            end
          end
          return retval
        end)
      end)
    end

    hook_spell_speed("app.Job06Parameter", "getPrepareSpellTime", true)
    hook_spell_speed("app.Job03Parameter", "get_AddRateForPreparingSpellWhileWalkingProp", false)
    hook_spell_speed("app.Job03Parameter", "get_AddRateForPreparingSpellWhileRunningProp", false)
    hook_spell_speed("app.Job03Parameter", "get_AddRateForPreparingSpellWhileLevitatingProp", false)
    hook_spell_speed("app.Job03Parameter", "get_AddRateForPreparingSpellWhileConcentrateProp", false)

    -- Dynamic scanner for additional chant / spell preparation rates
    local spellTypes = {
      "app.Job03Parameter",
      "app.Job06Parameter",
      "app.Job07Parameter",
      "app.Job08Parameter",
      "app.JobPrepareSpell",
      "app.Job03PrepareSpell",
      "app.Job06PrepareSpell",
      "app.JobMagicUserPrepareSpell",
      "app.HumanConcentratePrepareSpell",
      "app.JobMagicUserActionContext.PrepareSpellInformation",
    }
    for _, typeName in ipairs(spellTypes) do
      local td = sdk.find_type_definition(typeName)
      if td then
        local methods = td:get_methods()
        if methods then
          for _, m in ipairs(methods) do
            local mName = m:get_name()
            local mLower = mName:lower()
            if (mLower:find("chant") or mLower:find("magic") or mLower:find("spell")) and (mLower:find("speed") or mLower:find("time") or mLower:find("rate")) then
              local retType = m:get_return_type()
              local retName = retType and retType:get_full_name() or ""
              if retName == "System.Single" or retName == "System.Double" then
                pcall(function()
                  sdk.hook(m, nil, function(retval)
                    if cfg.incantation_speed_mult and cfg.incantation_speed_mult > 1.001 then
                      local v = sdk.to_float(retval)
                      if v and v > 0 then
                        if mLower:find("time") then
                          return sdk.float_to_ptr(v / cfg.incantation_speed_mult)
                        else
                          return sdk.float_to_ptr(v * cfg.incantation_speed_mult)
                        end
                      end
                    end
                    return retval
                  end)
                end)
              end
            end
          end
        end
      end
    end
  end)
  if not ok and err then
    log_act("init_gameplay_tweaks error: " .. tostring(err))
  end
end
init_gameplay_tweaks()

------------------------------------------------------------------------------------------------
-- Frame loop and hooks
------------------------------------------------------------------------------------------------
re.on_frame(function()
  -- Render combat damage log safely
  pcall(DamageLog.render)
  if not d2d_available and d2d and d2d.register and frame % 60 == 0 then
    pcall(setup_d2d)
  end
  if not damage_hook_initialized and frame % 30 == 0 then
    init_damage_hook()
  end
  if not gameplay_tweaks_initialized and frame % 30 == 0 then
    init_gameplay_tweaks()
  end
  pcall(update_menu_equip_rearm)

  -- Check Preset Cycle Hotkey
  if cfg.enabled and cfg.skill_swap_enabled and cfg.hotkey_skill_swap and #cfg.hotkey_skill_swap > 0 then
    local swapVk = cfg.hotkey_skill_swap[1]
    if swapVk and is_vk_down(swapVk) then
      if not Presets.swap_key_down then
        Presets.swap_key_down = true
        local wj = read_weapon_job()
        if wj then Presets.cycle(wj) end
      end
    else
      Presets.swap_key_down = false
    end
  end

  -- Draw preset notifications
  if Presets.notification_timer > 0 then
    Presets.notification_timer = Presets.notification_timer - 1
    if Presets.notification_timer > 0 and Presets.notification_text ~= "" then
      local draw_list = imgui.get_background_draw_list()
      draw_list:add_rect_filled(Vector2f.new(30, 30), Vector2f.new(420, 75), 0xDD141414)
      draw_list:add_rect(Vector2f.new(30, 30), Vector2f.new(420, 75), 0xFFB4A064, 0, 0, 2.0)
      draw_list:add_text(Vector2f.new(45, 42), 0xFFFFFFFF, Presets.notification_text)
    end
  end
  frame = frame + 1
  local ok, err = pcall(function()
    if frame % 10 == 0 or P.char == nil then refresh_player() end
    Track.update()
    SW.update()
    Ico.tick()
    Bg.tick()
    if P.job == cfg.warfarer_job and frame - Arisen.at >= 30 then Arisen.refresh() end
    Bind.update()
    if not cfg.pad_inited and frame >= 5 then               -- first run: the controller button is Select / View, found by name
      cfg.pad_inited = true
      mark_dirty()
      local v, n = Pad.default_button()
      if v and cfg.pad_button == 0 then
        cfg.pad_button = v
        log_act("Controller button: " .. n .. " (hold it to open the wheel)")
      else
        log_act("No Select / View button found by name in via.hid.GamePadButton: bind one in the Controller settings")
      end
    end
    handle_hotkey()
    Slow.update()
    if dirty and frame % 90 == 0 then save_cfg() end
  end)
  if not ok then last_error = tostring(err) end
  Dim.step(W.open or W.pinned)
  if W.open or W.pinned then
    local okr, errr = pcall(render_wheel)
    if not okr then last_error = tostring(errr); Ico.fast, Ico.fast_n = false, -1000 end
  else
    if Bg.tail > 0 or Dim.k > 0 then
      local okc, errc = pcall(render_cover)
      if not okc then last_error = tostring(errc) end
    end
    if frame < Safety.notice_until then pcall(render_notice) end
  end
end)

pcall(function()
  local td = sdk.find_type_definition("app.GuiManager")
  local m = td and td:get_method("OnChangeSceneType")
  if m then
    sdk.hook(m, function()
      if W.open then W.open = false; Slow.force_restore() end
      SW.want, SW.inst, Track.prev, Track.hand_wid, Track.prev_wid, Track.guessed = nil, nil, nil, nil, nil, false
      Ico.cells, Ico.shown, Ico.dead, Ico.res, Ico.retry_at = {}, false, 0, nil, 0   -- the spawned GUIs belong to the old scene
      Bg.reset()
      Arisen.list, Arisen.equip, Arisen.index = {}, nil, nil
      P.char = nil
    end, function(r) return r end)
  end
end)
re.on_script_reset(function() pcall(Ico.destroy_all); pcall(Bg.destroy); Slow.force_restore(); if dirty then save_cfg() end end)
re.on_config_save(function() save_cfg() end)

------------------------------------------------------------------------------------------------
-- REFramework UI
------------------------------------------------------------------------------------------------
local function reset_setting(key)
  if DEFAULTS[key] ~= nil then
    cfg[key] = deep_copy(DEFAULTS[key])
    mark_dirty()
    if key == "theme" then cfg.theme = deep_copy(THEME_DEFAULT) end
  end
end

local function reset_keys(keys)
  for _, k in ipairs(keys) do
    if DEFAULTS[k] ~= nil then
      cfg[k] = deep_copy(DEFAULTS[k])
    end
  end
  mark_dirty()
end

local function reset_all_defaults()
  for k, v in pairs(DEFAULTS) do
    if k ~= "vocation_presets" then
      cfg[k] = deep_copy(v)
    end
  end
  cfg.theme = deep_copy(THEME_DEFAULT)
  mark_dirty()
end

local function ui_reset_btn(key)
  imgui.same_line()
  if imgui.button("Reset##res_" .. key) then
    reset_setting(key)
  end
end

local function ui_check(label, key, noReset)
  local c, v = imgui.checkbox(label, cfg[key])
  if c then cfg[key] = v; mark_dirty() end
  if not noReset then ui_reset_btn(key) end
end
local function ui_float(label, key, lo, hi, fmt, noReset)
  local c, v = imgui.slider_float(label, cfg[key], lo, hi, fmt or "%.2f")
  if c then cfg[key] = v; mark_dirty() end
  if not noReset then ui_reset_btn(key) end
end
local function ui_int(label, key, lo, hi, noReset)
  local c, v = imgui.slider_int(label, cfg[key], lo, hi)
  if c then cfg[key] = math.floor(v); mark_dirty() end
  if not noReset then ui_reset_btn(key) end
end
local function ui_combo(label, key, items, noReset)
  local c, v = imgui.combo(label, cfg[key], items)
  if c then cfg[key] = math.floor(v); mark_dirty() end
  if not noReset then ui_reset_btn(key) end
end
local GOLD, RED = abgr(THEME_DEFAULT.accent), 0xFF7878FF

local function draw_theme()
  for _, e in ipairs(THEME_LABELS) do
    local key, label = e[1], e[2]
    local c, v = imgui.color_edit(label .. "##th_" .. key, abgr(T(key)))
    if c and type(v) == "number" then
      cfg.theme[key] = { v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF }
      mark_dirty()
    end
  end
  if imgui.button("Reset colours") then cfg.theme = deep_copy(THEME_DEFAULT); mark_dirty() end
end

local function draw_main_ui()
  imgui.text("Version " .. VERSION)
  imgui.same_line()
  if imgui.button("Restore All Mod Settings to Defaults##res_all_master") then
    reset_all_defaults()
  end
  if imgui.button("Restore General Defaults##res_sec_gen") then
    reset_keys({ "enabled", "skill_wheel", "skill_hold", "order_mode", "show_name" })
  end
  ui_check("Enabled", "enabled")
  ui_check("Open the wheel when holding the Rearmament skill (a short tap is a normal Rearmament)", "skill_wheel")
  if cfg.skill_wheel then
    ui_float("  Hold time before it opens (seconds)", "skill_hold", 0.1, 1.0)
    if Skill.msg then imgui.text_colored("  " .. Skill.msg, 0xFFA0A0A0) end
  end
  ui_combo("Wheel order", "order_mode", { "Rearmament order", "Vocation order" })
  ui_check("Show the vocation name next to the wheel", "show_name")

  imgui.separator()
  if imgui.button("Restore Slow Motion Defaults##res_sec_slow") then
    reset_keys({ "slowmo_enabled", "slowmo_scale", "dim_enabled", "dim_alpha" })
  end
  ui_check("Slow motion while the wheel is open", "slowmo_enabled")
  ui_float("Time scale", "slowmo_scale", 0.05, 1.0)
  ui_check("Dim the background while the wheel is open", "dim_enabled")
  ui_float("Dim strength", "dim_alpha", 0.0, 0.95)
  imgui.separator()

  imgui.text_colored("Controls", GOLD)
  imgui.text("Hotkey: " .. hotkey_str())
  imgui.same_line()
  if Bind.state then
    imgui.text_colored(Bind.state == "release" and "release all keys..." or "press key(s) / mouse button(s), Esc cancels", GOLD)
  elseif imgui.button("Bind") then
    Bind.start()
  end
  imgui.same_line()
  if imgui.button("Clear##hk") then cfg.hotkey = {}; mark_dirty() end
  imgui.same_line()
  if imgui.button("Restore Controller Defaults##res_sec_pad") then
    reset_keys({ "pad_enabled", "pad_type", "pad_button", "pad_combo", "pad_button2", "pad_hold", "pad_stick", "pad_dead", "pad_flip_y" })
  end
  imgui.text("Hold the hotkey, steer with the mouse, release to pick.")
  imgui.spacing()
  imgui.spacing()
  imgui.spacing()
  ui_check("Controller support", "pad_enabled")
  ui_combo("Controller type (button names)", "pad_type", { "Auto", "Xbox", "PlayStation" })
  imgui.text("Using " .. (Pad.kind() == "ps" and "PlayStation" or "Xbox") .. " button names" .. (cfg.pad_type == 1 and " (found from the connected controller)" or ""))
  local m = Pad.menu_items()
  if #m.vals <= 1 then
    imgui.text("via.hid.GamePadButton was not found: no button list to choose from")
  else
    local items, idx = m.items, 1
    for i, v in ipairs(m.vals) do if v == cfg.pad_button then idx = i; break end end
    if cfg.pad_button ~= 0 and idx == 1 then                    -- a value that is not one single button (an older binding)
      items = { table.unpack(m.items) }
      items[#items + 1] = string.format("custom 0x%X", cfg.pad_button)
      idx = #items
    end
    local ch, ni = imgui.combo("Button (hold it, steer with the stick, release to pick)##padbtn", idx, items)
    if ch and m.vals[ni] ~= nil then
      cfg.pad_button, cfg.pad_getter, cfg.pad_inited = m.vals[ni], "get_Button", true
      mark_dirty()
    end
    imgui.same_line()
    if imgui.button("Reset (" .. Pad.OFFICIAL[Pad.kind()].CLeft .. ")##paddefault") then
      local v = Pad.default_button()
      if v then cfg.pad_button, cfg.pad_getter, cfg.pad_inited = v, "get_Button", true; mark_dirty() end
    end
    local cc, cv = imgui.checkbox("Open with a combination of two buttons (hold both)##padcombo", cfg.pad_combo)
    if cc then
      cfg.pad_combo = cv
      if cv and cfg.pad_button2 == 0 then                     -- first time: the left bumper as the second button
        for _, e in ipairs(Pad.load_enum()) do if e.name == "LTrigTop" then cfg.pad_button2 = e.value end end
      end
      mark_dirty()
    end
    if cfg.pad_combo then
      local idx2 = 1
      for i, v in ipairs(m.vals) do if v == cfg.pad_button2 then idx2 = i; break end end
      local ch2, ni2 = imgui.combo("Second button##padbtn2", idx2, m.items)
      if ch2 and m.vals[ni2] ~= nil then cfg.pad_button2 = m.vals[ni2]; mark_dirty() end
    end
  end
  ui_float("Hold time before the wheel opens (seconds)", "pad_hold", 0.1, 1.5)
  ui_combo("Stick that steers the wheel", "pad_stick", { "Right stick", "Left stick", "Either stick" })
  ui_int("Stick dead zone (%)", "pad_dead", 10, 90)
  ui_check("Flip the stick's up / down (if the wheel picks the opposite slice)", "pad_flip_y")
  imgui.text(string.format("Controller %s | down now: %s | right stick %.2f, %.2f | left stick %.2f, %.2f",
    Pad.ok and "found" or "NOT found", Pad.label(Pad.read(), cfg.pad_getter), (Pad.sticks() or Pad.rx), Pad.ry, Pad.lx, Pad.ly))
  if imgui.tree_node("Controller dump (for troubleshooting)##paddumptree") then
    if imgui.button("Dump the controller's values (hold the button first)##paddump") then pcall(Pad.dump) end
    imgui.same_line()
    if imgui.button("Copy##padcopy") then pcall(sdk.copy_to_clipboard, Pad.text) end
    imgui.input_text_multiline("##padbox", Pad.text, Vector2f.new(0, 150))
    if imgui.tree_node("Button names the game knows##padnames") then
      local parts = {}
      for _, e in ipairs(Pad.load_enum()) do parts[#parts + 1] = string.format("%s=0x%X", e.name, e.value) end
      imgui.text(#parts > 0 and table.concat(parts, "  ") or "via.hid.GamePadButton was not found")
      imgui.tree_pop()
    end
    imgui.tree_pop()
  end
  imgui.separator()

  if imgui.tree_node("Look") then
    if imgui.button("Restore Look Defaults##res_sec_look") then
      reset_keys({ "scale", "auto_scale", "wheel_radius", "inner_radius", "center_radius", "slice_gap_deg", "hl_alpha", "game_bg", "game_icons", "hide_center_weapon", "hide_center_job", "icon_size_k", "font_file" })
    end
    ui_float("Scale", "scale", 0.5, 2.0)
    ui_check("Scale with screen height", "auto_scale")
    ui_int("Outer radius", "wheel_radius", 120, 500)
    ui_int("Inner radius", "inner_radius", 60, 400)
    ui_int("Centre radius", "center_radius", 40, 300)
    ui_float("Slice gap (deg)", "slice_gap_deg", 0, 10, "%.1f")
    ui_int("Highlight opacity over the hovered slice", "hl_alpha", 0, 255)
    ui_check("Use the game's menu background for the wheel", "game_bg")
    ui_check("Use the game's own vocation icons", "game_icons")
    ui_check("Hide the weapon name in the inner circle", "hide_center_weapon")
    ui_check("Hide the vocation name in the inner circle", "hide_center_job")
    ui_float("Icon size", "icon_size_k", 0.6, 1.6)
    local fm = Fonts.menu()
    local fch, fni = imgui.combo("Font##wwfont", fm.index, fm.items)
    if fch and fm.files[fni] ~= nil then cfg.font_file = fm.files[fni]; cfg.font_gen = cfg.font_gen + 1; mark_dirty() end
    if cfg.font_file == "" then
      imgui.text("Using REFramework's default font.")
    elseif cfg.font_file ~= Fonts.loaded_for then
      imgui.text_colored("Reset scripts to apply this font.", GOLD)
    else
      Fonts.check()
      if Fonts.found == true then
        imgui.text("Using " .. cfg.font_file)
      elseif Fonts.found == false then
        imgui.text_colored(cfg.font_file .. " was not loaded. Make sure it is in the game's reframework\\fonts folder, then reset scripts once more.", RED)
      end
    end
    imgui.text("A Windows font is copied by hand from C:\\Windows\\Fonts into <game folder>\\reframework\\fonts (REFramework can not read other folders).")

    if imgui.tree_node("Colours") then draw_theme(); imgui.tree_pop() end
    local c, v = imgui.checkbox("Preview: keep the wheel open (no slow motion, no switching)", W.pinned)
    if c then W.pinned = v; if v then prepare_wheel() end end
    imgui.tree_pop()
  end

  if imgui.tree_node("Mouse") then
    if imgui.button("Restore Mouse Defaults##res_sec_mouse") then
      reset_keys({ "select_mode", "mouse_source", "mouse_sens", "deadzone", "stick_max", "cancel_rmb", "block_input_while_open" })
    end
    ui_combo("Selection mode", "select_mode", { "Relative (GTA style)", "Absolute cursor" })
    ui_combo("Movement source", "mouse_source", { "Auto", "via.hid delta", "via.hid position diff", "imgui position diff" })
    ui_float("Sensitivity", "mouse_sens", 0.1, 5.0)
    ui_int("Deadzone", "deadzone", 1, 80)
    ui_int("Stick range", "stick_max", 20, 400)
    ui_check("Right mouse cancels", "cancel_rmb")
    ui_check("Block game input while the wheel is open", "block_input_while_open")
    imgui.tree_pop()
  end

  --------------------------------------------------------------------------------------------------
  -- Vocation Skillsets (6 Skill Slots per Preset) & Dark Arisen DLC
  --------------------------------------------------------------------------------------------------
  imgui.separator()
  if imgui.tree_node("Vocation Skillsets (6 Skill Slots) & Dark Arisen DLC") then
    if imgui.button("Restore Skillset Settings to Defaults##res_sec_skills") then
      reset_keys({ "skill_swap_enabled", "rearmament_stamina_consumption", "filter_guild_skills_by_weapon", "show_swap_notification", "load_guild_class_skills", "unlock_all_skills_in_presets", "free_rearmament_slot" })
    end
    ui_check("Enable Skillset Presets Swapping", "skill_swap_enabled")
    ui_check("Free Rearmament Slot (All 4 slots for class skills; swap weapons freely)", "free_rearmament_slot")
    ui_check("Rearmament Consumes Stamina", "rearmament_stamina_consumption")
    ui_check("Filter Vocation Guild Skills by Equipped Weapon", "filter_guild_skills_by_weapon")
    ui_check("Show Preset Swap Notification", "show_swap_notification")
    ui_check("Auto-load Skills Assigned to Class at Guild on Weapon Swap", "load_guild_class_skills")
    ui_check("Unlock All Skills in Presets & Swapping (even if not yet learned)", "unlock_all_skills_in_presets")

    if imgui.button("Import Current Guild Skills into Presets##imp_guild") then
      local n = Presets.import_guild_skills()
      log_act("Imported " .. n .. " guild skills into presets.")
      mark_dirty()
    end
    imgui.same_line()
    imgui.text_colored("(Copies currently equipped guild skills into Preset 1)", 0xFFAAAAAA)

    imgui.text("Skillset Cycle Hotkey: " .. hotkey_str(cfg.hotkey_skill_swap))
    imgui.same_line()
    if imgui.button("Bind Cycle Key##bind_swap") then
      Bind.start()
      -- Use hotkey binding for swap key
    end
    imgui.same_line()
    if imgui.button("Reset to L-Alt##reset_swap") then
      cfg.hotkey_skill_swap = { 0xA4 }
      mark_dirty()
    end

    if imgui.button("Refresh Skills Database (Dark Arisen / Game Scan)##refskills") then
      Presets.refresh_database()
    end

    imgui.separator()
    imgui.text_colored("Configure 6 Skill Slots for Each Vocation (including Dark Arisen DLC skills):", GOLD)

    local SLOT_LABELS = {
      "Slot 1: Left (X / [] / Square)",
      "Slot 2: Top (Y / Triangle)",
      "Slot 3: Bottom (A / Cross)",
      "Slot 4: Right (B / Circle)",
      "Slot 5: Left Bumper / Modifier 1",
      "Slot 6: Right Bumper / Modifier 2"
    }

    ensure_vocation_presets()
    local curWpJob = read_weapon_job()

    for j = 1, 9 do
      local jInfo = JOBS[j]
      local vp = cfg.vocation_presets[j]
      local isActive = (j == curWpJob)
      local header = (jInfo and jInfo.name or ("Vocation " .. j)) .. (isActive and " [ACTIVE]" or "")

      if imgui.tree_node(header .. "##jobnode_" .. j) then
        -- Build skill options for this vocation
        local skillOptions = {}
        local skillIds = {}
        local jobSkills = Presets.active_skills_by_job[j] or {}
        if #jobSkills == 0 and VOCATION_SKILL_DATABASE[j] then
          jobSkills = VOCATION_SKILL_DATABASE[j].skills
        end

        for _, sk in ipairs(jobSkills) do
          local sname = sk.name or Presets.resolve_skill_name(j, sk.id, 1)
          table.insert(skillOptions, tostring(sk.id) .. " - " .. sname)
          table.insert(skillIds, sk.id)
        end
        table.insert(skillOptions, "100 - Rearmament")
        table.insert(skillIds, 100)

        if vp and vp.presets then
          for pIdx, pr in ipairs(vp.presets) do
            imgui.push_id("job_" .. j .. "_preset_" .. pIdx)
            local isCurrentPreset = (pIdx == vp.currentPresetIndex)
            if isCurrentPreset and isActive then
              imgui.text_colored("* Active Preset", 0xFF66FF66)
            end

            local c_pn, n_pn = imgui.input_text("Preset Name", pr.name or ("Preset " .. pIdx))
            if c_pn then pr.name = n_pn; mark_dirty() end

            -- 6 SKILL SLOTS
            for slot = 1, 6 do
              local curId = pr.skills[slot] or 100
              local cIdx = 1
              for idx, sid in ipairs(skillIds) do
                if sid == curId then cIdx = idx; break end
              end

              local c_sk, n_sk = imgui.combo(SLOT_LABELS[slot], cIdx, skillOptions)
              if c_sk and n_sk and skillIds[n_sk] then
                pr.skills[slot] = skillIds[n_sk]
                mark_dirty()
                if isActive and isCurrentPreset then
                  Presets.apply(j)
                end
              end
            end

            if #vp.presets > 1 then
              if imgui.button("Delete Preset##del_" .. j .. "_" .. pIdx) then
                table.remove(vp.presets, pIdx)
                if vp.currentPresetIndex > #vp.presets then
                  vp.currentPresetIndex = #vp.presets
                end
                mark_dirty()
                imgui.pop_id()
                break
              end
            end

            imgui.separator()
            imgui.pop_id()
          end

          if #vp.presets < cfg.max_presets_toggle then
            if imgui.button("Add New Preset##add_" .. j) then
              table.insert(vp.presets, {
                name = "Preset " .. (#vp.presets + 1),
                skills = { 100, 100, 100, 100, 100, 100 }
              })
              mark_dirty()
            end
          end
        end

        imgui.tree_pop()
      end
    end

    imgui.tree_pop()
  end

  --------------------------------------------------------------------------------------------------
  -- Combat Damage Log UI (HUD Chat Overlay)
  --------------------------------------------------------------------------------------------------
  imgui.separator()
  if imgui.tree_node("Combat Damage Log (HUD Chat Overlay)") then
    if imgui.button("Restore Damage Log Defaults##res_sec_dmg") then
      reset_keys({ "damage_log_enabled", "damage_log_preview", "damage_log_corner", "damage_log_max_lines", "damage_log_duration", "damage_log_width", "damage_log_bg_opacity", "damage_log_offset_x", "damage_log_offset_y", "damage_log_player_only", "damage_log_include_pawns", "damage_log_show_weakpoint", "damage_log_show_dps", "damage_log_ultrawide_constrain" })
    end
    imgui.separator()
    ui_check("Enable Combat Damage Log", "damage_log_enabled")
    if cfg.damage_log_enabled then
      ui_check("Preview Damage Log in HUD (Keeps visible on-screen for positioning)", "damage_log_preview")
      local CORNERS = { "Bottom-Left", "Top-Left", "Bottom-Right", "Top-Right" }
      ui_combo("Screen Corner", "damage_log_corner", CORNERS)
      ui_check("Constrain to 16:9 HUD Area (Ultrawide displays)", "damage_log_ultrawide_constrain")
      imgui.text_colored("(Aligns to centered 16:9 HUD area on 21:9 / 32:9 monitors rather than outer screen edge)", 0xFFAAAAAA)
      ui_check("Only Log Player (Warfarer) & Pawn Damage", "damage_log_player_only")
      ui_check("Include Pawn Damage", "damage_log_include_pawns")
      ui_check("Highlight Weakpoint / Critical Hits", "damage_log_show_weakpoint")
      ui_check("Show Encounter DPS & Total Damage Header", "damage_log_show_dps")
      ui_int("Max Displayed Lines", "damage_log_max_lines", 3, 20)
      ui_float("Message Duration (seconds)", "damage_log_duration", 1.0, 15.0)
      ui_int("Log Width (px)", "damage_log_width", 250, 600)
      ui_float("Background Opacity", "damage_log_bg_opacity", 0.0, 1.0)
      ui_int("Screen Margin X (px)", "damage_log_offset_x", 0, 500)
      ui_int("Screen Margin Y (px)", "damage_log_offset_y", 0, 500)

      if imgui.button("Send Test Log Entries##test_dmg") then
        DamageLog.add(380, "Goblin", false, false)
        DamageLog.add(1450, "Cyclops", true, false)
        DamageLog.add(210, "Harpy", false, true)
      end
      imgui.same_line()
      imgui.text_colored("(Sends 3 live test damage entries to test fading)", 0xFFAAAAAA)
    end
    imgui.tree_pop()
  end

  --------------------------------------------------------------------------------------------------
  -- Gameplay Tweaks (Incantation Speed & Fall Damage)
  --------------------------------------------------------------------------------------------------
  imgui.separator()
  if imgui.tree_node("Gameplay Tweaks (Incantation Speed & Fall Damage)") then
    if imgui.button("Restore Gameplay Defaults##res_sec_gameplay") then
      reset_keys({ "incantation_speed_mult", "no_fall_damage" })
    end
    imgui.separator()

    imgui.text_colored("--- Magic & Spellcasting ---", GOLD)
    ui_float("Incantation Speed Multiplier", "incantation_speed_mult", 1.0, 5.0, "%.2fx")
    imgui.text_colored("(Multiplies spell preparation & chant speed for Mage, Sorcerer, and magic vocations. 1.0 = Vanilla)", 0xFFAAAAAA)

    imgui.text("Quick Presets:")
    imgui.same_line()
    if imgui.button("1.0x (Normal)##inc_1") then cfg.incantation_speed_mult = 1.0; mark_dirty() end
    imgui.same_line()
    if imgui.button("1.5x##inc_15") then cfg.incantation_speed_mult = 1.5; mark_dirty() end
    imgui.same_line()
    if imgui.button("2.0x (Fast)##inc_2") then cfg.incantation_speed_mult = 2.0; mark_dirty() end
    imgui.same_line()
    if imgui.button("3.0x (Very Fast)##inc_3") then cfg.incantation_speed_mult = 3.0; mark_dirty() end
    imgui.same_line()
    if imgui.button("5.0x (Instant)##inc_5") then cfg.incantation_speed_mult = 5.0; mark_dirty() end

    imgui.separator()
    imgui.text_colored("--- World & Physics ---", GOLD)
    ui_check("Disable Fall Damage", "no_fall_damage")
    imgui.text_colored("(Prevents fatal fall thresholds and negates all fall impact damage for the Arisen)", 0xFFAAAAAA)

    imgui.tree_pop()
  end

  imgui.separator()

  if last_error then imgui.text_colored("Last error: " .. last_error, RED) end
end

re.on_draw_ui(function()
  if not d2d_available and DamageLog.last_rendered_frame ~= frame then
    pcall(DamageLog.render_imgui)
  end
  if not imgui.tree_node(MOD) then return end
  local ok, err = pcall(draw_main_ui)
  if not ok then imgui.text_colored("UI error: " .. tostring(err), RED) end
  imgui.tree_pop()
end)

log_act(MOD .. " v" .. VERSION .. " loaded. Hotkey: " .. hotkey_str())
pcall(function() Presets.refresh_database() end)

