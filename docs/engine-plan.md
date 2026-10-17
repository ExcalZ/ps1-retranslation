# Engine options: the plan

Proposed 2026-10-16. **Decided by the owner on 2026-10-16:** A expand to 1 MB; B proportional
cut-scenes if the per-picture audit finds the tiles; C menus stay upper case for now; D party
names 6 letters, items and enemies 12 cells; E reuse the series face. **Milestone 1 (options
1-3) is built** - see `pipeline.md` section 6; option 3 came out simpler than planned (below). Each change is an
option in `PSI_Disasm/ps1.options.asm`, as in PS II: with every option at 0 the ROM stays the
US/EU v3 byte for byte (`checkstock.py`), every hook is the exact size of the stock code it
replaces, and new code goes in `PSI_Disasm/ext/`.

## 1. What the plan has to work with (measured)

| fact | figure | source |
|---|---|---|
| free ROM | about 2.8 KB in all, spread over 32 banks; banks 0 and 1 (the fixed code) have none (bank 0: 40 bytes of unused RST slots) | `$FF` runs at the bank ends |
| text room now | bank 2: 183 bytes, bank 12: 40 | `linecheck.py` |
| the script | 13,900 kana of Japanese; the US English is 22,500 characters packed into 18.1 KB by the 128-word dictionary. A translation from the Japanese typically runs 1.6-2x the kana: **22-28 KB** of plain text | `dialogue.json` |
| names | JP party names 4 kana, but the series' English needs 5 letters (Alisa, Tyron); JP items and enemies up to 8 kana, English full names up to about 16 letters (Titanium Sword, Motavian Peasant) | `script.json` |
| VRAM never on screen in town, the menus, a conversation, a shop or a battle | `$EC-$FF` (20 tiles), `$1B0-$1BF` (16), probably `$B5-$BF` (11). Battle sprites take `$100-$19F` (a red dragon 89 tiles of it, Dark Falz 70) | `work/scripts/vramaudit.lua` |
| the frame interrupt | saves and restores the paged bank (`$FFFF`), so new code paged into slot 2 can wait for frames | `VInt` |
| windows | each window saves the screen under it into a fixed RAM area (`$DA18` the dialogue window, `$D8A4` the command menu and shop list, `$DE14`, `$DE64` YES/NO, `$DB74` the spell list, ...); the areas overlap where windows are never open together, so a wider window means re-planning them (PSRP's notes say the same) | the window code |
| the face | the PS IV retranslation's menu face, which PS II and III use for their dialogue: proportional, mixed case, 8 px tall in **one tile row** - exactly a PS I text line. Lowercase averages 4.6 px, so a 144 px line holds about 28-30 characters against 18 now | `../ps3-translate/tools/vwfmixed.py` (MIT, the owner's) |

Prior art: Maxim's PSRP stays at 512 KB by recompressing the graphics, Huffman-codes the script
behind a word list, and keeps fixed-width menus. That is a lot of machinery for the space it
wins; the plan below expands the ROM instead, which the sibling projects' "nothing in the stock
image moves" rule makes cheap.

## 2. The architecture

* **A 1 MB ROM.** Banks 32-63 are new and empty (512 KB). The header stays as it is (its
  checksum covers the first 256 KB, which the export BIOS checks). The Sega mapper, Mesen,
  Emulicious, Genesis Plus GX and the Everdrive all take 1 MB.
* **Far calls through bank 0.** New code lives in a new bank paged into slot 2 (`$8000`). A few
  bank-0 stubs make that possible: `FarCall` (page the code bank, call, restore the caller's
  bank), `FarRead` (with interrupts off, page a data bank, read a byte, page the code bank back:
  how the new code reads text and font data in other banks), and `CallStock` (call a stock
  routine that pages slot 2 itself, such as the tilemap drawer `LABEL_3A57`, then page the code
  bank back). The stubs go in the unused RST slots and in the stock printer's own bytes, which
  the new printer replaces.

## 3. The options, in build order

| # | option | what it does | how it is checked |
|---|---|---|---|
| 1 | `expand_rom` | the ROM to 1 MB | `checkstock.py` at 0; at 1 the first 512 KB unchanged |
| 2 | `far_calls` | the bank-0 stubs | a test call from the harness |
| 3 | `relocate_script` | built: each text group moves whole to a bank of its own (dialogue 32, messages 33, cut-scenes 34), and the three printers page the bank of their own first label - same-size operand changes, no new code. The dictionary stays. A (bank, address) table per id comes later, only if the dialogue outgrows bank 32 | **milestone 1**: with the US text, every scenario's `--expect`, `--words` and `--known` pass unchanged - the engine proven before anything visible changes |
| 4 | `vwf_dialogue` | **built** (milestone 2). The dungeon audit took the plan's second line set away: a dungeon shows `$1B0-$1BF` (corridor floor, beside the window as well as under it) and `$B5-$BF`, so the only tiles free wherever the window can appear are the 20 at `$EC-$FF` (the title alone uses them; the JP, whose kana font filled `$C0-$FF`, proves the game's pictures avoid them). So each line owns 10 tiles: **80 px**, about 16-17 mixed-case characters - the stock line's count in characters, now proportional and mixed case. A new line takes the set the line above does not show; the stock scroll moves the nametable entries, so nothing is copied | the harness reads the window's tile pixels back and decodes them with the face; `forcetalk --expect` and `battle --known` pass on mixed-case lines |
| 5 | `vwf_cutscene` | the cut-scene printer proportional. The audit has room here: a cut-scene screen shows no menu, status or list, so the whole font area `$C0-$FF` (64 tiles) is free while one is up - 4 lines of 16 tiles, **128 px** a line. The font must come back when the cut-scene ends (the next map, dungeon or battle load reloads it: to verify) | `opening --expect` |
| 6 | `long_names` | party names to 6 letters (Alisa, Tyron): a new name table; the name boxes and status boxes are already 6 cells; the party menu widens from 4 cells to 6 | `menus`, `battle` with the new names |
| 7 | `long_item_names` | items and enemies from a new table, up to an agreed width: the inventory, shop list, battle name box and item-action windows widen and move, and their RAM save areas are re-planned so windows open together never overlap | a RAM-map audit first (which windows are open together); then `menus`, `shop`, `battle --words` |
| 8 | `menu_case` | mixed case in the menus (fixed width) | depends on decision C below |
| - | later | the naming screen with lower case (a new key grid and key table), the credits (the owner's call), the title screen | - |

Tooling with them: gentext's encoder for the new engine (plain bytes, the new character set,
`relocate_script`'s bank layout), `linecheck.py` in pixels (144 px dialogue lines, 160 px
cut-scene lines, names at their agreed widths), a `diafont.py` that builds the face's tiles and
width table from `vwfmixed.py`, `checkbuild.py` extended to the new banks, and later the
proofreader (`proofread.html`, as PS II's) drawing lines in the game's face.

## 4. Decisions for the owner

* **A. Expand to 1 MB** (recommended) **or stay at 512 KB** as PSRP does (graphics
  recompression and a compressed script: much more work for the same result).
* **B. Cut-scene text**: proportional like the dialogue if the per-picture audit finds the
  tiles (recommended), or a fixed-width mixed-case font there.
* **C. Menus**: (1) stay upper case, fixed width, as the US (cheapest; the dialogue is mixed
  case); (2) small capitals for lower case, if about 26 more tiles turn up (dungeon audit);
  (3) proportional menus (not recommended: an 8-name inventory alone needs 64 work tiles).
* **D. Name widths**: party 6 letters; items and enemies how wide - 12 cells (most full names
  fit, some abbreviated) or 16 (all fit, the windows cover more of the screen)?
* **E. The face**: reuse the PS IV / PS II / PS III dialogue face (recommended: the series reads
  the same, and it fits PS I's one-row lines as it stands).

## 5. Risks, and what is verified before each step

* **Dungeons** (done 2026-10-16): a dungeon shows 426 tiles, `$1B0-$1BF` and `$B5-$BF` among them; only `$EC-$FF` stays free. Hence 80 px lines (option 4).
* **The window RAM areas** (option 7): map which windows are open together before moving any.
* **Read-on strings**: four bank-12 strings are reached by the printer reading past a
  terminator; option 3 keeps them adjacent in their text bank, and `--known` / `--expect` check
  each.
* **Speed**: composing one proportional character must fit inside a frame (PS II's does on a
  68000; on the Z80 it is shifting 8 bytes into at most 2 tiles - small, but measured in the
  harness).
* **Compatibility**: a 1 MB SMS ROM on real hardware needs a flash cart (Everdrive); the
  emulators all take it. Worth saying in the release notes.

Milestone 1 (options 1-3) changes nothing on screen and proves the engine. The first visible
step is option 4.
