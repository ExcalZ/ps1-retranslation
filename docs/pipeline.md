# The build pipeline

The working reference for anyone changing text or engine code here. The current state and
checklist are in [`../work/STATUS.md`](../work/STATUS.md). Sections marked *planned* describe
the shape the PS II and PS III projects have and this one will follow; they are not built yet.

## 1. Shape of the build

There is no ROM patching. The game is assembled from source (`PSI_Disasm/ps1.asm` and
`banks/*.asm`) by WLA-DX, and the translation reaches the source through one generator,
`tools/gentext.py`, which writes the JSON into the assembly.
Engine changes are build options in `PSI_Disasm/ps1.options.asm` (section 6): with every
option at 0 and every `en` equal to its `us`, the ROM is byte-identical to the US/EU release
v3 (`checkstock.py`).

```
work/dialogue.json --gentext.py--> text/dialogue.asm (DialogueBlock + the blocks),
                                   text/cutscenes.asm, text/messages.asm: included where the
                                   stock had them (ps1.asm bank 2, sound/sound_driver.asm bank
                                   12), or in banks 32-34 with relocate_script (ext/banks.asm)
work/script.json   --gentext.py--> ps1.asm: CharacterNames, ItemNames
                                   banks/bank03.asm: the enemy names
                                   banks/bank27.asm, bank18.asm, ps1.asm: the tilemap text
                                   (naming screen, credits: read-only)
```

`tools/sourcebuild.py [out.sms] [--no-gen]` runs `gentext.py`, then
`wla-z80 -o ps1.o ps1.asm` and `wlalink -r -s link.txt ps1built.sms` in `PSI_Disasm/`
(the same steps as `build.bat`), fixes the SMS header checksum and copies the ROM
(default `ps1en.sms`). It writes `PSI_Disasm/ps1.log` when the assembler or the linker
fails; `-s` also writes `ps1built.sym`, WLA symbols that Mesen 2 imports.

**Assembler.** WLA-DX 10.7 (`$WLADX` or `wla_dx_v10.7_Win64/` in the repository root). The
disassembly ships a 2006 WLA-DX in `binaries/`; it is neither tracked nor used. 10.7 refuses a
label with the name of a `.define`, so 57 unreferenced dungeon-layout labels in
`banks/bank15.asm` were renamed `DungeonID_*` -> `DungeonLayout_*`; nothing else changed and
the output is bit-exact.

**Header checksum.** The SMS header is at `$7FF0` (`TMR SEGA`, checksum little-endian at
`$7FFA`, region and size at `$7FFF` = `$40`: export, 256 KB range). The export BIOS sums
`$0000-$7FEF` plus `$8000` to the end of that range; `sourcebuild.py` recomputes it
(verified on stock: `$EAD8`). Anything that grows past `$40000` is outside the checked range.

## 2. The ROMs

| file | what | size | CRC32 | SHA-1 |
|---|---|---|---|---|
| `PSI_Disasm/ps1original.sms` | US/EU release **v3** (header version 3, product 9500): what the disassembly reproduces; ships in the disassembly | 524,288 | `00BEF1D7` | `07fcf297...8e06838` |
| `work/ps1en_stock.sms` | the same US/EU v3, supplied by the owner (byte-identical to `ps1original.sms`) | 524,288 | `00BEF1D7` | `07fcf297...8e06838` |
| `work/ps1jp_stock.sms` | Japan, 1987 (header version 0, product 9500, checksum `$2C6B`, `$7FFF` = `$40`): the source of the JP script; the owner's dump | 524,288 | `6605D36A` | `c9a40ddd...0d3e68e4` |

All three are git-ignored (`*.SMS`). SHA-256: v3 `9e324e92bd833b45...`, JP
`1d8554202f313d97...`. The JP ROM differs from v3 in 67,697 bytes. Banks 0, 1, 2 and 12 differ
almost throughout (code moved, all the text rewritten). Banks 3 (`$869F-$BFFD`), 15, 16 (the
font), 18 (`$BE84-$BFBB`), 20 (credits, `$BDC6-$BFA6`) and 27 (menus, `$B41B-$BCE1`) differ in
part, and bank 14 in one byte. The other banks are identical, so graphics, maps and music
line up bank for bank. Section 3.12 maps the JP text against the US layout.

The US/EU v2 (`E4A65E79`) is the other export dump; whether the patch should also apply to it
(as PS II's patcher takes both US revisions) is open.

## 3. The stock text engine

Surveyed on the stock (US/EU v3) build from the source and `ps1built.sym`. Addresses are
`bank:addr` as in the symbol file. Banks 0 and 1 are fixed at `$0000-$7FFF`; every other bank
is paged into slot 2 (`$8000-$BFFF`) by writing `$FFFF`. ROM offset = bank x `$4000` + (addr -
`$8000`). Line numbers are `ps1.asm`'s unless a file is named. The figures (string counts,
bytes, free space) were measured on the built ROM.

### 3.1 Where the text is

| text | label, bank:addr | form |
|---|---|---|
| NPC dialogue | `DialogueBlock` 02:8000 (341 pointers); `Dialogue_Index_0002`-`02AA` 02:82AA-B49A | encoded strings, 12,785 bytes |
| intro and ending cut-scenes | `LABEL_B49B`-`LABEL_BA54` 02:B49B-BA80 | 23 encoded strings, no index, 1,510 bytes |
| dictionary | `DialogueWordBlock` 02:BA81 (128 pointers); `Dialogue_Word_Index_00`-`7F` 02:BB81-BF48 | `$65`-terminated words |
| system, battle, shop, item and ending messages | `LABEL_B12_B108`-`LABEL_B12_BFC4` 0C:B108-BFD7, in `sound/sound_driver.asm` (bank 12 is the sound bank) | 174 encoded strings (170 labels, 4 more follow a label unnamed), 3,792 bytes |
| party names | `CharacterNames` 00:31BB | 4 x 4 bytes |
| item names | `ItemNames` 01:7DA3 | 65 x 8 bytes |
| enemy names | `B03_EnemyData` 03:867F | bytes 0-7 of 75 x 32-byte records |
| spell names, menus, status labels | bank 27 `LABEL_B27_B40B`-`LABEL_B27_BD43` (1B:B40B-BD62); bank 0 `LABEL_3639`, `LABEL_3875`-`LABEL_38B1`, `LABEL_3AC4` | VDP tilemaps (3.7) |
| intro caption, spaceport menu | `LABEL_B18_BEF4` 12:BEF4, `LABEL_B18_BE84` 12:BE84 | tilemaps |
| naming screen | `LABEL_423C` 01:423C, `LABEL_4280` 01:4280 | RLE tilemap, key table (3.8) |
| staff credits | `LABEL_B20_BDB8` 14:BDB8-BFA6 | ASCII records (3.9) |
| save-RAM signature | `LABEL_807` 00:0807, "PHANTASY STAR ... NAKA YUJI" | not shown; it validates the save RAM, never translate it |

Free space after the text (all `$FF`): bank 2 `$BF49-$BFFF`, 183 bytes; bank 12
`$BFD8-$BFFF`, 40 bytes; bank 20 `$BFA7-$BFFF`, 89 bytes. The US script fills both text banks
to the brim with an abridged, dictionary-packed English, so the retranslation needs the
text-scheme engine option (STATUS Next 5) before it can be longer than the stock.

### 3.2 Encoding

One byte per character, the same in every printer.

* **`$20`-`$5A`** are ASCII-shaped. A character is one cell wide and two tile rows high. The
  glyph table `LABEL_7D17` 01:7D17 gives two tiles per code for `$20`-`$65` (70 pairs, upper
  row then lower row): `LABEL_33D6` 00:33D6 writes the upper tile at the cursor and the lower
  one 64 bytes (a row) below. In the US font every upper tile is blank (`$C0`) except `"`
  (`$22`: `$EB` above) and the apostrophe (`$27` and `$40`: the comma tile `$E5` above). The
  upper row is the JP font's dakuten row (3.12). Lower tiles: digits `$C1`-`$CA`, letters
  `$CB`-`$E4`, `,` `$E5`, `;` `$E6`, `.` `$E7`, `!` `$E8`, `?` `$E9`, `-` `$EA`.
* **Blank codes.** 13 codes print a space: `$23`-`$26`, `$28`-`$2B`, `$2F`, `$3A`, `$3C`-`$3E`.
  So there is no colon, slash or parenthesis, and no lower case. The script writes the
  apostrophe as `$40` (`Dialogue_Apostrophe`); `$27` shows the same glyph.
* **`$5B`-`$65`** are controls (below). `$66`-`$7F` act as `$65` in the dialogue printer
  (`cp $65 / jp nc`) and are never used.
* **`$80`-`$FF`** is dictionary word `n & $7F` (3.3).

Controls, as the dialogue window (`LABEL_31FA` 00:31FA) and the cut-scene printer
(`LABEL_337D` 00:337D) treat them. In the cut-scene printer `$5B`-`$5E`, `$62` and `$64` are
not handled and print blank; the stock never uses them there.

| byte | define | dialogue window | cut-scene printer |
|---|---|---|---|
| `$5B` | `Dialogue_CurrentCharacter` | the name of party member `CurrentCharacter` (`$C2C2` & 3) from `CharacterNames`: 4 characters, stops early at `$65` (`Display65TerminatedString` 00:336C) | - |
| `$5C` | `Dialogue_EnemyName` | `CurrentBattle_EnemyName` `$C2C8`, at most 8 characters, stops at `$65` | - |
| `$5D` | `Dialogue_CurrentItem` | `ItemNames` + 8 x `CurrentItem` (`$C2C4`), at most 8, stops at `$65` | - |
| `$5E` | `Dialogue_NumberFromC2C5` | the 16-bit value at `$C2C5` (`CurrentDialogueNumber` is a misnomer: it holds meseta amounts and prices) in decimal, 1-5 digits, no leading zeros (`LABEL_3292`, `LABEL_32FB`). The comment in `sound_driver.asm` says `$C525`; the code reads `$C2C5`. | - |
| `$5F` | none | redraw the empty window and go on at line 1 without waiting | clear the text rows without waiting and go on at line 1. Used once, at the start of `LABEL_BA54`. |
| `$60` | `Dialogue_NewLine` | go to line 2; if already there, scroll up a line first | next line (two tile rows down) |
| `$61` | `Dialogue_NewPage` | wait for button 1/2, then as `$60`: it **scrolls**, it does not clear | wait, then clear the text rows and start at line 1 (a real page) |
| `$62` | `Dialogue_Terminator62` | return at once with the window open (before a YES/NO menu or a follow-up string) | - |
| `$63` | `Dialogue_Terminator63` | wait up to 30 frames or a button, return (`LABEL_2D33`; the battle messages) | pause 208 frames, return (`LABEL_2D47`; the ending's names) |
| `$64` | `Dialogue_Terminator64` | pause 208 frames, return (the ending narration) | - |
| `$65` | `Dialogue_Terminator65` | wait for a button, return (`WaitForButton1Or2` 00:2D25) | the same |

`$65` also ends dictionary words and short name fields.

### 3.3 The dictionary

* 128 words, `Word_Alis` (`$80`) to `Word_Ould` (`$FF`) in `ps1.constants.asm`. The pointer
  table is `DialogueWordBlock` 02:BA81; the strings `Dialogue_Word_Index_00`-`7F` (02:BB81-BF48)
  each end in `$65`. They are 1-16 characters long, 840 in all.
* 17 words carry their own trailing space (`"THE "`, `"YOU "`, `"MAGIC "` ...), so the script
  writes `Word_You, "SHOULD"` with no space between. Some are fragments: `Word_Ould` is `"OULD"`
  (`"C", Word_Ould`). `Word_Magic_84` is `"MAGIC "` and `Word_Magic_EF` is `"MAGIC"`.
* **Expander.** `LABEL_333E` 00:333E doubles `n & $7F` into `DialogueWordBlock`. It pages in
  bank 2 (saving `$FFFF`), prints the word one character at a time through `LABEL_33D6`, and
  restores the bank. So words work in bank-12 strings too. A word holds no controls and no
  other word. After a word that fills the line, the wrap test (3.4) runs on the next byte.
* All 128 words are used in banks 2 and 12; the most frequent are THE (199), YOU (131), HAVE
  (45) and ARE (40). The table is the US's packing, not a property of the script, and a new
  scheme replaces it.

### 3.4 The dialogue window

* **Opening.** `ShowDialogue_B2` 01:575A (pages bank 2) and `ShowDialogue_B12` 00:31CF (pages
  bank 12) both enter `LABEL_31D4` 00:31D4. That saves the 6 x 20 cells under the window
  (VRAM `$7C8C`: row 18, column 6) to RAM `$DA18`, draws `LABEL_B27_B5EF`/`LABEL_B27_B619`
  and sets `$C2D3` = `$FF`. `LABEL_3464` 00:3464 restores the screen and clears `$C2D3`. If
  the window is already open, the next string goes on in it on a new line (`LABEL_31CB`).
* **Lines.** Two text lines of **18 cells**: line 1 at VRAM `$7CCE` (rows 19-20, columns
  7-24), line 2 at `$7D4E` (rows 21-22). One character is drawn per frame.
* **Auto-wrap at 18.** When the 18th cell is filled (`LABEL_33D6`, then `LABEL_3419`), the
  printer looks at the next byte. If it is printable (`< $5F`) or a word, the printer moves to
  line 2 (scrolling if needed), at any byte, even mid-word. If it is a control, nothing extra
  happens, so a full line followed by `$60` does not leave a blank line. The US script relies
  on this: 57 source lines in bank 2 and 27 in bank 12 are longer than 18 and break only by
  the wrap. For example `Dialogue_Index_0086` has `"MOTAVIA'S GOVERNORAND LASSIC ARE NOT"`,
  which shows as "MOTAVIA'S GOVERNOR" / "AND LASSIC ARE NOT". **An extractor must render the
  18-column wrap to get the displayed lines; `gentext.py` should write explicit `$60`s.**
* **Scrolling.** `LABEL_342C` 00:342C calls `LABEL_3439` twice; each call moves the interior
  up one tile row and pauses 4 frames, so a text line scrolls off the top. Line 1 is only used
  for a string's first line; after that every line arrives at line 2. Budget: 18 x 2 per
  screen, any number of screens.

### 3.5 Dialogue blocks, script ids and flags

* **Ids.** `ShowDialogue_B2` takes an id in `hl` and reads the pointer at `DialogueBlock - 2 +
  id`. So ids are even, `$0002`-`$02AA`, and `Dialogue_Index_NNNN` is id `NNNN`. All 278 call
  sites (85 `call`, 193 `jp`) load the id as a literal (`ld hl, $0146` / `call
  ShowDialogue_B2`).
* **Labels.** Bank-12 strings are reached by label (`ld hl, LABEL_B12_xxxx` / `call
  ShowDialogue_B12`, 202 sites with `call`, `call c`/`nz` and `jp`), and the cut-scene strings
  by label through `LABEL_337D` (23 sites).
  Neither has an id table, so the extractor keys them by label.
* **Chains.** A block is an entry point, not always a whole utterance. 68 of the 341 blocks
  have no terminator and run on into the next one: 51 end in `$61`, 14 in `$60`, and three
  stop mid-sentence (`Dialogue_Index_015C`, `01B2`, `01C0`). For example `Dialogue_Index_0002`
  ("I'M SUELO ...") plays on through `0004`, and a later visit starts at `0006`. Text plays
  from the entry label to the first terminator. The extractor must keep the chains in label
  order, and `gentext.py` must keep every label at the start of its block. The blocks that do
  end end in `$65` (233), `$62` (39) or `$63` (1). The 23 cut-scene strings all end in a
  terminator.
* **Who plays which.** A person or object on a town map carries a talk id from the map object
  data in bank 3. `LABEL_6A2F` 01:6A2F stores it in `$C2DB`, with the background scene in
  `$C2DC`. `LABEL_474B` 01:474B jumps through the 181-entry handler table `LABEL_4773`
  01:4773 (`LABEL_48DF` ...). Each handler is code: it tests and sets bytes of the flag page
  and calls `ShowDialogue_B2` with literal ids. For example, `LABEL_48DF` checks `$C501`: on
  the first visit it sets the byte and shows `$0002`; it always shows `$0006`. So which text
  plays when lives in these handlers, not in data, and the translation does not change it.
* **Flags (`Dialogue_flags`, `$C500`).** The handlers name `$C501`-`$C518` directly. Dungeon
  objects (`B03_ObjectData`) each point to a byte of this page. `LABEL_698E` 01:698E skips an
  object whose byte is `$FF`, and `LABEL_28EE` 00:28EE writes `$FF` once its chest is opened
  or its fight is won; that is the constants file's "if value is `$FF`, dialogue is not
  loaded". `Event_flags` (`$C600`) is a separate page.

### 3.6 Name fields

* **Party.** `CharacterNames` 00:31BB: "ALIS", "MYAU", "ODIN", "NOAH", 4 bytes each with no
  terminator, printed by `$5B`. The names also appear as dictionary words (`Word_Alis`,
  `Word_Myau`), baked into tilemaps (`LABEL_B27_B40B`, `LABEL_B27_B4AB`-`LABEL_B27_B53B`,
  `LABEL_B27_BB1F`) and spelled out in the script ("ODIN", "NOAH"). A rename touches all four.
* **Items.** `ItemNames` 01:7DA3: 65 fields of 8 bytes (`ItemID_Nothing` blank to
  `ItemID_Secrets` `$40`), US abbreviations ("SHT. SWD", "MAGC HAT"). A shorter name ends in
  `$65` and is padded with spaces to 8. `ItemData` 01:7FAB follows directly, so the width is
  fixed by layout. The names are printed by `$5D` (which stops at `$65`) and as exactly 8 cells
  in the inventory (line 7601) and shop (line 8117) windows. Those loops print every byte
  through the glyph table, whose `$65` pair is blank.
* **Enemies.** `B03_EnemyData` 03:867F: 75 records of 32 bytes (`Enemy_None` `$00` to
  Saccubus `$4A`). The name is bytes 0-7, `$65`-terminated if shorter (layout in the comment
  above the label). Line 13016 copies it to `CurrentBattle_EnemyName` `$C2C8` (8 bytes), and
  it is printed by `$5C` and in the battle name box. That box is drawn by `LABEL_3105`
  00:3105 at VRAM `$781C` (row 0, column 14), 10 cells wide, with the name as exactly 8 bytes
  through `LABEL_315C`, upper and lower rows.
* **Spells.** There is no string table. The names exist only as 4-cell entries in the spell
  lists `LABEL_B27_B6DF` 1B:B6DF. That is six tilemaps of 144 bytes (12 rows x 6 cells, five
  slots), selected by `LABEL_3478` 00:3478: list = character (Noah's 3 becomes 2), plus 3 for
  field magic. The window shows 2n+1 rows for n known spells and closes with
  `LABEL_B27_BA3F`. Contents in slot order: battle, Alis HEAL BYE CHAT FIRE ROPE; Myau CURE
  TERR WALL HELP; Noah FIRE TELE WIND PROT THUN. Field: Alis HEAL FLY; Myau CURE TRAP EXIT;
  Noah CURE EXIT TELE OPEN RISE. The `MagicID_*` defines are the internal order. A spell name
  in the script would be plain text.

### 3.7 Menus and windows

Every menu is a prebuilt VDP tilemap of (tile, attribute) pairs. Attribute `$10` marks a
text cell (priority bit). `$11`/`$13`/`$15`/`$17` mark the frame tiles `$1F1`-`$1F3` with
their flips. A menu word is therefore stored as glyph-table lower tiles (one cell per
letter, the upper row is not used), not as text. `gentext.py` must encode menus through the
glyph table, and a menu cannot hold a character the font lacks.

The maps are drawn by `LABEL_3A57` 00:3A57 (pages bank 27), `LABEL_3A68` (current bank) and
`LABEL_3A83`, with `b` rows of `c` bytes. The screen underneath is saved first by
`LABEL_3AA6`. The VRAM nametable is at `$3800` (`$7800` with the write bit), 32 cells x 2
bytes a row. In the table, rows x cells include the frame.

| tilemap | content | VRAM, row, column | rows x cells |
|---|---|---|---|
| `LABEL_B27_B56B` | battle commands ATTK MAGC ITEM TALK RUN (4 cells) | `$7842` r1 c1 | 11 x 6 |
| `LABEL_B27_BB8B` | field commands STAS MAGC ITEM SRCH SAVE (4) | `$7842` r1 c1 | 11 x 6 |
| `LABEL_B27_BB1F` + `BB7F` | party member select ALIS MYAU ODIN NOAH (4) | `$7A54` r9 c10 | 9 x 6 |
| `LABEL_B27_B40B` | four name boxes ALIS ... NOAH, 36 bytes each | `$7B02` r12 c1 | 3 x 6 each |
| `LABEL_B27_B4AB`, `B4DB`, `B50B`, `B53B` + `B49B` | battle status boxes " ALIS " ... (6 cells) | `$7C80`/`$7C90`/`$7CA0`/`$7CB0` r18 c0/8/16/24 | 3 x 8 each |
| `LABEL_B27_B6DF` + `BA3F` | spell lists (3.6) | `$7A0C` r8 c6 | 12 x 6 |
| `LABEL_B27_BC0F` | item actions USE EQP DRP (3) | `$7A32` r8 c25 | 7 x 5 |
| `LABEL_B27_BC55` | shop BUY SELL (4) | `$7B48` r13 c4 | 5 x 6 |
| `LABEL_B27_BC91` | YES NO (3) | `$7B6A` r13 c21 | 5 x 5 |
| `LABEL_B27_BACF` + `BAE3`, `BAF7` | inventory (`LABEL_352D`): the money line, 8-cell item names, and a "NEXT" row from 9 items | `$78AC` r2 c22 | up to 21 x 10 |
| `LABEL_B27_BACF` + `BAE3` | battle enemy name (3.6) | `$781C` r0 c14 | 4 x 10 |
| `LABEL_B27_BD23` + `BD43` | shop list: item name and price | `$780C` r0 c6 | 8 x 16 |
| `LABEL_B27_BCC3`-`BD0B`; bank 0 `LABEL_3881`-`LABEL_38B1` | status: ATTACK, DEFENSE, MAX HP, MAX MP (7-cell labels) and the values | `$7920` r4 c16 | 14 x 12 |
| bank 0 `LABEL_3639` (via `LABEL_35C4`) | "MST", the meseta label (3 cells) and the amount | money box (`LABEL_39F7`) `$782C` r0 c22 | 3 x 10 |
| bank 0 `LABEL_3875` | "EP" in the special tiles `$1F7` `$1F5` (3.10) | status window | - |
| `LABEL_B27_B5EF` + `B619` | dialogue window (3.4) | `$7C8C` r18 c6 | 6 x 20 |
| `LABEL_B18_BE84` 12:BE84 (via `LABEL_3A21` 00:3A21) | spaceport destinations GOTHIC UZO SKURE (6) | `$7AE4` r11 c18 | 7 x 8 |
| bank 0 `LABEL_3AC4` | save-slot list, slots 1-5. It is copied to SRAM `$8100` when the save RAM is formatted and drawn from there. | `$786E` r1 c23 | 12 x 9 |

No title-menu text was found in any text or tilemap form; the title screen's words are
presumably in its graphics (`LABEL_B29_87B8`). To be confirmed in Mesen's tile viewer.

### 3.8 The naming screen

`LABEL_4166` 01:4166 unpacks `LABEL_423C` 01:423C into RAM `$D100`. The format is:
`$00` ends; `$01`-`$7F` repeats the next byte n times; `$80`-`$BF` writes n tiles counting up
from the next byte, each followed by a blank cell; `$C0`-`$FF` copies n literal tiles. The
result is "INPUT YOUR NAME.", the key grid A-K / L-V / W-Z , ; . ! ? - (with the upper-row `"`
of the `"` key) and "ADV RUB END". `LABEL_4280` 01:4280 is the 4 x 11 key table: the codes a
key enters (ASCII letters and punctuation) and `$5C`/`$5D`/`$5E` for ADV/RUB/END, which here
are key commands, not text controls. The name labels a save slot. New keys or lower case mean
a new grid and a new key table.

### 3.9 Intro and ending

* **Cut-scene printer.** `LABEL_337D` 00:337D (bank 2) writes from VRAM `$7C0C` (column 6)
  into text rows 16-23: 4 lines of two tile rows each. `$60` moves down a line. There is
  **no auto-wrap and no width check**. The stock lines are at most 18 cells, under a picture
  12 x 20 cells drawn by `LABEL_46D1` at `$78CC` (row 3, columns 6-25). Each scene is
  `ld a, picture` / `call LABEL_46D1` / `ld hl, string` / `call LABEL_337D`.
* **Intro (lines 9353-9497).** First the caption `LABEL_B18_BEF4` 12:BEF4, a 5 x 20 tilemap
  at `$7886` (row 2, column 3): "SPACE CENTURY 342," / "CAMINEET ON PALMA" (18 cells a
  line). Then `LABEL_B49B` (the soldier), `B4FC` (Nero) and `B5D5` (Alis), followed by the
  recruiting scenes: `B617`-`B6C1` Myau, `B6F3`-`B7D1` Odin, `B85C`/`B884` the governor's
  letter, `B929`/`B97C` Myau's transformation.
* **Ending (`LABEL_454E` 01:454E).** It opens with `ShowDialogue_B12` of `LABEL_B12_BEB6`,
  `BED0`, `BEE8`, `BEFD`, `BF09` and `BF21`, each ending in `$64` (a timed page in the
  dialogue window). Then come the cut-scene strings `LABEL_B9E8`, `B9F0`, `B9FB` and `BA06`
  (`$60`, five spaces, then ALIS / ODIN / NOAH / AND MYAU, each `$63`-timed), then
  `LABEL_BA12` and `LABEL_BA54` (which starts with `$5F`). Then the credits.
* **Credits.** `LABEL_B20_BDB8` 14:BDB8 holds 16 pointers. 0 and 1 are unused; `LABEL_6E04`
  01:6E04 steps `$C2F5` from 2 to 15, giving 14 screens. Each screen is a count followed by
  records of (an address in the `$D000` nametable buffer, a length, ASCII). Bytes below `$40`
  (the space) are skipped; letters add `$80` and become tiles `$C1`-`$DA` of the credits font
  `LABEL_B15_BDEE` 0F:BDEE (26 tiles, A-Z only), loaded at `$5820`. The joypad script
  `LABEL_B15_BF80` walks the party through the credits dungeon meanwhile. Content: section
  titles (STAFF, TOTAL PLANNING, SCENARIO WRITER ... PRESENTED BY) and staff handles (OSSALE
  KOHTA, MUUUU YUJI, ...); whether to touch them is the owner's call. 89 bytes free after.

### 3.10 The font and free glyphs

* **Text font.** `LABEL_B16_BAD8` 10:BAD8 (640 bytes compressed) unpacks to 44 tiles at VRAM
  `$1800`, tiles `$C0`-`$EB`: blank, 0-9, A-Z, `, ; . ! ? - "` (3.2). It is reloaded with the
  map, dungeon and battle screens (lines 1134, 2112, 8523, 9341, 9691).
* **Compression.** `LABEL_3FA` 00:03FA unpacks the tiles. The four bitplanes are stored one
  after another, each a run list written to every 4th VRAM byte. A run byte n: `$00` ends
  the plane; with bit 7 clear the next byte is repeated n & `$7F` times; with bit 7 set, n &
  `$7F` literal bytes follow. A new font must be packed this way or loaded by new code.
* **Window tiles.** `LABEL_B16_BD58` 10:BD58 unpacks to 12 tiles at `$3E00`, tiles
  `$1F0`-`$1FB`: the cursor, corner, horizontal and vertical frame pieces (flipped by the
  attribute), the letters H P M E, two half blocks, and L V for the HP / MP / EP / LV labels.
* **Free.** In the glyph table, the 13 blank codes (3.2) are the spare character codes. In
  VRAM, no compressed load in the stock code targets tiles `$EC`-`$FF` (`$1D80`-`$1FFF`,
  **20 tiles**): that is room for new glyphs without moving anything. This comes from a scan
  of every `LABEL_3FA` call; confirm it in Mesen's tile viewer in a town, a dungeon and a
  battle. The full-screen pictures that overwrite tiles `$000`-`$19C` reload the font
  afterwards. The JP font fills `$C0`-`$FF` (64 tiles, 3.12), so this range was font space
  from the start. A lower-case set (26) does not fit in either; it is engine-option work.

### 3.11 What the extractor needs, in short

* **Script by id:** the 341 `Dialogue_Index_*` labels in order, each from its label to the
  next label, decoded through the controls and the dictionary. Record the chains (3.5) and
  the displayed lines at 18 columns (3.4).
* **Bank 12 and the cut-scenes:** keyed by label. The bank-12 label names match their
  addresses. The 4 strings with no label of their own follow the end of the previous label's
  string (0C:B17E, B346, B7A0, B99A); key them by address. Take addresses from
  `ps1built.sym`.
* **Fixed fields:** party 4, items 8, enemies 8 (+24 bytes of stats), spells 4 (in
  tilemaps), menu words 3-7 cells (3.7). The credits are ASCII.
* **Do not split on these labels:** `LABEL_B18_BF20`, `LABEL_B18_BF50` and `LABEL_B18_BF80`
  fall inside the intro-caption tilemap. Code with another bank paged in uses them as
  addresses (lines 12846, 12884), which is harmless as long as nothing moves.
* **Japanese:** decoded from `work/ps1jp_stock.sms` by the layout in 3.12. Maxim's JP
  disassembly and `.tbl` files are a cross-check only.

### 3.12 The Japanese ROM, compared

Read from `work/ps1jp_stock.sms`. There are no labels: addresses are JP `bank:addr`, found by
code signatures of the US routines. All JP text sits in **bank 2**. The US moved the battle
and system messages to bank 12, and the item names and the glyph table to bank 1, to make
room.

| | JP | US |
|---|---|---|
| glyph table | 02:8000-80B1, 89 pairs for codes `$00`-`$58`, read with bank 2 paged | `LABEL_7D17` 01:7D17, 70 pairs (`$20`-`$65`), any bank |
| `DialogueBlock` | 02:80B2, 341 pointers, the same ids (`ShowDialogue` 01:59BA reads `$80B0` + id) | 02:8000 |
| dialogue blocks | 02:835C-AB1E, 10,179 bytes | 02:82AA-B49A, 12,785 bytes |
| battle and system messages | 02:AB1F-B8BE, 171 strings | bank 12, 174 strings |
| cut-scene strings | 02:B8BF-BD93, 22 strings (printer 00:34A5) | 02:B49B-BA80, 23 (`LABEL_337D`) |
| item names | 02:BD94, 65 x 8; then `ItemData` at 02:BF9C | `ItemNames` 01:7DA3; `ItemData` 01:7FAB |
| dictionary | none | 128 words, bank 2 |
| party names | 00:3326, 4 x 4: アリサ, ミャウ, タイロン, ルツ | `CharacterNames` 00:31BB |
| enemy names | bank 3, the same 32-byte records at 03:867F, 8 kana | the same, ASCII |
| font | `LABEL_B16_BAD8` 10:BAD8 (the same label, 998 bytes packed), 64 tiles `$C0`-`$FF` | 44 tiles `$C0`-`$EB` |
| menus, spell lists | bank 27, the same tilemaps and window sizes, kana | bank 27 |
| intro caption | 03:BF02 tilemap, 5 x 15 cells at `$7886` | `LABEL_B18_BEF4`, 5 x 20 |
| credits | `LABEL_B20_BDB8`, the same format and staff, a few screens moved | the same |
| free at end of bank 2 | 36 bytes from `$BFDC` | 183 bytes |

* **Encoding.** One byte per kana, katakana only:
  * `$00` space;
  * `$01`-`$32` ア イ ウ エ オ カ ... ワ ヲ ン ッ ャ ュ ョ (gojuon order, tiles `$CB`-`$FC`);
  * `$33`-`$46` ガ ... ド, バ ... ボ: the base kana's tile below and the dakuten tile `$FD`
    above;
  * `$47`-`$4B` パ ... ポ: handakuten `$FE` above;
  * `$4C` 。 (tile `$FE` in the lower row, attribute `$12`), `$4D` ー (`$FF`);
  * `$4E` ァ, lower tile `$A4` (outside the 64 font tiles), used once: ダークファルス.

  Digits are written by the number printer as tiles `$C1`-`$CA`, as in the US. There is no
  dictionary: no high-bit test in the printer.
* **Controls**, in the US order: `$4F` character name, `$50` enemy, `$51` item (8 bytes from
  02:BD94), `$52` number, `$53` clear the window, `$54` new line, `$55` new page, `$56` end
  without waiting, `$57` timed end, `$58` (and anything above) end after a button. So JP
  `$4F`-`$58` correspond to US `$5B`-`$63` and `$65`. JP has no counterpart of `$64`. Short
  name fields end in `$58`.
* **Window.** The JP printer (00:333A) uses the same window, the same 18-cell lines, the same
  wrap rule (no wrap when the next byte is `>= $53`) and the same scroll.
* **Cut-scenes.** The JP cut-scene printer (00:34A5) starts at the same VRAM `$7C0C`
  (column 6) with no auto-wrap, and its lines run to **20 cells** (columns 6-25, the
  picture's width); the US kept to 18. The budget is 20.
* **Alignment.** The ids line up one for one. JP id `$0002` is Suelo's line (ワタシハ スエロ。...),
  as in the US, and the same 68 blocks run on into the next. The messages and cut-scenes are
  in the same order as the US's bank 12 and bank 2 strings. The last message is ココロガ
  ナゴムヨウナ / ウツクシイ ネイロダ, the US's "THE SOUND IS HEARTWARMING.". The counts differ
  slightly (171 vs 174, 22 vs 23), so align those two by order and content, not index.
* **Menus.** JP menu words use both tile rows (マジック is シ with ゛ above). The US reuses the
  same tilemaps and leaves the upper row blank.
* **Messages and cut-scenes, paired** (`work/pairing.json`): US message n is JP n up to 105;
  the US split JP 105 (the hospital's "sorry") over two strings and so runs one ahead from
  107 to 158; JP 158, "wrong password", has no US string (`jp_only` in `dialogue.json`); from
  159 they pair again; the US split each of the three ending-narration strings (JP 165-167)
  in two `$64` pages; the last three pair one for one. The 23rd US cut-scene string continues
  the JP's 22nd.
* **Spaceport (placed).** The JP menu is an 8 x 5 map at 03:BEB2 (ガシコ ウーゾ スクレ), drawn at
  `$7AAA` by JP code that pages bank 3; JP bank 18 is `$FF` at `$BE84-$BFBB`. Other JP tilemaps:
  status labels 00:399E-39CE, meseta 00:3756, save slots 00:3BE8, naming screen 01:4406 (RLE
  with consecutive tiles, unpacker 01:42DA), intro-caption kanji tiles from 10:BF5E.

## 4. The script files and the generator

**Extraction** (`tools/extract_text.py`, done once on the stock build; it refuses to overwrite
the JSON without `--force`, which would drop the translation). It reads the US text from the
source (`tools/textsrc.py`: the two regions, split after each end code), checks every string
against the stock ROM at its symbol address, decodes the JP from `work/ps1jp_stock.sms`, pairs
them (dialogue by id, the rest by `work/pairing.json`) and writes:

* `work/dialogue.json`: 538 entries (341 `dialogue` by id `0002`-`02AA`, 174 `message` by
  label, 23 `cutscene` by label), each with `kind`, `label` (null for the four strings the
  game reaches by reading on: their id is `LABEL.1`), `addr`, `hex` (the stock bytes), `us`,
  `jp`, `jp_addr`, `en`; `falls_through` on the 69 with no end code, `jp_cont` on the 5 whose
  JP is part of the entry before. `jp_only`: the JP strings with no US string.
* `work/script.json`: `segments` `party` (4, width 4), `items` (65, width 8) and `enemies` (74,
  width 8, with the record label), each run `id`, `hex`, `us`, `jp`, `en`.

* `work/script.json` also holds the **tilemap segments** (`tools/tilemaps.py`, added by
  `extract_text.py --tilemaps`): `name_boxes`, `status_boxes`, `battle_menu`, `spells` (30),
  `inventory`, `party_menu`, `field_menu`, `item_menu`, `shop_menu`, `yes_no`,
  `status_labels`, `money`, `save_slots`, `spaceport`, `intro_caption` (kind `tilemap`, 75
  runs), and `naming_screen` and `credits` (kind `readonly`: `us`/`jp` only). A tilemap run has
  `label`, `offset` (bytes into the map), `cells`, `upper` (it owns the row above, where JP
  dakuten and the US `"`/apostrophe tops go), `addr`, `hex`, `upper_hex`, `jp_addr`,
  `jp_cells`, `jp_upper`, `us`, `jp`, `en`, `where`. One character a cell, leading spaces kept.
  gentext writes each run through the glyph table `LABEL_7D17` into the map's `.db` lines,
  only where bytes change; en = us keeps the stock bytes. linecheck checks glyphs, cells and
  upper rows, and that the party names in the menus match the party table.

**The text form** (`tools/ps1text.py`): `{BR}` new line, `{PAGE}` wait then new line (the
window scrolls; a cut-scene clears), `{CLR}` clear, `{NAME}` `{ENEMY}` `{ITEM}` `{NUMBER}`
inserts, end codes `{END}` (after a button), `{NOWAIT}` (window stays open: a YES/NO or another
string follows), `{TIMED}` (a short wait; in a cut-scene 208 frames), `{PAUSE}` (208 frames,
the ending), `{$xx}` any other byte. `us` and `jp` are rendered as the window shows them: the
18-cell auto-wrap is written as an explicit `{BR}` (so "GOVERNORAND" reads "GOVERNOR{BR}AND"),
and the dictionary words are spelled out. JP spaces are U+3000.

**Generation** (`tools/gentext.py`). The script is written whole into three files,
`PSI_Disasm/text/dialogue.asm` (`DialogueBlock`, the 341 pointers in id order, then the blocks),
`cutscenes.asm` and `messages.asm`, one label per entry in JSON order (an unlabelled entry
follows its predecessor, with a comment naming its id); `ps1.asm`, `sound/sound_driver.asm` and
`ext/banks.asm` include them, each under `relocate_script` (section 6). The
name fields are rewritten line by line where the bytes change, padded with `$65` and spaces.
An `en` equal to its `us` is written from `hex`; any other is encoded for the stock engine
(`encode_us`: upper case and the font's punctuation, the 128 words packed greedily, explicit
`$60`s). `--check` fails if a file would change; `--encode-all` encodes the stock entries too.
Encoded that way the whole stock script takes 14,221 bytes in bank 2 (stock 14,295) and 3,811
in bank 12 (stock 3,796), and the build moves nothing: the encoder fits the stock engine.

## 5. Verification

* `python tools/checkstock.py` - options at 0 and en = us: byte-identical to v3.
* `python tools/checkbuild.py` - "nothing moved": every label outside the two text regions
  (02:82AA-BFFF, 0C:B108-BFFF) at its stock address (`work/stock_labels.json`, 2,008 labels;
  `--snapshot` rewrites it, on a stock build only).
* `python tools/gentext.py --check` - must rewrite nothing after a build.
* `python tools/linecheck.py` - each changed `en`: encodable, 18 cells a line (cut-scenes 20,
  4 lines a page), inserts at their widest, the stock end code; name widths; and the bytes
  used in banks 2 and 12 against the room (stock + 183 / + 40). `--all` checks the stock
  text too (one stock line fails only because `{NUMBER}` is counted at 5 digits).
* `python tools/test_text.py` - the JP glyph table, every `hex` against the ROM, `us` and `jp`
  re-rendered from both ROMs, the encoder's round trip on every entry, the name tables.

## 6. Engine options (`PSI_Disasm/ps1.options.asm`)

Each is a `.define NAME 0|1` tested with `.IF`; hooks are the exact size of the stock code they
replace; new code and data go in `PSI_Disasm/ext/`. The plan for the rest is
[`engine-plan.md`](engine-plan.md). All three below are on in the working build.

| option | what it does | where |
|---|---|---|
| `expand_rom` | a 1 MB ROM: the bank map grows to 64 banks; banks 32-63 are new (`$FF` where unused). The first 512 KB stay the stock ROM; the header is unchanged (its checksum covers the first 256 KB) | `ps1.asm` (the bank map), `ext/banks.asm` |
| `far_calls` | `FarCall` (call the routine at `hl` in bank `a` through slot 2, then page the caller's bank back; 22 bytes) and `FarRead` (`a` = the byte at `hl` in bank `a`; 18 bytes) in the unused RST slots `$10-$37`, exactly 40 bytes, so the interrupt handler stays at `$38`. A self-test routine in bank 63; `work/scripts/farcall.lua` runs both at runtime (the CPU is sent into each stub at a `WaitForVInt` call and checked when it comes back). Not yet used by the game: the proportional printer will be its first caller | `ps1.asm` (bank 0), `ext/banks.asm` |
| `vwf_dialogue` | the dialogue window in the series' proportional face, mixed case, **80 px a line** (10 tiles; off in the working build until the translation fills the window: the stock upper-case lines are wider and would clip). `LABEL_33D6`'s first 4 bytes jump to `VwfGate`, which sits with a new `{NUMBER}` call in the stock number printer's 160 bytes (`LABEL_3292`-`LABEL_3331`): a character for the window's text rows (the cell `de` on row 19 or 21) goes through `FarCall` to `VwfChar` in bank 35, any other (the cut-scene printer, the lists) to the stock code. `VwfChar` composes the glyph into the tile under the pen and the next (1 bpp in RAM, uploaded as the stock font draws: plane 0 background, plane 1 ink) and gives each new line a set of 10 tiles - `$EC-$F5` or `$F6-$FF`, the one the line above does not show (the stock scroll moves the nametable entries, so the old line keeps its tiles). The stock still does the controls, waits, scroll, inserts and dictionary words; the line state `b` ($12 at a new line, then $11) keeps its 18-cell wrap from firing. The printer ends only on `$65` (`jp z` for `jp nc`), so `$66-$7F` are a-z. RAM `$DF00-$DF1F` (`ext/vwf_ram.asm`; the stock never touches `$DE96-$DFFB`). The face: `tools/diafont.py` from `tools/vwfmixed.py` writes `ext/vwffont.asm` on every build | `ps1.asm`, `ext/vwf.asm`, `ext/vwf_ram.asm`, `ext/vwffont.asm` |
| `vwf_cutscene` | the cut-scenes in the face, mixed case, 4 lines of **120 px** (needs `vwf_dialogue`; off with it). A cut-scene screen shows no menu or list, so the font area is free while one is up: line k owns 15 tiles from `$C1 + 15k` (`$C0` stays blank). `VwfGate` sends rows 16-23 to `VwfChar`, which tells the window's rows (19, 21: bit 6 of `e`) from the cut-scene's (16, 18, 20, 22); the cut-scene printer zeroes `bc` at its entry, at a new line and after a page, so `b` = 0 starts a line. `VwfCutDirty` then has the stock font reloaded (`LABEL_3FA` of `LABEL_B16_BAD8`) when the next fade-out ends (`LABEL_7B0B` calls `VwfFadeWait` for its frame wait) or, failing a fade, before the next tilemap is drawn (`LABEL_3A57` and `LABEL_3A83` call `VwfMenuFont` first). All of it fits the number printer's 160 bytes (to `$3308`) | `ps1.asm`, `ext/vwf.asm` |
| `long_names` | party names up to 6 letters (needs `vwf_dialogue`). `{NAME}` (`LABEL_3244`) calls `VwfName` in bank 35, which draws the name from `LongNames` (6 bytes each, the face's codes) - mixed case, "Alisa". The battle's name box (`LABEL_2EAC`, restore `LABEL_2ECD`) and the party menu (`LABEL_369F`, at `$7A44` with restore `LABEL_36BB`, at `$7A54` with restore `LABEL_36CC`) are 8 cells wide: their maps (`LongNameBoxes`, `LongPartyRows`, `LongPartyEnd`) are bank 27's two cells wider, written by gentext into `ext/longnames_data.asm` with the names in capitals for the fixed font, and drawn from bank 35 with `LABEL_3A68`. The callers still save the 6 stock columns in the stock buffers (`$D700`, `$DDA8`, `$DE14`); the 2 new columns go to `LongBoxExtra` / `LongPartyExtraA` / `LongPartyExtraB` (`$DEA0-$DEF3`, `ext/vwf_ram.asm`). Each patched routine is padded with `.ORGA` to the next stock label. `CharacterNames` and the stock 4-cell maps keep their stock bytes (unused). The status boxes already have 6 cells: their `status_boxes` runs must show the party names in capitals (`linecheck.py`) | `ps1.asm`, `ext/longnames.asm`, `ext/longnames_data.asm` |
| `relocate_script` | the dialogue (with `DialogueBlock`) to bank 32, the messages to bank 33, the cut-scenes to bank 34, a whole bank each. The three printers page the bank of their own text: `ShowDialogue_B2` `ld a, :DialogueBlock`, `ShowDialogue_B12` `ld a, :LABEL_B12_B108`, the cut-scene printer `LABEL_337D` `ld a, :LABEL_B49B` - the stock bytes (2, 12, 2) when the text stays, so the code needs no `.IF`. The dictionary stays in bank 2 (the word expander still pages bank 2) | `ps1.asm`, `sound/sound_driver.asm`, `ext/banks.asm` |

Room with `relocate_script`: dialogue 15,702 bytes (12,785 stock), messages 16,384 (3,796), cut-scenes
16,384 (1,510). The dialogue bank is the tight one: an English from the Japanese may outgrow it,
and splitting it over two banks needs a bank per id (a job for the far calls).

**The tiles**: `work/scripts/vramaudit.lua` records the tiles every screen shows (town, menus,
a conversation, a shop, battles with small and large monsters, a dungeon with its menu and a
battle, the intro) and the RAM the CPU never touches. Free everywhere the dialogue window can
appear: only `$EC-$FF` (the title screen uses them; the JP's kana font filled `$C0-$FF` on every
text screen). A dungeon shows `$1B0-$1BF` and `$B5-$BF`; battles `$100-$19F`.

**Seeing them**: `python tools/trybuild.py EDITS.json OUT.sms --option vwf_dialogue=1 --option
vwf_cutscene=1`,
then any scenario with `--rom=OUT.sms --dialogue=OUT.sms.dialogue.json`. On 2026-10-16 Suelo's
conversation in mixed case (7 of 7 window pages) and a battle's messages with `{ENEMY}` and
`{NUMBER}` (10 of 10 lines) read back exactly; opening, menus, shop, save / continue and the far
calls passed on the same build (the cut-scenes and lists keep the stock font). With
`vwf_cutscene` too: the intro's three cut-scenes in mixed case, 120 px lines (8 of 8 pages), the
font back on the field, and every scenario passing. With `long_names` (party Alisa, Myau,
Tyron, Lutz): the party menu in both places, the name box at each battle turn, the status boxes
and "Alisa died." all show the new names, and every window restores the screen under it.

Every scenario passes on the relocated build with the same checks as on the stock game
(2026-10-16): opening, talk, forcetalk (`--expect`), menus (`--words`), save / continue, both
shops, both battles (`--known`), and an edited line and menu word (`trybuild`). Not exercised
by any scenario yet: the ending's strings and two of the four read-on messages.

## 7. Emulator harness

Mesen 2.1.1 (`Mesen_2.1.1/`, git-ignored, or `$MESEN`), driven by `tools/ps1emu.py`:

```bash
python tools/ps1emu.py opening --expect=B49B,B4FC,B5D5
```

* **How it runs.** The runner writes one Lua file to `work/analysis/run/`: a `PS1` table (run
  name, output folder, frame cap, every bank 0/1 label of `ps1built.sym`, the `key=value`
  params; `PS1.rom`, every label's ROM offset, for reading data in any bank), then
  `work/scripts/lib.lua`, then the scenario. Mesen runs it with `--testRunner`:
  no window, full speed (the opening's 1,800 frames take about 2 s). The log and screenshots go
  to `work/analysis/` (`NAME.log`, `NAME_NNN_shot.png`). The default ROM is `ps1en.sms`;
  `--rom=PSI_Disasm/ps1original.sms` runs the stock game (the code labels are the same:
  `checkbuild.py`).
* **Portable Mesen.** `ps1emu.py` keeps `Mesen_2.1.1/settings.json` with three things a fresh
  Mesen lacks: the file itself (without one Mesen opens its first-run wizard and the test runner
  never starts), Lua I/O access (`Debug.ScriptWindow.AllowIoOsAccess`, off by default: no log,
  no screenshots), and an SMS pad in port 1 (`Sms.Port1.Type`; the wizard sets it, so without
  it `emu.setInput` reaches nothing). Portable mode also keeps Mesen's data out of Documents.
* **Bounded.** Every wait in `lib.lua` has a frame limit and raises when it runs out;
  the run stops at `--frames` (default 30,000); Mesen stops at `--timeout` (default 120 s) and
  the runner kills it 30 s later. Exit codes: 0 done, 1 the scenario raised (a `fail`
  screenshot is taken), 2 the frame cap.
* **A blank battery.** Mesen keeps the cartridge RAM in `Mesen_2.1.1/Saves/ROM.sav`; the runner
  deletes it before each run unless `--keep-sram`, so a saved game never changes what the next
  run sees (into a slot already named the game skips the naming screen).
* **No reset.** `emu.reset()` from a test-runner script stops the script (Mesen then runs to its
  timeout); a power cycle is two runs, the second with `--keep-sram`.
* **What a scenario sees** (`lib.lua`): `ram(addr)` (work RAM by CPU address),
  `game_mode()` (`$C202`; `MODE.intro` 3, `map` 9, `dungeon` 11, `interaction` 13, `road` 15),
  `wait`, `wait_until(pred, max, what)`, `press(buttons, n, gap)` (`one`, `two`, `up`, `down`,
  `left`, `right`, `pause`; button 1 shows as `$10` in `Ctrl_1_held` `$C204`),
  `at_button_wait()` (an exec callback on `WaitForButton1Or2`, which runs once a frame while the
  game waits), `at_timed_wait()` (the same on `LABEL_2D39`, the `{TIMED}` wait), `dialogue_text()` and `cutscene_text()` (the text read back from the VRAM
  nametable through the font's tiles: no OCR), `shot(name)`, `log(msg)`; `window_open()`
  (`$C2D3`), `page_window(max, tag)` (pages a conversation with button 1, logging each page),
  `yes_no_shown()` (the YES / NO box, by its words), `dump_screen(tag)` (every row with text),
  `new_game_to_field(max_pages, on_page)`, `open_command_menu()`, `area_text(r0, r1, c0, c1)`
  (a menu: one line per row, step 2; a US menu word is one tile row, a dialogue or cut-scene
  line two, read on its lower row), `type_name(name)` (the naming screen: the cursor walks the
  key grid until `$C788`, the code under it, is the key wanted, each step checked; the typed name
  at `$C721` checked after each key; then END).
* **Checking against the JSON.** `--expect=ID,...` (ids in the order the game plays them; each
  runs on through its `falls_through` entries) compares the pages a scenario logged with those
  entries' `en`: cut-scene pages as they are, and the dialogue window by a model of it
  (`window_pages`: two lines; `{BR}` and `{PAGE}` move to the next line, scrolling; `{PAGE}` and
  `{END}` wait; a string that starts in the open window starts on a new line; at each wait the
  last two lines show). Inserts match any value they can hold. `--dialogue=PATH` takes the
  text from another copy. `--words=SEGMENT[:ids],...` (ids `n`, `a-b`, or several joined with
  `+`) checks that those `script.json` runs' `en` are on the rows a scenario dumped. `--known`
  checks that every window line a scenario logged is a line of some `dialogue.json` entry (for
  scenes whose order is random, such as a battle).
* **Trying a line before committing it.** `tools/trybuild.py EDITS.json OUT.sms` applies a few
  `en` edits (`{"dialogue": {id: en}, "script": {segment: {run id: en}}}`) to copies of the
  JSON, builds `OUT.sms` from them, checks nothing moved, and puts the source back. Then run a
  scenario with `--rom=OUT.sms --dialogue=OUT.sms.dialogue.json`. Tried on 2026-10-16: the
  soldier's intro speech rewritten with 20-cell lines and the field menu's STAS / SRCH as STAT
  / LOOK: the game showed both exactly (the encoder's output and the tilemap writer, seen).
* **Scenarios** (`work/scripts/`), all passing on 2026-10-16:

  | scenario | what | check |
  |---|---|---|
  | `boot` | the title; button 1 reaches `Ctrl_1_held` | - |
  | `opening` | a new game: every intro page, to the field in Camineet | `--expect=B49B,B4FC,B5D5` (8 pages) |
  | `talk` | Alisa walks up into her home: its sign | `--expect=02A4` |
  | `forcetalk talk=N` | any person's conversation without walking: the talk id is written to `$C2DB` before the button that opens the interaction screen, whose dispatcher `LABEL_474B` runs that handler (0 is the command menu); 1 is Suelo | `talk=1 --expect=0002,0006` (7 window pages) |
  | `fieldmenu` | the command menu (on the field a button switches to the interaction screen, mode 13) | - |
  | `menus` | STAS, MAGC (two field spells given: `$C40F`), ITEM (nine items given: `$C4C0`, count `$C4E2`; the list's NEXT row) and the item actions; button 2 chooses, button 1 cancels | `--words=field_menu,status_labels,spells:15-16,items:33-40,item_menu` (22 words) |
  | `savegame` | SAVE: the slot list, YES, the naming screen (`type_name`), then the name in the cartridge RAM's slot list (a tilemap of tile, attribute pairs at `$0100`) | the name found |
  | `continue` | run after `savegame` with `--keep-sram`: CONTINUE, "CONTINUE GAME- YES", the slot list showing the name, the field | slot 1 shows the name |
  | `shop shop=N type=armory\|food` | a shop without walking: `Interaction_Type` `$C29E` = `$16` (armory, `LABEL_2BC0`) or `$18` (food, `LABEL_2C8F`) and the shop `$C2DB` (`B03_ShopData`: 1 Camineet Armory, 3 Camineet First Food Shop, 4 / 6 Parolit, 7 Scion) before the button; 2000 meseta given; YES, the stock list, the first item bought, NO, "WELL, COME AGAIN."; the item and the price checked against the stock data in the ROM (its count byte is the last index) | `--expect=B12_B7C7,B12_B7F5,B12_B807,B12_B7E3 --words=items:25+27+28` (the run logs the stock) |
  | `partymenu` | the party filled (`$C4F0` = 3, each member alive), STAS asks who: the party menu (at `$7A44`) read back, cancelled, the screen under it checked | the screen comes back |
  | `healtarget` | four members, a field HEAL: the caster menu (`$7A44`), the spell list, the target menu (`$7A54`, `LABEL_3682`); one cancel closes all three | the screen comes back |
  | `battle enemy=N` | a forced battle: `$C2E6` the enemy, `$C29D` `$FF`, game mode `$0C`, what a random encounter leaves; Alisa boosted (attack 255, 99 HP; `strong=0` not); `party=4` all four members (the name box shows at each turn); ATTK each round; every message logged at its wait; a chest opened (`chest=no`) | `--known --words=enemies:N,battle_menu` |

  `battle enemy=1`: the menu, the name box SWORM, "SWORM / IS KILLED.", "YOU GAINED 2 /
  EXPERIENCE POINTS.", the chest and "THERE ARE 3 / MESETAS INSIDE." (10 of 10 lines known);
  `battle enemy=2 strong=0` (a Green Slime against a level-1 Alisa): "ALIS DIED." and the game
  over's three pages. Not yet: the second-hand shop (selling), the hospital and church, a
  dungeon.

Emulicious stays the second opinion for accuracy questions.
