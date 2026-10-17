-- Start any person's conversation from the field: talk=N (the talk id: the handler table
-- LABEL_4773, 1 = Suelo LABEL_48DF; docs/pipeline.md 3.5). On the map a button switches to the
-- interaction screen, whose dispatcher LABEL_474B runs handler $C2DB, or the command menu when
-- it is 0; the scenario writes the id there just before the press. Every window page is logged
-- and filmed. bg=N also sets the background scene $C2DC.
-- Bounded: the new game to the field, 5 presses to reach the interaction screen, 30 pages.

function scenario()
  local id = tonumber(PS1.params.talk or 1)
  new_game_to_field(40)
  wait(60)
  for try = 1, 5 do
    poke(0xC2DB, id)
    if PS1.params.bg then poke(0xC2DC, tonumber(PS1.params.bg)) end
    press("one", 4, 0)
    local ok = pcall(wait_until, function() return window_open() end, 120, "the window")
    if ok then break end
    if try == 5 then error("no window for talk id " .. id .. " in 5 tries") end
  end
  log(string.format("talk id %d (game mode %d)", id, game_mode()))
  local pages = page_window(30, string.format("talk%02X_", id))
  log(string.format("window closed after %d pages", pages))
  wait(30)
  shot("after")
end
