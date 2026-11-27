-- Four-member map movement, cornering, collision cadence, and vehicle regression.
-- Run this scenario against both the stock-speed and fast_walk builds and compare the
-- logged actor states. The map is loaded normally; only its RAM tile cache is made
-- uniformly passable so the same route can be used in either build.
local L, R = PS1.labels, PS1.rom
local fast = PS1.params.fast ~= "0"
local world = PS1.params.world == "1"
local collision_checks, encounter_checks, tracking = 0, 0, false
emu.addMemoryCallback(function()
  if tracking then collision_checks = collision_checks + 1 end
end, emu.callbackType.exec, assert(L.LABEL_74E4, 'missing collision label'))
emu.addMemoryCallback(function()
  if tracking then encounter_checks = encounter_checks + 1 end
  if tracking and world then
    -- Isolate walking from random battles on the overworld; still count each entry.
    local st = emu.getState()
    st["cpu.pc"] = L.LABEL_5FF9
    emu.setState(st)
  end
end, emu.callbackType.exec, assert(L.Map_RunRandomBattles, 'missing encounter label'))

local function fill_passable()
  local table_addr = assert(R.LABEL_B03_BC6F, 'missing tile flags')
  if ram(0xC308) >= 4 then table_addr = table_addr + 256 end
  local tile
  for i = 0, 255 do
    -- Bit 0 blocks walking, bits 2/3 are events; other bits describe the backdrop.
    if emu.read(table_addr + i, emu.memType.smsPrgRom) & 0x0D == 0 then tile = i break end
  end
  if not tile then error('no passable event-free map tile') end
  for i = 0, 1023 do poke(0xCC00 + i, tile) end
end

local function actor_state(tag)
  local states = {}
  for n = 0, 3 do
    local a = 0xC800 + n * 0x20
    if ram(a) == 0 then error('party actor ' .. n .. ' is missing') end
    states[#states + 1] = string.format('%d:%02X,%02X,%02X,%02X,%02X', n,
      ram(a+2), ram(a+4), ram(a+10), ram(a+18), ram(a+19))
    if n > 0 then
      local dy = math.abs(ram(a+2) - ram(a-0x20+2))
      local dx = math.abs(ram(a+4) - ram(a-0x20+4))
      if dx + dy > 64 then error('party follower separated by more than 64 pixels') end
    end
  end
  log(tag .. ' actors y,x,flags,direction,previous=' .. table.concat(states, ' '))
end

local function map_y()
  return (ram(0xC306) * 192 + ram(0xC305)) % 1536
end
local function tile_step(dir, dx, dy, vehicle)
  fill_passable()
  local x, y = ram16(0xC301), map_y()
  local old_collisions, old_encounters = collision_checks, encounter_checks
  set_held({dir})
  wait_until(function() return ram(0xC265) > 0 end, 80, 'map step start ' .. dir)
  set_held({})
  local t = now()
  wait_until(function() return ram(0xC265) == 0 end, 80, 'map step end ' .. dir)
  wait(2) -- let GameMode_Map process the completed step
  if game_mode() ~= MODE.map then error('left the map during a step') end
  if (ram16(0xC301) - x) % 2048 ~= dx % 2048 or (map_y() - y) % 1536 ~= dy % 1536 then
    error(string.format('%s did not move exactly one tile: x %d->%d y %d->%d',
      dir, x, ram16(0xC301), y, map_y()))
  end
  local checks, rolls = collision_checks - old_collisions, encounter_checks - old_encounters
  if checks ~= 1 or rolls ~= 1 then
    error(string.format('%s: expected one collision and one encounter check, got %d and %d', dir, checks, rolls))
  end
  log(string.format('%s vehicle=%s remaining_frames=%d collision=%d encounter=%d',
    dir, tostring(vehicle), now()-t-2, checks, rolls))
  if now()-t-2 ~= ((vehicle or fast) and 7 or 15) then error('unexpected map speed') end
  return now()-t-2
end

local function reload_map()
  set_held({})
  poke(0xC202, 8)
  wait_until(function() return game_mode() == MODE.map end, 600, 'map reload')
  wait(60)
end

function scenario()
  new_game_to_field(40)
  if game_mode() ~= MODE.map then error('new game did not reach the map') end
  poke(0xC4F0, 3)
  for _, a in ipairs({0xC400, 0xC410, 0xC420, 0xC430}) do poke(a, ram(a) | 1) end
  if world then poke(0xC308, 0) end
  reload_map()
  tracking = true
  actor_state('start')
  -- Four tiles per side establish a visible train, then exercise all four turns.
  for _, leg in ipairs({{'left',-16,0}, {'up',0,-16}, {'right',16,0}, {'down',0,16}}) do
    for _ = 1, 4 do tile_step(leg[1], leg[2], leg[3], false) end
    actor_state(leg[1])
    for n = 0, 3 do
      local a = 0xC800 + n*0x20
      if ram(a+4) ~= 128 - n*leg[2] or ram(a+2) ~= 96 - n*leg[3] then
        error('party follower lost one-tile spacing at the corner')
      end
    end
  end
  shot('party_corners')
  tracking = false
  -- C30E=1 selects a stock vehicle actor and the vehicle collision path.
  poke(0xC30E, 1)
  reload_map()
  tracking = true
  local frames = tile_step('left', -16, 0, true)
  if frames ~= 7 then error('vehicle step timing changed: remaining frames=' .. frames) end
  tracking = false
  log('vehicle step remains two pixels per frame')
end
