# PS I Retranslation - Status

Updated: 2026-10-16

## State

Project started. The disassembly is in place and assembles the US/EU release v3 bit-exact
with WLA-DX 10.7 (`python tools/checkstock.py`), the stock text engine is mapped
(`docs/pipeline.md` section 3), and the script is extracted into JSON with the JP beside the
US and written back by a generator whose round trip is bit-exact. Nothing is translated yet:
every `en` equals its `us`.

## Done

* **Disassembly (2026-10-16).** lory90's Phantasy Star disassembly (WLA-DX; mirrored at
  `sung3r/ps1disasm` with lory90's 2019 history) copied into `PSI_Disasm/`. It targets the
  US/EU v3 ROM (`00BEF1D7`), which it ships as `ps1original.sms`. Changes: 57 unreferenced
  `DungeonID_*` data labels in `banks/bank15.asm` renamed `DungeonLayout_*` (WLA-DX 10.7 refuses a
  label named like a `.define`), and `.include "ps1.options.asm"` added to `ps1.asm`.
* **Build (2026-10-16).** `tools/sourcebuild.py` (WLA-DX, SMS header checksum, `ps1.log` on
  failure, `ps1built.sym` for Mesen) and `tools/checkstock.py`. Stock SHA-256
  `9e324e92bd833b45126861b6f1d2dcbb51251bdf3df6d563ab3a3ff784d8cf88`.
* **Text engine survey (2026-10-16).** `docs/pipeline.md` section 3 maps the stock US text
  engine: the encoding and the glyph table, every control byte in both printers, the
  128-word dictionary and its expander, the 341 `DialogueBlock` ids (68 run on into the next
  block), the talk-id handlers and the `$C500` flags, the 174 bank-12 messages, the name
  fields (party 4, item 8, enemy 8, spells only in tilemaps), every menu tilemap with its
  size, the naming screen, the intro, ending and credits, and the font (44 tiles at `$C0`;
  tiles `$EC`-`$FF` look free). Free space: 183 bytes in bank 2, 40 in bank 12. Read-only:
  nothing in the source changed.
* **Stock ROMs supplied (2026-10-16).** The owner added `work/ps1jp_stock.sms` (Japan,
  CRC32 `6605D36A`) and `work/ps1en_stock.sms` (US/EU v3, identical to `ps1original.sms`),
  both git-ignored and recorded in `docs/pipeline.md` section 2. The JP text layout is mapped
  in section 3.12: everything in bank 2, with the glyph table at `$8000`, the same 341 ids,
  no dictionary, one byte per katakana, and controls `$4F`-`$58`.

* **Extraction and generation (2026-10-16).** `tools/ps1text.py` (both codecs, the rendered
  text form, the US encoder), `tools/textsrc.py` (the text regions), `tools/extract_text.py`
  -> `work/dialogue.json` (538 entries: 341 dialogue, 174 messages, 23 cut-scenes; JP paired
  by id and by `work/pairing.json`; one JP-only message, "wrong password") and
  `work/script.json` (party 4, items 65, enemies 74, with their JP). `tools/gentext.py` writes
  them back between marker comments (bit-exact, idempotent); `checkbuild.py` (nothing moved,
  2,008 fixed labels), `linecheck.py`, `test_text.py` (0 failures), and `checkstock.py` now
  sets en = us. With every entry re-encoded instead of copied, the script still fits (bank 2
  14,221 of 14,478 bytes, bank 12 3,811 of 3,836) and nothing moves. JP `$4E` is ァ
  (ダークファルス); the cut-scene budget is 20 cells (the JP's).
* **Emulator harness (2026-10-16).** Mesen 2.1.1 in `Mesen_2.1.1/` (portable, git-ignored),
  driven headless by `tools/ps1emu.py` with `work/scripts/lib.lua` (bounded waits, button-wait
  detection on `WaitForButton1Or2`, text read back from the VRAM nametable, screenshots).
  `boot` and `opening` pass on the stock ROM and on `ps1en.sms`: the intro's 8 pages read
  back exactly as `dialogue.json` has them (`--expect=B49B,B4FC,B5D5`), then the field in
  Camineet. Not yet seen in the emulator: the dialogue window's scrolled pages, battles,
  shops, the other menus.
* **Seen in game (2026-10-16).** `tools/trybuild.py` builds a test ROM from a few `en` edits
  without touching the JSON or the source. A trial with the soldier's intro speech rewritten
  in 20-cell lines and the field menu's STAS / SRCH as STAT / LOOK: `opening --expect` read
  all 8 pages back as the edited JSON has them, `fieldmenu` read STAT / MAGC / ITEM / LOOK /
  SAVE, and the screenshots agree. So the encoder's dialogue and the tilemap writer both show
  correctly, and 20-cell cut-scene lines fit under the picture in the US printer.
* **More scenarios (2026-10-16).** `--expect` now models the dialogue window (two lines,
  scrolling; consecutive ids share one window) and matches inserts as wildcards; `--words`
  checks `script.json` words on screen. `forcetalk` opens any person's conversation by talk id
  (Suelo: 7 of 7 window pages as the JSON has them); `talk` walks into Alisa's home sign; `menus`
  reads STAS, MAGC, ITEM and the item actions (22 of 22 words); `savegame` types a name through
  the naming screen (each key checked) and finds it in the cartridge RAM; `continue`
  (`--keep-sram`) loads it after a power-on. Each run now starts with a blank battery. Found on
  the way: `emu.reset()` stops a test-runner script, and the naming screen ignores the pad for
  over a second after it appears.

* **Tilemap text (2026-10-16).** `tools/tilemaps.py`; `extract_text.py --tilemaps` added 15
  tilemap segments (75 runs: menus, status boxes, spell lists, status labels, meseta, save
  slots, spaceport, intro caption) with JP decoded through the JP glyph table, dakuten from
  the row above, plus read-only `naming_screen` and `credits`. The JP spaceport is 03:BEB2.
  gentext writes the runs back; checkstock byte-identical, nothing moved, test_text 0
  failures. A changed tilemap `en` is now seen in the emulator (above). Open: three JP caption
  kanji ($BB $BD $BE) unread; the save-slot names' cells not traced (runs are the digit only).

## Next, in order

1. **Left from the survey:** a cross-check against Maxim's
   JP disassembly (`maxim-zhao/psrp`, `disassembly/`); in Mesen, that tiles `$EC`-`$FF` are
   free in every mode and that the title-screen words are graphics.
2. **The rest of script.json:** done but for writing the naming screen and (the owner's
   call) the credits, both read-only for now.
3. **More scenarios:** a battle (forced, as PS II's: the battle messages and the enemy name
   box); a shop (forcetalk to a shopkeeper's talk id); a dungeon.
4. **Engine options**: lower case, a proportional dialogue face, longer names, a text scheme
   with room for the new script (the stock banks have 183 and 40 bytes to spare).
5. **Translation**, then proofreading in play, then release packaging (BPS + Patcher.html).
