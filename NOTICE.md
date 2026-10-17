# Third-party components

| Component | Where | Origin | Terms |
|---|---|---|---|
| Phantasy Star disassembly (`PSI_Disasm/`) | the whole directory, minus `ps1.options.asm` and the translation edits | lory90 (lorenzo, lory1990), "Phantasy Star Disassembly for Sega Master System" (2019; romhacking.net document 723; the original GitHub repository is gone, `sung3r/ps1disasm` mirrors it with lory90's history and assembles the US/EU v3 ROM bit-exact). Credits inside: Veo (ROM data research), Isotarge (labels, RAM constants) | Its author's disclaimer, reproduced below. No formal license. Non-commercial. |
| Label renames in the disassembly | `PSI_Disasm/banks/bank15.asm` | this project: 57 unreferenced data labels `DungeonID_*` renamed `DungeonLayout_*`, because WLA-DX 10.7 refuses a label with the name of a `.define` (the 2006 WLA-DX allowed it) | as the disassembly |

Not included, but used by the build and test tooling - install them yourself:

* **WLA-DX 10.7** (GPL-2.0, Ville Helin and contributors, https://github.com/vhelin/wla-dx) -
  `tools/sourcebuild.py` expects `wla_dx_v10.7_Win64/` in the repository root or `$WLADX`.
  The 2006 WLA-DX binaries that ship in the disassembly's `binaries/` are not used and not tracked.
* **Mesen 2** (GPL-3.0, Sour) - the emulator harness (planned).
* **Floating IPS (Flips)** (GPL) - release packaging (planned).

Read for reference only, nothing copied: Maxim's *Phantasy Star Retranslation*
(https://github.com/maxim-zhao/psrp; no license stated), whose `technical.md` documents the
text engine and whose JP disassembly is a cross-check for the Japanese script.

## Disassembly disclaimer

> DISCLAIMER: Any and all content presented in this repository is presented for
> informational and educational purposes only. Commercial usage is expressly
> prohibited. I do not claim ownership of any code in this repository. You
> assume any and all responsibility for using this content responsibly. I do
> not claim responsibility or warranty.

Phantasy Star is copyright SEGA. This repository contains no ROM image; see `README.md`
for which ROMs the build expects.
