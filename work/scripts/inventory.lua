-- The inventory opened and cancelled: nine items given (the list shows its NEXT row), ITEM
-- chosen, the list read back, then button 1; the screen under it must come back as it was.
-- Check the names with --words=items:33-40.
-- Bounded: the new game to the field, the menu helpers' limits.

local function snap()
  local s = {}
  for r = 0, 23 do s[#s + 1] = text_line(r, 0, 31) end
  return table.concat(s, "|")
end

function scenario()
  new_game_to_field(40)
  for i = 0, 8 do poke(0xC4C0 + i, 0x21 + i) end
  poke(0xC4E2, 9)
  open_command_menu()
  wait(30)
  local before = snap()
  press("down", 4, 20)
  press("down", 4, 20)
  press("two", 4, 60)                   -- ITEM
  dump_screen("inventory")
  shot("inventory")
  press("one", 4, 40)                   -- cancel
  wait(20)
  shot("after")
  local same = snap() == before
  log("restored: " .. tostring(same))
  if not same then dump_screen("after") error("the screen under the inventory did not come back") end
end
