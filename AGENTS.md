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

**State:** see `work/STATUS.md`. The build reproduces the US/EU v3 ROM byte for byte; nothing
has been extracted or translated yet.

## Rebuild rule

Every ROM build must include the current JSON (once `gentext.py` exists):

```bash
python tools/sourcebuild.py ps1en.sms
```

then, before any commit that touches the engine, the generator or the tables:

```bash
python tools/checkstock.py      # options at 0: byte-identical to US/EU v3
```

`PSI_Disasm/ps1.log` existing after a build means WLA-DX failed: never test a ROM from a
failed build (chain commands with `&&` and `test ! -f PSI_Disasm/ps1.log`).

## Hard rules (inherited from the siblings, each learned the hard way)

1. **Nothing in the stock image moves.** A hook in `ps1.asm` sits under `.IF option ... .ELSE
   <stock code> .ENDIF` and must be exactly the size of the code it replaces; new code goes in
   `PSI_Disasm/ext/`. (A `checkbuild.py` that proves it is still to be written.)
2. **Every option at 0 must reproduce US/EU v3 byte for byte** - `checkstock.py`.
3. **Line endings.** The disassembly is CRLF throughout. Python text-mode I/O on Windows and
   Git Bash `sed -i` change endings silently: edit bytes or open with `newline=''`; check with
   `open(f,'rb').read().count(b'\r\n')`. Stage with `git -c core.autocrlf=false add ...`.
4. **Bash heredocs eat backslashes** - and the disassembly's includes are `"banks\bank03.asm"`.
   Use a file editor or a script file for anything with escapes.
5. **Emulator scenarios must be bounded.** Every loop has a limit, checks RAM before pressing
   on and raises instead of guessing; a Mesen `--testRunner` script ends in `emu.stop(code)`
   and runs under `--timeout=`. Never type blindly into the naming screen.
6. **Extraction runs only on a stock build** and must not overwrite hand-made layout in the
   JSON once it exists.
7. **Never commit game data** (ROMs, savestates, SRAM, `work/analysis/`); `.gitignore` covers
   it. `PSI_Disasm/ps1original.sms` ships with the disassembly and is ignored.
8. **Maxim's PSRP** (`maxim-zhao/psrp`) states no license: read it as a reference, copy no code
   or text from it, and credit any finding taken from its docs in `NOTICE.md`.

## Style

As the siblings (`../ps2-translate/work/glossary.md` "Style"): American English, Japanese
names, narration in the past tense, 「」 becomes "...", serial comma, punctuation inside closing
quotes.

## Tools

* WLA-DX 10.7: `$WLADX` or `wla_dx_v10.7_Win64/` (git-ignored). Not the 2006 build in
  `PSI_Disasm/binaries/`.
* Emulator: **Mesen 2.1.1** (git-ignored, `Mesen*/` in the repo root or `$MESEN`). Headless:
  `Mesen.exe --testRunner --timeout=60 script.lua rom.sms`; Lua `emu.read`/`emu.write`/
  `emu.setInput`/`emu.takeScreenshot`/`emu.addEventCallback`/`emu.stop`. Its debugger imports
  `PSI_Disasm/ps1built.sym`. Emulicious is the second opinion on accuracy.

## Decisions that belong to the owner - do not settle them yourself

* names not yet in `work/glossary.md` (most of PS I's);
* whether the patch should also apply to US/EU v2 (`E4A65E79`);
* which engine extras to take (see `work/STATUS.md`, Next 5).
