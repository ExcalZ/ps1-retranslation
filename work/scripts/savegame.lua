-- Save a game. SAVE from the command menu: the save prompt (a button wait if it has two pages),
-- the slot list (button 2 on slot 1), "YOU SELECTED 1 / IS THAT O.K." with YES/NO (button 2 on
-- YES), the naming screen (type_name: every key checked under the cursor; a slot already named
-- skips it and says "WELL, SAVING 1." / "COMPLETED." instead); the name must then be in the
-- cartridge RAM. continue.lua, run after it with --keep-sram, loads the game. The window text
-- at each step is logged.
-- name=XXXXX sets the slot's name (default TEST).
-- Bounded: the new game to the field, every wait limited, the run's frame cap.

local NAME = PS1.params.name or "TEST"

local function window_line(tag)
  wait(4)
  log(string.format("%s: %s", tag, table.concat(dialogue_text(), " / ")))
end

local function slots() return area_text(3, 11, 23, 31) end

function scenario()
  new_game_to_field(40)
  open_command_menu()
  for _ = 1, 4 do press("down", 4, 10) end
  press("two", 4, 0)
  -- the stock's two pages wait for a button first; a one-page prompt opens the slot list at once
  wait_until(function() return at_button_wait() or #slots() >= 5 end, 300, "the save prompt")
  window_line("save")
  shot("save")
  if #slots() < 5 then press("one", 4, 0) end
  wait_until(function() return #slots() >= 5 end, 300, "the slot list")
  window_line("slots")
  log("slots: " .. table.concat(slots(), " / "))
  press("two", 4, 0)                     -- slot 1
  wait_until(yes_no_shown, 300, "YES / NO")
  window_line("confirm")
  for try = 1, 3 do                      -- YES; the prompt takes a moment to listen
    wait(20)
    press("two", 4, 0)
    if pcall(wait_until, function() return game_mode() >= 16 end, 120, "the naming screen") then break end
    if try == 3 then error("YES did not lead to the naming screen in 3 presses") end
  end
  type_name(NAME)
  -- after a new name the game saves and goes straight back to the command menu; into a named
  -- slot it says "WELL, SAVING 1." and waits on "COMPLETED."
  wait_until(function()
    return at_button_wait() or (game_mode() == MODE.interaction and #area_text(2, 10, 1, 6) >= 5)
  end, 900, "COMPLETED or the command menu")
  if at_button_wait() then
    window_line("saved")
    press("one", 4, 30)
  else
    log("saved: back at the command menu")
  end
  shot("saved")

  -- the name is in the cartridge RAM now (the battery Mesen keeps for --keep-sram runs): the
  -- slot list there (from $0100) is a tilemap of (tile, attribute) pairs, so the name is its
  -- font tiles (A = $CB) every second byte
  local size = emu.getMemorySize(emu.memType.smsCartRam)
  local found
  for off = 0, size - 2 * #NAME do
    local ok = true
    for i = 1, #NAME do
      if emu.read(off + 2 * (i - 1), emu.memType.smsCartRam) ~= NAME:byte(i) - 0x41 + 0xCB then ok = false break end
    end
    if ok then found = off break end
  end
  if not found then error(NAME .. " is not in the cartridge RAM's slot list") end
  log(string.format("saved: %s in the cartridge RAM's slot list at $%04X", NAME, found))
end
