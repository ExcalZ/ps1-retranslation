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

function log(msg)
  logf:write(string.format("[%6d] %s\n", frame, msg))
  logf:flush()
end

local function finish(code, msg)
  if msg then log(msg) end
  log("exit " .. code)
  logf:close()
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

-- the characters of one text line: its lower tile row, with the upper row's marks
-- (the apostrophe is a comma above a blank, the quote mark a " above a blank)
function text_line(lower_row, c0, c1)
  local s = {}
  for c = c0, c1 do
    local lo, up = cell(lower_row, c), cell(lower_row - 1, c)
    local ch = TILE[lo]
    if lo == 0xC0 and up == 0xE5 then ch = "'"
    elseif lo == 0xC0 and up == 0xEB then ch = '"'
    elseif ch == nil then ch = "~" end
    s[#s + 1] = ch
  end
  return (table.concat(s):gsub("[%s~]+$", ""))   -- "~": a cell outside the font
end

-- the dialogue window's two lines (rows 19-22, columns 7-24)
function dialogue_text()
  return { text_line(20, 7, 24), text_line(22, 7, 24) }
end

-- the cut-scene text: four lines (rows 16-23, columns 6-25)
function cutscene_text()
  return { text_line(17, 6, 25), text_line(19, 6, 25), text_line(21, 6, 25), text_line(23, 6, 25) }
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

emu.addEventCallback(function()
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
    finish(1, "FAIL " .. tostring(err))
  elseif coroutine.status(co) == "dead" then
    finish(0, "done")
  end
end, emu.eventType.endFrame)
