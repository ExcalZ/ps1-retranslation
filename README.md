# Phantasy Star: English Retranslation - source and tools

A new English translation of *Phantasy Star* (Master System, 1987), made from the Japanese
script, built as a **source patch on top of the game's disassembly** rather than by editing
the ROM - the same shape as the
[Phantasy Star II](https://github.com/ExcalZ/ps2-retranslation),
[III](https://github.com/ExcalZ/ps3-retranslation) and
[IV](https://github.com/ExcalZ/ps4-retranslation) retranslations.

[![Latest release](https://img.shields.io/github/v/release/ExcalZ/ps1-retranslation?label=Download%20the%20patch)](https://github.com/ExcalZ/ps1-retranslation/releases/latest)

**Players:** get the patch from the [Releases page](https://github.com/ExcalZ/ps1-retranslation/releases/latest) - the zip has an offline patcher (`Patcher.html`, for the US/European release, version 3), the BPS patch and the readme. Nothing else on this page is needed to play. No ROM is included here or there.

**Status: v1.0.** The whole script is translated from the Japanese; the text engine is rebuilt
(proportional text in the dialogue, the story scenes and every window, full-length names), with
battle macros, the hospital's Everyone and faster exploration as engine options. Every option
at 0 still assembles the US/EU release byte for byte. See `work/STATUS.md`.

No ROM is included here. To build you need WLA-DX 10.7 (`wla_dx_v10.7_Win64/` in the
repository root, or `$WLADX`) and the stock US/EU v3 ROM (CRC32 `00BEF1D7`) at
`PSI_Disasm/ps1original.sms`.
Aligning the Japanese script will need the JP ROM as `work/ps1jp_stock.sms`.

## Repository map

```
README.md                this file
AGENTS.md                handoff for anyone (or any agent) picking the work up
docs/pipeline.md         how a build works, the ROMs, the stock text engine
work/STATUS.md           current state, what is done, what is next - read first
work/glossary.md         naming decisions
work/dialogue.json       the script: 538 strings, JP / US / EN
work/script.json         party, item and enemy names, JP / US / EN
work/pairing.json        the JP / US alignment of the strings without ids
docs/engine-plan.md      the engine options: the plan and the owner's decisions
PSI_Disasm/              lory90's disassembly (the translation is written into it)
PSI_Disasm/text/         the script as assembly, written by gentext.py
PSI_Disasm/ext/          the new engine code and banks
PSI_Disasm/ps1.options.asm  the engine options (1 MB ROM, far calls, relocated script)
tools/                   the toolchain (Python 3.10+, standard library only)
tools/ps1emu.py          runs the bounded emulator scenarios (work/scripts/) in Mesen 2
tools/release.py         packages a release: BPS patches, Patcher.html, readme (release/)
tools/diafont.py         the proportional face (from tools/vwfmixed.py, the series' face)
```

## Building

```bash
python tools/sourcebuild.py ps1en.sms
```

writes the JSON into the source (`gentext.py`), assembles with WLA-DX, fixes the header
checksum and copies the ROM. Checks: `checkbuild.py`, `linecheck.py`, `gentext.py --check`,
`checkstock.py`, `test_text.py` (`AGENTS.md`).

## Releasing

```bash
python tools/release.py 1.0
```

after a build and the checks: writes `release/PS1_Retranslation_v1.0/` and its zip (both ignored
by git), the patch made against US/EU v3; the readme is rendered from
`release/readme_template.txt`.

## Editing the translation

Edit only the `en` fields of `work/dialogue.json` and `work/script.json`; `AGENTS.md` lists the
controls and the budgets, `docs/pipeline.md` section 4 the format.

## Credits and legal

Translation, hacking and testing by **Excalibur_Z**, with Claude (Anthropic) for translation
and technical work. Built on lory90's Phantasy Star disassembly (with Veo's and Isotarge's
research). Tooling and documentation are MIT licensed (`LICENSE`); third-party components are
listed in `NOTICE.md`. Phantasy Star is copyright SEGA; this repository contains no ROM image
and no right to one.
