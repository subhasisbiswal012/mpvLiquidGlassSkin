-- SVG → ASS converter for the Liquid Glass icon pipeline.
--
-- mpv/ASS can't render SVG natively. We ship icons as SVG files for
-- portability and convert them at startup into a list of "shapes" that
-- the renderer hands straight to libass:
--
--   shape = {
--     ass_path     = "m 1 2 l 3 4 ...",  -- ASS drawing command string
--     mode         = "stroke" | "fill",  -- how the renderer should paint it
--     stroke_width = 1.5,                 -- only when mode == "stroke"
--     opacity      = 0.5,                 -- 0..1, multiplied into the icon alpha
--   }
--
-- Supported SVG features (sufficient for the icons we ship under
-- assets/icons/ — none of those use anything else):
--   * <path d="...">   M L H V C Z  +  lowercase relative variants
--   * <circle cx cy r> approximated with four cubic beziers
--   * <line x1 y1 x2 y2>  as a stroke segment
--   * <g opacity="..."> opacity stacks onto contained shapes
--   * transform="matrix(a b c d e f)" or "translate(tx ty)" on path/circle
--   * fill / stroke / stroke-width / opacity attributes per element
--
-- NOT supported: arcs (A), smooth/quadratic shortcuts (S/T/Q), <polygon>,
-- <polyline>, <ellipse>, <text>. Authoring rule: icons live on a 24x24
-- viewBox and use the supported subset only.

local M = {}

------------------------------------------------------------ helpers --

local function tokenize_numbers(s)
  local nums = {}
  -- Match floats, allowing leading minus and a single decimal point.
  for n in s:gmatch('-?%d+%.?%d*') do
    nums[#nums + 1] = tonumber(n)
  end
  return nums
end

local function fmt(n)
  -- Trim trailing zeros so ASS drawings stay short.
  local s = string.format('%.4f', n)
  s = s:gsub('0+$', ''):gsub('%.$', '')
  if s == '' or s == '-0' then s = '0' end
  return s
end

----------------------------------------------------- attribute reader --

-- Pull a single attribute value out of a tag's attribute string.
local function attr(tag_inner, name)
  local v = tag_inner:match(name .. '%s*=%s*"([^"]*)"')
  if v then return v end
  return tag_inner:match(name .. "%s*=%s*'([^']*)'")
end

------------------------------------------------------------ transforms

-- Identity. Affine matrix laid out as {a, b, c, d, e, f} where
-- (x', y') = (a*x + c*y + e,  b*x + d*y + f).
local IDENT = {1, 0, 0, 1, 0, 0}

local function mat_mul(A, B)
  return {
    A[1]*B[1] + A[3]*B[2],
    A[2]*B[1] + A[4]*B[2],
    A[1]*B[3] + A[3]*B[4],
    A[2]*B[3] + A[4]*B[4],
    A[1]*B[5] + A[3]*B[6] + A[5],
    A[2]*B[5] + A[4]*B[6] + A[6],
  }
end

local function mat_apply(A, x, y)
  return A[1]*x + A[3]*y + A[5], A[2]*x + A[4]*y + A[6]
end

local function parse_transform(transform_str)
  if not transform_str or transform_str == '' then return IDENT end
  local m = IDENT
  for op, args in transform_str:gmatch('(%a+)%s*%(([^%)]*)%)') do
    local nums = tokenize_numbers(args)
    local part
    if op == 'matrix' and #nums >= 6 then
      part = {nums[1], nums[2], nums[3], nums[4], nums[5], nums[6]}
    elseif op == 'translate' then
      part = {1, 0, 0, 1, nums[1] or 0, nums[2] or 0}
    elseif op == 'scale' then
      local sx = nums[1] or 1
      local sy = nums[2] or sx
      part = {sx, 0, 0, sy, 0, 0}
    end
    if part then m = mat_mul(m, part) end
  end
  return m
end

------------------------------------------------------------ d parser --

-- Convert an SVG `d` string into a list of ASS path tokens, applying
-- `xform` (4x6 affine) to every coordinate. Returns the joined string.
local function path_d_to_ass(d, xform)
  if not d or d == '' then return '' end
  xform = xform or IDENT
  local out = {}
  local cx, cy = 0, 0      -- current point
  local sx, sy = 0, 0      -- last move-to (subpath origin)

  local function emit_move(x, y)
    local tx, ty = mat_apply(xform, x, y)
    out[#out + 1] = 'm'
    out[#out + 1] = fmt(tx)
    out[#out + 1] = fmt(ty)
  end
  local function emit_line(x, y)
    local tx, ty = mat_apply(xform, x, y)
    out[#out + 1] = 'l'
    out[#out + 1] = fmt(tx)
    out[#out + 1] = fmt(ty)
  end
  local function emit_cubic(x1, y1, x2, y2, x, y)
    local a1, b1 = mat_apply(xform, x1, y1)
    local a2, b2 = mat_apply(xform, x2, y2)
    local a3, b3 = mat_apply(xform, x,  y)
    out[#out + 1] = 'b'
    out[#out + 1] = fmt(a1); out[#out + 1] = fmt(b1)
    out[#out + 1] = fmt(a2); out[#out + 1] = fmt(b2)
    out[#out + 1] = fmt(a3); out[#out + 1] = fmt(b3)
  end

  -- Split into command + argument-blob pairs.
  local pairs_list = {}
  for cmd, args in d:gmatch('([MLHVCZmlhvcz])([^MLHVCZmlhvcz]*)') do
    pairs_list[#pairs_list + 1] = {cmd, args}
  end

  for _, pair in ipairs(pairs_list) do
    local cmd = pair[1]
    local nums = tokenize_numbers(pair[2])

    if cmd == 'M' then
      local i = 1
      cx, cy = nums[i], nums[i + 1]; i = i + 2
      sx, sy = cx, cy
      emit_move(cx, cy)
      while i + 1 <= #nums do
        cx, cy = nums[i], nums[i + 1]; i = i + 2
        emit_line(cx, cy)
      end
    elseif cmd == 'm' then
      local i = 1
      cx, cy = cx + nums[i], cy + nums[i + 1]; i = i + 2
      sx, sy = cx, cy
      emit_move(cx, cy)
      while i + 1 <= #nums do
        cx, cy = cx + nums[i], cy + nums[i + 1]; i = i + 2
        emit_line(cx, cy)
      end
    elseif cmd == 'L' then
      local i = 1
      while i + 1 <= #nums do
        cx, cy = nums[i], nums[i + 1]; i = i + 2
        emit_line(cx, cy)
      end
    elseif cmd == 'l' then
      local i = 1
      while i + 1 <= #nums do
        cx, cy = cx + nums[i], cy + nums[i + 1]; i = i + 2
        emit_line(cx, cy)
      end
    elseif cmd == 'H' then
      for _, n in ipairs(nums) do
        cx = n
        emit_line(cx, cy)
      end
    elseif cmd == 'h' then
      for _, n in ipairs(nums) do
        cx = cx + n
        emit_line(cx, cy)
      end
    elseif cmd == 'V' then
      for _, n in ipairs(nums) do
        cy = n
        emit_line(cx, cy)
      end
    elseif cmd == 'v' then
      for _, n in ipairs(nums) do
        cy = cy + n
        emit_line(cx, cy)
      end
    elseif cmd == 'C' then
      local i = 1
      while i + 5 <= #nums do
        local x1, y1 = nums[i],     nums[i + 1]
        local x2, y2 = nums[i + 2], nums[i + 3]
        local x,  y  = nums[i + 4], nums[i + 5]
        emit_cubic(x1, y1, x2, y2, x, y)
        cx, cy = x, y
        i = i + 6
      end
    elseif cmd == 'c' then
      local i = 1
      while i + 5 <= #nums do
        local x1, y1 = cx + nums[i],     cy + nums[i + 1]
        local x2, y2 = cx + nums[i + 2], cy + nums[i + 3]
        local x,  y  = cx + nums[i + 4], cy + nums[i + 5]
        emit_cubic(x1, y1, x2, y2, x, y)
        cx, cy = x, y
        i = i + 6
      end
    elseif cmd == 'Z' or cmd == 'z' then
      -- Close path: ASS filled drawings close implicitly, but we emit
      -- a line back to the subpath origin so strokes also close.
      if cx ~= sx or cy ~= sy then
        emit_line(sx, sy)
      end
      cx, cy = sx, sy
    end
  end

  return table.concat(out, ' ')
end

--------------------------------------------------------- circle helper

-- Approximate a circle with 4 cubic beziers (standard 0.5523 control-
-- point factor) and emit the resulting ASS path under the given affine.
local function circle_to_ass(cxv, cyv, r, xform)
  local k = 0.5523 * r
  local d =
    string.format('M%g,%g ', cxv - r, cyv) ..
    string.format('C%g,%g %g,%g %g,%g ', cxv - r, cyv + k, cxv - k, cyv + r, cxv, cyv + r) ..
    string.format('C%g,%g %g,%g %g,%g ', cxv + k, cyv + r, cxv + r, cyv + k, cxv + r, cyv) ..
    string.format('C%g,%g %g,%g %g,%g ', cxv + r, cyv - k, cxv + k, cyv - r, cxv, cyv - r) ..
    string.format('C%g,%g %g,%g %g,%g',  cxv - k, cyv - r, cxv - r, cyv - k, cxv - r, cyv)
  return path_d_to_ass(d, xform)
end

------------------------------------------------------- element parser

-- Decide whether an element's `fill`/`stroke` attributes describe a
-- fill shape, a stroke shape, or both. Returns a list of shape stubs
-- (mode + stroke_width) that the caller fills in with the ass_path.
local function shape_modes(attrs)
  local fill = attrs.fill
  local stroke = attrs.stroke
  local stroke_width = tonumber(attrs.stroke_width) or 1.5
  local stubs = {}

  -- The svgrepo style sets fill="none" at the <svg> root and applies
  -- stroke="..." per shape — so a path with no explicit fill, no
  -- "none", and a stroke, renders strokes only.
  local has_fill = fill and fill ~= 'none' and fill ~= ''
  local has_stroke = stroke and stroke ~= 'none' and stroke ~= ''

  -- Fall back: if both are absent treat as fill (matches our authored
  -- icons that ship with fill="currentColor").
  if not has_fill and not has_stroke then has_fill = true end

  if has_fill then
    stubs[#stubs + 1] = {mode = 'fill', stroke_width = 0}
  end
  if has_stroke then
    stubs[#stubs + 1] = {mode = 'stroke', stroke_width = stroke_width}
  end
  return stubs
end

-- Extract a property out of an SVG inline `style="..."` attribute.
-- e.g. style_value("fill:#FC9B28;opacity:0.4", "fill") -> "#FC9B28"
local function style_value(style_str, key)
  if not style_str or style_str == '' then return nil end
  for k, v in style_str:gmatch('([%w%-]+)%s*:%s*([^;]+)') do
    if k == key then return v:match('^%s*(.-)%s*$') end
  end
  return nil
end

-- Treat "#FFCC33" or "FFCC33" alike; drop the leading '#'. Returns nil
-- for non-hex values ("none", "white", "currentColor") so the renderer
-- can safely fall through to the caller's ink colour.
local function clean_color(c)
  if not c or c == 'none' or c == '' then return nil end
  local hex = c:gsub('^#', '')
  if hex:match('^%x%x%x%x%x%x$') then return hex end
  return nil
end

-- Walk the SVG text element-by-element, maintaining a stack of <g>
-- contexts (opacity, transform).
function M.parse(svg_text)
  local shapes = {}

  -- Strip XML comments to keep regexes simple.
  svg_text = svg_text:gsub('<!--.-%-%->', '')

  -- Build a root transform that normalises any viewBox to 0..24 path
  -- units, so a 4000x4000 illustration and a 24x24 icon both render at
  -- the same screen pixel size when the caller asks for `size = N`.
  local root_xform = IDENT
  local view_w, view_h = 24, 24
  local svg_open = svg_text:match('<svg[^>]*>')
  if svg_open then
    local vb = svg_open:match('viewBox%s*=%s*"([^"]+)"') or svg_open:match("viewBox%s*=%s*'([^']+)'")
    if vb then
      local nums = tokenize_numbers(vb)
      if #nums >= 4 then
        local mx, my, w, h = nums[1], nums[2], nums[3], nums[4]
        if w > 0 and h > 0 then
          view_w, view_h = w, h
          local max_dim = math.max(w, h)
          local scale = 24 / max_dim
          -- translate so (mx,my) becomes origin, then scale.
          root_xform = mat_mul({scale, 0, 0, scale, 0, 0},
                                {1, 0, 0, 1, -mx, -my})
        end
      end
    end
  end
  -- Stroke widths are in path-units of the source viewBox, so they need
  -- the same scale factor when the viewBox is bigger than 24x24.
  local stroke_scale = 24 / math.max(view_w, view_h)

  local g_stack = {{opacity = 1, transform = root_xform, color = nil}}

  -- Single-pass scanner: find every tag in source order.
  local i = 1
  while true do
    local s, e, tag = svg_text:find('<(/?)([%w_]+)', i)
    if not s then break end
    -- We only care about a handful of tags; skip others by advancing past '>'.
    local closing = svg_text:sub(s + 1, s + 1) == '/'
    -- Need to figure out which tag name we matched. Pattern above returned
    -- '/' or '' in the first capture; redo with proper anchoring.
    local close_slash, tag_name = svg_text:sub(s + 1):match('^(/?)([%w_]+)')
    -- Locate the closing '>' of this tag.
    local gt = svg_text:find('>', s, true)
    if not gt then break end
    local tag_body = svg_text:sub(s + 1 + #close_slash + #tag_name, gt - 1)

    if close_slash == '/' then
      if tag_name == 'g' then
        if #g_stack > 1 then table.remove(g_stack) end
      end
      i = gt + 1
    elseif tag_name == 'g' then
      local style_str = attr(tag_body, 'style')
      local op = tonumber(attr(tag_body, 'opacity') or style_value(style_str, 'opacity')) or 1
      local transform_str = attr(tag_body, 'transform')
      local g_fill = clean_color(attr(tag_body, 'fill') or style_value(style_str, 'fill'))
      local parent = g_stack[#g_stack]
      local combined_xform = mat_mul(parent.transform, parse_transform(transform_str))
      g_stack[#g_stack + 1] = {
        opacity = (parent.opacity or 1) * op,
        transform = combined_xform,
        color = g_fill or parent.color,
      }
      i = gt + 1
    elseif tag_name == 'path' or tag_name == 'circle' or tag_name == 'line' or tag_name == 'rect' then
      local parent = g_stack[#g_stack]
      local local_xform = parse_transform(attr(tag_body, 'transform'))
      local effective = mat_mul(parent.transform, local_xform)

      local style_str = attr(tag_body, 'style')
      local self_op = tonumber(attr(tag_body, 'opacity') or style_value(style_str, 'opacity')) or 1
      local effective_opacity = parent.opacity * self_op
      -- Fill / stroke can be set either as XML attributes (`fill="..."`)
      -- or via inline CSS (`style="fill:#XXX"`). Adobe Illustrator
      -- exports favour the latter, so we read both.
      local fill_value   = attr(tag_body, 'fill')   or style_value(style_str, 'fill')
      local stroke_value = attr(tag_body, 'stroke') or style_value(style_str, 'stroke')
      local sw_value     = attr(tag_body, 'stroke%-width') or style_value(style_str, 'stroke-width')
      local attrs = {
        fill         = fill_value,
        stroke       = stroke_value,
        stroke_width = sw_value,
      }
      local stubs = shape_modes(attrs)
      -- Per-shape colour preserved so multi-colour illustrations (cat,
      -- etc.) keep their palette instead of becoming monochrome blobs.
      local own_fill_color   = clean_color(fill_value)
      local own_stroke_color = clean_color(stroke_value)
      local inherited_color  = parent.color

      local ass_path
      if tag_name == 'path' then
        local d = attr(tag_body, 'd')
        ass_path = d and path_d_to_ass(d, effective) or ''
      elseif tag_name == 'circle' then
        local cxv = tonumber(attr(tag_body, 'cx')) or 0
        local cyv = tonumber(attr(tag_body, 'cy')) or 0
        local rv  = tonumber(attr(tag_body, 'r')) or 0
        ass_path = circle_to_ass(cxv, cyv, rv, effective)
      elseif tag_name == 'line' then
        local x1 = tonumber(attr(tag_body, 'x1')) or 0
        local y1 = tonumber(attr(tag_body, 'y1')) or 0
        local x2 = tonumber(attr(tag_body, 'x2')) or 0
        local y2 = tonumber(attr(tag_body, 'y2')) or 0
        ass_path = path_d_to_ass(string.format('M%g %g L%g %g', x1, y1, x2, y2), effective)
      elseif tag_name == 'rect' then
        local rx = tonumber(attr(tag_body, 'x')) or 0
        local ry = tonumber(attr(tag_body, 'y')) or 0
        local rw = tonumber(attr(tag_body, 'width')) or 0
        local rh = tonumber(attr(tag_body, 'height')) or 0
        ass_path = path_d_to_ass(
          string.format('M%g %g L%g %g L%g %g L%g %g Z', rx, ry, rx + rw, ry, rx + rw, ry + rh, rx, ry + rh),
          effective)
      end

      if ass_path and #ass_path > 0 then
        for _, stub in ipairs(stubs) do
          local shape_color
          if stub.mode == 'fill' then
            shape_color = own_fill_color or inherited_color
          else
            shape_color = own_stroke_color or inherited_color
          end
          shapes[#shapes + 1] = {
            ass_path     = ass_path,
            mode         = stub.mode,
            -- Path-unit widths are scaled to the normalised 24-grid.
            stroke_width = stub.stroke_width * stroke_scale,
            opacity      = effective_opacity,
            color        = shape_color,  -- nil → renderer uses caller ink
          }
        end
      end
      i = gt + 1
    else
      i = gt + 1
    end
  end

  return shapes
end

return M
