# PS I Retranslation - Status

Updated: 2026-10-16

## State

Project started. The disassembly is in place and assembles the US/EU release v3 bit-exact
with WLA-DX 10.7 (`python tools/checkstock.py`), and the stock text engine is mapped
(`docs/pipeline.md` section 3); nothing has been extracted or translated.

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

## Next, in order

1. **The JP ROM.** The owner supplies *Phantasy Star* (Japan) as `work/ps1jp_stock.sms`
   (CRC32 `6605D36A`). Decode its script (kana encoding, its own dictionary if any) with
   `tools/ps1text.py`; check against Maxim's JP disassembly (`maxim-zhao/psrp`, `disassembly/`).
2. ~~The stock text engine~~: done (see Done and `docs/pipeline.md` section 3). Still to
   confirm in Mesen when the harness exists: that tiles `$EC`-`$FF` are free in every mode,
   and that the title-screen words are graphics.
3. **Extraction** into `work/dialogue.json` and `work/script.json` (JP / US / EN), and
   `gentext.py` with a bit-exact round trip; then `checkbuild.py`, `linecheck.py`,
   `test_text.py`, as PS II.
4. **The emulator harness**: Mesen 2.1.1 `--testRunner` with Lua, every scenario bounded.
5. **Engine options**: lower case, a proportional dialogue face, longer names, a text scheme
   with room for the new script.
6. **Translation**, then proofreading in play, then release packaging (BPS + Patcher.html).
