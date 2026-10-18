-- Myau's wings: a Laerma berry (Nuts, $31) used where talk id $B0 (LABEL_5535: a button wait,
-- then the command menu) puts the party, Myau alive, with the background $C2DC = $FF and not
-- in $C309 = $17 (ItemUse_Nuts' conditions). B12_B743, then $C2D8 = 7 sends the menu's
-- dispatcher to LABEL_4497's cut-scenes (B929, B97C); the scenario stops when LABEL_4517 (the
-- flight that follows) runs. Every page is logged and filmed. Check with
--   --expect=B12_B743,B929,B97C
-- Bounded: the new game to the field, start_talk's tries, page_scene's limits.

function scenario()
  new_game_to_field(40)
  poke(0xC4C0, 0x31) poke(0xC4E2, 1)
  poke(0xC4F0, 1)
  poke(0xC410, ram(0xC410) | 1)
  if ram(0xC411) == 0 then poke(0xC411, 20) end
  wait(60)
  start_talk(0xB0, at_button_wait, "button wait")
  wait(2)
  press("one", 4, 0)
  wait_until(command_menu_up, 300, "the command menu")
  poke(0xC2DC, 0xFF)
  log(string.format("$C309 = $%02X", ram(0xC309)))
  if ram(0xC309) == 0x17 then error("$C309 is $17: the berry would not work here") end
  use_first_item()
  page_scene(label_hit("LABEL_4517"), 10, "wings")
  wait(60)
  shot("after")
end
