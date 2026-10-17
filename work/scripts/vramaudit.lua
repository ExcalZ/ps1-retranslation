-- Which pattern tiles each screen uses: for the engine options (a proportional face needs work
-- tiles). Plays through the intro (cut-scenes), the town map, the command menu with STAS, MAGC
-- and ITEM, a conversation, a shop and a battle; for each phase it records the tiles written
-- (a write callback on VRAM $0000-$37FF, 448 tiles) and the tiles shown (the nametable and the
-- sprite table, sampled every 10 frames). The result is written to work/analysis/vramaudit.json.
-- only=battle enemy=N [bg=N]: the intro and one battle only (bg: the backdrop, $C29E); only=dungeon: a dungeon (walking, the
-- command menu, a battle there). (VDP writes do not reach Mesen's VRAM
-- write callback, so "written" stays empty: "shown" is the measure.)
-- Bounded: as the scenarios it borrows from.

local phase = "boot"
local written, shown = {}, {}
local function mark(t, tile)
  t[phase] = t[phase] or {}
  t[phase][tile] = true
end

emu.addMemoryCallback(function(addr) mark(written, addr // 32) end, emu.callbackType.write,
                      0x0000, 0x37FF, emu.cpuType.sms, emu.memType.smsVideoRam)

-- work RAM the CPU reads or writes, over every phase (for finding RAM a new routine can own)
local ram_w, ram_r = {}, {}
local track_ram = false          -- from the title on: power-on clears all of RAM
emu.addMemoryCallback(function(addr) if track_ram then ram_w[addr] = true end end, emu.callbackType.write,
                      0xC000, 0xDFFF, emu.cpuType.sms, emu.memType.smsMemory)
emu.addMemoryCallback(function(addr) if track_ram then ram_r[addr] = true end end, emu.callbackType.read,
                      0xC000, 0xDFFF, emu.cpuType.sms, emu.memType.smsMemory)

local function sample()
  for cell = 0, 32 * 24 - 1 do
    local lo, hi = vram(0x3800 + 2 * cell), vram(0x3801 + 2 * cell)
    mark(shown, lo + 256 * (hi & 1))
  end
  for i = 0, 63 do
    local y = vram(0x3F00 + i)
    if y == 0xD0 then break end
    mark(shown, 256 + vram(0x3F81 + 2 * i))   -- sprites take tiles 256-511 (register 6)
  end
end

local sample_every = 10
emu.addEventCallback(function()
  if now() % sample_every == 0 then sample() end
end, emu.eventType.endFrame)

local function set_phase(p) phase = p log("phase " .. p) end

local function choose(n)
  for _ = 2, n do press("down", 4, 10) end
  press("two", 4, 40)
end
local function leave()
  for _ = 1, 6 do
    if game_mode() ~= MODE.interaction and #area_text(2, 10, 1, 6) < 5 then return end
    press("one", 4, 30)
  end
end

function scenario()
  wait_until(function() return game_mode() == MODE.intro end, 900, "the title")
  track_ram = true
  set_phase("intro")
  new_game_to_field(40)
  if PS1.params.only == "battle" then goto battle end
  if PS1.params.only == "dungeon" then
    -- the dungeon a game event enters (Dungeon_position $159C: index $15, position $9C;
    -- direction 1; LABEL_534B), then walk, turn, the command menu and a battle there
    set_phase("dungeon")
    wait(60)
    poke(0xC30C, 0x9C) poke(0xC30D, 0x15) poke(0xC30A, 0x01) poke(0xC202, 0x0A)
    wait_until(function() return game_mode() == MODE.dungeon end, 600, "the dungeon")
    wait(60)
    shot("dungeon")
    for _, b in ipairs({ "up", "up", "left", "up", "right", "right", "up", "down" }) do
      press(b, 4, 40)
    end
    shot("dungeon_walked")
    set_phase("dungeon menus")
    open_command_menu()
    choose(1) wait(30) leave()
    for i = 0, 8 do poke(0xC4C0 + i, 0x21 + i) end
    poke(0xC4E2, 9)
    wait(30)
    open_command_menu() choose(3) wait(30) leave()
    wait_until(function() return #area_text(2, 10, 1, 6) < 5 and not window_open() end, 300, "the menus closed")
    wait(60)                             -- the screen under the windows restored before the battle
    set_phase("dungeon battle")
    poke(0xC408, 255) poke(0xC401, 99) poke(0xC406, 99)
    poke(0xC2E6, 1) poke(0xC29D, 0xFF) poke(0xC202, 0x0C)
    wait_until(function() return battle_menu_up() end, 300, "the battle menu")
    local start = now()
    while game_mode() == MODE.interaction and now() - start < 3000 do
      if at_button_wait() then press("one", 4, 6)
      elseif yes_no_shown() then wait(20) press("two", 4, 20)
      elseif battle_menu_up() and not at_timed_wait() then press("two", 4, 20)
      else wait(1) end
    end
    wait(60)
    shot("after_battle")
    log("back in game mode " .. game_mode())
    goto done
  end
  set_phase("town")
  set_held({ "left" }) wait(60) set_held({ "down" }) wait(60) set_held({}) wait(60)
  set_phase("menus")
  open_command_menu()
  choose(1) wait(30) leave()
  poke(0xC40F, 2)
  for i = 0, 8 do poke(0xC4C0 + i, 0x21 + i) end
  poke(0xC4E2, 9)
  open_command_menu() choose(2) wait(30) leave()
  open_command_menu() choose(3) wait(30) leave()
  set_phase("talk")
  wait(60)
  for try = 1, 5 do
    poke(0xC2DB, 1)
    press("one", 4, 0)
    if pcall(wait_until, window_open, 120, "the window") then break end
  end
  page_window(30, "t")
  set_phase("shop")
  wait(60)
  poke(0xC4E0, 0xD0) poke(0xC4E1, 0x07)
  for try = 1, 5 do
    poke(0xC29E, 0x16) poke(0xC2DB, 1)
    press("one", 4, 0)
    if pcall(wait_until, window_open, 120, "the shop") then break end
  end
  wait_for_button_wait(600, "the shop's page") press("one", 4, 6)
  wait_until(yes_no_shown, 300, "YES / NO") wait(20) press("two", 4, 0)
  wait_until(function() return #area_text(2, 6, 6, 21) >= 1 end, 300, "the stock list") wait(30)
  press("one", 4, 30)
  for _ = 1, 10 do
    if not window_open() and game_mode() ~= MODE.interaction then break end
    if yes_no_shown() then press("down", 4, 10) press("two", 4, 20)
    elseif at_button_wait() then press("one", 4, 10)
    else press("one", 4, 30) end
  end
  ::battle::
  do
  set_phase("battle")
  wait(60)
  poke(0xC408, 255) poke(0xC401, 99) poke(0xC406, 99)
  if PS1.params.bg then poke(0xC29E, tonumber(PS1.params.bg)) end   -- the backdrop (Interaction_Type)
  poke(0xC2E6, tonumber(PS1.params.enemy or 1)) poke(0xC29D, 0xFF) poke(0xC202, 0x0C)
  wait_until(function() return battle_menu_up() end, 300, "the battle menu")
  local start = now()
  while game_mode() == MODE.interaction and now() - start < 3000 do
    if at_button_wait() then press("one", 4, 6)
    elseif yes_no_shown() then wait(20) press("two", 4, 20)
    elseif battle_menu_up() and not at_timed_wait() then press("two", 4, 20)
    else wait(1) end
  end
  end
  ::done::
  set_phase("end")

  local f = io.open(PS1.out .. "/vramaudit.json", "w")
  f:write("{")
  local first = true
  for _, kind in ipairs({ "written", "shown" }) do
    local t = kind == "written" and written or shown
    for p, tiles in pairs(t) do
      local list = {}
      for tile in pairs(tiles) do list[#list + 1] = tile end
      table.sort(list)
      for i, v in ipairs(list) do list[i] = tostring(v) end
      f:write((first and "" or ",") .. string.format('"%s %s": [%s]', kind, p, table.concat(list, ",")))
      first = false
    end
  end
  local untouched = {}
  for a = 0xC000, 0xDFFF do
    if not ram_w[a] and not ram_r[a] then untouched[#untouched + 1] = tostring(a) end
  end
  f:write(string.format(',"ram untouched": [%s]', table.concat(untouched, ",")))
  f:write("}")
  f:close()
  log("wrote vramaudit.json")
end
