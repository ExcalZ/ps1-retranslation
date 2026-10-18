# Handoff: Phantasy Star retranslation

For an agent picking this up. Read this, then `work/STATUS.md` (the running log),
`docs/pipeline.md` (how the build works) and `work/glossary.md` (every naming decision).

## What this is

A new English translation of *Phantasy Star* (Master System, 1987) from the Japanese script,
built as a **source patch on lory90's disassembly** (`PSI_Disasm/ps1.asm`, WLA-DX), not a ROM
hack. The owner is Excalibur_Z; the sibling projects `../ps2-translate`, `../ps3-translate`
and `../ps4-translate` are the same shape and set the conventions (American English, Japanese
names, PS I names as the PS IV translation ships them). `../ps2-translate` is the most
complete model: copy its structure and tool names when building the pipeline here.

Unlike the siblings this is a **Z80 / Master System** game: the Mega Drive tools
(`tools/md/`, BlastEm, the 68000 interpreter) do not apply.

**State:** see `work/STATUS.md`. The script is extracted (`work/dialogue.json`,
`work/script.json`) and the generator writes it back bit-exact; nothing is translated yet.
Engine options on: `expand_rom`, `far_calls`, `relocate_script` (`docs/pipeline.md` section 6;
the plan for the rest in `docs/engine-plan.md`).

## Rebuild rule

Every ROM build must include the current JSON:

```bash
python tools/sourcebuild.py ps1en.sms
```

(runs `gentext.py`; never pass `--no-gen` for a real build). Then always:

```bash
python tools/checkbuild.py      # must print "nothing moved"
python tools/linecheck.py       # must print "0 problems"
python tools/gentext.py --check # must rewrite nothing after a build
```

and before any commit that touches the engine, the generator or the tables:

```bash
python tools/checkstock.py      # options at 0, en = us: byte-identical to US/EU v3
python tools/test_text.py       # codecs, JSON vs both ROMs, the encoder's round trip
```

`PSI_Disasm/ps1.log` existing after a build means WLA-DX failed: never test a ROM from a
failed build (chain commands with `&&` and `test ! -f PSI_Disasm/ps1.log`).

## Hard rules (inherited from the siblings, each learned the hard way)

1. **Nothing in the stock image moves.** A hook in `ps1.asm` sits under `.IF option ... .ELSE
   <stock code> .ENDIF` and must be exactly the size of the code it replaces; new code goes in
   `PSI_Disasm/ext/`. `checkbuild.py` proves it: only the text regions may move.
2. **Every option at 0 must reproduce US/EU v3 byte for byte** - `checkstock.py`.
3. **Line endings.** The disassembly is CRLF throughout. Python text-mode I/O on Windows and
   Git Bash `sed -i` change endings silently: edit bytes or open with `newline=''`; check with
   `open(f,'rb').read().count(b'\r\n')`. Stage with `git -c core.autocrlf=false add ...`.
4. **Bash heredocs eat backslashes** - and the disassembly's includes are `"banks\bank03.asm"`.
   Use a file editor or a script file for anything with escapes.
5. **Emulator scenarios must be bounded.** Every loop has a limit, checks RAM before pressing
   on and raises instead of guessing: use `lib.lua`'s `wait_until(pred, max, what)` and
   `at_button_wait()`, never a bare loop. `ps1emu.py` adds a frame cap and a process timeout.
   Never type blindly into the naming screen.
6. **Extraction (`extract_text.py`) runs only on a stock build** and refuses to overwrite the
   JSON (it would drop the translation). You should not need to run it again.
7. **Never commit game data** (ROMs, savestates, SRAM, `work/analysis/`); `.gitignore` covers
   it. `PSI_Disasm/ps1original.sms` ships with the disassembly and is ignored.
8. **Maxim's PSRP** (`maxim-zhao/psrp`) states no license: read it as a reference, copy no code
   or text from it, and credit any finding taken from its docs in `NOTICE.md`.
9. **Generated files**: `PSI_Disasm/text/*.asm` (the script), the name lines and the tilemap
   runs are written by `gentext.py`: edit the JSON, not the source. Any tool that rewrites them
   for a test must put them back (`checkstock.SOURCES` lists them).

## How to work on the text

* `work/dialogue.json` - edit only `en`. Controls: `{BR}` next line, `{PAGE}` wait then next
  line, `{CLR}` clear; inserts `{NAME}` `{ENEMY}` `{ITEM}` `{NUMBER}`; end codes `{END}`,
  `{NOWAIT}`, `{TIMED}`, `{PAUSE}` - keep the stock entry's. An entry with `falls_through` must
  not end in an end code (it runs on into the next entry); `jp_cont` entries carry part of the
  JP of the entry before - keep the split. `us` and `jp` show the window's auto-wrap as `{BR}`.
* With `vwf_dialogue` (on in the working build): dialogue and messages
  are mixed case in the series face, **80 px a line** (`linecheck.py` measures it), any
  character `tools/diafont.py` has; with `vwf_cutscene` too, cut-scenes are **120 px** a line,
  4 lines a page. With `long_names`: party names up to 6 letters (mixed case in `{NAME}`,
  capitals in the menus; the `status_boxes` runs must match them in capitals); with
  `long_item_names`: item and enemy names up to 14 characters (with `vwf_windows` also at most
  80 px in the face: the windows list them in 10 cells); with `vwf_windows` (on): the
  menus too, mixed case, each run at most its cells x 8 px (`linecheck.py`). Without them:
* Budgets: dialogue and messages 18 cells a line (the window scrolls, no line limit);
  cut-scenes 20 cells, 4 lines a page; inserts count at their widest ({NAME} 4, {ENEMY} and
  {ITEM} 8, {NUMBER} 5). Names: party 4, items 8, enemies 8.
* Until the text-scheme engine option exists the encoder is the stock engine's: upper case,
  digits, `, ; . ! ? - " '` only, and 183 bytes to spare in bank 2, 40 in bank 12
  (`linecheck.py` prints the count).

## Style

As the siblings (`../ps2-translate/work/glossary.md` "Style"): American English, Japanese
names, narration in the past tense, 「」 becomes "...", serial comma, punctuation inside closing
quotes.

## Tools

* WLA-DX 10.7: `$WLADX` or `wla_dx_v10.7_Win64/` (git-ignored). Not the 2006 build in
  `PSI_Disasm/binaries/`.
* Emulator: **Mesen 2.1.1** (`Mesen_2.1.1/`, git-ignored, or `$MESEN`), run only through
  `python tools/ps1emu.py SCENARIO [--rom=] [--expect=ID,...]`: headless, bounded, log and
  screenshots in `work/analysis/` (`docs/pipeline.md` section 7). Scenarios in
  `work/scripts/` on top of `lib.lua`: `boot`, `opening`, `talk`, `forcetalk talk=N`, `fieldmenu`,
  `menus`, `savegame`, then `continue --keep-sram`, `shop shop=N`, `battle enemy=N`,
  `partymenu`, `healtarget`, `inventory`, `battlelist enemy=N`, `windows screen=hospital|church|sell|port|dungeon`,
  `myau`, `tyron`, `lutz`, `wings`, `ending [answer=no]` (the story scenes and the credits),
  `vramdump enemy=N` (then `tools/vramsheet.py`: the
  battle's VRAM as a tile sheet, free tiles marked)
  (`docs/pipeline.md` section 7 has the table and each one's check). To see a line in the game
  before committing it: `python tools/trybuild.py EDITS.json OUT.sms`, then a scenario with
  `--rom=OUT.sms --dialogue=OUT.sms.dialogue.json --expect=...` (then `tools/applyedits.py EDITS.json`
  writes them into the JSON). Never run Mesen.exe directly without a
  `settings.json` beside it (its first-run wizard blocks the test runner). The GUI debugger
  imports `PSI_Disasm/ps1built.sym`. Emulicious is the second opinion on accuracy.

## Decisions that belong to the owner - do not settle them yourself

* names not yet in `work/glossary.md` (most of PS I's);
* whether the patch should also apply to US/EU v2 (`E4A65E79`);
* which engine extras to take (see `work/STATUS.md`, Next 5).
