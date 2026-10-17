-- The field command menu's entries, each opened, read back and filmed: STAS (the status
-- window), MAGC (Alisa's field spells: two are given, $C40F map_magic_num = 2), ITEM (nine
-- items are given, $C4C0 / count $C4E2, so the list shows its NEXT row; the cursor starts on
-- NEXT) and the item actions on the first item. In these menus button 2 chooses and button 1
-- cancels (CheckOptionSelect). Every screen row with text is logged (dump_screen); check with
-- --words=field_menu,status_labels,spells:15-16,items:33-40,item_menu (page one of the list).
-- Bounded: the new game to the field, the menu helpers' limits, 6 cancels to leave a menu.

local ITEMS = { 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29 }

local function choose(n)
  for _ = 2, n do press("down", 4, 10) end
  press("two", 4, 40)
end

local function leave()
  for _ = 1, 6 do
    if game_mode() ~= MODE.interaction then return end
    press("one", 4, 30)
  end
  error("could not leave the menus in 6 presses of button 1")
end

local function look(tag)
  wait(30)
  dump_screen(tag)
  shot(tag)
end

function scenario()
  new_game_to_field(40)
  poke(0xC40F, 2)
  for i, item in ipairs(ITEMS) do poke(0xC4C0 + i - 1, item) end
  poke(0xC4E2, #ITEMS)
  wait(30)

  log("menu: " .. table.concat(open_command_menu(), " / "))
  choose(1) look("STAS") leave()

  open_command_menu()
  choose(2) look("MAGC") leave()

  open_command_menu()
  choose(3) look("ITEM")
  press("down", 4, 10)                   -- off NEXT onto the first item
  press("two", 4, 40) look("ITEM_ACTIONS")
  leave()
end
