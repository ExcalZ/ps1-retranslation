# Phantasy Star: English Retranslation - source and tools

A new English translation of *Phantasy Star* (Master System, 1987), made from the Japanese
script, built as a **source patch on top of the game's disassembly** rather than by editing
the ROM - the same shape as the
[Phantasy Star II](https://github.com/ExcalZ/ps2-retranslation),
[III](https://github.com/ExcalZ/ps3-retranslation) and
[IV](https://github.com/ExcalZ/ps4-retranslation) retranslations.

**Status: just started.** The disassembly assembles the US/EU release byte for byte; the
script has not been extracted yet. See `work/STATUS.md`.

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
PSI_Disasm/              lory90's disassembly (the translation will be written into ps1.asm)
PSI_Disasm/ps1.options.asm  the engine options (none yet)
tools/sourcebuild.py     assembles the ROM, fixes the header checksum
tools/checkstock.py      proves the options-at-0 build is the stock ROM
```

## Building

```bash
python tools/sourcebuild.py ps1en.sms
```

```bash
python tools/checkstock.py
```

## Credits and legal

Translation, hacking and testing by **Excalibur_Z**, with Claude (Anthropic) for translation
and technical work. Built on lory90's Phantasy Star disassembly (with Veo's and Isotarge's
research). Tooling and documentation are MIT licensed (`LICENSE`); third-party components are
listed in `NOTICE.md`. Phantasy Star is copyright SEGA; this repository contains no ROM image
and no right to one.
