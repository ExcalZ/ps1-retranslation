-- The party menu with four members: the party is filled (Party_curr_num $C4F0 = 3, each
-- member alive: status bit 0 of $C400/$C410/$C420/$C430), STAS asks who, and the menu is read
-- back (rows 9-17), then cancelled; the screen under it must come back as it was.
-- Check the names with --words=status_boxes (or party in capitals with long_names).
-- Bounded: the new game to the field, the menu helpers' limits.

local function snapshot()
  local s = {}
  for r = 8, 18 do s[#s + 1] = text_line(r, 0, 31) end
  return table.concat(s, "|")
end

function scenario()
  new_game_to_field(40)
  poke(0xC4F0, 3)
  for _, a in ipairs({ 0xC400, 0xC410, 0xC420, 0xC430 }) do
    poke(a, ram(a) | 1)
    if ram(a + 1) == 0 then poke(a + 1, 20) end          -- some HP
  end
  open_command_menu()
  local before = snapshot()
  for try = 1, 3 do                     -- STAS: who? (the menu takes a moment to listen)
    wait(20)
    press("two", 4, 0)
    if pcall(wait_until, function() return snapshot() ~= before end, 120, "the party menu") then break end
    if try == 3 then error("STAS did not open the party menu in 3 presses") end
  end
  wait(30)
  dump_screen("party")
  shot("partymenu")
  press("one", 4, 40)                   -- cancel
  wait(20)
  local after = snapshot()
  shot("after")
  log("restored: " .. tostring(after == before))
  if after ~= before then
    dump_screen("after")
    error("the screen under the party menu did not come back")
  end
end
