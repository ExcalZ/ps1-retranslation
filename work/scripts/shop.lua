-- Buy in a shop, without walking: shop=N (B03_ShopData: 1 Camineet Armory, 3 Camineet First
-- Food Shop, 4 / 6 Parolit, 7 Scion) and type=armory|food (default armory). On the map the
-- button that opens the interaction screen runs handler (Interaction_Type $C29E - $10) of the
-- table LABEL_3C2A ($16 armory LABEL_2BC0, $18 food shop LABEL_2C8F), with the stock of shop
-- $C2DB; the scenario writes both just before the press, and gives Alisa 2000 meseta.
--
-- "THIS IS AN ARMORY. / DO YOU WANT TO BUY" (a page), YES, the stock list (read back and
-- filmed), button 2 on the first item, "THANK YOU. / ANYTHING ELSE?" NO, "WELL, COME AGAIN."
-- Then the inventory must hold the item and the money must be 2000 less its price, both read
-- from the stock data in the ROM. Check the text with
--   --expect=B12_B7C7,B12_B7F5,B12_B807,B12_B7E3 --words=items:25+27+28 (the stock, which the
-- run logs; these are shop 1's)
-- Bounded: the new game to the field, 5 tries to open the shop, every wait limited.

local SHOP = tonumber(PS1.params.shop or 1)
local TYPE = ({ armory = 0x16, food = 0x18 })[PS1.params.type or "armory"]
local MONEY = 2000

local function rom(off) return emu.read(off, emu.memType.smsPrgRom) end

local function answer(yes)
  wait_until(yes_no_shown, 300, "YES / NO")
  wait(20)
  if not yes then press("down", 4, 10) end
  press("two", 4, 0)
end

local page = 0
local function log_page()
  wait_for_button_wait(600, "a button wait")
  wait(2)
  page = page + 1
  log(string.format("page %d (window): %s", page, table.concat(dialogue_text(), " / ")))
  shot(string.format("page%d", page))
  press("one", 4, 6)
end

function scenario()
  local data = PS1.rom.B03_ShopData + 10 * SHOP
  local item, price = rom(data + 1), rom(data + 2) + 256 * rom(data + 3)
  -- the count byte is the last index (it goes to Option_total_num): 2 means three items
  local stock = {}
  for i = 0, rom(data) do stock[#stock + 1] = tostring(rom(data + 1 + 3 * i)) end
  log(string.format("shop %d: items %s (check with --words=items:%s); the first at %d meseta",
                    SHOP, table.concat(stock, " "), table.concat(stock, "+"), price))

  new_game_to_field(40)
  poke(0xC4E0, MONEY % 256) poke(0xC4E1, MONEY // 256)
  local count = ram(0xC4E2)
  wait(60)
  for try = 1, 5 do
    poke(0xC29E, TYPE)
    poke(0xC2DB, SHOP)
    press("one", 4, 0)
    if pcall(wait_until, window_open, 120, "the shop's window") then break end
    if try == 5 then error("the shop did not open in 5 tries") end
  end
  log_page()                             -- THIS IS AN ARMORY. / DO YOU WANT TO BUY
  answer(true)
  wait_until(function() return #area_text(2, 6, 6, 21) >= 1 end, 300, "the stock list")  -- rows 2, 4, 6
  wait(30)
  dump_screen("list")
  shot("list")
  press("two", 4, 0)                     -- the first item
  answer(false)                          -- ANYTHING ELSE? NO
  log_page()                             -- WELL, COME AGAIN.
  wait_until(function() return not window_open() end, 300, "the window to close")

  local money = ram(0xC4E0) + 256 * ram(0xC4E1)
  log(string.format("bought: inventory %d -> %d, last item $%02X; money %d -> %d",
                    count, ram(0xC4E2), ram(0xC4C0 + ram(0xC4E2) - 1), MONEY, money))
  if ram(0xC4E2) ~= count + 1 or ram(0xC4C0 + count) ~= item then error("the item is not in the inventory") end
  if money ~= MONEY - price then error("the money is not " .. (MONEY - price)) end
end
