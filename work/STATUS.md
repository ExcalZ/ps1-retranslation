# PS I Retranslation - Status

Updated: 2026-11-02

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

* **The translation is complete (2026-10-17).** The last 193 entries: the 20 cut-scenes
  (Myau, Tyron and Lutz joining, Myau's wings, the credits' names centered in the 120 px
  line) and the 173 messages (battle, items, shops, hospital, church, save and continue,
  the monster talk, the ending's breeze). Every entry of `work/dialogue.json` is from the JP
  now. Battle messages put `{ENEMY}` (66 px at its widest, Horseshoe Crab) on a line of its
  own so most stay two lines; the vehicle lines name the vehicle as the JP does
  (`{ITEM}` is set: boarding and getting off are both item uses). `savegame.lua` takes a
  one-page save prompt (the slot list opens at once) as well as the stock's two pages.
  Bytes: bank 32 10,141, bank 33 3,173, bank 34 1,154. In game: the battle, shop, save,
  continue, hospital, church, sell and menu scenarios, and the opening.
* **The story scenes in game (2026-10-17).** Five scenarios reach the scenes no scenario
  showed: `myau`, `tyron`, `lutz`, `wings`, `ending [answer=no]` (the talk handler or the
  item use that starts each, the RAM it reads set first: `docs/pipeline.md` section 7).
  `lib.lua`'s `page_scene` logs timed waits as pages too (a cut-scene's `{TIMED}`, the
  window's `{PAUSE}` and `{TIMED}`), and `--expect`'s window model ends a page there. Every
  page of Myau's, Tyron's and Lutz's cut-scenes, Myau's wings, the Governor's speech with
  both answers, the breeze and the credits reads back as `dialogue.json` has it (9, 9, 5, 4
  and 24 pages); the credits' names sit where the stock's do (centered in the text line,
  some 20 px left of the screen's center, as the stock's six leading cells put them).
* **The naming screen's keys (2026-10-23).** The owner: "ADV RUB END" becomes "FWD DEL
  END", as in PS II. The three words are a literal run in the screen's RLE (`LABEL_423C` +
  47, 11 tiles), so `script.json` has a new segment `naming_keys` (kind `naming`, 3 cells
  each, lower tiles only) that gentext writes in place; the rest of the screen stays
  read-only. `linecheck` and the proofreader check it as a tilemap run, `test_text` against
  both ROMs. `type_name` (lib.lua) now screenshots the screen before END; `savegame` shows
  FWD DEL END and still types and saves.
* **Battle macros (2026-11-02): `battle_macros`.** The owner asked for PS II's macro system;
  their design for PS I: each round opens with **Command / Macro / Talk / Flee** (Command asks
  the members Fight / Magic / Item as the stock does; Talk and Flee are the stock's, moved up),
  eight slots A-H, set from the field menu's new fifth entry (Stats / Magic / Item / Search /
  **Macro** / Save) and saved with the game. A slot's preview (each member's name and command,
  a healing spell's target after it) follows the cursor in battle and in the editor; C on a set
  slot gives each acting member its command and starts the round; a line not set, or one that
  cannot be carried out (MP short, the item gone, the target down), fights. The macros live in
  `$C3C0-$C3FF`, inside the block the save copies and a new game clears: the audit tour (town,
  menus, talk, shop, battle, a dungeon) finds no writer of `$C318-$C3FF` but the new game's
  clear. Words in `script.json` `macro_words` (new kind `macro`; linecheck, the proofreader).
  Checked: `macros` (the editor's bytes after each line, the preview in both places, the
  battle records equal to the macro, the round played: Heal on Myau, the PelorieMate with its
  target menu), `savegame macros=1` then `continue macros=1 --keep-sram` (the macros back after
  a power-on), `macros first=talk` / `first=flee` (the stock's, from the first window),
  `macros enemy=39 stress=1` (four 80 px item names in the preview against the Leviathan, the
  battle with the fewest tiles to lend: all in the face), the other scenarios (the battle ones
  go through Command; `savegame` finds SAVE as the last entry), checkbuild, checkstock
  (byte-identical with the options at 0), test_text. Found on the way: the two battle windows
  first kept 20 pool tiles (their runs' cells) and `battlelist enemy=39` drew its ninth item in
  capitals; they now keep what their runs take (15, the stock menu's own count, gentext).
  Then the colours (the owner, the same day): a slot's letter red when empty, amber when a
  party member's line cannot be carried out as set, those lines amber in the preview. They are
  window cells on the sprite palette, whose red and amber (21, 22) every battle, interaction
  screen and dungeon loads (`LABEL_3D1D`, `LABEL_6DF7`; Dark Falz's too); sampled while a menu
  is up across the audit tour, always red and amber. Seen: red (255,0,0) and amber (255,173,0) in
  the editor and in battle; `macros` checks each colour in VRAM. Not done: erasing a whole slot
  (a line can be set again, not cleared).

* **A window fix (2026-11-02): the status window and back.** The owner: after Alisa's status
  the field menu came back with "Item" in her name box. The map copy releases a mark for each
  row of a buffer coming back, and a row's address can share another buffer's key: the
  equipment box's last row (`$D9B4`) released `MacroExtra`'s mark, `LongSharedExtra`'s third
  (`$DF2C`) the name box's (`$D724`), so the pool rewound under the name box and the field
  menu, drawn again, took its tiles. Now only a buffer's first row releases (`WinRowBack`: a
  row going on from the last, in RAM and on the screen, is the same buffer's). Found on the
  way: the field menu drawn again after the status window counted as a new window (it lay in
  the region the status window saved last) and took 14 new tiles a time, so the twelfth status
  view ran the pool into the font; a release now ends that region. `menus` opens and closes
  STAS three times and checks the menu, the name box and `WinPos`.
* **VDP pacing (2026-11-02).** The owner, in Camineet: the third STAS drew the equipment box's
  top edge as a strip of hedge tiles. `LongBorder` (every name window's top and bottom edge)
  wrote the first middle cell's tile 18 cycles after the corner's attribute; while the screen
  is drawn the VDP takes a CPU write only at a free access slot and a second write replaces a
  pending one, so on some frames the attribute was lost and every cell after it pointed at a
  low tile (the backdrop's hedges, a menu glyph). Mesen models it: 3 views of 20 went wrong,
  by the frame's phase. Every VDP access in `ext/` audited by cycles: `LongBorder` now waits
  36 or more between writes, the inventory's money line had 25 (now 46), `WinTileFor`'s VRAM
  read waits 53 after its address as the stock's do 37; the rest were 31 and more. `menus`
  now opens STAS 20 times a frame or more apart and checks the box's top edge in the
  nametable (the old code fails at the twelfth).

* **Faster exploration (2026-11-02): `fast_transitions`, `fast_walk`.** The owner asked for
  faster screen transitions and double walking speed. Both on: palette fades keep every
  colour step at half the delay (36 -> 18 frames out, 40 -> 20 in); overhead on-foot movement
  takes 8 frames per 16-pixel tile instead of 16, with followers' direction history and
  signed movement matched. Vehicles stay at 8 frames; on-foot road travel uses the faster
  mover too. Dungeon animations use four rendered views with alternating graphics buffers
  (step 39 -> 27 frames, turn 50 -> 27 in the bounded scenario; see the motion fix below).
  No new RAM or bank
  dependencies. `exploration` compares both speeds, walls, closed/open doors and encounter
  cadence, with byte-identical final dungeon screenshots. `mapwalk` checks four followers
  around all four corners, 16-pixel spacing, one collision/encounter entry per tile, and
  vehicle timing (synthetic passable cache). All stock-address, text and stock-reproduction
  checks pass; opening, home entrance, menus, dungeon windows, all five story scenes,
  battle, shop and macros pass. Details and commands: `docs/pipeline.md` section 6.

* **Dungeon motion fix (2026-11-02).** The owner reported visual corruption during movement.
  The initial speedup kept even view IDs, but their low bit selects the graphics bank:
  writing even frames repeatedly overwrote tiles still on screen. Settled screenshots had
  missed this. `fast_dungeon_table.asm` now keeps odd/even/odd/even views and the original
  pointer offsets, direction deltas and final still view. Steps use four renders instead
  of six (~1.5x speed); turns four instead of eight (~2x). `dungeon_anim` checks every upload
  against the visible nametable across forward/backward and all eight turn variants:
  the broken ROM fails 38/38 uploads, the stock-speed ROM passes 76/76, the fix passes
  40/40; `film=1` records every frame, visibly reproducing the old tearing and showing the
  corrected motion. `exploration` also checks doors, wall collision and encounter cadence.

## Next, in order

1. **Left from the survey:** a cross-check against Maxim's
   JP disassembly (`maxim-zhao/psrp`, `disassembly/`); in Mesen, that tiles `$EC`-`$FF` are
   free in every mode and that the title-screen words are graphics.
2. **The rest of script.json:** done but for writing the naming screen's grid and prompt
   (its key words are `naming_keys`) and (the owner's call) the credits, both read-only for
   now.
3. **More scenarios** (as the translation needs them).
4. **Engine**: the naming screen with lower case (later).
5. **Proofreading in play** (the translation is complete; every scene now has a scenario:
   the story scenes are `myau`, `tyron`, `lutz`, `wings`, `ending`), then release packaging
   (BPS + Patcher.html).

* **First shield equip restoration (2026-11-03).** Reproduced the lingering inventory strip:
  the equipment preview overwrote the inventory extra-column background in LongSharedExtra.
  Its columns now save separately at $D9C8/$DA08, in the 80-byte gap before the dialogue
  buffer. `equip` fails on the old build (16 changed cells), passes on the fix, and verifies
  the shield was equipped and removed from inventory. Stock reproduction and text/build
  checks pass; inventory, menus and party-menu regressions also pass.

* **Chests and dungeon fights in the windows' pool (2026-11-26).** The owner reported "Yes No"
  drawn into a dungeon chest and "Green Slime" into the slime, with two savestates. A dungeon
  shows its chests, people and fights as sprites from tile `$100` up; `WinEnsurePool` gave
  every screen in game mode `$0B` the corridor's pool, `$101-$1BF`, measured on the still view
  with a menu up and no sprite. Now a fight takes the battle's pool (also before `$C29D` is
  up: `LABEL_100F` draws the name box first, so `LongEnemyBoxSave` raises `WinBattleStart`),
  a person the interaction screen's, and a chest `WinPoolChest` (`$1A0-$1A9`, `$1B0-$1BF`, the
  letters, then `$116-$19F`: its pictures fill `$100-$19F`, the closed chest `$100-$115`).
  The same held for a chest a battle leaves and the party declines: it stays on the
  interaction screen, whose pool started at `$101` (found by `battle chest=no`). The chest's
  question (`LABEL_28DB` -> `WinChestAsk`) unpacks the pictures again if the pool lent them,
  since a declined chest stays up and Search or a spell asks without `LABEL_16B2`. `lib.lua`
  takes `state=PATH` (a Mesen savestate) for any scenario. Replayed from the owner's chest:
  the Yes/No takes `$1A0-$1A4`, the opening plays clean, a full Item list over it is in the
  face, a scribbled sheet is whole again at Search's question; a fresh dungeon encounter keeps
  its enemy's tiles byte for byte; on the field, decline, Item list (lends `$116-$12E`),
  Search, Yes: whole at the question and after. Then the owner's third state: the governor's
  robot guard (talk `$9B`, `LABEL_53BF`) is enemy `$2E`'s pictures, loaded by `LABEL_5FFE` for
  a talk with no person (`$C2DC` 0), so the corridor's pool drew "Yes No" into it. A talk with
  an enemy slot filled (`$C2DB`, `$C440`) now takes the interaction screen's ranges above that
  enemy's graphics: replayed, its question draws in `$15E-$162` and the robot's 94 tiles stay
  byte for byte. Not tested in play: a person met in a dungeon
  (no scenario reaches one). `battle chest=no` still fails as a scenario: after NO the chest
  stays on the interaction screen and its loop presses into the field menu (it never handled
  that; only YES was checked).

* **Window text flicker in battle (2026-11-26).** The owner saw tiles flicker in a battle with a
  Desert Leech ("Desert Lee:h", savestate). The battle redraws the enemy name box in place
  after hits, items and turns (`LABEL_3105`). `WinDraw` uploaded the tile under the pen after
  every glyph, so a redraw showed tiles half drawn for a frame; and after the last glyph,
  with the pen on a tile boundary, it uploaded the empty next tile, which in place took pool
  position `WinP0 + c` for a cell past the text: with `WinPos` rewound below the box's own
  tiles, that was the tile of its second "e". Now a tile is uploaded once, whole (when the pen
  leaves it, and the last at the run's end), and a cell drawn in place with no tile takes one
  above every tile the run keeps (`WinKeptTop`, `WinPoolPos`). Replayed: tiles `$190-$1BF`
  no longer change, the name box reads "Desert Leech" throughout. A per-frame check (any
  on-screen face tile whose content changes and returns within a few frames, and two face
  cells sharing a tile) finds none over the replay and full battles but the menu's own
  switches (Command / Fight) and the stock cursor's blink. Fewer VDP writes per run too.

* **The enemy's name box kept low in the pool (2026-11-26).** The owner saw the same flicker
  against Bat Man (savestate, a dungeon fight, four members). The round's windows save into one
  region, `$7842-$7E00`, and the name box (`LABEL_3105`, drawn again after hits, items and turns)
  lies inside it, so each redraw took new tiles at the top of the pool; Bat Man's graphics reach
  `$19C`, so "Bat Man" landed on `$1A0-$1A1`, the effects' tiles, which every attack rewrote.
  `LongEnemyBox` now draws in place (`WinForceReuse`): the box keeps `$CB-$CF` all battle. While
  a message (and so an effect) is up only positions to 12 are in use; the command windows reach
  `$1A0` against the tallest enemies but are closed before an effect plays. The effects reach
  `$1BD`, not `$1B6` (`LABEL_5BF1`, `LABEL_5EA2`, `LABEL_5EA8` measured from the ROM). Checked
  over four-member battles with Bat Man, enemy `$48` (graphics to `$19E`) and others: no window
  tile rewritten under an effect, none shared.

* **The macro preview without garbling (2026-11-26).** Browsing slots, the preview redrew its
  lines one by one from `MacroPrevBase`, so a new line took a later old line's tiles for a frame
  or two. The names now go first on the same tiles each time, and each member's command keeps a
  fixed place as wide as that member's widest command in the eight slots (`MacroCmdW`,
  `WinMeasure`); a line rewrites only its own tiles, an unchanged one shows no change. Where the
  places do not fit, the commands go elsewhere or line by line with only a colliding old command
  blanked (`MacroPreviewSeq`). Browsing all eight slots in the field and in battles (enemies 39
  and 18): no shared tile, no command blanked, each line straight from its old text to its new.

* **Dr. Luveno's Yes / No (2026-11-26).** The owner's savestate: "Yes No" drawn into Dr.
  Luveno. His room runs in dungeon mode, and his talk's handler (`LABEL_51DC`) loads his
  pictures itself (`ld a, $34 / call LABEL_617D`) with `$C2DC` 0, so the pool took the
  corridor's `$101` up. `LABEL_617D` now records the person it loads (`WinPersonHook`,
  `WinShownPerson`), and a talk's pool starts above that person's graphics. Replayed: his
  question draws in `$12A-$12D`, above his `$100-$129`.

* **Gashiko's razed houses (2026-11-26).** The owner's savestate: the Status page's second
  window (Max HP, Max MP, Meseta) and the equipment list garbled. A razed house is a room with
  a talk and no person (`$C2DB` set, `$C2DC` 0); `LABEL_617D` returns at once for person 0, so
  `WinShownPerson` kept the last person met and the pool started above graphics that were not
  there (84 tiles): the Status page ran out, and its last runs fell back to stock capitals the
  face had already taken. The hook now covers `LABEL_617D`'s `or a / ret z` and records 0 too.
  Replayed: left the house, walked back in, Status: the pool from `$101`, every line in the
  face, no stock letter on a face tile.

* **The save list after a dungeon's fight (2026-11-26).** The owner's savestate: the save slots'
  names garbled. They are stock capitals (the names typed at the start); a battle lends the
  font's letters first, and the font came back only at a fade-out, which a dungeon's fight does
  not end with. Now before a menu draws (`VwfMenuFont`) the font is reloaded too when its letters
  were lent and no window of the screen holds them (`WinLettersBack`). Replayed: closed the
  menus, opened Save: the names in clean capitals, the face windows intact.
  `WinLettersBack` sits last in bank 35 (`ext/banks.asm`) so the code before it keeps its
  addresses. The Desert Leech and Bat Man states (`ps1en_4`, `ps1en_5`) no longer replay: they
  were saved mid-code in bank 35 before `hospital_everyone` grew `longnames_data.asm`, and resume
  at the old addresses on any build since (the build before this fix too); fresh battles of
  both kinds still show no shared tile.

* **The Air Castle's spot (2026-11-26).** The owner's savestate: the menu opened after the
  Aero Prism showed the Air Castle, the Item list in garbled stock capitals. The spot is a
  dungeon screen (game mode `$0B`) whose map entry sets `$C2DB` `$B0`; the reveal (`$C2D8` 6:
  `LABEL_7CBB`) sets `$C2DC` to `$FF`, which `WinEnsurePool` took for a person: the interaction
  screen's pool with no person in the table (16 tiles and the letters), so the list ran out of
  tiles and fell back to the stock capitals on letters the menu had lent. Now in a dungeon a
  `$C2DC` of `$FF` is no one (`WinSpotPerson`, last in bank 35, called in place of the
  `ld a, ($C2DC)`): the dungeon's pool, `$101-$1BF`, which the castle's screen does not show.
  Replayed (`ps1en_1`): left the spot, walked back on, used the Aero Prism, opened Item: the list
  in the face from `$101`, no stock capitals; the build without the fix shows the owner's screen.

* **Release packaging, v1.0 (2026-11-26).** The owner: "commit everything we have and prepare
  a 1.0 release", the patch to take US/EU v2 as well as v3 (settling that open question).
  `tools/release.py VERSION`, as PS II's: BPS from v3 and from v2 (`_V2.bps`), `Patcher.html`
  (`tools/webpatch.py`, `tools/patcher_template.html`: PS II's page for `.sms`, a copier
  header dropped, a v2 -> v3 BPS embedded as an alternate), `readme.txt` from
  `release/readme_template.txt` (sizes and hashes filled from the files), and the zip. `tools/bps.py`
  is PS II's. Dry run (v3 standing in for the missing v2 dump): Flips patches of 25,975
  bytes, re-applied byte-exact; the page in a browser patched v3, plain and with a 512-byte
  header, to CRC32 `C1EAE68B` and refused the JP ROM. A save made on the stock v3 ROM loads in
  the patched one (`savegame` on `ps1original.sms`, its battery under a copy of the patched
  ROM, `continue --keep-sram`). Waiting on the v2 dump (`work/ps1en_v2_stock.sms`) for the
  real package.

* **Out of tiles, safely (2026-11-26).** The owner asked for the fallback to be safe too. A run
  that runs out of pool tiles fell back to the stock capitals, which show only where the font's
  letters do; a pool lends them (the battle's first, the others' last), so once one runs out
  they are lent, and the capitals drew other windows' glyphs. Now `WinRun_Fallback` jumps to
  `WinSafeFallback` (last in bank 35; its `ld de, (WinRunVram)` -> `jp` and a `nop`): the tiles
  the run drew into count as lent (`WinFontNote`); letters not lent: the capitals as before;
  lent but no window below the run holds them (their pool position at or above `WinP0`, or not
  in the pool): the font back (`VwfFontBack`), then the capitals; held: the run in the face as
  far as its tiles went (the cells before the tile that failed), the rest blank, and `WinPos`
  at the pool's end. Tested on two test ROMs: the Air Castle screen without the fix above
  (`ps1en_1`: "Aeropris" in the face, the rest of the list blank, no capital on a lent tile),
  and a field screen with no pool, the letters scribbled and the font marked lent as the
  fallback starts (`ps1en_7`): the font back byte for byte, the menu in clean capitals.

* **The hospital's Everyone (2026-11-26): `hospital_everyone`.** The owner asked for an
  Everyone entry at the hospital that sums the individual fees and restores everyone's HP and
  MP. The party menu ("Who needs treatment?") now ends in Everyone, after the names (r9, or r7
  with four members, clear of the dialogue window). The fee is the sum of each living member's
  stock fee (max HP - HP + max MP - MP, 8 bits each, exactly what choosing them one by one
  costs); a member who is down is left out, as the hospital never treats the dead. Two new
  lines (proposed English, no JP: the owner's to settle): `HospAllCost` "Treatment for
  everyone comes to N meseta. All right?" and `HospAllNone` "You're all in good health.";
  after paying, the stock "Thank you for waiting. Take care." and the visit ends. The routine
  moved whole to bank 35 (`ext/hospital.asm`); the word is `script.json` `hospital_words`; the
  lines are `dialogue.json` entries marked `added` (the tools now take an entry with no stock
  text). Checked: new scenario `hospital` (`pay` with 4, 3 and 2 members and with one down,
  `none`, `short`, `one`, the stock path): fee, money, HP / MP and the screen back, every window
  line from `dialogue.json`, Everyone in the face; `windows` hospital and church, `partymenu`,
  `healtarget`, `menus`; checkbuild, linecheck, test_text, checkstock (byte-identical). Found:
  the stock fee is 8 bits, so a member missing more than 255 HP and MP together is charged the
  remainder (Everyone sums those same fees).
