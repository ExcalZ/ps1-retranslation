-- Open the field command menu and read its words back. On the map either button switches to
-- the interaction screen (game mode 13), which draws the command tilemap LABEL_B27_BB8B at
-- VRAM $7842: rows 1-11 with the frame, columns 1-6; a menu word is one row (the lower tile
-- only), on rows 2, 4, 6, 8, 10.
-- Bounded: the new game to the field, 5 presses 40 frames apart to reach mode 13, 300 frames
-- for the menu.

local function menu() return area_text(2, 10, 1, 6) end

function scenario()
  new_game_to_field(40)
  for try = 1, 5 do
    press("one", 4, 36)
    if game_mode() == MODE.interaction then break end
    if try == 5 then error("the map did not take button 1 in 5 tries") end
  end
  wait_until(function() return #menu() >= 5 end, 300, "the command menu")
  wait(10)
  log("field menu: " .. table.concat(menu(), " / "))
  shot("fieldmenu")
end
