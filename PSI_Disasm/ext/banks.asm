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
.IF battle_macros == 1
.include "ext\macros.asm"	; the battle's first window and the macros
.ENDIF

.IF hospital_everyone == 1
.include "ext\hospital.asm"	; the hospital's Everyone
.ENDIF
.IF vwf_windows == 1
; last in the bank, so the code before it keeps its addresses (the owner's savestates resume
; in it)
; the letters lent (WinFontDirty) and no window of this screen on them: the stock font back
; (VwfMenuFont, before a menu draws), for the stock capitals a menu may write - the save list's
; names after a dungeon's fight, which has no fade to give them back. A battle lends them first:
; its windows keep them
WinLettersBack:
	push	bc
	ld	a, (WinKind)
	cp	1
	jr	z, WinLB_End
	cp	6
	jr	nc, WinLB_Back		; a fresh screen ($FF)
	ld	bc, $00CB
	call	WinPoolPos
	jr	c, WinLB_Back		; not in this screen's pool
	ld	b, a
	ld	a, (WinPos)
	cp	b
	jr	z, WinLB_Back
	jr	nc, WinLB_End		; a window holds tiles from the letters up
WinLB_Back:
	call	VwfFontBack
WinLB_End:
	pop	bc
	ret

; WinEnsurePool's person ($C2DC; c the kind so far): in a dungeon $FF is no one but a spot's
; mark: the Air Castle's spot ($C2DB $B0) once the castle shows (the $C2D8 6 code, LABEL_7CBB). Persons
; are below 62, and the screen shows no tile from $101 up: the dungeon's pool
WinSpotPerson:
	ld	a, c
	cp	3
	ld	a, ($C2DC)
	ret	nz
	cp	$FF
	ret	nz
	xor	a
	ret

; WinRun out of tiles (WinRun_Fallback; WinNewMax: the tile it failed at + 1). The stock
; capitals are right only where the font's letters show them: a pool lends the letters (the
; battle's first, the others' last), and a run runs out once they are taken. Letters this run
; drew into are lent too. Letters lent, none held by an older window (their pool position at
; or above WinP0, or not in the pool): the font back, then the capitals. Held: the run in the
; face as far as its tiles went, its last cells blank (WinRun_CellsK), never another's tiles.
WinSafeFallback:
	ld	a, (WinNewMax)
	or	a
	jr	z, WinSF_Check
	ld	b, a
	ld	c, 0
-:	push	bc
	ld	a, (WinP0)
	add	a, c
	call	WinPoolTile
	call	nc, WinFontNote
	pop	bc
	inc	c
	djnz	-
WinSF_Check:
	ld	a, (WinFontDirty)
	or	a
	jr	z, WinSF_Caps		; the letters intact
	ld	bc, $00CB
	call	WinPoolPos
	jr	c, WinSF_Back		; not in this screen's pool
	ld	b, a
	ld	a, (WinP0)
	cp	b
	jr	z, WinSF_Back
	jr	c, WinSF_Back		; no window below this run holds them
	ld	a, (WinNewMax)		; held: the cells before the tile that failed
	or	a
	jr	z, +
	dec	a
+:
	ld	(WinNewMax), a
	ld	(WinJ), a
	jp	WinRun_CellsK
WinSF_Back:
	call	VwfFontBack
WinSF_Caps:
	ld	de, (WinRunVram)
	jp	WinRun_FallbackCaps
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
