-- The party menu's second place ($7A54, LABEL_3682): a field HEAL with all four members. MAGC,
-- the caster (the party menu at $7A44), HEAL, then the target (the party menu at $7A54); one
-- cancel closes all three and the command menu and status boxes must be back as they were.
-- Bounded: the new game to the field, fixed waits between presses.

local function snap()
  local s = {}
  for r = 0, 23 do s[#s + 1] = text_line(r, 0, 31) end
  return table.concat(s, "|")
end

function scenario()
  new_game_to_field(40)
  poke(0xC4F0, 3)
  for _, m in ipairs({ 0xC400, 0xC410, 0xC420, 0xC430 }) do
    poke(m, ram(m) | 1)
    poke(m + 1, 10) poke(m + 6, 30)
  end
  poke(0xC40F, 2) poke(0xC402, 20) poke(0xC407, 20)      -- Alisa: two field spells, 20 MP
  open_command_menu()
  wait(30)
  local before = snap()
  press("down", 4, 20)                                    -- MAGC
  for step = 1, 3 do                                      -- MAGC, Alisa casts, HEAL
    wait(20)
    press("two", 4, 50)
  end
  dump_screen("target")
  shot("target")
  press("one", 4, 40)                                     -- cancel: every menu closes
  wait(20)
  shot("after")
  local same = snap() == before
  log("restored: " .. tostring(same))
  if not same then dump_screen("after") error("the screen did not come back") end
end
