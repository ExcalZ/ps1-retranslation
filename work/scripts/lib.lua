-- The bounded scenario driver, prepended to every scenario by tools/ps1emu.py.
--
-- ps1emu.py defines PS1 = { name, out, max_frames, labels = {Label = cpu address}, params }
-- before this file. A scenario is the body of function scenario(), run as a coroutine resumed
-- once per frame; it drives the game with the helpers below. Every wait is bounded: a helper
-- that runs out of frames raises, and the whole run stops at PS1.max_frames. Exit codes
-- (emu.stop): 0 done, 1 the scenario raised, 2 the frame cap.

local frame = 0
local held = {}
local co
local logf = io.open(PS1.out .. "/" .. PS1.name .. ".log", "w")
local button_wait_frame = -10
local timed_wait_frame = -10

function log(msg)
  logf:write(string.format("[%6d] %s\n", frame, msg))
  logf:flush()
end

local finished = false

-- emu.stop does not halt at once: frames can still arrive, so `finished` shuts the run off
local function finish(code, msg)
  if finished then return end
  if msg then log(msg) end
  log("exit " .. code)
  logf:close()
  finished = true
  emu.stop(code)
end

-- ---------------------------------------------------------------- memory

function ram(addr) return emu.read(addr - 0xC000, emu.memType.smsWorkRam) end
function ram16(addr) return ram(addr) + 256 * ram(addr + 1) end
function poke(addr, v) emu.write(addr - 0xC000, v, emu.memType.smsWorkRam) end
function vram(addr) return emu.read(addr, emu.memType.smsVideoRam) end
function game_mode() return ram(0xC202) & 0x1F end

MODE = { intro = 3, ship = 5, map = 9, dungeon = 11, interaction = 13, road = 15, name_input = 17 }

-- ---------------------------------------------------------------- time and input

function now() return frame end

function wait(n)
  for _ = 1, n do coroutine.yield() end
end

-- wait until pred() is true; raise after max frames
function wait_until(pred, max, what)
  for n = 0, max do
    if pred() then return n end
    coroutine.yield()
  end
  error(string.format("waited %d frames for %s", max, what), 2)
end

-- hold buttons ("one", "two", "up", "down", "left", "right", "pause") for n frames, then release
-- for gap frames
function set_held(buttons)
  held = {}
  for _, b in ipairs(buttons) do held[b] = true end
end

function press(buttons, n, gap)
  if type(buttons) == "string" then buttons = { buttons } end
  set_held(buttons)
  wait(n or 3)
  set_held({})
  wait(gap or 3)
end

-- the game is in WaitForButton1Or2 (the label runs once a frame while it waits)
function at_button_wait() return button_wait_frame >= frame - 1 end

-- the game is in the timed wait of an end code {TIMED} ($63: LABEL_2D33 / LABEL_2D39, up to
-- 30 frames or a button; the battle messages)
function at_timed_wait() return timed_wait_frame >= frame - 1 end

function wait_for_button_wait(max, what)
  return wait_until(at_button_wait, max, what or "a button wait")
end

-- ---------------------------------------------------------------- the screen

-- the text tiles of the stock font (docs/pipeline.md 3.2, 3.10)
local TILE = { [0xC0] = " ", [0xE5] = ",", [0xE6] = ";", [0xE7] = ".", [0xE8] = "!",
               [0xE9] = "?", [0xEA] = "-", [0xEB] = '"' }
for i = 0, 9 do TILE[0xC1 + i] = string.char(48 + i) end
for i = 0, 25 do TILE[0xCB + i] = string.char(65 + i) end

local function cell(row, col)
  local a = 0x3800 + row * 64 + col * 2
  return vram(a) + 256 * (vram(a + 1) & 1)
end

-- vwf_windows draws a window's text in the face into tiles it borrows, each such cell's
-- attribute with bit 5 set: a run of them is read from the tiles' ink (plane 1), column by
-- column, and matched against the face (FACE, from tools/diafont.py; the longest glyph first)
local face_cands
local function face_text(tiles)
  if not face_cands then
    face_cands = {}
    for _, g in ipairs(FACE or {}) do
      if g[1] ~= "0" and g[1] ~= " " then face_cands[#face_cands + 1] = g end
    end
    table.sort(face_cands, function(a, b) return a[2] > b[2] end)
  end
  local cols = {}
  for _, t in ipairs(tiles) do
    local rows = {}
    for r = 0, 7 do rows[r] = vram(t * 32 + r * 4 + 1) end
    for x = 0, 7 do
      local c = 0
      for r = 0, 7 do
        if (rows[r] >> (7 - x)) & 1 == 1 then c = c | (1 << r) end
      end
      cols[#cols + 1] = c
    end
  end
  local n, out, x = #cols, {}, 1
  local function blank_from(i)
    for k = i, n do if cols[k] ~= 0 then return false end end
    return true
  end
  while x <= n and not blank_from(x) do
    local hit = false
    for _, g in ipairs(face_cands) do
      local ok = true
      for i = 1, g[2] do
        if (cols[x + i - 1] or 0) ~= (g[3][i] or 0) then ok = false break end
      end
      if ok then
        out[#out + 1] = g[1]
        x = x + g[2]
        hit = true
        break
      end
    end
    if not hit then
      if (cols[x] or 0) == 0 and (cols[x + 1] or 0) == 0 and (cols[x + 2] or 0) == 0 then
        out[#out + 1] = " "
        x = x + 3
      else
        out[#out + 1] = "~"
        x = x + 1
      end
    end
  end
  return table.concat(out)
end

local function face_cell(row, col)
  return (vram(0x3800 + row * 64 + col * 2 + 1) & 0x20) ~= 0
end

-- the characters of one text line: its lower tile row, with the upper row's marks
-- (the apostrophe is a comma above a blank, the quote mark a " above a blank)
function text_line(lower_row, c0, c1)
  local s = {}
  local c = c0
  while c <= c1 do
    if face_cell(lower_row, c) then        -- a run of the face's cells (vwf_windows)
      local tiles = {}
      while c <= c1 and face_cell(lower_row, c) do
        tiles[#tiles + 1] = cell(lower_row, c)
        c = c + 1
      end
      s[#s + 1] = face_text(tiles)
      goto next_cell
    end
    do
    local lo, up = cell(lower_row, c), cell(lower_row - 1, c)
    local ch = TILE[lo]
    if lo == 0xC0 and up == 0xE5 then ch = "'"
    elseif lo == 0xC0 and up == 0xEB then ch = '"'
    elseif ch == nil then ch = "~" end
    s[#s + 1] = ch
    c = c + 1
    end
    ::next_cell::
  end
  return (table.concat(s):gsub("[%s~]+$", ""))   -- "~": a cell outside the font
end

-- a window line drawn by vwf_dialogue: its lower row's cells from column 7 show tiles $EC-$FF.
-- It is read back as "vwf:" and the hex of the ink (tile plane 1) of its 10 tiles, 8 rows a
-- tile; tools/ps1emu.py decodes it with the face (tools/diafont.py)
local function vwf_line(lower_row, col, ntiles, lo, hi)
  local first = cell(lower_row, col)
  if first < lo or first > hi then return nil end
  local hex = {}
  for c = col, col + ntiles - 1 do
    local t = cell(lower_row, c)
    for r = 0, 7 do
      local b = 0
      if t >= lo and t <= hi then b = vram(t * 32 + r * 4 + 1) end
      hex[#hex + 1] = string.format("%02X", b)
    end
  end
  return "vwf:" .. table.concat(hex)
end

-- the dialogue window's two lines (rows 19-22, columns 7-24)
function dialogue_text()
  return { vwf_line(20, 7, 10, 0xEC, 0xFF) or text_line(20, 7, 24),
           vwf_line(22, 7, 10, 0xEC, 0xFF) or text_line(22, 7, 24) }
end

-- a cut-scene line drawn by vwf_cutscene: 15 tiles from column 6 in $C1-$FC, and the upper
-- row still the cleared tile 0 (the stock printer puts $C0 there with every character)
local function cut_vwf_line(lower_row)
  if cell(lower_row - 1, 6) ~= 0 then return nil end
  return vwf_line(lower_row, 6, 15, 0xC1, 0xFC)
end

-- the cut-scene text: four lines (rows 16-23, columns 6-25)
function cutscene_text()
  local out = {}
  for _, r in ipairs({ 17, 19, 21, 23 }) do
    out[#out + 1] = cut_vwf_line(r) or text_line(r, 6, 25)
  end
  return out
end

-- the text of a screen area: one line per lower tile row in rows r0..r1 (step 2 from r0)
function area_text(r0, r1, c0, c1)
  local out = {}
  for r = r0, r1, 2 do
    local s = text_line(r, c0, c1)
    if s:match("[^%s~]") then out[#out + 1] = s:gsub("^[%s~]+", "") end
  end
  return out
end

-- log every screen row that holds text (each row read as a lower row, marks from the row
-- above), tagged; for finding where a menu draws
function dump_screen(tag)
  for r = 0, 23 do
    local s = text_line(r, 0, 31)
    if s:match("[A-Z0-9]") then log(string.format("%s r%02d |%s", tag, r, s)) end
  end
end

-- on the field (the map: a button switches to the interaction screen, mode 13) or in a
-- dungeon (the menu opens over the corridor, mode 11): wait for the command menu.
-- Bounded: 5 presses, 300 frames for the menu.
function open_command_menu()
  local function menu_up() return #area_text(2, 10, 1, 6) >= 5 end
  for try = 1, 5 do
    press("one", 4, 36)
    if game_mode() == MODE.interaction or menu_up() then break end
    if try == 5 then error("the map did not take button 1 in 5 tries") end
  end
  wait_until(function() return #area_text(2, 10, 1, 6) >= 5 end, 300, "the command menu")
  wait(10)
  return area_text(2, 10, 1, 6)
end

-- ---------------------------------------------------------------- the naming screen

-- the key table LABEL_4280: 4 rows of 11; $5C ADV, $5D RUB, $5E END
local KEYS = {}
for i, c in ipairs({ "A","B","C","D","E","F","G","H","I","J","K",
                     "L","M","N","O","P","Q","R","S","T","U","V",
                     "W","X","Y","Z",",",";",".","!","?","-",'"' }) do KEYS[i - 1] = c:byte() end
for i = 33, 39 do KEYS[i] = 0x5C end
KEYS[40], KEYS[41], KEYS[42], KEYS[43] = 0x5D, 0x5D, 0x5E, 0x5E

local function key_index(code)
  for i = 0, 43 do if KEYS[i] == code then return i end end
end

-- the cursor's key ($C788 holds the code under it) moved onto `code`, one step at a time,
-- each step checked. Bounded: 30 steps.
local function cursor_to(code)
  for _ = 1, 30 do
    local here = ram(0xC788)
    if here == code then return end
    local a, b = key_index(here), key_index(code)
    if a == nil then error(string.format("cursor on an unknown key $%02X", here)) end
    local ar, ac, br, bc = a // 11, a % 11, b // 11, b % 11
    local dir = (br > ar and "down") or (br < ar and "up") or (bc > ac and "right") or "left"
    for try = 1, 4 do                    -- the screen ignores the pad while it fades in
      press(dir, 3, 8)
      if ram(0xC788) ~= here then break end
      if try == 4 then error(string.format("the cursor did not move %s from $%02X in 4 presses", dir, here)) end
      wait(30)
    end
  end
  error(string.format("cursor not on $%02X after 30 steps", code))
end

-- type `name` (at most 5 of A-Z , ; . ! ? - ") and END. Each key is checked under the cursor
-- before button 2, and the typed name ($C721) after it.
function type_name(name)
  wait_until(function() return game_mode() == MODE.name_input end, 300, "the naming screen")
  wait(30)
  for i = 1, #name do
    cursor_to(name:byte(i))
    press("two", 3, 10)
    if ram(0xC721 + i - 1) ~= name:byte(i) then
      error(string.format("typed %q, but the name has $%02X at %d", name:sub(i, i), ram(0xC721 + i - 1), i))
    end
  end
  log("typed " .. name)
  cursor_to(0x5E)
  press("two", 3, 10)
end

function on_field()
  local m = game_mode()
  return m == MODE.map or m == MODE.road or m == MODE.dungeon
end

-- a new game from power-on to the field, paging every button wait with button 1;
-- on_page(n, lines, in_window) is called at each wait if given. Bounded: 900 frames to the
-- title, 1500 to each wait, max_pages waits.
function new_game_to_field(max_pages, on_page)
  wait_until(function() return game_mode() == MODE.intro end, 900, "the title")
  wait(120)
  press("one", 4, 30)                    -- START
  for page = 1, max_pages do
    wait_until(function() return at_button_wait() or on_field() end, 1500, "a button wait or the field")
    if not at_button_wait() then
      wait(60)
      return page - 1
    end
    wait(2)
    if on_page then
      local window = ram(0xC2D3) == 0xFF
      on_page(page, window and dialogue_text() or cutscene_text(), window)
    end
    press("one", 4, 6)
  end
  error("still no field after " .. max_pages .. " pages")
end

function window_open() return ram(0xC2D3) == 0xFF end

-- a menu word as the stock or the translation has it (PS1_WORDS, from the build's script.json),
-- in any case
local function is_word(text, stock, en)
  local t = text:upper()
  return t:find(stock, 1, true) ~= nil or (en ~= nil and en ~= "" and t:find(en:upper(), 1, true) ~= nil)
end

-- the YES / NO box (LABEL_B27_BC91 at VRAM $7B6A: rows 13-17, columns 21-25) is up; checked by
-- its words, since other screens (the title's logo) put font tiles in that area
function yes_no_shown()
  local w = PS1_WORDS or {}
  return is_word(text_line(14, 21, 26), "YES", w.yes) and is_word(text_line(16, 21, 26), "NO", w.no)
end

-- the battle menu is up: its first word (ATTK, or the translation's)
function battle_menu_up()
  local m = area_text(2, 10, 1, 6)[1]
  return m ~= nil and is_word(m, "ATTK", (PS1_WORDS or {}).attack)
end

-- page through the dialogue window with button 1, logging and filming each page, until it
-- closes. Bounded: `max` pages, 600 frames for each (a YES/NO prompt is not a button wait:
-- it times out here; answer it in the scenario instead).
function page_window(max, tag)
  for page = 1, max do
    wait_until(function() return at_button_wait() or not window_open() end, 600,
               "a button wait or the window to close")
    if not window_open() then return page - 1 end
    wait(2)
    log(string.format("page %d (window): %s", page, table.concat(dialogue_text(), " / ")))
    shot(string.format("%s%02d", tag or "win", page))
    press("one", 4, 6)
  end
  error("the window still open after " .. max .. " pages")
end

local shots = 0
function shot(name)
  shots = shots + 1
  local path = string.format("%s/%s_%03d_%s.png", PS1.out, PS1.name, shots, name)
  local f = io.open(path, "wb")
  f:write(emu.takeScreenshot())
  f:close()
  log("shot " .. path)
end

-- ---------------------------------------------------------------- the run

emu.addEventCallback(function()
  local b = {}
  for k, v in pairs(held) do b[k] = v end
  emu.setInput(b, 0, 0)
end, emu.eventType.inputPolled)

if PS1.labels.WaitForButton1Or2 then
  emu.addMemoryCallback(function() button_wait_frame = frame end, emu.callbackType.exec,
                        PS1.labels.WaitForButton1Or2)
end
if PS1.labels.LABEL_2D39 then
  emu.addMemoryCallback(function() timed_wait_frame = frame end, emu.callbackType.exec,
                        PS1.labels.LABEL_2D39)
end

emu.addEventCallback(function()
  if finished then return end
  frame = frame + 1
  if frame > PS1.max_frames then
    finish(2, "FAIL frame cap " .. PS1.max_frames)
    return
  end
  if not co then
    co = coroutine.create(scenario)
  end
  local ok, err = coroutine.resume(co)
  if not ok then
    pcall(shot, "fail")
    finish(1, "FAIL " .. tostring(err))
  elseif coroutine.status(co) == "dead" then
    finish(0, "done")
  end
end, emu.eventType.endFrame)
