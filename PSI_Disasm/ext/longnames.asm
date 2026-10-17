; long_names: the party's names up to 6 letters (docs/pipeline.md 6). Bank 35, with the
; renderer it draws {NAME} through (needs vwf_dialogue).
;
; * {NAME}: LABEL_3244 calls VwfName, which takes the name from LongNames (6 bytes each, the
;   face's codes, $65-padded) instead of CharacterNames (4 bytes).
; * The battle's name box (LABEL_2EAC) and the party menu (LABEL_369F, at $7A44 or $7A54) are
;   8 cells wide instead of 6: their maps are in ext/longnames_data.asm (gentext writes them
;   from the stock maps of bank 27, two cells wider, with the names in capitals). The callers
;   still save the 6 stock columns under them in the stock buffers; the 2 columns more go to
;   LongBoxExtra / LongPartyExtraA / LongPartyExtraB (ext/vwf_ram.asm), and the restores
;   (LABEL_2ECD, LABEL_36BB, LABEL_36CC) put both back.
; LABEL_3A68 draws from the current slot-2 bank (this one); LABEL_3A57 and LABEL_3AA6 save and
; restore $FFFF themselves, so this code can call all three.

; {NAME}: the current character's name, a character a frame as the stock
VwfName:
	push	de
	ld	a, b
	cp	$12
	call	z, VwfNewLine
	ld	b, $11
	push	bc
	ld	a, (CurrentCharacter)
	and	$03
	ld	l, a
	add	a, a
	add	a, l
	add	a, a			; 6 * index
	ld	l, a
	ld	h, 0
	ld	de, LongNames
	add	hl, de
	ld	b, 6
-:	ld	a, (hl)
	cp	Dialogue_Terminator65
	jr	z, +
	push	bc
	push	hl
	call	VwfDraw
	ld	a, $0A
	call	WaitForVInt
	pop	hl
	pop	bc
	inc	hl
	djnz	-
+:	pop	bc
	pop	de
	ret

; the name box of party member ($C267), 3 rows of 8 cells at $7B02
LongNameBox:
	ld	hl, LongBoxExtra
	ld	de, $7B02 + 12
	ld	bc, $0304
	call	LABEL_3AA6
	ld	a, ($C267)
	ld	l, a
	ld	h, 0
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl			; 16 * index
	ld	d, h
	ld	e, l
	add	hl, hl
	add	hl, de			; 48 * index
	ld	de, LongNameBoxes
	add	hl, de
	ld	de, $7B02
	ld	bc, $0310
	jp	LABEL_3A68

LongNameBoxRestore:
	ld	hl, $D700
	ld	de, $7B02
	ld	bc, $030C
	call	LABEL_3A57
	ld	hl, LongBoxExtra
	ld	de, $7B02 + 12
	ld	bc, $0304
	jp	LABEL_3A57

; the party menu at de: (Party_curr_num + 1) * 2 rows of 8 cells, then its bottom row
LongPartyMenu:
	push	de
	ld	hl, $000C
	add	hl, de
	ex	de, hl			; de = the two columns more
	call	LongPartyExtra
	ld	bc, $0904
	call	LABEL_3AA6
	pop	de
	ld	a, (Party_curr_num)
	inc	a
	add	a, a
	ld	b, a
	ld	c, $10
	ld	hl, LongPartyRows
	call	LABEL_3A68
	ld	hl, LongPartyEnd
	ld	bc, $0110
	jp	LABEL_3A68

; the screen back under the party menu at de: the stock 6 columns, then the 2 more
LongPartyRestore:
	push	de
	ld	hl, $DDA8
	ld	a, e
	cp	$44
	jr	z, +
	ld	hl, $DE14
+:	ld	bc, $090C
	call	LABEL_3A57
	pop	de
	ld	hl, $000C
	add	hl, de
	ex	de, hl
	call	LongPartyExtra
	ld	bc, $0904
	jp	LABEL_3A57

; hl = the buffer for the two columns more at de ($7A44 + 12 or $7A54 + 12)
LongPartyExtra:
	ld	hl, LongPartyExtraA
	ld	a, e
	cp	$50
	ret	z
	ld	hl, LongPartyExtraB
	ret

.include "ext\longnames_data.asm"
