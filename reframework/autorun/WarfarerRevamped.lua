--[[
  Denarmo's Warfarer Revamped
  ===========================
  The definitive Warfarer overhaul for Dragon's Dogma 2.
  Combines the best of Warfarer's Arsenal (radial weapon wheel, slow-mo selection,
  controller & mouse navigation) with Enhanced Warfarer Vocation (dynamic per-weapon
  skillsets, multiple presets, guild editing, stamina toggle, vocation HUD),
  fully upgraded with native support for Dragon's Dogma 2 DLC Dark Arisen and all
  new Obelisk weapon skills.

  Authors: Denarmo (merged & updated), socastix (Warfarer's Arsenal), keegarsc (Enhanced Warfarer Vocation)
  Version: 1.0.0
]]

local MOD_NAME = "Denarmo's Warfarer Revamped"
local MOD_VERSION = "1.0.0"
local CFG_FILE = "WarfarerRevamped/config.json"
local LEGACY_ARSENAL_CFG = "WarfarerArsenal/config.json"
local LEGACY_ENHANCED_CFG = "enhanced_warfarer_vocation.json"
local TAU = math.pi * 2
local REARMAMENT_SKILL_ID = 100
local WARFARER_JOB_ID = 10

----------------------------------------------------------------------------------------------------
-- Singletons & Helper Functions
----------------------------------------------------------------------------------------------------
local g_guiManager, g_charaManager, g_itemManager = nil, nil, nil

local function getGuiManager()
  if not g_guiManager then
    g_guiManager = sdk.get_managed_singleton("app.GuiManager")
  end
  return g_guiManager
end

local function getCharaManager()
  if not g_charaManager then
    g_charaManager = sdk.get_managed_singleton("app.CharacterManager")
  end
  return g_charaManager
end

local function getItemManager()
  if not g_itemManager then
    g_itemManager = sdk.get_managed_singleton("app.ItemManager")
  end
  return g_itemManager
end

local function getPlayer()
  local cm = getCharaManager()
  if cm then return cm:get_ManualPlayer() end
  return nil
end

local function deep_copy(orig)
  local t = type(orig)
  local copy
  if t == 'table' then
    copy = {}
    for k, v in next, orig, nil do copy[deep_copy(k)] = deep_copy(v) end
    setmetatable(copy, deep_copy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end

----------------------------------------------------------------------------------------------------
-- Vocations Definition
----------------------------------------------------------------------------------------------------
local JOBS = {
  [1]  = { name = "Fighter",          weapon = "Sword & Shield", abbr = "FI", icon = "dd2-fighter.png",          icon50 = "dd2-fighter-50.png" },
  [2]  = { name = "Archer",           weapon = "Bow",            abbr = "AR", icon = "dd2-archer.png",           icon50 = "dd2-archer-50.png" },
  [3]  = { name = "Mage",             weapon = "Staff",          abbr = "MA", icon = "dd2-mage.png",             icon50 = "dd2-mage-50.png" },
  [4]  = { name = "Thief",            weapon = "Daggers",        abbr = "TH", icon = "dd2-thief.png",            icon50 = "dd2-thief-50.png" },
  [5]  = { name = "Warrior",          weapon = "Two-Hander",     abbr = "WA", icon = "dd2-warrior.png",          icon50 = "dd2-warrior-50.png" },
  [6]  = { name = "Sorcerer",         weapon = "Archistaff",     abbr = "SO", icon = "dd2-sorcerer.png",         icon50 = "dd2-sorcerer-50.png" },
  [7]  = { name = "Mystic Spearhand", weapon = "Duospear",       abbr = "MS", icon = "dd2-mystic_spearhand.png", icon50 = "dd2-mystic_spearhand-50.png" },
  [8]  = { name = "Magick Archer",    weapon = "Magick Bow",     abbr = "MK", icon = "dd2-magick_archer.png",    icon50 = "dd2-magick_archer-50.png" },
  [9]  = { name = "Trickster",        weapon = "Censer",         abbr = "TR", icon = "dd2-trickster.png",        icon50 = "dd2-trickster-50.png" },
  [10] = { name = "Warfarer",         weapon = "Any",            abbr = "WF", icon = nil,                        icon50 = nil },
}

local MAISTER_SKILLS = { 12, 23, 37, 61, 68, 69, 79, 91, 99, 101 }
local MAISTER_JOB_MAP = {
  [12] = 1, [23] = 2, [37] = 3, [61] = 5, [68] = 6, [69] = 6,
  [79] = 7, [91] = 8, [99] = 9, [101] = 4
}

----------------------------------------------------------------------------------------------------
-- Default Configuration
----------------------------------------------------------------------------------------------------
local DEFAULT_CONFIG = {
  version = MOD_VERSION,
  enabled = true,

  -- Radial Weapon Selection Wheel
  wheel_enabled = true,
  order_mode = 1,               -- 1 = Rearmament order, 2 = Vocation order
  wheel_radius = 240,
  inner_radius = 115,
  center_radius = 92,
  slice_gap_deg = 2.0,
  dim_enabled = true,
  dim_alpha = 0.55,
  hide_center_weapon = false,
  hide_center_job = false,
  skill_wheel = true,           -- Hold Rearmament skill button to open wheel
  skill_hold = 0.25,            -- Seconds before wheel opens
  show_name = false,            -- Show hovered vocation name next to wheel
  slowmo_enabled = true,
  slowmo_scale = 0.3,
  hotkey_wheel = { 0x05 },      -- Mouse 4 / XButton1
  pad_enabled = true,
  pad_button = 0x0020,          -- Back / View button
  pad_hold = 0.35,
  pad_dead = 0.25,
  cancel_rmb = true,

  -- Skillsets & Presets System
  skill_swap_enabled = true,
  skill_swap_mode = "Toggle",   -- "Toggle" or "Hold"
  max_presets_toggle = 5,
  max_presets_hold = 2,
  hotkey_skill_swap = "LAlt",
  hotkey_rearmament = "R",
  show_swap_notification = true,
  rearmament_stamina_consumption = true,
  filter_guild_skills_by_weapon = true,
  show_guild_notification = true,

  -- Vocation Presets data
  vocation_presets = {}
}

for j = 1, 9 do
  DEFAULT_CONFIG.vocation_presets[j] = {
    id = j,
    name = JOBS[j].name:lower(),
    safeName = JOBS[j].name,
    currentPresetIndex = 1,
    presets = {
      { name = "Preset 1", skills = { REARMAMENT_SKILL_ID, REARMAMENT_SKILL_ID, REARMAMENT_SKILL_ID, REARMAMENT_SKILL_ID } }
    }
  }
end

local cfg = deep_copy(DEFAULT_CONFIG)

----------------------------------------------------------------------------------------------------
-- Configuration Load / Save & Legacy Migration
----------------------------------------------------------------------------------------------------
local function save_config()
  pcall(function()
    json.dump_file(CFG_FILE, cfg)
  end)
end

local function load_config()
  local loaded = json.load_file(CFG_FILE)
  if loaded and type(loaded) == "table" then
    for k, v in pairs(loaded) do
      if cfg[k] ~= nil then cfg[k] = v end
    end
    if loaded.vocation_presets then
      cfg.vocation_presets = loaded.vocation_presets
    end
  else
    -- Migrate from legacy Enhanced Warfarer config if present
    local legacy_ew = json.load_file(LEGACY_ENHANCED_CFG)
    if legacy_ew and type(legacy_ew) == "table" then
      if legacy_ew.ImageSet then
        for _, set in pairs(legacy_ew.ImageSet) do
          local jid = set.id
          if jid and cfg.vocation_presets[jid] then
            if set.presets and #set.presets > 0 then
              cfg.vocation_presets[jid].presets = set.presets
              cfg.vocation_presets[jid].currentPresetIndex = set.currentPresetIndex or 1
            end
          end
        end
      end
      if legacy_ew.SkillSwapMode then cfg.skill_swap_mode = legacy_ew.SkillSwapMode end
      if legacy_ew.RearmamentStaminaConsumption ~= nil then
        cfg.rearmament_stamina_consumption = legacy_ew.RearmamentStaminaConsumption
      end
      if legacy_ew.Hotkeys then
        if legacy_ew.Hotkeys.SkillSwap then cfg.hotkey_skill_swap = legacy_ew.Hotkeys.SkillSwap end
        if legacy_ew.Hotkeys.Rearmament then cfg.hotkey_rearmament = legacy_ew.Hotkeys.Rearmament end
      end
    end

    -- Migrate from legacy Warfarer Arsenal config if present
    local legacy_wa = json.load_file(LEGACY_ARSENAL_CFG)
    if legacy_wa and type(legacy_wa) == "table" then
      for _, key in ipairs({
        "order_mode", "wheel_radius", "inner_radius", "center_radius",
        "dim_enabled", "dim_alpha", "slowmo_enabled", "slowmo_scale",
        "skill_wheel", "skill_hold", "pad_button", "pad_hold"
      }) do
        if legacy_wa[key] ~= nil then cfg[key] = legacy_wa[key] end
      end
    end
    save_config()
  end
end

load_config()

----------------------------------------------------------------------------------------------------
-- Comprehensive Skills Database (Base Game + Dragon's Dogma 2 DLC Dark Arisen)
----------------------------------------------------------------------------------------------------
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
      { id = 24, name = "Flagration" },        -- Shared with Mage
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

local g_activeSkillsByJob = {}
local g_guiBaseInstance = nil

local function getGuiBase()
  if not g_guiBaseInstance then
    pcall(function()
      g_guiBaseInstance = sdk.create_instance("app.GUIBase"):add_ref()
    end)
  end
  return g_guiBaseInstance
end

local function resolveSkillName(jobId, skillId, levelNo)
  levelNo = levelNo or 1
  local gb = getGuiBase()
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

-- Refresh skills dynamically from reflection and database
local function refreshSkillsDatabase()
  local gm = getGuiManager()
  local player = getPlayer()
  local human = player and player:get_Human()
  local skillCtx = human and human:get_SkillContext()

  for j = 1, 10 do
    g_activeSkillsByJob[j] = {}
    local knownMap = {}

    -- 1. Base database skills
    if VOCATION_SKILL_DATABASE[j] then
      for _, sk in ipairs(VOCATION_SKILL_DATABASE[j].skills) do
        local entry = { id = sk.id, name = sk.name, level = { "NA" }, currentLevel = 0 }
        table.insert(entry.level, resolveSkillName(j, sk.id, 1))
        table.insert(entry.level, resolveSkillName(j, sk.id, 2))
        entry.name = entry.level[2] or sk.name
        table.insert(g_activeSkillsByJob[j], entry)
        knownMap[sk.id] = entry
      end
    end

    -- 2. Inspect GuiManager CustomSkillJobDefineDictionary
    if gm then
      pcall(function()
        local dict = gm.CustomSkillJobDefineDictionary
        local jobSkills = dict and dict[j]
        if jobSkills then
          for _, def in pairs(jobSkills) do
            if def and def.CustomSkillID then
              local sid = def.CustomSkillID
              if not knownMap[sid] then
                local sname = resolveSkillName(j, sid, 1)
                local entry = { id = sid, name = sname, level = { "NA", sname, resolveSkillName(j, sid, 2) }, currentLevel = 0 }
                table.insert(g_activeSkillsByJob[j], entry)
                knownMap[sid] = entry
              end
            end
          end
        end
      end)

      pcall(function()
        local exDict = gm.ExCustomSkillJobDefineDictionary
        local exJobSkills = exDict and exDict[j]
        if exJobSkills then
          for _, def in pairs(exJobSkills) do
            if def and def.CustomSkillID then
              local sid = def.CustomSkillID
              if not knownMap[sid] then
                local sname = resolveSkillName(j, sid, 1)
                local entry = { id = sid, name = sname, level = { "NA", sname, resolveSkillName(j, sid, 2) }, currentLevel = 0 }
                table.insert(g_activeSkillsByJob[j], entry)
                knownMap[sid] = entry
              end
            end
          end
        end
      end)
    end

    -- 3. Check learned state from SkillContext
    if skillCtx then
      pcall(function()
        local enabledItems = skillCtx:get_field("EnabledCustomSkills"):get_field("_items")
        for _, entry in ipairs(g_activeSkillsByJob[j]) do
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

----------------------------------------------------------------------------------------------------
-- Warfarer Arsenal Radial Wheel System
----------------------------------------------------------------------------------------------------
local W = {
  open = false,
  t_open = 0,
  src = nil,              -- "mouse", "pad", "skill"
  aim_x = 0, aim_y = 0,
  hover_idx = nil,
  weapons = {},
  active_equip_no = nil,
  current_vocation = nil,
}

local SlowMo = {
  active = false,
}

local function setTimeScale(scale)
  pcall(function()
    sdk.set_native_timescale(scale)
  end)
end

local function open_wheel(source)
  if W.open then return end
  local player = getPlayer()
  if not player then return end
  local human = player:get_Human()
  local jobCtx = human and human:get_JobContext()
  if not jobCtx or jobCtx:get_field("CurrentJob") ~= WARFARER_JOB_ID then return end

  W.open = true
  W.src = source
  W.t_open = os.clock()
  W.aim_x = 0
  W.aim_y = 0
  W.hover_idx = nil

  if cfg.slowmo_enabled then
    SlowMo.active = true
    setTimeScale(cfg.slowmo_scale)
  end
end

local function close_wheel(execute_pick)
  if not W.open then return end
  W.open = false

  if SlowMo.active then
    SlowMo.active = false
    setTimeScale(1.0)
  end

  if execute_pick and W.hover_idx and W.weapons[W.hover_idx] then
    local target = W.weapons[W.hover_idx]
    local player = getPlayer()
    local im = getItemManager()
    if player and im then
      local charaId = player:get_CharaID()
      local equipData = im:getEquipData(charaId)
      local data = equipData and equipData:get_field("Data")
      local curIdx = data and data:get_field("<CurrentArisenWeaponIndex>k__BackingField")

      if data and curIdx ~= nil and target.equipNo ~= nil then
        local maxTries = 15
        while target.equipNo ~= curIdx + 1 and maxTries > 0 do
          data:setNextArisenWeapon()
          curIdx = data:get_field("<CurrentArisenWeaponIndex>k__BackingField")
          maxTries = maxTries - 1
        end

        local human = player:get_Human()
        local actionSel = human and human:get_HumanActionSelector()
        if actionSel then
          actionSel:requestJob10CustomSkill()
        end
      end
    end
  end
end

----------------------------------------------------------------------------------------------------
-- Weapon Inventory Tracker
----------------------------------------------------------------------------------------------------
local function update_warfarer_weapons()
  local im = getItemManager()
  local player = getPlayer()
  if not im or not player then return end
  local charaId = player:get_CharaID()
  local equipData = im:getEquipData(charaId)
  if not equipData then return end

  local data = equipData:get_field("Data")
  local currentIdx = data and data:get_field("<CurrentArisenWeaponIndex>k__BackingField")
  local weaponList = equipData:get_ArisenWeaponList()
  if not weaponList then return end

  local list = {}
  local count = weaponList:get_size()
  for i = 0, count - 1 do
    local item = weaponList:get_element(i)
    local main = item and item.Main
    if main then
      local ep = main:call("get_EquipParam()")
      local wp = main:call("get_WeaponParam()")
      if ep and wp then
        local jid = ep:call("getJob()")
        table.insert(list, {
          jobId = jid,
          name = main:call("get_Name()"),
          itemId = main:call("get_ItemId()"),
          equipNo = main:call("get_ArisenEquipNo()"),
          slot = i
        })
      end
    end
  end

  W.weapons = list
  W.active_equip_no = currentIdx

  local human = player:get_Human()
  local chara = human and human:get_Chara()
  if chara then
    pcall(function()
      W.current_vocation = sdk.to_int64(chara.WeaponJob)
    end)
  end
end

----------------------------------------------------------------------------------------------------
-- Skill Palette Swapping System (from Enhanced Warfarer Vocation)
----------------------------------------------------------------------------------------------------
local g_lastEquippedVocation = nil
local g_notificationText = ""
local g_notificationTimer = 0

local function apply_skillset_for_vocation(jobId)
  if not cfg.skill_swap_enabled or not jobId or jobId == 10 then return end
  local player = getPlayer()
  if not player then return end
  local human = player:get_Human()
  local skillCtx = human and human:get_SkillContext()
  if not skillCtx then return end

  local vPreset = cfg.vocation_presets[jobId]
  if not vPreset or not vPreset.presets or #vPreset.presets == 0 then return end

  local pIndex = vPreset.currentPresetIndex or 1
  if pIndex < 1 or pIndex > #vPreset.presets then pIndex = 1 end
  local preset = vPreset.presets[pIndex]
  if not preset or not preset.skills then return end

  local numSlots = 4
  local hasRearmament = false
  for slot = 1, numSlots do
    local skId = preset.skills[slot] or REARMAMENT_SKILL_ID
    if skId == REARMAMENT_SKILL_ID then hasRearmament = true end
    skillCtx:setSkill(WARFARER_JOB_ID, skId, slot - 1)
  end

  if not hasRearmament then
    skillCtx:setSkill(WARFARER_JOB_ID, REARMAMENT_SKILL_ID, numSlots - 1)
  end

  pcall(function()
    local gm = getGuiManager()
    if gm then gm:call("setupKeyGuideCustomSkill()") end
  end)

  g_lastEquippedVocation = jobId
end

local function cycle_skill_preset(jobId)
  local vPreset = cfg.vocation_presets[jobId]
  if not vPreset or not vPreset.presets or #vPreset.presets <= 1 then return end

  vPreset.currentPresetIndex = (vPreset.currentPresetIndex % #vPreset.presets) + 1
  apply_skillset_for_vocation(jobId)

  if cfg.show_swap_notification then
    local p = vPreset.presets[vPreset.currentPresetIndex]
    g_notificationText = "Warfarer: " .. (JOBS[jobId] and JOBS[jobId].name or "Vocation") .. " - " .. (p.name or "Preset")
    g_notificationTimer = 180
  end
  save_config()
end

----------------------------------------------------------------------------------------------------
-- Input Tracking & GamePad Controller
----------------------------------------------------------------------------------------------------
local KeyState = {
  swap_down = false,
  rearm_down = false,
  rearm_press_time = 0,
  wheel_hotkey_down = false,
  pad_button_down = false,
  pad_press_time = 0,
}

local function is_key_down(vk)
  if not vk then return false end
  local ok, res = pcall(function() return reframework:is_key_down(vk) end)
  if ok and res ~= nil then return res end
  return false
end

local VK_MAP = {
  ["LAlt"] = 0x12, ["RAlt"] = 0x12, ["Alt"] = 0x12,
  ["LCtrl"] = 0x11, ["RCtrl"] = 0x11, ["Ctrl"] = 0x11,
  ["LShift"] = 0x10, ["RShift"] = 0x10, ["Shift"] = 0x10,
  ["R"] = 0x52, ["Q"] = 0x51, ["E"] = 0x45, ["F"] = 0x46,
  ["Tab"] = 0x09, ["Space"] = 0x20, ["V"] = 0x56, ["C"] = 0x43
}

local function get_vk_for_name(name)
  if type(name) == "number" then return name end
  return VK_MAP[name] or 0x12
end

local function get_gamepad_state()
  local mgr = sdk.get_native_singleton("via.hid.GamePad")
  local td = sdk.find_type_definition("via.hid.GamePad")
  if not mgr or not td then return nil, 0, 0, 0, 0 end

  local dev = nil
  pcall(function() dev = sdk.call_native_func(mgr, td, "get_MergedDevice") end)
  if not dev then
    pcall(function() dev = sdk.call_native_func(mgr, td, "get_Device") end)
  end
  if not dev then return nil, 0, 0, 0, 0 end

  local btn = 0
  local ok, b = pcall(function() return dev:call("get_Button") end)
  if ok and b then btn = math.floor(tonumber(b) or 0) end

  local lx, ly, rx, ry = 0, 0, 0, 0
  pcall(function()
    local al = dev:call("get_AxisL")
    if al then lx, ly = al.x, al.y end
    local ar = dev:call("get_AxisR")
    if ar then rx, ry = ar.x, ar.y end
  end)

  return btn, lx, ly, rx, ry
end

----------------------------------------------------------------------------------------------------
-- Engine Hooks
----------------------------------------------------------------------------------------------------
pcall(function()
  local jwm = sdk.find_type_definition("app.Job10WeaponManager")
  if jwm then
    local onWeaponChange = function()
      update_warfarer_weapons()
      if W.current_vocation and W.current_vocation ~= g_lastEquippedVocation then
        apply_skillset_for_vocation(W.current_vocation)
      end
    end

    local mChange = jwm:get_method("changeWeapon") or jwm:get_method("changeToCurrentWeapon")
    if mChange then sdk.hook(mChange, nil, onWeaponChange) end

    local mAppear = jwm:get_method("appearWeapon(app.Weapon)")
    if mAppear then sdk.hook(mAppear, nil, onWeaponChange) end
  end
end)

pcall(function()
  local stmCtrl = sdk.find_type_definition("app.HumanStaminaController")
  if stmCtrl then
    local mStm = stmCtrl:get_method("Chara_OnConsumeStaminaHandler(System.Single, app.StaminaParameterBase.Parameter)")
    if mStm then
      sdk.hook(mStm, function(args)
        if not cfg.enabled or cfg.rearmament_stamina_consumption then return end
        local player = getPlayer()
        if not player then return end
        local human = player:get_Human()
        if human and human:get_CustomSkillState() == REARMAMENT_SKILL_ID then
          return sdk.PreHookResult.SKIP_ORIGINAL
        end
      end, nil)
    end
  end
end)

local g_isEditingInGuild = false

pcall(function()
  local uiGuild = sdk.find_type_definition("app.ui040101_00")
  if uiGuild then
    local mOpen = uiGuild:get_method("openMenu(app.ui040101_00.MenuKind)")
    if mOpen then
      sdk.hook(mOpen, function(args)
        g_isEditingInGuild = true
      end, nil)
    end

    local mClose = uiGuild:get_method("close")
    if mClose then
      sdk.hook(mClose, nil, function(ret)
        g_isEditingInGuild = false
        save_config()
        return ret
      end)
    end

    local mFilter = uiGuild:get_method("addCustomSkillContentsList")
    if mFilter then
      sdk.hook(mFilter, function(args)
        if not g_isEditingInGuild or not cfg.filter_guild_skills_by_weapon then return end
        local targetJob = sdk.to_int64(args[3])
        local jobCtx = sdk.to_managed_object(args[4])
        local curJob = jobCtx and jobCtx:get_field("CurrentJob")
        if curJob == WARFARER_JOB_ID and W.current_vocation then
          if targetJob ~= W.current_vocation and targetJob ~= WARFARER_JOB_ID then
            return sdk.PreHookResult.SKIP_ORIGINAL
          end
        end
      end, nil)
    end
  end
end)

----------------------------------------------------------------------------------------------------
-- Frame Updates
----------------------------------------------------------------------------------------------------
re.on_frame(function()
  if not cfg.enabled then return end

  update_warfarer_weapons()

  if W.current_vocation and W.current_vocation ~= g_lastEquippedVocation then
    apply_skillset_for_vocation(W.current_vocation)
  end

  if g_notificationTimer > 0 then
    g_notificationTimer = g_notificationTimer - 1
    if g_notificationTimer <= 0 then g_notificationText = "" end
  end

  -- Keyboard Skillset cycle hotkey
  local swapVk = get_vk_for_name(cfg.hotkey_skill_swap)
  if swapVk and is_key_down(swapVk) then
    if not KeyState.swap_down then
      KeyState.swap_down = true
      if W.current_vocation then
        cycle_skill_preset(W.current_vocation)
      end
    end
  else
    KeyState.swap_down = false
  end

  -- Radial wheel hold Rearmament detection
  if cfg.skill_wheel and cfg.wheel_enabled then
    local rearmVk = get_vk_for_name(cfg.hotkey_rearmament)
    if rearmVk and is_key_down(rearmVk) then
      if not KeyState.rearm_down then
        KeyState.rearm_down = true
        KeyState.rearm_press_time = os.clock()
      else
        local held = os.clock() - KeyState.rearm_press_time
        if held >= cfg.skill_hold and not W.open then
          open_wheel("skill")
        end
      end
    else
      if KeyState.rearm_down then
        KeyState.rearm_down = false
        if W.open and W.src == "skill" then
          close_wheel(true)
        end
      end
    end
  end

  -- Radial wheel dedicated mouse/keyboard hotkey
  if cfg.wheel_enabled and cfg.hotkey_wheel and #cfg.hotkey_wheel > 0 then
    local wheelVk = cfg.hotkey_wheel[1]
    if wheelVk and is_key_down(wheelVk) then
      if not KeyState.wheel_hotkey_down then
        KeyState.wheel_hotkey_down = true
        if not W.open then open_wheel("mouse") else close_wheel(true) end
      end
    else
      KeyState.wheel_hotkey_down = false
    end
  end

  -- Gamepad Controller Handling
  if cfg.pad_enabled and cfg.wheel_enabled then
    local padBtn, lx, ly, rx, ry = get_gamepad_state()
    if padBtn then
      local btnMask = cfg.pad_button or 0x0020
      local isBtnDown = (padBtn & btnMask) == btnMask
      if isBtnDown then
        if not KeyState.pad_button_down then
          KeyState.pad_button_down = true
          KeyState.pad_press_time = os.clock()
        else
          local held = os.clock() - KeyState.pad_press_time
          if held >= cfg.pad_hold and not W.open then
            open_wheel("pad")
          end
        end
      else
        if KeyState.pad_button_down then
          KeyState.pad_button_down = false
          if W.open and W.src == "pad" then
            close_wheel(true)
          end
        end
      end

      -- If wheel is open via pad, use analog stick for steering
      if W.open and W.src == "pad" then
        local sx = math.abs(rx) > math.abs(lx) and rx or lx
        local sy = math.abs(ry) > math.abs(ly) and ry or ly
        local mag = math.sqrt(sx * sx + sy * sy)
        if mag >= cfg.pad_dead then
          local padAngle = math.atan2(-sy, sx)
          if padAngle < 0 then padAngle = padAngle + TAU end

          local n = #W.weapons
          if n > 0 then
            local slice_angle = TAU / n
            for i = 1, n do
              local a_start = (i - 1) * slice_angle - math.pi / 2
              if a_start < 0 then a_start = a_start + TAU end
              local a_end = a_start + slice_angle
              local match = false
              if a_end > TAU then
                match = (padAngle >= a_start and padAngle <= TAU) or (padAngle >= 0 and padAngle <= (a_end - TAU))
              else
                match = (padAngle >= a_start and padAngle <= a_end)
              end
              if match then
                W.hover_idx = i
                break
              end
            end
          end
        end
      end
    end
  end
end)

----------------------------------------------------------------------------------------------------
-- ImGui Drawing: Radial Weapon Wheel & Notification HUD
----------------------------------------------------------------------------------------------------
local function draw_radial_wheel()
  if not W.open or #W.weapons == 0 then return end

  local display_w, display_h = imgui.get_display_size().x, imgui.get_display_size().y
  local center_x, center_y = display_w / 2, display_h / 2
  local draw_list = imgui.get_background_draw_list()

  -- Dim background
  if cfg.dim_enabled then
    local dim_col = (math.floor(cfg.dim_alpha * 255) << 24) | 0x000000
    draw_list:add_rect_filled(Vector2f.new(0, 0), Vector2f.new(display_w, display_h), dim_col)
  end

  local n = #W.weapons
  local slice_angle = TAU / n
  local gap_rad = (cfg.slice_gap_deg * math.pi / 180) / 2

  -- Mouse aim calculation if not controlled by gamepad
  if W.src ~= "pad" then
    local mouse_pos = imgui.get_mouse_pos()
    local dx = mouse_pos.x - center_x
    local dy = mouse_pos.y - center_y
    local dist = math.sqrt(dx * dx + dy * dy)
    local angle = math.atan2(dy, dx)
    if angle < 0 then angle = angle + TAU end

    W.hover_idx = nil
    if dist >= cfg.inner_radius and dist <= cfg.wheel_radius then
      for i = 1, n do
        local a_start = (i - 1) * slice_angle - math.pi / 2
        if a_start < 0 then a_start = a_start + TAU end
        local a_end = a_start + slice_angle
        local match = false
        if a_end > TAU then
          match = (angle >= a_start and angle <= TAU) or (angle >= 0 and angle <= (a_end - TAU))
        else
          match = (angle >= a_start and angle <= a_end)
        end
        if match then
          W.hover_idx = i
          break
        end
      end
    end
  end

  -- Draw slices
  for i = 1, n do
    local wp = W.weapons[i]
    local a_start = (i - 1) * slice_angle - math.pi / 2 + gap_rad
    local a_end = i * slice_angle - math.pi / 2 - gap_rad
    local is_hover = (i == W.hover_idx)
    local is_equipped = (wp.equipNo == W.active_equip_no)

    local col_bg = is_hover and 0xEE26526C or (is_equipped and 0xCC1A382A or 0xCC141212)
    local col_border = is_hover and 0xFF96E2FF or (is_equipped and 0xFF8CC878 or 0xFF625A4A)

    local steps = 16
    local pts = {}
    for s = 0, steps do
      local a = a_start + (a_end - a_start) * (s / steps)
      table.insert(pts, Vector2f.new(center_x + math.cos(a) * cfg.wheel_radius, center_y + math.sin(a) * cfg.wheel_radius))
    end
    for s = steps, 0, -1 do
      local a = a_start + (a_end - a_start) * (s / steps)
      table.insert(pts, Vector2f.new(center_x + math.cos(a) * cfg.inner_radius, center_y + math.sin(a) * cfg.inner_radius))
    end
    draw_list:add_convex_poly_filled(pts, col_bg)
    draw_list:add_polyline(pts, col_border, true, 2.0)

    -- Weapon / Vocation label
    local mid_angle = (a_start + a_end) / 2
    local label_dist = (cfg.inner_radius + cfg.wheel_radius) / 2
    local lx = center_x + math.cos(mid_angle) * label_dist
    local ly = center_y + math.sin(mid_angle) * label_dist
    local jInfo = JOBS[wp.jobId]
    local label = jInfo and (jInfo.abbr .. " - " .. wp.name) or wp.name
    draw_list:add_text(Vector2f.new(lx - 35, ly - 8), 0xFFFFFFFF, label)
  end

  -- Center disc
  draw_list:add_circle_filled(Vector2f.new(center_x, center_y), cfg.center_radius, 0xEE120A08)
  draw_list:add_circle(Vector2f.new(center_x, center_y), cfg.center_radius, 0xFFB4A064, 32, 2.0)

  -- Center info
  if W.hover_idx and W.weapons[W.hover_idx] then
    local hwp = W.weapons[W.hover_idx]
    local hj = JOBS[hwp.jobId]
    if not cfg.hide_center_job and hj then
      draw_list:add_text(Vector2f.new(center_x - 35, center_y - 18), 0xFFE0C080, hj.name)
    end
    if not cfg.hide_center_weapon then
      draw_list:add_text(Vector2f.new(center_x - 35, center_y + 2), 0xFFFFFFFF, hwp.name)
    end
  else
    draw_list:add_text(Vector2f.new(center_x - 28, center_y - 8), 0xFFAAAAAA, "Warfarer")
  end
end

local function draw_notifications()
  if g_notificationTimer <= 0 or g_notificationText == "" then return end
  local draw_list = imgui.get_background_draw_list()
  local pos = Vector2f.new(40, 40)
  draw_list:add_rect_filled(Vector2f.new(30, 30), Vector2f.new(380, 70), 0xDD111111)
  draw_list:add_rect(Vector2f.new(30, 30), Vector2f.new(380, 70), 0xFFB4A064, 0, 0, 1.5)
  draw_list:add_text(pos, 0xFFFFFFFF, g_notificationText)
end

----------------------------------------------------------------------------------------------------
-- REFramework Settings & Preset Editor Menu
----------------------------------------------------------------------------------------------------
local BUTTON_NAMES = { "Top (Y / △)", "Left (X / □)", "Bottom (A / ✕)", "Right (B / ○)" }

re.on_draw_ui(function()
  if not imgui.tree_node(MOD_NAME) then return end

  imgui.text("Version " .. MOD_VERSION .. " | Dragon's Dogma 2 DLC Dark Arisen Edition")
  local changed = false

  local c_en, n_en = imgui.checkbox("Mod Enabled", cfg.enabled)
  if c_en then cfg.enabled = n_en; changed = true end

  if cfg.enabled then
    imgui.indent(10)

    -- Gameplay Settings
    local c_stm, n_stm = imgui.checkbox("Rearmament Consumes Stamina", cfg.rearmament_stamina_consumption)
    if c_stm then cfg.rearmament_stamina_consumption = n_stm; changed = true end

    -- Radial Weapon Wheel
    if imgui.tree_node("Radial Weapon Wheel") then
      local c_we, n_we = imgui.checkbox("Enable Radial Weapon Wheel", cfg.wheel_enabled)
      if c_we then cfg.wheel_enabled = n_we; changed = true end

      local c_sw, n_sw = imgui.checkbox("Open Wheel on Holding Rearmament Button", cfg.skill_wheel)
      if c_sw then cfg.skill_wheel = n_sw; changed = true end

      if cfg.skill_wheel then
        local c_sh, n_sh = imgui.slider_float("Hold Time (seconds)", cfg.skill_hold, 0.1, 1.0)
        if c_sh then cfg.skill_hold = n_sh; changed = true end
      end

      local c_sm, n_sm = imgui.checkbox("Slow Motion While Wheel is Open", cfg.slowmo_enabled)
      if c_sm then cfg.slowmo_enabled = n_sm; changed = true end

      if cfg.slowmo_enabled then
        local c_ss, n_ss = imgui.slider_float("Slow Motion Speed", cfg.slowmo_scale, 0.05, 1.0)
        if c_ss then cfg.slowmo_scale = n_ss; changed = true end
      end

      local c_wr, n_wr = imgui.slider_float("Outer Radius", cfg.wheel_radius, 150, 400)
      if c_wr then cfg.wheel_radius = n_wr; changed = true end

      local c_ir, n_ir = imgui.slider_float("Inner Radius", cfg.inner_radius, 80, 250)
      if c_ir then cfg.inner_radius = n_ir; changed = true end

      local c_cr, n_cr = imgui.slider_float("Center Disc Radius", cfg.center_radius, 50, 180)
      if c_cr then cfg.center_radius = n_cr; changed = true end

      local c_dm, n_dm = imgui.checkbox("Dim Screen Background", cfg.dim_enabled)
      if c_dm then cfg.dim_enabled = n_dm; changed = true end

      imgui.tree_pop()
    end

    -- Vocation Skillsets & Dark Arisen DLC Skills
    if imgui.tree_node("Vocation Skillsets & Dark Arisen DLC Skills") then
      local c_se, n_se = imgui.checkbox("Skill Swapping Enabled", cfg.skill_swap_enabled)
      if c_se then cfg.skill_swap_enabled = n_se; changed = true end

      local c_gf, n_gf = imgui.checkbox("Filter Vocation Guild Skills by Weapon Vocation", cfg.filter_guild_skills_by_weapon)
      if c_gf then cfg.filter_guild_skills_by_weapon = n_gf; changed = true end

      local c_sn, n_sn = imgui.checkbox("Show Swap Notification", cfg.show_swap_notification)
      if c_sn then cfg.show_swap_notification = n_sn; changed = true end

      if imgui.button("Refresh Skills Database (Dark Arisen / Game Scan)") then
        refreshSkillsDatabase()
      end

      imgui.separator()
      imgui.text_colored("Configure Skill Palettes per Vocation (including DLC Skills):", 0xFFE0C080)

      for j = 1, 9 do
        local jInfo = JOBS[j]
        local vPreset = cfg.vocation_presets[j]
        local isActive = (j == W.current_vocation)
        local header = (jInfo and jInfo.name or ("Vocation " .. j)) .. (isActive and " [ACTIVE]" or "")

        if imgui.tree_node(header) then
          -- Prepare list of available skills for this vocation
          local skillOptions = {}
          local skillIds = {}
          local jobSkills = g_activeSkillsByJob[j] or {}

          for _, sk in ipairs(jobSkills) do
            local label = tostring(sk.id) .. " - " .. (sk.name or ("Skill " .. sk.id))
            table.insert(skillOptions, label)
            table.insert(skillIds, sk.id)
          end
          -- Always include Rearmament
          table.insert(skillOptions, "100 - Rearmament")
          table.insert(skillIds, REARMAMENT_SKILL_ID)

          if vPreset and vPreset.presets then
            for pIdx, preset in ipairs(vPreset.presets) do
              imgui.push_id("job_" .. j .. "_preset_" .. pIdx)

              -- Preset Name Input
              local c_pname, n_pname = imgui.input_text("Preset Name", preset.name or ("Preset " .. pIdx))
              if c_pname then preset.name = n_pname; changed = true end

              -- 4 Skill Slots Dropdown Combos
              for slot = 1, 4 do
                local curSkillId = preset.skills[slot] or REARMAMENT_SKILL_ID
                local comboIdx = 1
                for idx, sid in ipairs(skillIds) do
                  if sid == curSkillId then comboIdx = idx; break end
                end

                local slotLabel = BUTTON_NAMES[slot] or ("Slot " .. slot)
                local c_sk, n_sk = imgui.combo(slotLabel, comboIdx, skillOptions)
                if c_sk and n_sk and skillIds[n_sk] then
                  preset.skills[slot] = skillIds[n_sk]
                  changed = true
                  if isActive then
                    apply_skillset_for_vocation(j)
                  end
                end
              end

              if #vPreset.presets > 1 then
                if imgui.button("Delete Preset##del_" .. j .. "_" .. pIdx) then
                  table.remove(vPreset.presets, pIdx)
                  if vPreset.currentPresetIndex > #vPreset.presets then
                    vPreset.currentPresetIndex = #vPreset.presets
                  end
                  changed = true
                  imgui.pop_id()
                  break
                end
              end

              imgui.separator()
              imgui.pop_id()
            end

            if #vPreset.presets < cfg.max_presets_toggle then
              if imgui.button("Add New Preset##job_" .. j) then
                table.insert(vPreset.presets, {
                  name = "Preset " .. (#vPreset.presets + 1),
                  skills = { REARMAMENT_SKILL_ID, REARMAMENT_SKILL_ID, REARMAMENT_SKILL_ID, REARMAMENT_SKILL_ID }
                })
                changed = true
              end
            end
          end

          imgui.tree_pop()
        end
      end

      imgui.tree_pop()
    end

    -- Keybindings & Hotkeys
    if imgui.tree_node("Keybindings & Hotkeys") then
      local c_kswap, n_kswap = imgui.input_text("Skillset Cycle Hotkey", cfg.hotkey_skill_swap)
      if c_kswap then cfg.hotkey_skill_swap = n_kswap; changed = true end

      local c_krearm, n_krearm = imgui.input_text("Rearmament Hotkey", cfg.hotkey_rearmament)
      if c_krearm then cfg.hotkey_rearmament = n_krearm; changed = true end

      imgui.tree_pop()
    end

    imgui.unindent(10)
  end

  imgui.tree_pop()

  if changed then save_config() end
end)

re.on_frame(function()
  if cfg.enabled then
    if W.open then draw_radial_wheel() end
    draw_notifications()
  end
end)

refreshSkillsDatabase()
