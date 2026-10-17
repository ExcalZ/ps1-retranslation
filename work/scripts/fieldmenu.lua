-- Open the field command menu and read its words back. On the map either button switches to
-- the interaction screen (game mode 13), which draws the command tilemap LABEL_B27_BB8B at
-- VRAM $7842: rows 1-11 with the frame, columns 1-6; a menu word is one row (the lower tile
-- only), on rows 2, 4, 6, 8, 10.
-- Bounded: see open_command_menu in lib.lua.

function scenario()
  new_game_to_field(40)
  log("field menu: " .. table.concat(open_command_menu(), " / "))
  shot("fieldmenu")
end
