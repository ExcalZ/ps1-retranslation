-- The windows no other scenario reaches, one a run: screen=hospital | church | sell | port |
-- dungeon. Each opens its window without walking, dumps the screen (for --words), films it,
-- backs out with button 1 and checks the screen under it came back.
--   hospital: Interaction_Type $12 (LABEL_298D): YES, then the party menu (who?)
--   church:   $14 (LABEL_2A85): YES, then the party menu
--   sell:     $1A, the second-hand shop (LABEL_2C98): the BUY / SELL menu, SELL, the inventory
--   port:     talk 181 (LABEL_56F9): the ship's destinations (LABEL_3A21)
--   dungeon:  the dungeon a game event enters (as vramaudit): the command menu, ITEM, STAS
-- All four members are in the party and alive, nine items given, 2000 meseta.
-- Check with --words: hospital / church party_menu? (the party menu shows LongNames: check
-- the logged rows), sell shop_menu,items:33-40, port spaceport, dungeon
-- field_menu,items:33-40,status_labels.
-- Bounded: the new game to the field, 5 tries to open, every wait limited, 60 steps to reach
-- the window.

local SCREEN = PS1.params.screen or "hospital"

local function snap()
  local s = {}
  for r = 0, 23 do s[#s + 1] = text_line(r, 0, 31) end
  return table.concat(s, "|")
end

local function open(type, id)
  for try = 1, 5 do
    poke(0xC29E, type)
    poke(0xC2DB, id)
    press("one", 4, 0)
    if pcall(wait_until, window_open, 120, "the window") then return end
  end
  error("no window in 5 tries")
end

-- press on (button 1 at a page, YES at a YES / NO, `choose` at a menu) until `done`
local function reach(done, what, at_menu)
  for step = 1, 60 do
    if done() then return end
    if yes_no_shown() then
      wait(20)
      press("two", 4, 30)
    elseif at_menu and at_menu() then
      wait(10)
    elseif at_button_wait() then
      wait(2)
      log("page: " .. table.concat(dialogue_text(), " / "))
      press("one", 4, 10)
    else
      wait(10)
    end
  end
  error("did not reach " .. what .. " in 60 steps")
end

local function party_menu_up() return #area_text(10, 16, 3, 9) >= 4 end
local function inventory_up() return #area_text(5, 21, 21, 31) >= 5 end

-- the command menu's cursor (tile $F0 in column 1, rows 2-10) moved to entry n (1 STAS ... 5 SAVE)
local function menu_to(n)
  local function cursor()                -- tile $F0 in column 1, rows 2-10 (it blinks)
    for _ = 1, 40 do
      for k = 1, 5 do
        if vram(0x3800 + (2 * k) * 64 + 2) == 0xF0 then return k end
      end
      wait(1)
    end
    error("no cursor in the menu")
  end
  for _ = 1, 12 do                       -- one press at a time, checked (no wrapping round)
    local at = cursor()
    if at == n then break end
    press(at < n and "down" or "up", 2, 16)
  end
  if cursor() ~= n then error("the cursor did not reach entry " .. n) end
end

local function look(tag)
  wait(30)
  dump_screen(tag)
  shot(tag)
end

function scenario()
  new_game_to_field(40)
  poke(0xC4F0, 3)
  for _, m in ipairs({ 0xC400, 0xC410, 0xC420, 0xC430 }) do
    poke(m, ram(m) | 1)
    if ram(m + 1) == 0 then poke(m + 1, 20) poke(m + 6, 20) end
  end
  for i = 0, 8 do poke(0xC4C0 + i, 0x21 + i) end
  poke(0xC4E2, 9)
  poke(0xC4E0, 2000 % 256) poke(0xC4E1, 2000 // 256)
  wait(60)

  if SCREEN == "hospital" or SCREEN == "church" then
    open(SCREEN == "hospital" and 0x12 or 0x14, 1)
    reach(party_menu_up, "the party menu")
    look(SCREEN)
    log("party menu: " .. table.concat(area_text(10, 16, 3, 9), " / "))
  elseif SCREEN == "sell" then
    open(0x1A, 1)
    local function buy_sell() return #area_text(14, 16, 5, 9) >= 2 end
    reach(buy_sell, "the BUY / SELL menu")
    look("buy_sell")
    log("buy / sell: " .. table.concat(area_text(14, 16, 5, 9), " / "))
    press("down", 4, 10)
    press("two", 4, 30)                  -- SELL
    reach(inventory_up, "the inventory to sell from", buy_sell)
    look("sell")
    log("inventory: " .. table.concat(area_text(5, 21, 21, 31), " / "))
  elseif SCREEN == "port" then
    for try = 1, 5 do
      poke(0xC2DB, 181)
      press("one", 4, 0)
      if pcall(wait_until, window_open, 120, "the window") then break end
      if try == 5 then error("no window for talk 181 in 5 tries") end
    end
    local function port_up() return #area_text(12, 16, 19, 25) >= 3 end
    reach(port_up, "the destinations")
    look("port")
    log("destinations: " .. table.concat(area_text(12, 16, 19, 25), " / "))
  elseif SCREEN == "dungeon" then
    poke(0xC30C, 0x9C) poke(0xC30D, 0x15) poke(0xC30A, 0x01) poke(0xC202, 0x0A)
    wait_until(function() return game_mode() == MODE.dungeon end, 600, "the dungeon")
    wait(60)
    local before = snap()
    log("command menu: " .. table.concat(open_command_menu(), " / "))
    look("dungeon_menu")
    menu_to(3)
    press("two", 4, 40)                  -- ITEM
    wait_until(inventory_up, 300, "the inventory")
    look("dungeon_item")
    log("inventory: " .. table.concat(area_text(5, 21, 21, 31), " / "))
    press("one", 4, 40)
    wait_until(function() return not inventory_up() end, 300, "the inventory to close")
    wait(20)
    menu_to(1)
    press("two", 4, 40)                  -- STAS
    wait(30)
    if party_menu_up() then press("two", 4, 40) end   -- who? Alisa
    wait_until(function() return #area_text(6, 16, 17, 30) >= 4 end, 300, "the status window")
    look("dungeon_stas")
    log("status: " .. table.concat(area_text(6, 16, 17, 30), " / "))
    for _ = 1, 8 do
      if #area_text(2, 10, 1, 6) < 5 and not window_open() then break end
      press("one", 4, 30)
    end
    wait(40)
    local same = snap() == before
    log("restored: " .. tostring(same))
    if not same then dump_screen("after") error("the dungeon view did not come back") end
    return
  else
    error("screen=" .. SCREEN .. "?")
  end
  -- back out: button 1 until the windows are gone
  for _ = 1, 8 do
    if not window_open() and #area_text(2, 22, 1, 30) == 0 then break end
    if yes_no_shown() then press("down", 4, 10) press("two", 4, 30)
    else press("one", 4, 30) end
  end
  wait(30)
  shot("after")
  log("backed out (game mode " .. game_mode() .. ")")
end
