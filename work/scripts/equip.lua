-- First shield equip with the starting sword and armor. Give Alisa a Leather Shield,
-- choose Item / Leather Shield / Equip, dismiss the equipment preview, and compare
-- every inventory cell with its saved background. The old shared extra-column buffer
-- leaves 16 changed cells at r2-r9 c20-c21. All waits and loops are bounded.
function scenario()
  new_game_to_field(40)
  poke(0xC4C0, 25) poke(0xC4E2, 1)
  open_command_menu() wait(30)
  local before = {}
  for a = 0, 1535 do before[a] = vram(0x3800 + a) end
  press('down',4,15) press('down',4,15) press('two',4,60)
  press('two',4,40)
  press('down',4,15) press('two',4,60)
  wait_for_button_wait(300, 'equipment confirmation')
  shot('equipped') dump_screen('equipped')
  press('two',4,80) wait(40)
  shot('after') dump_screen('after')
  if ram(0xC40C) ~= 25 then error('shield not equipped') end
  if ram(0xC4E2) ~= 0 then error('first shield was not removed from inventory') end
  local n=0
  for r=2,22 do for c=20,31 do
    local a=(r*32+c)*2
    if vram(0x3800+a) ~= before[a] or vram(0x3801+a) ~= before[a+1] then
      n=n+1; log(string.format('changed r%d c%d',r,c))
    end
  end end
  if n>0 then error(n .. ' inventory cells remain changed') end
end
