; ps1.options.asm - build options of the retranslation
;
; Each engine change is an option here, tested with .IF in ps1.asm. With every
; option at 0 (and every en equal to its us in the JSON) the build must
; reproduce the US/EU release v3 (CRC32 00BEF1D7) byte for byte:
; python tools/checkstock.py proves it.
;
; No options yet.
