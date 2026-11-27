-- battle_macros: two slots used in turn in one battle (the owner's report, 2026-11-26: slot B
-- with Lutz casting, then slot A with Lutz fighting, and Lutz cast again).
--
-- All four members (as macros.lua), Lutz with his five battle spells and 30 MP. Slot A: every
-- line Fight (01 00); slot B: Lutz Magic, his first spell (03 00), the others Fight. Battle
-- (enemy=N, default 1, its HP kept up): round 1 slot B, rounds 2 and 3 slot A. Each round the
-- members' records at $C2AC are checked against the slot, and the round's messages logged.
-- Check: the scenario raises on any difference.
-- Bounded: every wait limited, 12 presses to reach a line, 3000 frames a round.

local ENEMY = tonumber(PS1.params.enemy or 1)
local DATA = 0xC3C0

local function bytes(addr, n)
  local t = {}
  for i = 0, n - 1 do t[#t + 1] = string.format("%02X", ram(addr + i)) end
  return table.concat(t, " ")
end

local function cursor_row(col, r0, r1, step)
  for _ = 1, 40 do
    for r = r0, r1, step do
      if vram(0x3800 + r * 64 + col * 2) == 0xF0 then return r end
    end
    wait(1)
  end
  error(string.format("no cursor in column %d, rows %d-%d", col, r0, r1))
end

local function cursor_to(col, r0, r1, step, want)
  for _ = 1, 12 do
    local at = cursor_row(col, r0, r1, step)
    if at == want then return end
    press(at < want and "down" or "up", 2, 16)
  end
  if cursor_row(col, r0, r1, step) ~= want then error("the cursor did not reach row " .. want) end
end

local function slots()
  local t = {}
  for r = 2, 9 do t[#t + 1] = (text_line(r, 9, 9):gsub("[%s~]+", "")) end
  return t
end

local function preview()
  local t = {}
  for r = 12, 15 do t[#t + 1] = (text_line(r, 9, 25):gsub("^[%s~]+", ""):gsub("[%s~]+$", "")) end
  return t
end

-- one round: the first window, Macro, slot (2 A, 3 B), the records checked; then its messages
local function round(n, row, want)
  wait_until(function() return battle_top_up() and not window_open() end, 3000, "the round's first window")
  poke(0xC441, 200)                      -- the enemy stays up
  wait(20)
  cursor_to(1, 2, 8, 2, 4)               -- Macro
  press("two", 4, 30)
  wait_until(function() return #table.concat(slots()) >= 8 end, 300, "the slots A-H")
  wait(20)
  cursor_to(8, 2, 9, 1, row)
  wait(20)
  log(string.format("round %d, slot %s: %s", n, row == 2 and "A" or "B", table.concat(preview(), " / ")))
  shot("round" .. n)
  press("two", 4, 0)
  wait_until(function() return ram(0xC267) >= 4 end, 120, "the macro's commands")
  local rec = bytes(0xC2AC, 16)
  log(string.format("round %d records: %s (MacroSlot %d); Lutz MP %d", n, rec, ram(0xC7C5), ram(0xC432)))
  if rec ~= want then error(string.format("round %d: records %s, not %s", n, rec, want)) end
  wait_until(function() return not battle_top_up() end, 300, "the first window closed")
  local last, start = nil, now()
  while not (battle_top_up() and not window_open()) do
    if now() - start > 3000 then error("round " .. n .. " still on after 3000 frames") end
    if game_mode() ~= MODE.interaction then error("the battle ended in round " .. n) end
    if at_button_wait() or at_timed_wait() then
      local text = table.concat(dialogue_text(), " / ")
      if text ~= last then
        wait(2)
        text = table.concat(dialogue_text(), " / ")
        log(string.format("round %d: %s", n, text))
        last = text
      end
      if at_button_wait() then press("one", 4, 6) else wait(1) end
    else
      wait(1)
    end
  end
end

local function commands() return area_text(2, 6, 13, 17) end

-- the field editor: slot (2 A, 3 B), Lutz (preview row 15), Fight (row 2) or his first spell
local function edit_lutz(row, magic)
  cursor_to(8, 2, 9, 1, row)
  wait(20)
  press("two", 4, 30)
  cursor_row(8, 12, 15, 1)
  cursor_to(8, 12, 15, 1, 15)
  press("two", 4, 40)
  wait_until(function() return #commands() >= 3 end, 300, "Fight / Magic / Item")
  cursor_to(12, 2, 6, 2, magic and 4 or 2)
  press("two", 4, 60)
  if magic then
    wait(20)
    log("spells: " .. table.concat(area_text(10, 18, 7, 12), " / "))
    press("two", 4, 60)
  end
  wait_until(function() return #commands() == 0 end, 300, "the commands closed")
  wait(30)
  log(string.format("slot %s edited: %s; macros %s", row == 2 and "A" or "B",
      table.concat(preview(), " / "), bytes(DATA, 16)))
  press("one", 4, 30)                    -- back to the slots
  cursor_row(8, 2, 9, 1)
end

local function editor()
  open_command_menu()
  wait(10)
  cursor_to(1, 2, 12, 2, 10)             -- Macro
  press("two", 4, 30)
  wait_until(function() return #table.concat(slots()) >= 8 end, 300, "the slots A-H")
  wait(20)
  edit_lutz(3, true)                     -- B: Lutz, Flaeli
  edit_lutz(2, false)                    -- A: Lutz, Fight
  press("one", 4, 30)
  wait_until(function() return #area_text(2, 12, 1, 6) == 6 and slots()[1] == "" end, 300,
             "the field menu without the slots")
  press("one", 4, 30)
  wait_until(function() return #area_text(2, 12, 1, 6) == 0 end, 300, "the field menu closed")
  local m = bytes(DATA, 16)
  log("macros after the editor: " .. m)
  if m ~= "01 00 01 00 01 00 01 00 01 00 01 00 01 00 03 00" then
    error("the editor's macros are not A all Fight, B Lutz Flaeli")
  end
end

function scenario()
  if PS1.params.probe then               -- with state=: what a savestate holds
    wait(2)
    log("mode " .. game_mode() .. ", macros: " .. bytes(DATA, 64))
    log("MacroSlot " .. ram(0xC7C5) .. ", party " .. ram(0xC4F0) .. ", $C267 " .. ram(0xC267) ..
        ", records " .. bytes(0xC2AC, 16))
    for m = 0, 3 do log(string.format("member %d: %s", m, bytes(0xC400 + 16 * m, 16))) end
    shot("probe")
    return
  end
  new_game_to_field(40)
  wait(60)
  poke(0xC4F0, 3)                        -- all four
  for _, m in ipairs({ 0xC400, 0xC410, 0xC420, 0xC430 }) do
    poke(m, ram(m) | 1)
    poke(m + 1, 99) poke(m + 6, 99)
  end
  poke(0xC43E, 5)                        -- Lutz: Fire, Tele, Wind, Prot, Thun
  poke(0xC432, 30) poke(0xC437, 30)
  for i = 0, 7, 2 do poke(DATA + i, 1) poke(DATA + i + 1, 0) end
  for i = 0, 7, 2 do poke(DATA + 8 + i, 1) poke(DATA + 9 + i, 0) end
  if PS1.params.editor then
    poke(DATA + 6, 0) poke(DATA + 14, 0)   -- Lutz not set in either: the editor sets them
    log("macros: " .. bytes(DATA, 16))
    editor()
  else
    poke(DATA + 14, 3) poke(DATA + 15, 0)  -- B: Lutz, Magic, his first spell
    if PS1.params.unset then poke(DATA + 6, 0) end  -- A made before Lutz joined: his line not set
    log("macros: " .. bytes(DATA, 16))
  end
  wait(60)
  poke(0xC2E6, ENEMY) poke(0xC29D, 0xFF) poke(0xC202, 0x0C)
  local fight = "01 00 00 00 01 00 00 00 01 00 00 00 "
  round(1, 3, fight .. "03 05 00 00")    -- Fire (MagicID_Fire 5), the third byte 0
  round(2, 2, fight .. "01 00 00 00")
  round(3, 2, fight .. "01 00 00 00")
  log("done")
end
