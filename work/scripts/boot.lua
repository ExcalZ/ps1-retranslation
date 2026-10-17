-- Boot to the title screen, film it, and check the joypad reaches the game.
-- Bounded: 900 frames to the title, 60 for the press to register.

function scenario()
  wait_until(function() return game_mode() == MODE.intro end, 900, "the title (game mode 3)")
  wait(240)
  shot("title")
  local seen = {}
  set_held({ "one" })
  wait_until(function()
    seen[#seen + 1] = string.format("%02X", ram(0xC204))
    return ram(0xC204) ~= 0
  end, 60, "Ctrl_1_held to show button 1")
  set_held({})
  log("Ctrl_1_held while holding 1: " .. table.concat(seen, " "))
end
