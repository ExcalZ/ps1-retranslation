-- Runtime test of far_calls (needs expand_rom and far_calls). On the field, when the game
-- calls WaitForVInt, the CPU is sent into a stub instead, with bank 63 as the target, and
-- checked when it comes back to WaitForVInt's caller:
--   FarCall a=63 hl=FarSelfTest  -> hl must be $5AA5 (the routine ran in bank 63);
--   FarRead a=63 hl=FarSelfTestByte -> a must be $A7, bc kept.
-- Both times the caller's slot-2 bank ($FFFF, mirrored at RAM $DFFF) must be paged back. The
-- registers the test borrows are put back, and the skipped frame wait does no harm.
-- Bounded: the new game to the field, 120 frames for each test.

local L, R = PS1.labels, PS1.rom
local function bank() return emu.read(0x1FFF, emu.memType.smsWorkRam) end
local function mem(a) return emu.read(a, emu.memType.smsMemory) end

local test, result
local armed = false

emu.addMemoryCallback(function()
  if not armed then return end
  armed = false
  local st = emu.getState()
  local sp = st["cpu.sp"]
  local back = mem(sp) + 256 * mem(sp + 1)
  test.saved = { a = st["cpu.a"], h = st["cpu.h"], l = st["cpu.l"], b = st["cpu.b"], c = st["cpu.c"] }
  test.bank = bank()
  test.back = back
  st["cpu.pc"] = test.entry
  st["cpu.a"] = 63
  st["cpu.h"] = test.hl >> 8
  st["cpu.l"] = test.hl & 0xFF
  emu.setState(st)
  local ref
  ref = emu.addMemoryCallback(function()
    local s2 = emu.getState()
    result = { a = s2["cpu.a"], hl = s2["cpu.h"] * 256 + s2["cpu.l"], b = s2["cpu.b"], c = s2["cpu.c"],
               bank = bank() }
    for k, v in pairs(test.saved) do s2["cpu." .. k] = v end
    emu.setState(s2)
    emu.removeMemoryCallback(ref, emu.callbackType.exec, back)
  end, emu.callbackType.exec, back)
end, emu.callbackType.exec, L.WaitForVInt)

local function run(name, entry, hl)
  test, result = { entry = entry, hl = hl }, nil
  armed = true
  wait_until(function() return result ~= nil end, 120, name .. " to come back")
  log(string.format("%s: back at $%04X; a=$%02X hl=$%04X bc=$%02X%02X (was $%02X%02X); bank $%02X (was $%02X)",
                    name, test.back, result.a, result.hl, result.b, result.c, test.saved.b, test.saved.c,
                    result.bank, test.bank))
  if result.bank ~= test.bank then error(name .. " did not page the caller's bank back") end
  return result
end

function scenario()
  if not L.FarCall or not R.FarSelfTest then error("this build has no far_calls") end
  new_game_to_field(40)
  wait(30)
  local r = run("FarCall", L.FarCall, R.FarSelfTest % 0x4000 + 0x8000)
  if r.hl ~= 0x5AA5 then error(string.format("FarCall: hl $%04X, not $5AA5", r.hl)) end
  r = run("FarRead", L.FarRead, R.FarSelfTestByte % 0x4000 + 0x8000)
  if r.a ~= 0xA7 then error(string.format("FarRead: a $%02X, not $A7", r.a)) end
  if r.b ~= test.saved.b or r.c ~= test.saved.c then error("FarRead did not keep bc") end
  wait(60)
  shot("field")
  log("far calls work; the game runs on (game mode " .. game_mode() .. ")")
end
