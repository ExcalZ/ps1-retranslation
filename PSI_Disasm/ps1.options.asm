; ps1.options.asm - build options of the retranslation
;
; Each engine change is an option here, tested with .IF in ps1.asm. With every
; option at 0 (and every en equal to its us in the JSON) the build must
; reproduce the US/EU release v3 (CRC32 00BEF1D7) byte for byte:
; python tools/checkstock.py proves it. docs/pipeline.md section 6 describes each.

.define expand_rom 1		; 1 MB: banks 32-63 for new code and text (ext/banks.asm)
.define far_calls 1		; FarCall / FarRead in the unused RST slots $10-$37 (needs expand_rom)
.define relocate_script 1	; the script to banks 32-34 (needs expand_rom)
.define vwf_dialogue 1		; the dialogue window in the series face, 80 px lines (needs far_calls; ext/vwf.asm)
.define vwf_cutscene 1		; the cut-scenes in the series face, 120 px lines in the font area (needs vwf_dialogue)
.define long_names 1		; party names up to 6 letters: {NAME}, the name box, the party menu (needs vwf_dialogue)
.define long_item_names 1	; item and enemy names up to 14 characters (needs vwf_dialogue; ext/longitems.asm)
.define vwf_windows 1		; every window's text in the face, tiles lent by the screen (needs vwf_cutscene,
				; long_names, long_item_names; ext/vwfwin.asm)
.define script_dictionary 1	; the 128 dictionary words chosen from the script as built (needs relocate_script,
				; vwf_dialogue, vwf_cutscene; tools/scriptdict.py, text/words.asm)
