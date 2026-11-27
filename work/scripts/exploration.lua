-- Bounded movement/transition regression. Run against the stock-speed and fast builds.
-- A real dungeon is loaded first; a small RAM-only corridor isolates movement from events.
local L = PS1.labels
local fast = PS1.params.fast ~= "0"
local tracking = false
local returns, roll_count = {}, 0
local fade_start, fade_times = nil, {}

emu.addMemoryCallback(function()
  returns[#returns + 1] = now()
end, emu.callbackType.exec, L.GameMode_Dungeon)
emu.addMemoryCallback(function()
  if tracking then roll_count = roll_count + 1 end
end, emu.callbackType.exec, L.UpdateRNGSeed)
emu.addMemoryCallback(function(_, value)
  if value == 9 or value == 0x89 then fade_start = now() end
  if value == 0 and fade_start then
    fade_times[#fade_times + 1] = now() - fade_start
    fade_start = nil
  end
end, emu.callbackType.write, 0xC21B)

local function dungeon_action(button, changed, what)
  local done = #returns
  set_held({button})
  wait_until(changed, 90, what)
  set_held({})
  wait_until(function() return #returns > done end, 180, what .. " animation")
  wait(2)
end

function scenario()
  new_game_to_field(40)
  -- Straight safe town stretch: displacement, step-counter alignment, and a reverse turn.
  local x, y = ram16(0xC301), ram16(0xC305)
  log(string.format("map start x=%d y=%d", x, y))
  set_held({"left"})
  wait_until(function() return ram(0xC265) > 0 end, 60, "a map step")
  set_held({})
  local t = now()
  wait_until(function() return ram(0xC265) == 0 end, 60, "the map step to finish")
  log(string.format("map step remaining=%d dx=%d dy=%d", now()-t,
    ram16(0xC301)-x, ram16(0xC305)-y))
  if now()-t ~= (fast and 7 or 15) then error("wrong on-foot map speed") end
  if math.abs(ram16(0xC301)-x) ~= 16 or ram16(0xC305) ~= y then
    error("a map step did not move exactly 16 pixels")
  end
  shot("map")

  poke(0xC30C, 0x9C) poke(0xC30D, 0x15) poke(0xC30A, 1) poke(0xC202, 0x0A)
  wait_until(function() return game_mode() == MODE.dungeon end, 600, "the dungeon")
  wait(90)
  -- Empty 4x4 room with walls around it. No object, stair, exit, or encounter can intervene.
  for i = 0, 255 do poke(0xCB00+i, 1) end
  for r = 6, 9 do for c = 6, 9 do poke(0xCB00+r*16+c, 0) end end
  poke(0xC30C, 0x88) poke(0xC30A, 0) poke(0xC2E3, 0)
  tracking = true
  local before = ram(0xC30C)
  local t0 = now()
  dungeon_action("up", function() return ram(0xC30C) ~= before end, "forward step")
  log(string.format("dungeon forward frames=%d position=$%02X rolls=%d", now()-t0,
    ram(0xC30C), roll_count))
  if ram(0xC30C) ~= 0x78 then error("forward skipped a dungeon tile") end
  shot("dungeon_forward")
  local dir = ram(0xC30A)
  t0 = now()
  dungeon_action("right", function() return ram(0xC30A) ~= dir end, "right turn")
  log(string.format("dungeon turn frames=%d", now()-t0))
  if ram(0xC30A) ~= 1 or ram(0xC30C) ~= 0x78 then error("turn moved the party") end
  shot("dungeon_turn")
  before = ram(0xC30C)
  t0 = now()
  dungeon_action("down", function() return ram(0xC30C) ~= before end, "backward step")
  log(string.format("dungeon backward frames=%d position=$%02X", now()-t0, ram(0xC30C)))
  if ram(0xC30C) ~= 0x77 then error("backward skipped a dungeon tile") end
  -- West is a wall after one more backward step. It must stay a wall on held input.
  before = ram(0xC30C)
  dungeon_action("down", function() return ram(0xC30C) ~= before end, "step to wall")
  if ram(0xC30C) ~= 0x76 then error("unexpected wall approach") end
  press("down", 60, 5)
  if ram(0xC30C) ~= 0x76 then error("walked through a dungeon wall") end
  tracking = false
  log("dungeon wall collision held; game mode=" .. game_mode())
  if roll_count ~= 4 then error("expected one encounter roll per dungeon action") end
  shot("dungeon_wall")
  -- A closed door blocks walking, opens with the action button, and crosses two cells.
  poke(0xCB77, 4)
  press("up", 30, 5)
  if ram(0xC30C) ~= 0x76 then error("walked through a closed door") end
  press("one", 4, 0)
  wait_until(function() return ram(0xCB77) == 0x84 end, 120, "the door to open")
  wait(90)
  before = ram(0xC30C)
  dungeon_action("up", function() return ram(0xC30C) ~= before end, "door passage")
  if ram(0xC30C) ~= 0x78 then error("door passage did not land beyond the door") end
  wait(90)
  shot("dungeon_door")
  if #fade_times < 2 then error("no fades were measured") end
  for _, frames in ipairs(fade_times) do
    if frames > (fast and 22 or 42) then error("fade took too long: " .. frames) end
  end
  log("fade frames=" .. table.concat(fade_times, ","))
end
