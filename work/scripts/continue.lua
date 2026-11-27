-- Load the game savegame.lua saved: run it with --keep-sram right after savegame. CONTINUE on
-- the title (down, button 1), "CONTINUE GAME- YES / DELETE GAME- NO" (button 2 on YES),
-- "CONTINUE A GAME. / SELECT A NUMBER." with the slot list (slot 1
-- must show the saved name), button 2 on slot 1, "CONTINUING GAME 1." and the field.
-- name=XXXXX: the name savegame used (default TEST). macros=1: the macros savegame macros=1
-- wrote (battle_macros, $C3C0-$C3FF) must be back.
-- Bounded: 900 frames to the title, 600 for the question, 3 tries at YES, 900 to the field.

local NAME = PS1.params.name or "TEST"

local function slots() return area_text(3, 11, 23, 31) end

function scenario()
  wait_until(function() return game_mode() == MODE.intro end, 900, "the title")
  wait(120)
  press("down", 4, 10)                   -- CONTINUE
  press("one", 4, 0)
  -- with a game saved the title asks first: CONTINUE GAME- YES / DELETE GAME- NO
  wait_until(yes_no_shown, 600, "CONTINUE GAME- YES")
  log("asked: " .. text_line(20, 3, 28) .. " / " .. text_line(22, 3, 28))
  for try = 1, 3 do                      -- YES; the prompt takes a moment to listen
    wait(20)
    press("two", 4, 0)
    if pcall(wait_until, function() return #slots() >= 5 end, 300, "the slot list") then break end
    if try == 3 then error("YES did not lead to the slot list in 3 presses") end
  end
  wait(4)
  log("continue: " .. table.concat(dialogue_text(), " / "))
  local list = slots()
  log("slots: " .. table.concat(list, " / "))
  shot("slots")
  if not list[1]:find(NAME, 1, true) then error("slot 1 does not show " .. NAME .. ": " .. list[1]) end
  press("two", 4, 0)                     -- slot 1
  wait_until(on_field, 900, "the field")
  wait(60)
  shot("field")
  log(string.format("continued: game mode %d, Alisa HP %d", game_mode(), ram(0xC401)))
  if PS1.params.macros == "1" then
    local want = { [0] = 0x01, 0x00, 0x43, 0x00, [62] = 0x04, 0x24 }   -- savegame.lua's MACROS
    for i = 0, 63 do
      if ram(0xC3C0 + i) ~= (want[i] or 0) then
        error(string.format("macro byte %d is $%02X, not $%02X", i, ram(0xC3C0 + i), want[i] or 0))
      end
    end
    log("the macros are back ($C3C0-$C3FF)")
  end
end
