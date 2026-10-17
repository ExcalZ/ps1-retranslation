-- VRAM in a battle, for finding tiles a screen leaves free: the tiles shown on the background
-- and as sprites (sampled every frame or two through six rounds of ATTK, the enemy's attacks
-- included), the whole of VRAM and the palette at the end. Writes work/analysis/vramdump.json;
-- tools/vramsheet.py draws it. Params: enemy=N (default 39, the US SANDWORM), bg=N (the
-- backdrop, Interaction_Type $C29E). Alisa is kept alive at attack 1 so the enemy keeps
-- attacking. Bounded: 4000 frames of battle, 6 rounds.
function scenario()
  new_game_to_field(40)
  wait(60)
  if PS1.params.bg then poke(0xC29E, tonumber(PS1.params.bg)) end
  poke(0xC408, 1) poke(0xC401, 99) poke(0xC406, 99)   -- weak but sturdy: the enemy lives and attacks
  poke(0xC2E6, tonumber(PS1.params.enemy or 39)) poke(0xC29D, 0xFF) poke(0xC202, 0x0C)
  wait_until(function() return area_text(2, 10, 1, 6)[1] == "ATTK" end, 300, "the battle menu")
  local bg, spr = {}, {}
  local function sample()
    for cell = 0, 32 * 24 - 1 do
      local lo, hi = vram(0x3800 + 2 * cell), vram(0x3801 + 2 * cell)
      local t = lo + 256 * (hi & 1)
      bg[t] = (bg[t] or 0) | (1 << ((hi >> 3) & 1))   -- bit 0: palette 0, bit 1: palette 1
    end
    for i = 0, 63 do
      if vram(0x3F00 + i) == 0xD0 then break end
      spr[256 + vram(0x3F81 + 2 * i)] = true
    end
  end
  local rounds, start, shots = 0, now(), 0
  while game_mode() == MODE.interaction and rounds < 6 and now() - start < 4000 do
    sample()
    poke(0xC401, 99)                     -- keep Alisa standing
    if at_button_wait() then press("one", 4, 6)
    elseif area_text(2, 10, 1, 6)[1] == "ATTK" and not window_open() then
      rounds = rounds + 1
      press("two", 4, 20)
    else wait(2) end
    if shots < 6 and now() % 120 < 2 then shots = shots + 1 shot("fight" .. shots) end
  end
  log("sampled " .. rounds .. " rounds")
  shot("battle")
  local ok, pal = pcall(function()
    local t = {}
    for i = 0, 31 do t[#t + 1] = emu.read(i, emu.memType.smsPaletteRam) end
    return t
  end)
  local f = io.open(PS1.out .. "/vramdump.json", "w")
  local hex = {}
  for a = 0, 0x3FFF do hex[#hex + 1] = string.format("%02X", vram(a)) end
  local function keys(t) local o = {} for k, v in pairs(t) do o[#o + 1] = string.format("[%d,%d]", k, v == true and 1 or v) end return table.concat(o, ",") end
  f:write('{"enemy":' .. (PS1.params.enemy or 39) .. ',"bg":' .. (PS1.params.bg or 0) .. ',"vram":"' .. table.concat(hex) .. '","shown":[' .. keys(bg) .. '],"spr":[' .. keys(spr) .. ']')
  if ok then f:write(',"pal":[' .. table.concat(pal, ",") .. ']') end
  f:write('}')
  f:close()
  log("dumped; palette " .. (ok and "read" or "not readable: " .. tostring(pal)))
end
