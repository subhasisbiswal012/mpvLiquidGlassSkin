-- SVG path → ASS path converter.
--
-- mpv/ASS can't render SVG natively, so we ship icons as SVG files for
-- portability and parse the path-data at startup into ASS drawing
-- commands (m / l / b). The output plugs straight into the same icons
-- registry that holds the inline ASS paths in lib/liquid/icons.lua.
--
-- Supported subset (sufficient for icons we author ourselves):
--   M x y        → m x y               (move)
--   L x y        → l x y               (line)
--   C x1 y1 x2 y2 x y  → b x1 y1 x2 y2 x y  (cubic bezier)
--   Z / z        → ignored (filled paths close implicitly in ASS)
--   Implicit repeats after M/L/C are honoured per SVG spec.
--
-- Lowercase relative commands and H/V/A/Q/S/T are NOT supported —
-- icons authored for this skin must use absolute M/L/C/Z only.

local M = {}

-- Pull all numeric tokens out of a string. Handles commas, whitespace,
-- and leading minus signs. Decimal numbers only (no scientific notation
-- in our icon files).
local function tokenize_numbers(s)
  local nums = {}
  for n in s:gmatch('-?%d+%.?%d*') do
    nums[#nums + 1] = n
  end
  return nums
end

-- Walk an SVG path d-string and emit ASS drawing commands.
function M.path_d_to_ass(d)
  local out = {}
  -- Split by command letter so we get { letter, "args", letter, "args", ... }.
  local parts = {}
  for letter, args in d:gmatch('([MLCZmlcz])([^MLCZmlcz]*)') do
    parts[#parts + 1] = letter
    parts[#parts + 1] = args
  end

  local i = 1
  while i <= #parts do
    local cmd = parts[i]
    local arg_str = parts[i + 1] or ''
    local nums = tokenize_numbers(arg_str)

    if cmd == 'M' then
      -- First pair is M, subsequent implicit pairs are L per spec.
      local j = 1
      out[#out + 1] = 'm'
      out[#out + 1] = nums[j]; out[#out + 1] = nums[j + 1]
      j = j + 2
      while j + 1 <= #nums do
        out[#out + 1] = 'l'
        out[#out + 1] = nums[j]; out[#out + 1] = nums[j + 1]
        j = j + 2
      end
    elseif cmd == 'L' then
      local j = 1
      while j + 1 <= #nums do
        out[#out + 1] = 'l'
        out[#out + 1] = nums[j]; out[#out + 1] = nums[j + 1]
        j = j + 2
      end
    elseif cmd == 'C' then
      local j = 1
      while j + 5 <= #nums do
        out[#out + 1] = 'b'
        out[#out + 1] = nums[j];     out[#out + 1] = nums[j + 1]
        out[#out + 1] = nums[j + 2]; out[#out + 1] = nums[j + 3]
        out[#out + 1] = nums[j + 4]; out[#out + 1] = nums[j + 5]
        j = j + 6
      end
    -- Z / z / unsupported lowercase commands: silently drop.
    end

    i = i + 2
  end

  return table.concat(out, ' ')
end

-- Parse a full SVG file's text and return the concatenated ASS path
-- string for every <path d="..."> element it contains.
function M.parse(svg_text)
  local pieces = {}
  for d in svg_text:gmatch('<path[^>]-%sd%s*=%s*"([^"]+)"') do
    pieces[#pieces + 1] = M.path_d_to_ass(d)
  end
  -- Also tolerate single-quoted d attributes.
  for d in svg_text:gmatch("<path[^>]-%sd%s*=%s*'([^']+)'") do
    pieces[#pieces + 1] = M.path_d_to_ass(d)
  end
  if #pieces == 0 then return nil end
  return table.concat(pieces, ' ')
end

-- Convert an ASS drawing string back into SVG path d-data. Used by the
-- one-shot exporter that seeds assets/icons/ from icons.lua. Not called
-- at runtime, but kept here so the round-trip stays in one file.
function M.ass_to_path_d(ass)
  local out = {}
  local tokens = {}
  for tok in ass:gmatch('%S+') do tokens[#tokens + 1] = tok end
  local i = 1
  while i <= #tokens do
    local cmd = tokens[i]
    if cmd == 'm' then
      out[#out + 1] = string.format('M%s %s', tokens[i + 1], tokens[i + 2])
      i = i + 3
    elseif cmd == 'l' then
      out[#out + 1] = string.format('L%s %s', tokens[i + 1], tokens[i + 2])
      i = i + 3
    elseif cmd == 'b' then
      out[#out + 1] = string.format('C%s %s %s %s %s %s',
        tokens[i + 1], tokens[i + 2],
        tokens[i + 3], tokens[i + 4],
        tokens[i + 5], tokens[i + 6])
      i = i + 7
    else
      i = i + 1
    end
  end
  return table.concat(out, ' ')
end

return M
