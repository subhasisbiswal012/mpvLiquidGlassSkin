-- Pure chapter / playlist navigation helpers.
--
-- No mpv or uosc globals are touched here on purpose: every function operates
-- on plain values so it can be unit-tested in vanilla Lua (see
-- tests/chapters_spec.lua). The Timeline element and SkipPill element call
-- into this module for all decision logic, keeping their render code thin.

local M = {}

-- Returns the chapter whose span contains `t` (the last chapter whose `time`
-- is <= `t`), plus its 1-based index. Returns nil when nothing qualifies:
-- empty/absent chapter list, missing time, or `t` sitting before the first
-- chapter's start.
---@param chapters table[]|nil Array of `{time, title}` sorted by time.
---@param t number|nil
---@return table|nil chapter, number|nil index
function M.chapter_at_time(chapters, t)
	if not chapters or #chapters == 0 or t == nil then return nil end
	local found, found_i
	for i, ch in ipairs(chapters) do
		if ch.time and ch.time <= t then
			found, found_i = ch, i
		else
			break
		end
	end
	return found, found_i
end

-- Returns the chapter after the given 1-based index, or nil if `index` is the
-- last chapter (or inputs are missing).
---@param chapters table[]|nil
---@param index number|nil
---@return table|nil
function M.next_chapter(chapters, index)
	if not chapters or not index then return nil end
	return chapters[index + 1]
end

-- Returns `{start, stop}` time bounds of the chapter at `index`. The last
-- chapter's `stop` is `duration`. Returns nil when the chapter does not exist.
---@param chapters table[]|nil
---@param index number|nil
---@param duration number|nil
---@return {start: number, stop: number}|nil
function M.chapter_span(chapters, index, duration)
	if not chapters or not index or not chapters[index] then return nil end
	local start = chapters[index].time
	if start == nil then return nil end
	local nxt = chapters[index + 1]
	local stop = nxt and nxt.time or duration
	if stop == nil then stop = start end
	return {start = start, stop = stop}
end

-- Human-facing label for a chapter. Falls back to "Chapter N" when the chapter
-- has no title.
---@param chapter table|nil
---@param index number|nil
---@return string|nil
function M.chapter_label(chapter, index)
	if not chapter then return nil end
	local title = chapter.title
	if title == nil or title == '' then
		return 'Chapter ' .. tostring(index or '?')
	end
	return title
end

-- Whether the end-of-video "next video" pill should show: only inside the last
-- `threshold` seconds of the file, and only when another playlist item exists.
---@param time number|nil
---@param duration number|nil
---@param threshold number|nil Seconds remaining at/below which to show.
---@param has_next boolean|nil
---@return boolean
function M.should_show_next_video(time, duration, threshold, has_next)
	if not has_next then return false end
	if time == nil or duration == nil or duration <= 0 then return false end
	if threshold == nil or threshold <= 0 then return false end
	return (duration - time) <= threshold
end

-- Truncates `str` to at most `max` codepoints, appending an ellipsis when cut.
-- Counts by UTF-8 lead bytes so multibyte titles are never split mid-character.
---@param str string|nil
---@param max number|nil
---@return string|nil
function M.truncate(str, max)
	if str == nil or max == nil or max <= 0 then return str end
	local count, i, bytes = 0, 1, #str
	while i <= bytes do
		local b = str:byte(i)
		local step = 1
		if b >= 0xF0 then step = 4
		elseif b >= 0xE0 then step = 3
		elseif b >= 0xC0 then step = 2 end
		count = count + 1
		if count > max then
			return str:sub(1, i - 1) .. '…'
		end
		i = i + step
	end
	return str
end

return M
