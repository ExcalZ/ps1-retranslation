; ps1.options.asm - build options of the retranslation
;
; Each engine change is an option here, tested with .IF in ps1.asm. With every
; option at 0 (and every en equal to its us in the JSON) the build must
; reproduce the US/EU release v3 (CRC32 00BEF1D7) byte for byte:
; python tools/checkstock.py proves it. docs/pipeline.md section 6 describes each.

.define expand_rom 1		; 1 MB: banks 32-63 for new code and text (ext/banks.asm)
.define far_calls 1		; FarCall / FarRead in the unused RST slots $10-$37 (needs expand_rom)
.define relocate_script 1	; the script to banks 32-34 (needs expand_rom)
