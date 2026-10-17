-- A new game from the title through the intro, to Alisa on the field.
--
-- At every button wait the text on screen is logged (the dialogue window when it is open,
-- else the cut-scene rows) and filmed, then button 1 is pressed. Bounded: 900 frames to the
-- title, 1500 frames for each wait, at most `pages` waits (default 40), and the run's frame cap.

local MAX_PAGES = tonumber(PS1.params.pages or 40)

local function field()
  local m = game_mode()
  return m == MODE.map or m == MODE.road or m == MODE.dungeon
end

function scenario()
  wait_until(function() return game_mode() == MODE.intro end, 900, "the title")
  wait(120)
  shot("title")
  press("one", 4, 30)                    -- START
  for page = 1, MAX_PAGES do
    wait_until(function() return at_button_wait() or (field() and not at_button_wait()) end,
               1500, "a button wait or the field")
    if not at_button_wait() then
      wait(60)
      shot("field")
      log(string.format("on the field after %d pages (game mode %d)", page - 1, game_mode()))
      return
    end
    wait(2)
    local window = ram(0xC2D3) == 0xFF
    local lines = window and dialogue_text() or cutscene_text()
    log(string.format("page %d (%s): %s", page, window and "window" or "cut-scene",
                      table.concat(lines, " / ")))
    shot(string.format("page%02d", page))
    press("one", 4, 6)
  end
  error("still no field after " .. MAX_PAGES .. " pages")
end
