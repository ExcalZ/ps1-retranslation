-- The ending: the Governor freed (talk id $AC, LABEL_5666, which LaShiec's defeat runs on
-- into): 0272-0278, the question YES (answer=yes, default: 0212) or NO (answer=no: 0230),
-- then LABEL_454E: the breeze messages (B12_BEB6-B12_BF21, each a {PAUSE}) and the credits'
-- cut-scenes (B9E8, B9F0, B9FB, BA06, BA12, BA54, each {TIMED}: the names centered with
-- leading spaces in the line); the scenario stops when the walk after the credits begins
-- (LABEL_661C: its screen stays black for 2400 frames after this forced entry, in the stock
-- game too). Every page is logged and filmed. Check with
--   --expect=0272,0212,B12_BEB6,B12_BED0,B12_BEE8,B12_BEFD,B12_BF09,B12_BF21,B9E8,B9F0,B9FB,BA06,BA12,BA54
-- (0230 for answer=no). Bounded: the new game to the field, start_talk's tries, page_scene's
-- limits.

function scenario()
  local yes = (PS1.params.answer or "yes") ~= "no"
  new_game_to_field(40)
  wait(60)
  start_talk(0xAC, function() return window_open() or at_button_wait() end, "the Governor")
  page_scene(yes_no_shown, 20, "end")
  answer_yes_no(yes, "queen")
  page_scene(label_hit("LABEL_661C"), 40, "end")
  log("the credits are over")
end
