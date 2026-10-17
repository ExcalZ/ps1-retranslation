; Banks 32-63 (expand_rom): the relocated script and the new code. docs/pipeline.md 6.

.BANK 32 SLOT 2
.ORG $0000
Bank32:
.IF relocate_script == 1
.include "text\dialogue.asm"	; DialogueBlock and the 341 blocks
.ENDIF

.BANK 33 SLOT 2
.ORG $0000
Bank33:
.IF relocate_script == 1
.include "text\messages.asm"	; the bank-12 messages, by label
.ENDIF

.BANK 34 SLOT 2
.ORG $0000
Bank34:
.IF relocate_script == 1
.include "text\cutscenes.asm"	; the cut-scene strings, by label
.ENDIF

.BANK 35 SLOT 2
.ORG $0000
Bank35:
.IF vwf_dialogue == 1
.include "ext\vwf.asm"	; the proportional dialogue window
.ENDIF
.IF long_names == 1
.include "ext\longnames.asm"	; the party's names up to 6 letters
.ENDIF
.IF long_item_names == 1
.include "ext\longitems.asm"	; item and enemy names up to 14 characters
.ENDIF
.IF vwf_windows == 1
.include "ext\vwfwin.asm"	; every window's text in the face
.ENDIF

.BANK 63 SLOT 2
.ORG $0000
Bank63:
.IF far_calls == 1
; for work/scripts/farcall.lua: FarCall must return hl = $5AA5, FarRead the byte $A7
FarSelfTest:
	ld hl, $5AA5
	ret
FarSelfTestByte:
.db $A7
.ENDIF
