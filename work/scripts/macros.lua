-- battle_macros: a macro set in the field menu's Macro, then used in a battle.
--
-- All four members (party=4 as battle.lua), Alisa with four battle spells and 30 MP, Myau
-- with Cure, a PelorieMate and a Searchlight held. Field: the menu's six entries are read; Macro
-- (the fifth) opens the slots A-H and the preview; slot B, Alisa: Magic, Heal, for Myau;
-- Myau: Item, the PelorieMate; Tyrone: Fight. The macro bytes ($C3C0 + 8) and the preview are
-- checked after each line, then B, B, B back to the field. Battle (enemy=N, default 1): the
-- round's first window is read (Command / Macro / Talk / Flee), Macro, slot B (the cursor
-- starts on it), its preview read, C: the members' records at $C2AC must be the macro's
-- (Lutz, whose line is not set, fights). Then the battle runs to its end (Command, Fight -
-- the first window's cursor moved back to Command; a party menu an item opens is answered with C).
-- stress=1: no editing; slot B is four of the widest item names (Telepathy Ball, Damour
-- Crystal, Carbuncle Eye, Light Pendant), its preview read in the battle (with enemy=39, the
-- battle that lends the fewest tiles) and the macro used (the items are not held: Fight).
-- first=talk|flee: no macro; the battle's first window's Talk or Flee (the stock's, by Alisa),
-- then the battle as above (Flee: escaped, or the next round's first window).
-- The colours are checked at each step: a slot's letter red when empty, amber when a party
-- member's line cannot be carried out as set (stress=1: the items not held), those lines amber;
-- a line not set (Lutz's) is Fight, white.
-- Check: the scenario raises on any difference; --words=macro_words:0-3,field_menu,battle_menu:0-2.
-- Bounded: every wait limited, 12 presses to reach an entry, 6000 frames of battle, 40 rounds.

local ENEMY = tonumber(PS1.params.enemy or 1)
local DATA = 0xC3C0

local function bytes(addr, n)
  local t = {}
  for i = 0, n - 1 do t[#t + 1] = string.format("%02X", ram(addr + i)) end
  return table.concat(t, " ")
end

-- the row of the cursor (tile $F0, it blinks) in column col, rows r0..r1 by step
local function cursor_row(col, r0, r1, step)
  for _ = 1, 40 do
    for r = r0, r1, step do
      if vram(0x3800 + r * 64 + col * 2) == 0xF0 then return r end
    end
    wait(1)
  end
  error(string.format("no cursor in column %d, rows %d-%d", col, r0, r1))
end

-- the row the cursor is drawn on this frame in column col, rows r0..r1 (step 2), or nil
local function cursor_shown(col, r0, r1)
  for r = r0, r1, 2 do
    if vram(0x3800 + r * 64 + col * 2) == 0xF0 then return r end
  end
  return nil
end

-- move the cursor of a list (column col, rows r0..r1 by step) to row want, a press at a time
local function cursor_to(col, r0, r1, step, want)
  for _ = 1, 12 do
    local at = cursor_row(col, r0, r1, step)
    if at == want then return end
    press(at < want and "down" or "up", 2, 16)
  end
  if cursor_row(col, r0, r1, step) ~= want then error("the cursor did not reach row " .. want) end
end

local function rows(r0, r1, c0, c1)
  local t = {}
  for r = r0, r1 do t[#t + 1] = (text_line(r, c0, c1):gsub("^[%s~]+", ""):gsub("[%s~]+$", "")) end
  return t
end

local function slots() return rows(2, 9, 9, 9) end

-- the colours (battle_macros' marks): a letter a slot A-H, a letter a preview line; r red,
-- a amber, w white, - none
local function inks(r0, r1, c0, c1)
  local t = {}
  for r = r0, r1 do t[#t + 1] = (run_ink(r, c0, c1) or "-"):sub(1, 1) end
  return table.concat(t)
end
local function expect_inks(what, letters, lines)
  local l, p = inks(2, 9, 9, 9), inks(12, 15, 9, 25)
  log(string.format("%s: slots %s, preview %s", what, l, p))
  if l ~= letters or p ~= lines then
    error(string.format("%s: slots %s preview %s, not %s %s", what, l, p, letters, lines))
  end
end
local function preview() return rows(12, 15, 9, 25) end
local function commands() return area_text(2, 6, 13, 17) end

local function expect(addr, want, what)
  local have = bytes(addr, #want // 3 + 1)
  log(string.format("%s: %s", what, have))
  if have ~= want then error(string.format("%s: %s, not %s", what, have, want)) end
end

local function field()
  open_command_menu()
  wait(10)
  local menu = area_text(2, 12, 1, 6)
  log("field menu: " .. table.concat(menu, " / "))
  dump_screen("field")
  if #menu ~= 6 then error("the field menu has " .. #menu .. " entries, not 6") end
  cursor_to(1, 2, 12, 2, 10)             -- Macro
  press("two", 4, 30)
  wait_until(function() return #table.concat(slots()) >= 8 end, 300, "the slots A-H")
  wait(20)
  log("slots: " .. table.concat(slots(), " "))
  log("preview A: " .. table.concat(preview(), " / "))
  expect_inks("colours, nothing set", "rrrrrrrr", "wwww")
  dump_screen("slots")
  shot("slots")
  cursor_to(8, 2, 9, 1, 3)               -- slot B
  wait(20)
  log("preview B (empty): " .. table.concat(preview(), " / "))
  press("two", 4, 30)
  cursor_row(8, 12, 15, 1)               -- the members
  -- Alisa: Magic, Heal, for Myau
  press("two", 4, 40)
  wait_until(function() return #commands() >= 3 end, 300, "Fight / Magic / Item")
  log("commands: " .. table.concat(commands(), " / "))
  shot("commands")
  cursor_to(12, 2, 6, 2, 4)              -- Magic
  press("two", 4, 60)
  wait(20)
  log("spells: " .. table.concat(area_text(10, 18, 7, 12), " / "))
  shot("spells")
  press("two", 4, 60)                    -- Heal
  wait(20)
  dump_screen("whom")
  shot("whom")
  cursor_to(10, 10, 16, 2, 12)           -- Myau
  press("two", 4, 60)
  wait_until(function() return #commands() == 0 end, 300, "the commands closed")
  wait(30)
  log("preview B: " .. table.concat(preview(), " / "))
  expect(DATA + 8, "53 00", "Alisa's line")
  expect_inks("colours, Alisa's line set", "rwrrrrrr", "wwww")
  -- Myau: Item, the PelorieMate
  cursor_to(8, 12, 15, 1, 13)
  press("two", 4, 40)
  wait_until(function() return #commands() >= 3 end, 300, "Fight / Magic / Item")
  cursor_to(12, 2, 6, 2, 6)              -- Item
  press("two", 4, 60)
  wait(30)
  shot("items")
  press("two", 4, 60)                    -- the first item
  wait_until(function() return #commands() == 0 end, 300, "the commands closed")
  wait(30)
  expect(DATA + 10, "04 24", "Myau's line")
  -- Tyrone: Fight
  cursor_to(8, 12, 15, 1, 14)
  press("two", 4, 40)
  wait_until(function() return #commands() >= 3 end, 300, "Fight / Magic / Item")
  press("two", 4, 60)                    -- Fight
  wait_until(function() return #commands() == 0 end, 300, "the commands closed")
  wait(30)
  expect(DATA + 12, "01 00", "Tyrone's line")
  local p = preview()
  log("preview B: " .. table.concat(p, " / "))
  expect_inks("colours, Lutz not set", "rwrrrrrr", "wwww")
  dump_screen("set")
  shot("set")
  press("one", 4, 30)                    -- back to the slots
  cursor_row(8, 2, 9, 1)
  press("one", 4, 30)                    -- back to the field menu
  wait_until(function() return #area_text(2, 12, 1, 6) == 6 and slots()[1] == "" end, 300,
             "the field menu without the slots")
  shot("menu_again")
  press("one", 4, 30)
  wait_until(function() return #area_text(2, 12, 1, 6) == 0 end, 300, "the field menu closed")
  log("macros: " .. bytes(DATA, 16))
end

local function battle()
  wait(60)
  poke(0xC408, 255) poke(0xC401, 99) poke(0xC406, 99)
  poke(0xC2E6, ENEMY) poke(0xC29D, 0xFF) poke(0xC202, 0x0C)
  wait_until(function() return battle_top_up() and not window_open() end, 600, "the round's first window")
  wait(20)
  local top = area_text(2, 10, 1, 7)
  log("first window: " .. table.concat(top, " / "))
  dump_screen("battle")
  shot("battle")
  if #top ~= 4 then error("the first window has " .. #top .. " entries, not 4") end
  local first = PS1.params.first
  if first == "talk" or first == "flee" then
    cursor_to(1, 2, 8, 2, first == "talk" and 6 or 8)
    press("two", 4, 0)
    log("chose " .. first)
  else
  cursor_to(1, 2, 8, 2, 4)               -- Macro
  press("two", 4, 30)
  wait_until(function() return #table.concat(slots()) >= 8 end, 300, "the slots A-H")
  wait(20)
  if cursor_row(8, 2, 9, 1) ~= 3 then error("the slots' cursor is not on B") end
  log("battle preview B: " .. table.concat(preview(), " / "))
  expect_inks("battle colours", PS1.params.stress and "rarrrrrr" or "rwrrrrrr",
              PS1.params.stress and "aaaa" or "wwww")
  dump_screen("battle_slots")
  shot("battle_slots")
  press("two", 4, 0)                     -- use B
  wait_until(function() return ram(0xC267) >= 4 end, 120, "the macro's commands")
  -- the records: command, spell or item, third byte (LABEL_1BB9), 4 bytes a member
  local rec = bytes(0xC2AC, 16)
  log("records: " .. rec)
  local want = PS1.params.stress and "01 00 00 00 01 00 00 00 01 00 00 00 01 00 00 00" or
               "03 01 01 00 04 24 00 00 01 00 00 00 01 00 00 00"
  if rec ~= want then error("the records are not the macro's") end
  wait(10)
  shot("used")
  end

  local page, last, rounds, start = 0, nil, 0, now()
  while game_mode() == MODE.interaction do
    if now() - start > 6000 then error("the battle still on after 6000 frames") end
    if at_button_wait() or at_timed_wait() then
      local text = table.concat(dialogue_text(), " / ")
      if text ~= last then
        wait(2)
        text = table.concat(dialogue_text(), " / ")
        page = page + 1
        log(string.format("page %d (window): %s", page, text))
        last = text
      end
      if at_button_wait() then press("one", 4, 6) else wait(1) end
    elseif yes_no_shown() then
      wait(20)
      press("two", 4, 20)
    elseif vram(0x3800 + 10 * 64 + 20) == 0xF0 then   -- a party menu (an item's target)
      log("whom: " .. table.concat(area_text(10, 16, 11, 17), " / "))
      press("two", 4, 20)
    elseif battle_menu_up() and not window_open() and cursor_shown(1, 2, 8) then
      if battle_top_up() and cursor_shown(1, 2, 8) ~= 2 then
        press("up", 2, 16)                 -- toward Command (the cursor keeps the last choice)
      else
        if not battle_top_up() then
          rounds = rounds + 1
          if rounds > 40 then error("still fighting after 40 rounds") end
        end
        press("two", 4, 20)
      end
    else
      wait(1)
    end
  end
  wait(30)
  shot("after")
  log(string.format("battle over after %d more rounds; Myau HP %d", rounds, ram(0xC411)))
end

function scenario()
  new_game_to_field(40)
  wait(60)
  poke(0xC4F0, 3)                        -- all four
  for _, m in ipairs({ 0xC400, 0xC410, 0xC420, 0xC430 }) do
    poke(m, ram(m) | 1)
    if ram(m + 1) == 0 then poke(m + 1, 20) poke(m + 6, 20) end
  end
  poke(0xC40E, 4)                        -- Alisa: Heal, Whisk, Fluency, Flaeli
  poke(0xC402, 30) poke(0xC407, 30)
  poke(0xC41E, 1)                        -- Myau: Megaheal
  poke(0xC412, 20) poke(0xC417, 20)
  poke(0xC4C0, 0x24) poke(0xC4C1, 0x27) poke(0xC4E2, 2)
  log("macros before: " .. bytes(DATA, 16))
  if PS1.params.stress then
    for i, b in ipairs({ 0x04, 0x2E, 0x04, 0x3C, 0x04, 0x3A, 0x04, 0x39 }) do poke(DATA + 7 + i, b) end
    poke(0xC7C5, 1)                        -- MacroSlot: B
  elseif not PS1.params.first then field() end
  battle()
end
