-- Check the renderer while it runs, rather than just its settled screen.
-- Each pattern upload must target tiles absent from the currently visible nametable.
-- Covers forward/backward and all eight turn variants using a RAM-only test room.
local L = PS1.labels
local active, overlaps, uploads = false, 0, 0
local loops, sequence = 0, -1
local film = PS1.params.film == "1"
local filming = false
local seen = {}

emu.addMemoryCallback(function() loops = loops + 1 end,
  emu.callbackType.exec, L.GameMode_Dungeon)
emu.addMemoryCallback(function()
  if active then
    sequence = emu.getState()["cpu.a"]
    seen[sequence] = true
    log("animation sequence=" .. sequence)
  end
end, emu.callbackType.exec, L.LABEL_6A58)

emu.addMemoryCallback(function()
  if not active then return end
  local st = emu.getState()
  local ptr = st["cpu.h"]*256 + st["cpu.l"]
  local base = (st["cpu.d"] & 0x3F)*256
  local size, terminated = 0, false
  -- Count the stock graphics RLE's output: every unit expands three planes to four.
  for _ = 1, 4096 do
    local code = emu.read(ptr, emu.memType.smsMemory)
    ptr = ptr + 1
    if code == 0 then terminated = true break end
    size = size + (code & 0x7F)*4
    ptr = ptr + (code < 0x80 and 3 or (code & 0x7F)*3)
  end
  if not terminated then overlaps = overlaps + 1 log("FAIL unterminated graphics RLE") return end
  uploads = uploads + 1
  local hit = 0
  for cell = 0, 32*24-1 do
    local addr = 0x3800 + 2*cell
    local tile = vram(addr) + 256*(vram(addr+1) & 1)
    if tile*32 >= base and tile*32 < base+size then hit = hit + 1 end
  end
  log(string.format("upload sequence=%d base=$%04X bytes=%d visible_cells=%d",
    sequence, base, size, hit))
  if hit > 0 then overlaps = overlaps + 1 end
end, emu.callbackType.exec, L.LABEL_6B1C)

emu.addEventCallback(function()
  if film and filming then shot("motion_" .. now()) end
end, emu.eventType.endFrame)

local function action(button, what)
  local before = loops
  local x, d = ram(0xC30C), ram(0xC30A)
  set_held({button})
  filming = true
  -- The first loop may only read this frame's input: wait for an actual action.
  wait_until(function() return ram(0xC30C) ~= x or ram(0xC30A) ~= d end, 180, what)
  set_held({})
  before = loops
  wait_until(function() return loops > before end, 180, what .. " to finish")
  wait(2)
  filming = false
end

local function room()
  for i = 0, 255 do poke(0xCB00+i, 1) end
  for r = 5, 11 do for c = 5, 11 do poke(0xCB00+r*16+c, 0) end end
  poke(0xC30C, 0x88) poke(0xC30A, 0) poke(0xC2E3, 0)
end

function scenario()
  new_game_to_field(40)
  poke(0xC30C, 0x9C) poke(0xC30D, 0x15) poke(0xC30A, 1) poke(0xC202, 0x0A)
  wait_until(function() return game_mode() == MODE.dungeon end, 600, "the dungeon")
  wait(90)
  active = true
  room()
  action("up", "forward")
  room()
  action("down", "backward")
  for _, button in ipairs({"left", "right"}) do
    for north = 0, 1 do for side = 0, 1 do
      room()
      poke(0xCB78, north)
      poke(button == "left" and 0xCB87 or 0xCB89, side)
      action(button, button .. " turn with walls " .. north .. "," .. side)
    end end
  end
  active = false
  for id = 0, 9 do if not seen[id] then error("animation variant not covered: " .. id) end end
  log(string.format("uploads=%d unsafe_visible_uploads=%d", uploads, overlaps))
  if overlaps > 0 then error("dungeon animation overwrote visible graphics") end
end
