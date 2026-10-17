-- A forced battle: enemy=N (B03_EnemyData index, default 1 Sworm). On the field the scenario
-- leaves what a random encounter does: $C2E6 the enemy, $C29D $FF, game mode $0C
-- (LoadInteraction), whose interaction screen then runs LABEL_5FFE / LABEL_100F, the battle.
-- Alisa gets attack 255 and 99 HP so ATTK wins (strong=0 leaves her as she is); party=4
-- brings all four members in (the battle then shows each one's name box at its turn).
--
-- The battle menu (ATTK MAGC ITEM TALK RUN, rows 2-10, columns 1-6) and the enemy name box
-- (row 2, columns 15-22) are read back once; each round button 2 chooses ATTK. Every message
-- is logged as a window page when the game waits on it, a button wait (button 1 is pressed)
-- or a timed one ({TIMED}: it passes by itself), until the battle is over. A chest the enemy
-- leaves is opened (YES; chest=no answers NO).
-- Check: --known (every window line is a line of dialogue.json), --words=enemies:N,battle_menu.
-- Bounded: the new game to the field, 120 frames for the battle to start, 6000 frames of
-- battle, 40 rounds.

local ENEMY = tonumber(PS1.params.enemy or 1)

local function battle_menu() return area_text(2, 10, 1, 6) end

local function menu_up()
  local m = battle_menu()
  return m[1] == "ATTK" and not at_button_wait() and not at_timed_wait()
end

function scenario()
  new_game_to_field(40)
  wait(60)
  if PS1.params.strong ~= "0" then
    poke(0xC408, 255)                    -- attack
    poke(0xC401, 99) poke(0xC406, 99)    -- HP, max HP
  end
  if PS1.params.party == "4" then         -- all four, so the battle shows whose turn it is
    poke(0xC4F0, 3)
    for _, m in ipairs({ 0xC400, 0xC410, 0xC420, 0xC430 }) do
      poke(m, ram(m) | 1)
      if ram(m + 1) == 0 then poke(m + 1, 20) poke(m + 6, 20) end
    end
  end
  poke(0xC2E6, ENEMY)
  poke(0xC29D, 0xFF)
  poke(0xC202, 0x0C)
  wait_until(menu_up, 300, "the battle menu")
  wait(10)
  log("battle menu: " .. table.concat(battle_menu(), " / "))
  log("enemy box: " .. text_line(2, 15, 22))
  dump_screen("battle")
  shot("battle")

  local page, last, rounds = 0, nil, 0
  local start = now()
  while game_mode() == MODE.interaction do
    if now() - start > 6000 then error("the battle still on after 6000 frames") end
    if at_button_wait() or at_timed_wait() then
      local text = table.concat(dialogue_text(), " / ")
      if text ~= last then
        wait(2)
        text = table.concat(dialogue_text(), " / ")
        page = page + 1
        log(string.format("page %d (window): %s", page, text))
        shot(string.format("msg%02d", page))
        last = text
      end
      if at_button_wait() then press("one", 4, 6) else wait(1) end
    elseif yes_no_shown() then           -- a chest: "DO YOU WANT TO OPEN IT?"
      wait(20)
      local text = table.concat(dialogue_text(), " / ")
      if text ~= last then
        page = page + 1
        log(string.format("page %d (window): %s", page, text))
        last = text
      end
      if PS1.params.chest == "no" then press("down", 4, 10) end
      press("two", 4, 20)
    elseif menu_up() and window_open() == false then
      rounds = rounds + 1
      if rounds > 40 then error("still fighting after 40 rounds") end
      press("two", 4, 20)                -- ATTK
    else
      wait(1)
    end
  end
  wait(30)
  shot("after")
  log(string.format("battle over after %d rounds (game mode %d); Alisa HP %d, EXP %d",
                    rounds, game_mode(), ram(0xC401), ram(0xC403) + 256 * ram(0xC404)))
end
