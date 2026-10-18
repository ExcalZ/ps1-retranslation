-- Tyron's rescue: the Alsulin ($2B) used at Tyron's statue (talk id $A3, LABEL_5538: the
-- command menu with $C2DB kept for ItemUse_Alsulin). Alisa and Myau in the party. The
-- messages B12_B366 and B12_B3B1 (timed), then $C2D8 = 5 sends the menu's dispatcher
-- (LABEL_1BEE -> LABEL_1C15) to a wait over Tyron's picture and LABEL_4414's cut-scenes
-- (B6F3, B746, B786, B7B9, B7D1). Every page is logged and filmed; Tyron must be in the
-- party after it. Check with
--   --expect=B12_B366,B12_B3B1,B6F3,B746,B786,B7B9,B7D1
-- Bounded: the new game to the field, start_talk's tries, page_scene's limits.

function scenario()
  new_game_to_field(40)
  poke(0xC4C0, 0x2B) poke(0xC4E2, 1)
  poke(0xC4F0, 1)
  poke(0xC410, ram(0xC410) | 1)
  if ram(0xC411) == 0 then poke(0xC411, 20) end
  wait(60)
  start_talk(0xA3, command_menu_up, "command menu")
  log(string.format("$C309 = $%02X", ram(0xC309)))
  use_first_item()
  page_scene(label_hit("LABEL_FF3"), 20, "tyron")
  wait_until(on_field, 600, "the field")
  wait(30)
  shot("after")
  log(string.format("Tyron $C420 = $%02X, party $C4F0 = %d, items %d", ram(0xC420), ram(0xC4F0), ram(0xC4E2)))
  if ram(0xC420) & 1 == 0 or ram(0xC4F0) ~= 2 then error("Tyron did not join") end
end
