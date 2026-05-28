-- Walks the SVG icon directory and registers each file's parsed path
-- into the icons registry. Files override the inline ASS paths shipped
-- in lib/liquid/icons.lua — those stay as a safety net for boots where
-- the asset folder is missing.

local svg   = require('lib/liquid/svg')
local icons = require('lib/liquid/icons')

local M = {}

local function read_file(path)
  local f = io.open(path, 'rb')
  if not f then return nil end
  local content = f:read('*all')
  f:close()
  return content
end

-- Load every *.svg in `dir` and register it under its filename stem.
-- Returns the count of icons successfully registered.
function M.load_directory(dir)
  local utils = require('mp.utils')
  local entries = utils.readdir(dir, 'files')
  if not entries then return 0 end
  local n = 0
  for _, fname in ipairs(entries) do
    local stem = fname:match('^(.-)%.svg$')
    if stem then
      local full_path = utils.join_path(dir, fname)
      local text = read_file(full_path)
      if text then
        local ass_path = svg.parse(text)
        if ass_path and #ass_path > 0 then
          icons.register(stem, ass_path)
          n = n + 1
        else
          mp.msg.warn('liquid svg: empty or unparseable path in ' .. fname)
        end
      end
    end
  end
  return n
end

-- Convenience: resolve the icon folder relative to the running script.
function M.default_dir()
  local utils = require('mp.utils')
  local script_dir = mp.get_script_directory and mp.get_script_directory() or '.'
  return utils.join_path(script_dir, 'assets/icons')
end

-- Boot entrypoint — call from main.lua once at startup.
function M.boot()
  local dir = M.default_dir()
  local count = M.load_directory(dir)
  if count > 0 then
    mp.msg.info(string.format('liquid svg: loaded %d icons from %s', count, dir))
  end
  return count
end

return M
