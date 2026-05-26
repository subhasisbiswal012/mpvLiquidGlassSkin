-- Stubs the global `mp` table that mpv injects into scripts.
-- busted runs in vanilla Lua, so we have to fake it for lib modules
-- that read script-opts or post script-messages.

local M = {}

function M.stub_mp(opts)
  opts = opts or {}
  _G.mp = {
    osd_message = function(_) end,
    msg = { info = function(_) end, warn = function(_) end, error = function(_) end },
    get_property = function(name, default) return (opts.properties or {})[name] or default end,
    get_property_native = function(name, default) return (opts.properties or {})[name] or default end,
    get_property_number = function(name, default) return tonumber((opts.properties or {})[name]) or default end,
    register_script_message = function(_, _) end,
    add_key_binding = function(_, _, _) end,
    options = { read_options = function(_, _) end },
  }
  -- Stub the `require('mp.xxx')` modules production code may pull in.
  package.loaded['mp.options'] = { read_options = function(_, _) end }
  package.loaded['mp.msg']     = { info = function(_) end, warn = function(_) end, error = function(_) end, verbose = function(_) end, debug = function(_) end }
  package.loaded['mp.utils']   = {
    join_path = function(a, b) return a .. '/' .. b end,
    split_path = function(p) return p:match('^(.*/)([^/]*)$') end,
    file_info = function(_) return nil end,
    format_json = function(_) return '{}' end,
    parse_json = function(_) return nil end,
  }
end

function M.clear_mp()
  _G.mp = nil
  package.loaded['mp.options'] = nil
  package.loaded['mp.msg']     = nil
  package.loaded['mp.utils']   = nil
end

return M
