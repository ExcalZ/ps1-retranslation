-- Myau joins: the merchant's talk (id $36, LABEL_4C0D: Party_curr_num $C4F0 must be 0) with a
-- Laconia Pot ($38) given: "100 million meseta" (0092) NO, the pot (0096-0098) YES, 009A,
-- then Myau's cut-scenes LABEL_43CF (B617, B646, B64D, B66E, B6C1). Every page is logged and
-- filmed; Myau must be in the party after it and the pot gone. Check with
--   --expect=0092,0096,009A,B617,B646,B64D,B66E,B6C1
-- Bounded: the new game to the field, start_talk's tries, page_scene's limits.

function scenario()
  new_game_to_field(40)
  poke(0xC4C0, 0x38) poke(0xC4E2, 1)
  wait(60)
  start_talk(0x36)
  page_scene(yes_no_shown, 10, "myau")
  answer_yes_no(false, "deal")          -- NO: YES is 0094, "You're a liar."
  page_scene(yes_no_shown, 10, "myau")
  answer_yes_no(true, "pot")
  page_scene(on_field, 20, "myau")
  wait(30)
  shot("after")
  log(string.format("Myau $C410 = $%02X, party $C4F0 = %d, items %d", ram(0xC410), ram(0xC4F0), ram(0xC4E2)))
  if ram(0xC410) & 1 == 0 or ram(0xC4F0) ~= 1 then error("Myau did not join") end
end
