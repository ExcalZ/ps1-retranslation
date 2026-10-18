# PS I Retranslation - Status

Updated: 2026-10-17

## State

Project started. The disassembly is in place and assembles the US/EU release v3 bit-exact
with WLA-DX 10.7 (`python tools/checkstock.py`), the stock text engine is mapped
(`docs/pipeline.md` section 3), and the script is extracted into JSON with the JP beside the
US and written back by a generator whose round trip is bit-exact. Every engine option is on
in the working build (1 MB, the series face in the window and cut-scenes, 6-letter party
names, 12-letter items and enemies); the stock English is re-wrapped for the face until it is
translated. One entry is translated (the CONTINUE prompt); the names glossary is a draft
waiting on the owner's decisions (`work/glossary.md`, questions 1-6).

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
* **Battle and shop (2026-10-16).** `shop` opens a shop by interaction type and shop id
  (`$C29E`, `$C2DB`), buys the first item and checks it against the stock data in the ROM:
  the armory and the First Food Shop pass, pages and stock as the JSON has them. `battle`
  forces an encounter (`$C2E6`, `$C29D` `$FF`, game mode `$0C`): the battle menu, the enemy
  name box, the victory, experience and chest messages, and (unboosted, against a Green Slime)
  the game over, every window line a line of `dialogue.json` (`--known`). The timed wait
  (`LABEL_2D39`) is detected like the button wait.

* **Tilemap text (2026-10-16).** `tools/tilemaps.py`; `extract_text.py --tilemaps` added 15
  tilemap segments (75 runs: menus, status boxes, spell lists, status labels, meseta, save
  slots, spaceport, intro caption) with JP decoded through the JP glyph table, dakuten from
  the row above, plus read-only `naming_screen` and `credits`. The JP spaceport is 03:BEB2.
  gentext writes the runs back; checkstock byte-identical, nothing moved, test_text 0
  failures. A changed tilemap `en` is now seen in the emulator (above). Open: three JP caption
  kanji ($BB $BD $BE) unread; the save-slot names' cells not traced (runs are the digit only).

* **Engine milestone 1 (2026-10-16).** The owner chose the plan's recommendations
  (`docs/engine-plan.md`). Built and on: `expand_rom` (1 MB), `far_calls` (`FarCall` /
  `FarRead` in the RST slots, tested at runtime by `farcall.lua`), `relocate_script` (the
  script in banks 32-34). The script now lives in `PSI_Disasm/text/*.asm`, written whole by
  gentext. Every scenario passes on the relocated build with the stock text; checkstock is
  byte-identical with the options at 0. Found on the way: checkstock and trybuild did not put
  the text files back (fixed).

* **Engine milestone 2: vwf_dialogue (2026-10-16).** The dungeon audit found the plan's second
  tile set (`$1B0-$1BF`) in use there, so the window's lines are **80 px** (10 tiles each, the
  20 tiles `$EC-$FF`), not 144 - about 16-17 mixed-case characters a line. Built: the gate in
  the stock number printer's bytes, the renderer in bank 35, the series face
  (`tools/vwfmixed.py`, `tools/diafont.py`), the mixed-case encoder, linecheck in pixels, the
  harness reading the window's pixels back. Mixed-case lines and inserts read back exactly in
  game (trial build). **Off in the working build** until translated lines fill the window.
  Cut-scenes have more room (64 tiles while one is up): `vwf_cutscene` can give 128 px lines.

* **Engine milestone 3: vwf_cutscene (2026-10-16).** The cut-scenes in the face, 4 lines of
  120 px in the font area (`$C1-$FC`), the stock font reloaded at the next fade-out or before
  the next menu or window. The intro in mixed case reads back exactly; every scenario passes
  with both proportional options on. Off in the working build with `vwf_dialogue`.

* **Engine milestone 4: long_names (2026-10-17).** Party names up to 6 letters: `{NAME}`
  through the renderer ("Alisa"), the name box and the party menu (both places) 8 cells wide in
  capitals, the extra columns saved in new RAM. Seen in game with Alisa, Myau, Tyron, Lutz:
  party menu, HEAL target, name box at each battle turn, status boxes, "Alisa died."; every
  window restores the screen. Off in the working build (it needs `vwf_dialogue`). New
  scenarios: `partymenu`, `healtarget`, `battle party=4`.

* **Engine milestone 5: long_item_names (2026-10-17).** The window map (every save area,
  `docs/pipeline.md` 3.7), then item and enemy names up to 12 characters: `{ITEM}` and
  `{ENEMY}` in the face, the inventory, shop list, equipment box and enemy name box 4 cells
  wider to the left. With all five options on and every test edit at once, every scenario
  passes and every window restores the screen. New scenario: `inventory`. The engine plan's
  options are all built.

* **The translation starts (2026-10-17).** Every option on in the working build. The face's
  printer never auto-wraps, so the stock English is rebuilt with its breaks written out and
  re-wrapped where it overflows the 80 px lines (`tools/stockwrap.py`, used by gentext,
  linecheck and the harness: 225 of 538 stock texts change). The CONTINUE prompt, a two-column
  table the re-wrap cannot keep, is the first translated entry ("Continue: YES / Delete:
  NO"). Every scenario passes (`battle party=4` now allows 40 rounds: the dice changed and 20
  was the stock build's exact count). The names glossary drafted from the JP script against
  the PS II and PS IV translations' shipped text: people, worlds, places, 64 items, 74
  enemies, 18 spells, with six questions for the owner.

* **Item and enemy windows 14 letters (2026-10-17).** The owner: "Expand windows as necessary,
  but accommodate mixed-case". `long_item_names` now takes 14 characters: the inventory (r2
  c16), shop list (r0 c0), equipment box (r10 c0) and battle name box (r0 c8) 6 cells wider than
  the stock, the two new columns saved at `$C790` (no stock code touches `$C790-$C7FF`) and
  `$DFE8`. Seen in game with LEATHER SHIELD, CERAMIC SHIELD, ESCAPE CLOTH and CHAOS SORCERER;
  every scenario passes. **Mixed case in these windows is not built:** the VRAM audit (all 74
  enemies' battles, town, menus, a dungeon) finds room for the 26 lower-case tiles everywhere
  except battles, which leave only 20 tiles free (`docs/engine-plan.md`). The way to take is the
  owner's call.

* **vwf_windows: every window's text in the face (2026-10-17).** The owner: "accommodate
  mixed-case", then "we don't need non-VWF non-numbers": the fixed font keeps the blank and
  digits for the windows, its letters lent in battle. The VRAM audit was redone against real
  battles (the map's encounter pools with their backdrops, all 15 backdrops set at the loader,
  all 74 enemies; `work/scripts/vramdump.lua`, `tools/vramsheet.py`): the pools in
  `docs/pipeline.md` 6. Menu maps carry marked runs (gentext: `WinStrings`); the map copy draws
  them in the face into lent tiles; marks keyed by the save buffers give them back; a run
  drawn again in place keeps its tiles. On in the working build: every scenario passes, and
  menus, lists and party names read back in mixed case (trial builds with Fight / Magic /
  Item / Talk / Flee, Status / Search, Use / Equip / Drop, Yes / No, 14-letter items and
  enemies, Alisa / Myau / Tyron / Lutz). Found on the way: tile `$1FF` is written every frame
  (not free); the battle redraws its menu in place for each member (`LABEL_30D5`). (The
  windows left then are done below.)
* **Meseta (2026-10-17).** The owner: MST becomes "Meseta", in the face. The money line (the
  money box, the inventory, the status window) is drawn as one run, "Meseta 2000", the amount
  in the face too: the money box's 8 cells hold "Meseta 65535" (55 px). The battle's pool now
  takes all the font's letters.

* **The name windows narrowed (2026-10-17).** With the names in the face, `long_item_names`'
  windows need 10 name cells (80 px), not 14: their width is now `LONG_W` / `LONG_X`
  (`ext/vwf_ram.asm`; 10 / 2 with `vwf_windows`, 14 / 6 without). The inventory, shop list,
  equipment box and battle name box are 2 cells wider than the stock's; the second extra
  buffers (`$C790`, `$DFE8`) are used only without `vwf_windows`. linecheck: an item or enemy at
  most 80 px. Both widths seen in game (trial builds); every scenario passes.

* **vwf_windows finished (2026-10-17).** The spell lists a cell wider (5 text cells: the
  proposed spells reach 36 px, Muwaller and Telepath), drawn in bank 35 from gentext's wider
  maps; the status window's labels in the face (`LABEL_2FD8` -> `WinLabel`; the LV row stays
  the stock's). Only the save slots and the intro caption keep the fixed font. New scenario
  `windows screen=hospital|church|sell|port|dungeon`, and `battlelist` reads the battle's
  spell list; menus are chosen by reading the cursor back. Seen in a mixed-case trial build:
  the hospital and church party menus, Buy / Sell and the selling list, the ship's
  destinations, the dungeon's menu, inventory and status window (the view comes back), the
  battle spell list (Muwaller / Telepath). Every scenario passes on the working build (24).

* **Names and menus in script.json (2026-10-17).** The party, items, enemies and spells from
  the glossary (settled forms, and the proposals where questions 1-3 and 6-8 are open); the
  menu words translated from the JP (Fight / Magic / Item / Talk / Flee, Stats / Search / Save,
  Use / Equip / Drop, Buy / Sell, Yes / No, Attack / Defense / Max HP / Max MP, More, the
  spaceport's Gashiko / Uzo / Skure). Every scenario passes with them (`--words` reads them
  back from the face).

* **Translation begun (2026-10-17): the opening and Camineet.** From the JP: the intro
  caption (AW 342, SPRING / CAMINEET, PALMA: the JP's two unread kanji are 春 and 居住, from
  the JP font's tiles), the three opening cut-scenes (LABEL_B49B, B4FC, B5D5) and Camineet's
  people (dialogue 0002-0024: Suelo, Nekise, the townsfolk, the soldiers and the gate guards).
  Window lines are 80 px (about 16 letters), two to a page as the stock; cut-scene lines
  120 px, four to a page. Seen in game: the opening's 7 pages and Suelo's 5 read back as
  written, and every Camineet talk id shows only script lines. `tools/applyedits.py` writes a
  tried edits file into the JSON.

* **Palma translated (2026-10-17).** From the JP, 176 more dialogue entries: Parolit,
  Scion, Epi village, Palma's spaceport and passport office (0026-007E), Gashiko, Dr. Luveno
  and his assistant, the tower road, Triada, Bartevo and Hapsby (00B2-0108), Loar and Abion
  (010A-012C), Damoa, the Bayamare tower, the Flow Mover, Drasgow and its hidden Gas Clear
  shop, Triada's cells and the road-pass robot, Luveno's ship, the inn and Alisa's home
  (0148-02A4). The JP's in-jokes are kept where the US replaced them (0188, "big sister
  Choko"). Prices the JP prints with {NUMBER} are written out as the US has them (the
  passport's 100, the Gas Clear's 1000, the ship's 1200): the US code may not set the number.
  `tools/wraptext.py` lays prose out in 80 px lines, two to a page. In game: every talk id
  checked (17-68, spot checks above) shows only script lines; the question prompts (the
  scenario does not answer yes / no) time out as they do on the stock text.
* **Bank 32 is nearly full: 15,275 of 15,702 bytes** with 192 of 341 dialogue entries
  translated. Mixed case barely compresses under the stock dictionary (capitals only): the
  translated entries take 9.3 KB against 6.9 KB stock; the remaining 149 would need about
  7.9 KB more, some 2 KB over the bank. Next: the dictionary generated from the new script.

* **script_dictionary (2026-10-17).** The 128 dictionary words chosen from the script at
  every build (`tools/scriptdict.py`, `text/words.asm`): bank 32 from 15,275 to 11,635 bytes
  with Palma translated; every scenario passes, the opening, dialogue, battle messages and
  shops read back through the new words.
* **Motavia translated (2026-10-17).** From the JP, 97 more dialogue entries (289 of 341):
  Paseo, its spaceport and the Governor (0080-00B0), Uzo and the Soothe Flute (012E-0146),
  Casba (0166-0170), Sopia, Miki the gamer and the village chief (01E8-0210), the Guaran
  armor (0224-022A), the eclipse fire, the Naura shortcake and Lutz's teacher (023A-0262),
  the passage boy and the Motavians (0282-0288), the Governor's last scenes and the ending
  narration (02A6-02AA). The JP's {NUMBER} prices are written out as the US has them (the
  animal's 100 million, the donation's 400, the shortcake's 1000). The face has no `*`:
  sobs are "(sob)". Falls-through chunks are laid out by hand to fill their pages, moving a
  few words across the JP's split where a lone word would sit on a page. Bank 32 is 11,122
  bytes (the dictionary re-chosen for the larger script). In game: the Governor (talk 55,
  9 pages) and the spaceport (talk 44) read back as script lines; every scenario passes.
* **Dezolis and the end translated (2026-10-17): every dialogue entry is now from the JP.**
  The last 53: Skure, the Laconia arms and the eclipse (01A0-01C6), the two Dezolian
  villages (01C8-01E6), LaShiec's double and LaShiec (0262-0270), the possessed man's
  thanks and the queen question (0272-0278) with its answers 0212 and 0230 (0212 is that
  answer, not a Sopia line: its Motavia wording is replaced). The JP gives the two Dezolian
  villages their own speech, ズラ where Palmans are hated and ンダス where they are welcome
  (the US's "ze" and "yes, indeed"). The owner's call (2026-10-17): an American Southern
  accent, as PS II and PS IV voice Dezolians; the ズラ village broad and gruff, the ンダス
  village gentle and courteous (`work/glossary.md`, "Voices"; talks 104, 106, 107, 113
  seen in game). 027A (talk 178) is the JP's in-joke, Chie of the
  letters page, where the US put an Aeroprism hint, as the Palma in-jokes are kept.
  027C-0280 are called by nothing in either version: the JP's copies of the passage boy's
  line, given the same English as 0282. Bank 32 is 10,663 bytes. In game: talks 96-98,
  102, 107 (every falls-through chain whole) and 178 read back as script lines; every
  scenario passes.

## Next, in order

1. **Left from the survey:** a cross-check against Maxim's
   JP disassembly (`maxim-zhao/psrp`, `disassembly/`); in Mesen, that tiles `$EC`-`$FF` are
   free in every mode and that the title-screen words are graphics.
2. **The rest of script.json:** done but for writing the naming screen and (the owner's
   call) the credits, both read-only for now.
3. **More scenarios** (as the translation needs them): the ending.
4. **Engine**: the naming screen with lower case (later). Not yet seen with
   `vwf_cutscene`: the Myau, governor and ending scenes (no scenario reaches them yet).
5. **Translation**: the messages and the cut-scenes (the dictionary keeps
   bank 32 in room: watch linecheck's byte count); then proofreading in play, then release
   packaging (BPS + Patcher.html).
