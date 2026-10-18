-- Lutz joins: Lutz's talk (id $7E, LABEL_516F: Party_curr_num $C4F0 under 3) with the Letter
-- ($37) given and Alisa, Myau and Tyron in the party: 00AE-00B0, a wait over Lutz's picture,
-- then LABEL_4461's cut-scenes (B85C, B884). Every page is logged and filmed; Lutz must be in
-- the party after it. Check with
--   --expect=00AE,B85C,B884
-- Bounded: the new game to the field, start_talk's tries, page_scene's limits.

function scenario()
  new_game_to_field(40)
  poke(0xC4C0, 0x37) poke(0xC4E2, 1)
  poke(0xC4F0, 2)
  for _, a in ipairs({ 0xC410, 0xC420 }) do
    poke(a, ram(a) | 1)
    if ram(a + 1) == 0 then poke(a + 1, 20) end
  end
  wait(60)
  start_talk(0x7E)
  page_scene(on_field, 20, "lutz")
  wait(30)
  shot("after")
  log(string.format("Lutz $C430 = $%02X, party $C4F0 = %d, items %d", ram(0xC430), ram(0xC4F0), ram(0xC4E2)))
  if ram(0xC430) & 1 == 0 or ram(0xC4F0) ~= 3 then error("Lutz did not join") end
end
