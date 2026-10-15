-- Run from the repository root with Lua 5.4.
local source_path = 'reframework/autorun/WarfarerRevamped.lua'
assert(loadfile(source_path)) -- Compile the complete mod, including Lua's local limit.
local f = assert(io.open(source_path, 'r'))
local source = f:read('*a'); f:close()
source = source:gsub('^\239\187\191', '')
source = source:sub(1, assert(source:find('local function log_act', 1, true)) - 1)
source = source .. '\nreturn {cfg=cfg, cloud=Cloud, save=save_cfg, edit=function() cfg.scale=1.75; mark_dirty() end, dirty=function() return dirty end}'
local function copy(v)
  if type(v) ~= 'table' then return v end
  local t = {}; for k,x in pairs(v) do t[k]=copy(x) end; return t
end
local function start(files, remote, options)
  options = options or {}
  local uploads = {}
  local env = setmetatable({}, {__index=_G})
  env.json = {
    load_file=function(path) return copy(files[path]) end,
    dump_file=function(path, value)
      if options.disk_failure then return false end
      files[path]=copy(value); return true
    end,
    load_string=function(bytes) if bytes=='broken' then error('bad JSON') end; return copy(bytes) end,
    dump_string=function(value) return copy(value) end,
  }
  if not options.no_plugin then
    env.warfarer_steam_cloud = {
      read=function() return options.status or (remote and 'ok' or 'missing'), remote end,
      write=function(bytes) uploads[#uploads+1]=copy(bytes); return not options.upload_failure end,
    }
  end
  return assert(load(source, 'config-test', 't', env))(), uploads
end
local config = 'WarfarerRevamped/config.json'
local journal = 'WarfarerRevamped/cloud-state.json'
local files = {[config]={cfg_version=47, scale=1.4}}
local mod, uploads = start(files)
assert(mod.cfg.scale==1.4 and mod.dirty())
mod.save(); assert(#uploads==1 and not files[journal].pending)
mod = start(files, {cfg_version=47, scale=1.6})
assert(mod.cfg.scale==1.6 and files[config].scale==1.6)
mod, uploads = start(files, nil, {no_plugin=true})
mod.edit(); mod.save(); assert(files[journal].pending and #uploads==0)
mod, uploads = start(files, {cfg_version=47, scale=1.1})
assert(mod.cfg.scale==1.75 and mod.dirty())
mod.save(); assert(#uploads==1 and not files[journal].pending)
mod, uploads = start(files, 'broken')
assert(mod.cfg.scale==1.75 and not mod.cloud.writable)
mod.save(); assert(#uploads==0)
files[journal]={pending=false}
mod, uploads = start(files, {cfg_version=999, scale=1.2})
assert(not mod.cloud.writable and mod.cfg.scale==1.75)
mod.save(); assert(#uploads==0)
mod, uploads = start(files, nil, {status='unavailable'})
mod.edit(); mod.save(); assert(files[journal].pending and #uploads==0)
mod, uploads = start(files, nil, {upload_failure=true})
mod.save(); assert(files[journal].pending and mod.cloud.pending)
mod, uploads = start(files, nil, {disk_failure=true})
mod.edit(); mod.save(); assert(mod.dirty() and #uploads==0)
print('PASS: full Lua compilation, migration, cloud download, offline edits, restart recovery, malformed cloud, unavailable API, failed upload, failed disk write')
