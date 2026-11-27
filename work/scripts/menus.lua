-- The field command menu's entries, each opened, read back and filmed: STAS (the status
-- window), MAGC (Alisa's field spells: two are given, $C40F map_magic_num = 2), ITEM (nine
-- items are given, $C4C0 / count $C4E2, so the list shows its NEXT row; the cursor starts on
-- NEXT) and the item actions on the first item. In these menus button 2 chooses and button 1
-- cancels (CheckOptionSelect). Every screen row with text is logged (dump_screen); check with
-- --words=field_menu,status_labels,spells:15-16,items:33-40,item_menu (page one of the list).
-- STAS is then opened and closed 20 times, each a frame or more later than the last (the
-- frame's phase when a window is drawn varies): the equipment box's top edge must be its frame
-- tiles in the nametable (a write too close to the last one while the screen is drawn is lost:
-- LongBorder once lost a byte on some frames), and after each close the menu and the name box
-- must read as before and the pool (WinPos, $C7FE) stay where it was (vwf_windows: a restored
-- buffer's later rows once released other windows' marks - Alisa's name drawn over by "Item" -
-- and the menu drawn again took new tiles each time).
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

  local menu0 = open_command_menu()
  local name0, pos0 = text_line(19, 0, 31), ram(0xC7FE)
  for k = 1, 20 do
    wait(k % 7)
    choose(1) wait(30)
    local edge = {}                      -- r10 c4-c15: corner, 10 x the top frame, corner flipped
    for c = 4, 15 do
      local a = 0x3800 + (10 * 32 + c) * 2
      edge[#edge + 1] = vram(a) + 256 * vram(a + 1)
    end
    for i, w in ipairs(edge) do
      local want = (i == 1 and 0x11F1) or (i == 12 and 0x13F1) or 0x11F2
      if w ~= want then
        shot("STAS_edge")
        error(string.format("STAS %d: the equipment box's top edge, cell %d: %04X, not %04X",
          k, i + 3, w, want))
      end
    end
    press("two", 4, 40) wait(30)         -- the status window closed (Alisa has no battle spells)
    local menu, name, pos = area_text(2, 10, 1, 6), text_line(19, 0, 31), ram(0xC7FE)
    log(string.format("STAS back %d: %s | %s | WinPos %02X", k, table.concat(menu, " / "), name, pos))
    if table.concat(menu, "/") ~= table.concat(menu0, "/") or name ~= name0 or pos ~= pos0 then
      error(string.format("after STAS %d: menu %s, name box %s, WinPos %02X (were %s, %s, %02X)",
        k, table.concat(menu, " / "), name, pos, table.concat(menu0, " / "), name0, pos0))
    end
  end
  leave()

  open_command_menu()
  choose(2) look("MAGC") leave()

  open_command_menu()
  choose(3) look("ITEM")
  press("down", 4, 10)                   -- off NEXT onto the first item
  press("two", 4, 40) look("ITEM_ACTIONS")
  leave()
end
