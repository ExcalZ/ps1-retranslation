-- A new game from the title through the intro, to Alisa on the field.
--
-- At every button wait the text on screen is logged (the dialogue window when it is open,
-- else the cut-scene rows) and filmed, then button 1 is pressed. Bounded: see
-- new_game_to_field in lib.lua; at most `pages` waits (default 40).

function scenario()
  local pages = new_game_to_field(tonumber(PS1.params.pages or 40), function(page, lines, window)
    log(string.format("page %d (%s): %s", page, window and "window" or "cut-scene",
                      table.concat(lines, " / ")))
    shot(string.format("page%02d", page))
  end)
  shot("field")
  log(string.format("on the field after %d pages (game mode %d)", pages, game_mode()))
end
