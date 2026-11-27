-- The hospital's Everyone (hospital_everyone, ext/hospital.asm). Interaction_Type $12
-- (LABEL_298D) opened without walking, as windows.lua does; party=N members (2-4, default 4),
-- 2000 meseta, every member alive. case=
--   pay   (default) every member hurt (dead=K: member K down, hurt too): YES, Everyone, YES.
--         The quoted fee (CurrentDialogueNumber) is the sum of the living members' stock fees
--         (max HP - HP + max MP - MP, 8 bits each), the money goes down by it, every living
--         member's HP and MP are at their maximum, a dead one is untouched, and the screen is
--         as before the hospital.
--   none  nobody hurt: Everyone gives "all in good health", then the menu again; button 1
--         there ends the visit; nothing paid.
--   short every member hurt, 5 meseta: Everyone, YES: the short-of-money ending, nobody healed,
--         the money kept.
--   one   the stock path: member 1 (Myau) chosen, healed for the stock's fee, NO to "anyone
--         else?"; the others untouched.
-- The menu is checked where hospital.asm puts it (r9, or r7 with four members): each member's
-- name row, then Everyone, the cursor's index (ram $C26B) reaching it. Every window page is
-- logged (check with --known) and the menu dumped (--words=hospital_words).
-- Bounded: the new game to the field, 5 tries to open, every wait limited, 40 steps a phase.

local CASE = PS1.params.case or "pay"
local PARTY = tonumber(PS1.params.party or "4")
local DEAD = tonumber(PS1.params.dead or "-1")
local STATS = { 0xC400, 0xC410, 0xC420, 0xC430 }
local pages = 0

-- the screen above the dialogue window (rows 0-17: the menu, the money box, YES / NO), as cells
local function snap()
  local s = {}
  for a = 0x3800, 0x3800 + 18 * 64 - 1 do s[#s + 1] = string.format("%02X", vram(a)) end
  return table.concat(s)
end

local function money() return ram16(0xC4E0) end

local function fee(m)                    -- the stock fee of the member at m, 8 bits
  return ((ram(m + 6) - ram(m + 1)) + (ram(m + 7) - ram(m + 2))) % 256
end

local function needs(m)
  return ram(m + 1) ~= ram(m + 6) or ram(m + 2) ~= ram(m + 7)
end

local function page()
  pages = pages + 1
  log(string.format("page %d (window): %s", pages, table.concat(dialogue_text(), " / ")))
  shot(string.format("page%02d", pages))
end

-- page on with button 1 until done() (a YES / NO, the menu, the window closed)
local function until_(done, what)
  for _ = 1, 40 do
    wait_until(function() return done() or at_button_wait() end, 600, what)
    if done() and not at_button_wait() then return end
    wait(2)
    page()
    press("one", 4, 10)
  end
  error("did not reach " .. what .. " in 40 pages")
end

local function yes_no(yes)
  until_(yes_no_shown, "YES / NO")
  wait(20)
  page()                                 -- the question (its NOWAIT lines)
  if not yes then press("down", 4, 10) end
  press("two", 4, 0)
  log("answered " .. (yes and "YES" or "NO"))
  wait_until(function() return not yes_no_shown() end, 120, "YES / NO to close")
end

-- the menu where hospital.asm draws it: its top row, then name k on top + 1 + 2k, Everyone last
local TOP = PARTY == 4 and 7 or 9
local EVERY_ROW = TOP + 1 + 2 * PARTY
local function menu_up()
  return text_line(EVERY_ROW, 3, 8):upper():find("EVERY", 1, true) ~= nil
end

local function cursor_to(n)
  for _ = 1, 8 do
    if ram(0xC26B) == n then return end
    press(ram(0xC26B) < n and "down" or "up", 2, 16)
  end
  if ram(0xC26B) ~= n then error("the cursor did not reach entry " .. n) end
end

function scenario()
  new_game_to_field(40)
  poke(0xC4F0, PARTY - 1)
  for k, m in ipairs(STATS) do
    poke(m, ram(m) | 1)                  -- alive
    poke(m + 6, 60 + 10 * k) poke(m + 7, 30 + 5 * k)     -- max HP, max MP
    if CASE == "none" then
      poke(m + 1, ram(m + 6)) poke(m + 2, ram(m + 7))
    else
      poke(m + 1, 10 * k) poke(m + 2, 3 * k)
    end
  end
  if DEAD >= 0 then poke(STATS[DEAD + 1], ram(STATS[DEAD + 1]) & 0xFE) end
  local cash = CASE == "short" and 5 or 2000
  poke(0xC4E0, cash % 256) poke(0xC4E1, cash // 256)
  local want = 0
  for k = 1, PARTY do
    local m = STATS[k]
    if ram(m) & 1 == 1 and needs(m) then want = want + fee(m) end
  end
  local before_stats = {}
  for k = 1, 4 do before_stats[k] = { ram(STATS[k] + 1), ram(STATS[k] + 2) } end
  wait(60)

  for try = 1, 5 do
    poke(0xC29E, 0x12)
    poke(0xC2DB, 1)
    press("one", 4, 0)
    if pcall(wait_until, window_open, 120, "the window") then break end
    if try == 5 then error("no hospital window in 5 tries") end
  end
  wait_until(at_button_wait, 600, "the hospital's first page")
  local before = snap()                  -- the interaction screen, no window over it yet
  yes_no(true)                           -- "Do you need treatment?"
  until_(menu_up, "the party menu with Everyone")
  wait(30)
  dump_screen("menu")
  shot("menu")
  local names = {}
  for k = 0, PARTY - 1 do names[#names + 1] = text_line(TOP + 1 + 2 * k, 3, 8) end
  log("menu: " .. table.concat(names, " / ") .. " / " .. text_line(EVERY_ROW, 3, 8))
  for k, n in ipairs(names) do
    if n == "" then error("no name on the menu's row " .. (TOP + 1 + 2 * (k - 1))) end
  end
  if TOP > 9 or EVERY_ROW + 1 >= 18 then error("the menu reaches the dialogue window") end

  if CASE == "one" then
    local m = STATS[2]
    local f = fee(m)
    cursor_to(1)
    press("two", 4, 0)
    yes_no(true)                         -- the stock's fee
    log(string.format("fee %d (stock %d)", ram16(0xC2C5), f))
    if ram16(0xC2C5) ~= f then error("the fee is not the stock's") end
    yes_no(false)                        -- "anyone else?": NO
    until_(function() return not window_open() end, "the window to close")
    if ram(m + 1) ~= ram(m + 6) or ram(m + 2) ~= ram(m + 7) then error("Myau not healed") end
    for k = 1, 4 do
      if k ~= 2 and (ram(STATS[k] + 1) ~= before_stats[k][1] or ram(STATS[k] + 2) ~= before_stats[k][2]) then
        error("member " .. (k - 1) .. " changed")
      end
    end
    if money() ~= cash - f then error("money " .. money() .. ", expected " .. (cash - f)) end
  else
    cursor_to(PARTY)                     -- Everyone
    log("cursor on Everyone (" .. ram(0xC26B) .. ")")
    press("two", 4, 0)
    if CASE == "none" then
      wait_until(at_button_wait, 600, "all in good health")
      wait(2)
      page()
      press("one", 4, 10)
      wait_until(function() return not menu_up() end, 300, "the menu to close")
      until_(menu_up, "the menu again")
      log("the menu again")
      wait(20)
      press("one", 4, 0)                 -- button 1: no one
      until_(function() return not window_open() end, "the window to close")
      for k = 1, 4 do
        if ram(STATS[k] + 1) ~= before_stats[k][1] or ram(STATS[k] + 2) ~= before_stats[k][2] then
          error("member " .. (k - 1) .. " changed")
        end
      end
      if money() ~= cash then error("money changed") end
    else
      yes_no(true)                       -- the summed fee
      log(string.format("fee %d (the living members' stock fees: %d)", ram16(0xC2C5), want))
      if ram16(0xC2C5) ~= want then error("the fee is not the sum") end
      until_(function() return not window_open() end, "the window to close")
      for k = 1, 4 do
        local m = STATS[k]
        local healed = ram(m + 1) == ram(m + 6) and ram(m + 2) == ram(m + 7)
        local same = ram(m + 1) == before_stats[k][1] and ram(m + 2) == before_stats[k][2]
        local should = CASE == "pay" and k <= PARTY and k - 1 ~= DEAD
        log(string.format("member %d: HP %d/%d MP %d/%d", k - 1, ram(m + 1), ram(m + 6), ram(m + 2), ram(m + 7)))
        if should and not healed then error("member " .. (k - 1) .. " not healed") end
        if not should and not same then error("member " .. (k - 1) .. " changed") end
      end
      local left = CASE == "pay" and cash - want or cash
      log(string.format("money %d (expected %d)", money(), left))
      if money() ~= left then error("money " .. money() .. ", expected " .. left) end
    end
  end
  wait(10)
  shot("after")
  local same = snap() == before
  log("restored: " .. tostring(same))
  if not same then dump_screen("after") error("the screen under the windows did not come back") end
end
