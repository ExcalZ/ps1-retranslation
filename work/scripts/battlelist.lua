-- The battle's lists: a forced battle (enemy=N, default 39), nine items given; at the battle
-- menu ITEM opens the inventory (logged, a shot), button 1 closes it; MAGC opens Alisa's spell
-- list (two battle spells given), logged, closed; then ATTK until the battle ends, every
-- message logged. Check: --words=items:33-40,battle_menu (the lists read back), the screen
-- under each list comes back (the menu rows after each), --known.
-- Bounded: the new game to the field, 600 frames for the menu, 30 frames a press, 40 rounds.

local ENEMY = tonumber(PS1.params.enemy or 39)
local function battle_menu() return area_text(2, 10, 1, 6) end
local function menu_up() return #battle_menu() >= 5 and not window_open() end

local function cells(tag, row, c0, c1)
  local t = {}
  for c = c0, c1 do
    local a = 0x3800 + row * 64 + c * 2
    t[#t + 1] = string.format("%02X:%02X", vram(a), vram(a + 1))
  end
  local m = {}
  for i = 0, ram(0xC7FC) - 1 do m[#m + 1] = string.format("%02X:%d", ram(0xC7E4 + 2 * i), ram(0xC7E5 + 2 * i)) end
  log(string.format("%s r%d: %s  pos %d marks %s", tag, row, table.concat(t, " "), ram(0xC7FE), table.concat(m, " ")))
end

local function choose(n)                 -- the battle menu's entry n (1 ATTK ... 5 RUN)
  for _ = 2, n do press("down", 4, 10) end
  press("two", 4, 40)
end

function scenario()
  new_game_to_field(40)
  wait(60)
  poke(0xC408, 255) poke(0xC401, 99) poke(0xC406, 99)
  for i = 0, 8 do poke(0xC4C0 + i, 0x21 + i) end
  poke(0xC4E2, 9)
  poke(0xC2E6, ENEMY) poke(0xC29D, 0xFF) poke(0xC202, 0x0C)
  wait_until(menu_up, 600, "the battle menu")
  wait(20)
  log("battle menu: " .. table.concat(battle_menu(), " / "))
  if PS1.params.trace then cells("menu", 6, 1, 6) end

  choose(3)                              -- ITEM
  wait(40)
  dump_screen("item")
  shot("item")
  if PS1.params.trace then cells("item list", 5, 16, 22) cells("item list menu", 6, 1, 6) end
  log("inventory: " .. table.concat(area_text(3, 21, 17, 31), " / "))
  press("one", 4, 40)
  wait_until(menu_up, 300, "the battle menu after ITEM")
  log("battle menu after ITEM: " .. table.concat(battle_menu(), " / "))
  shot("after_item")
  if PS1.params.trace then cells("after item", 6, 1, 6) end

  poke(0xC40E, 2)                        -- Alisa's battle spells (battle_magic_num): two
  choose(2)                              -- MAGC
  wait(40)
  dump_screen("magc")
  shot("magc")
  if PS1.params.trace then cells("magc", 6, 1, 6) cells("magc list", 9, 6, 12) end
  press("one", 4, 40)
  wait_until(menu_up, 300, "the battle menu after MAGC")
  log("battle menu after MAGC: " .. table.concat(battle_menu(), " / "))
  if PS1.params.trace then cells("after magc", 6, 1, 6) end

  local page, last, rounds, start = 0, nil, 0, now()
  while game_mode() == MODE.interaction do
    if now() - start > 6000 then error("the battle still on after 6000 frames") end
    if at_button_wait() or at_timed_wait() then
      local text = table.concat(dialogue_text(), " / ")
      if text ~= last then
        wait(2)
        text = table.concat(dialogue_text(), " / ")
        page = page + 1
        log(string.format("page %d (window): %s", page, text))
        last = text
      end
      if at_button_wait() then press("one", 4, 6) else wait(1) end
    elseif yes_no_shown() then
      wait(20)
      press("two", 4, 20)
    elseif menu_up() then
      rounds = rounds + 1
      if rounds > 40 then error("still fighting after 40 rounds") end
      press("two", 4, 20)
    else
      wait(1)
    end
  end
  log(string.format("battle over after %d rounds", rounds))
end
