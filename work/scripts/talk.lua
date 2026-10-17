-- Walk into a door: from the start of a new game Alisa walks up into the house above her, her
-- own home, whose sign reads "HERE IS THE HOME / OF ALIS." (DialogueBlock 02A4). Every page of
-- the window is logged and filmed. Check with --expect=02A4. To reach a person without walking,
-- use forcetalk.lua.
-- Bounded: the new game to the field, 300 frames of walking up, 20 pages.

function scenario()
  new_game_to_field(40)
  set_held({ "up" })
  wait_until(function() return window_open() end, 300, "a window (walking up)")
  set_held({})
  local pages = page_window(20, "home")
  log(string.format("window closed after %d pages (game mode %d)", pages, game_mode()))
  wait(30)
  shot("after")
end
