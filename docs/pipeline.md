# The build pipeline

The working reference for anyone changing text or engine code here. The current state and
checklist are in [`../work/STATUS.md`](../work/STATUS.md). Sections marked *planned* describe
the shape the PS II and PS III projects have and this one will follow; they are not built yet.

## 1. Shape of the build

There is no ROM patching. The game is assembled from source (`PSI_Disasm/ps1.asm` and
`banks/*.asm`) by WLA-DX, and the translation will reach the source through one generator,
`tools/gentext.py` (*planned*), which rewrites the text of the assembly in place from the JSON.
Engine changes are build options in `PSI_Disasm/ps1.options.asm` (section 6): with every
option at 0 and every `en` equal to its `us`, the ROM is byte-identical to the US/EU release
v3 (`checkstock.py`).

```
work/dialogue.json --gentext.py--> the Dialogue_Index_* blocks of ps1.asm      (planned)
work/script.json   --gentext.py--> items, enemies, spells, names, menus         (planned)
```

`tools/sourcebuild.py [out.sms] [--no-gen]` runs `gentext.py` (once it exists), then
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
| `work/ps1jp_stock.sms` | Japan, 1987 (needed to align the JP script; the owner's dump) | 524,288 | `6605D36A` | - |

The US/EU v2 (`E4A65E79`) is the other export dump; whether the patch should also apply to it
(as PS II's patcher takes both US revisions) is open.

## 3. The stock text engine (first survey; to be completed)

* **Encoding.** The US script is upper-case ASCII-like bytes inside `.db` strings in `ps1.asm`;
  control bytes are named in `ps1.constants.asm`: `$40` apostrophe, `$5B` current character's
  name, `$5C` enemy name, `$5D` current item, `$5E` a number (from `$C2C5`), `$60` new line,
  `$61` new page, `$62`-`$65` terminators (`Dialogue_Terminator65` also ends the item names).
* **Dictionary.** 128 words (`Dialogue_Word_Index_00`-`7F`, the `Word_*` defines) are inserted
  by one byte each; this is how the US fit its text. The retranslation will need a different
  scheme (a larger or generated dictionary, or compression - Maxim's PSRP documents one way).
* **Dialogue.** `DialogueBlock` is a word table of 341 entries `Dialogue_Index_0002`-`02AA`;
  dialogue flags at `$C500`.
* **Names.** Item names are fixed 8-byte fields (`"WAND", term, "   "`); enemy and spell
  names likewise, to be surveyed. Lower case, a proportional font and longer names are engine
  options to come, as in PS II.
* **Japanese.** The JP ROM uses kana; its script and its encoding have to be read from the JP
  ROM (Maxim's JP disassembly and `.tbl` files are a cross-check).

## 4. Extraction (*planned*: done once, on a stock build only)

`extract_dialogue.py` / `extract_tables.py` read the stock text out of the source, decode
the JP script from the JP ROM and align the two into `work/dialogue.json` /
`work/script.json` (`jp`, `us`, `en`, address, window), as PS II's.

## 5. Verification

* `python tools/checkstock.py` - options at 0: byte-identical to v3. **Works now.**
* *planned*: `checkbuild.py` (nothing in the stock image moved), `linecheck.py` (every line
  in budget), `gentext.py --check` (idempotent), `test_text.py` (codecs, JSON vs both ROMs).

## 6. Engine options (`PSI_Disasm/ps1.options.asm`)

None yet. Each will be a `.define NAME 0|1` tested with `.IF` in `ps1.asm`, with hooks the
exact size of the stock code they replace and new code in `PSI_Disasm/ext/`.

## 7. Emulator harness (*planned*)

Mesen 2.1.1: its `--testRunner script.lua rom.sms` mode runs a Lua script headless at full
speed and exits through `emu.stop(code)`, which is how the scenarios stay bounded; the Lua
API reads and writes RAM, sets the joypad and saves screenshots, and the debugger imports
`ps1built.sym`. Emulicious is the second opinion for accuracy questions.
