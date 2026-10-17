; long_item_names: item and enemy names up to 14 characters (docs/pipeline.md 6). Bank 35,
; with the renderer (needs vwf_dialogue).
;
; The names are in ext/longitems_data.asm (gentext writes them from work/script.json):
; LongItems (65 x 14 bytes) and LongEnemies (75 x 14), the face's codes, $65-padded. The
; inserts {ITEM} and {ENEMY} draw them proportionally (VwfItem, VwfEnemy); the windows that
; list them draw them in the menus' fixed font, a-z as capitals (LongRowName, through the
; stock glyph table LABEL_7D17 in bank 1).
;
; Each window that lists names is LONG_X cells wider (ext/vwf_ram.asm: 2 with vwf_windows,
; whose names are in the face, at most 80 px; 6 without, a cell a letter), to the left, its
; right edge where the stock has it: the battle's enemy name box (stock r0 c14; the HP box stays
; at c24), the equipment box (stock r10 c6; the status window stays at c16), the shop list
; (stock r0 c6; the money box stays at c22) and the inventory (stock r2 c22). The callers' stock
; buffers still take the stock columns; the LONG_XA new columns beside them go to
; LongEnemyBoxExtra / LongSharedExtra and, without vwf_windows, the LONG_XB at the left edge to
; LongEnemyBoxExtra2 / LongSharedExtra2.

; ---------------------------------------------------------------- the inserts

; {ITEM}: CurrentItem's name
VwfItem:
	push	de
	ld	a, b
	cp	$12
	call	z, VwfNewLine
	ld	b, $11
	push	bc
	ld	a, (CurrentItem)
	call	LongItemPtr
	jr	VwfLongName

; {ENEMY}: the battle's enemy ($C2E6)
VwfEnemy:
	push	de
	ld	a, b
	cp	$12
	call	z, VwfNewLine
	ld	b, $11
	push	bc
	call	LongEnemyPtr
VwfLongName:			; draw up to 14 codes at hl, a frame a character as the stock
	ld	b, 14
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

; hl = LongItems + 14 * a
LongItemPtr:
	ld	de, LongItems
LongPtr14:
	ld	l, a
	ld	h, 0
	add	hl, hl			; 2a
	push	de
	ld	d, h
	ld	e, l
	add	hl, hl
	add	hl, hl
	add	hl, hl			; 16a
	or	a
	sbc	hl, de			; 14a
	pop	de
	add	hl, de
	ret

; hl = the name of the battle's enemy
LongEnemyPtr:
	ld	a, ($C2E6)
	and	$7F
	ld	de, LongEnemies
	jr	LongPtr14

; ---------------------------------------------------------------- window rows

; a = the menus' tile for code a in row c (0 the upper, 1 the lower) of LABEL_7D17; a-z as A-Z
LongGlyph:
	cp	$66
	jr	c, +
	sub	$25
+:	sub	$20
	add	a, a
	add	a, c
	push	de
	ld	e, a
	ld	d, 0
	ld	hl, LABEL_7D17
	add	hl, de
	pop	de
	ld	a, (hl)
	ret

; one row of a name list: the left frame, the codes at hl in row c, the right frame, at de;
; de moves a row down, a frame's wait after (as the stock rows)
LongRowName:
	push	bc
	push	hl
	push	de
	di
	rst	$08
	call	LongRowCells
	ld	a, $F3
	out	(Port_VDPData), a
	push	af
	pop	af
	ld	a, $13
	out	(Port_VDPData), a
	jr	LongRowEnd

; the left frame and the LONG_W cells of the codes at hl in row c, to the VDP (its address set, interrupts off)
LongRowCells:
	push	hl
	ld	a, $F3
	out	(Port_VDPData), a
	push	af
	pop	af
	ld	a, $11
	out	(Port_VDPData), a
.IF vwf_windows == 1
	ld	a, c			; vwf_windows: the upper row blank, the name in the face below
	or	a
	jr	nz, LongRowCells_Face
	ld	b, LONG_W
-:	ld	a, $C0
	out	(Port_VDPData), a
	push	af
	pop	af
	ld	a, $10
	out	(Port_VDPData), a
	djnz	-
	pop	hl
	ret
LongRowCells_Face:
	push	de
	inc	de
	inc	de			; the first name cell
	ld	bc, LONG_W * 256 + 14	; at most 14 codes
	call	WinRun
	di
	rst	$08			; the VDP past the name, as the stock writes leave it
	pop	de
	pop	hl
	ret
.ELSE
	ld	b, LONG_W
-:	ld	a, (hl)
	cp	Dialogue_Terminator65
	jr	nz, +
	ld	a, $20			; past the name: blank
+:	push	hl
	call	LongGlyph
	pop	hl
	out	(Port_VDPData), a
	push	af
	pop	af
	ld	a, $10
	out	(Port_VDPData), a
	inc	hl
	djnz	-
	pop	hl
	ret
.ENDIF

; a border row at de: b cells between the corners; c = 0 the top, 1 the bottom
LongBorder:
	push	bc
	push	hl
	push	de
	ld	a, c
	or	a
	ld	a, $11
	jr	z, +
	ld	a, $15
+:	ld	c, a			; the attribute: $11 top, $15 bottom
	di
	rst	$08
	ld	a, $F1
	out	(Port_VDPData), a
	push	af
	pop	af
	ld	a, c
	out	(Port_VDPData), a
-:	ld	a, $F2
	out	(Port_VDPData), a
	push	af
	pop	af
	ld	a, c
	out	(Port_VDPData), a
	djnz	-
	ld	a, $F1
	out	(Port_VDPData), a
	push	af
	pop	af
	ld	a, c
	or	$02			; the right corner flipped
	out	(Port_VDPData), a
LongRowEnd:
	ei
	pop	de
	ld	hl, $0040
	add	hl, de
	ex	de, hl
	pop	hl
	pop	bc
	ld	a, $0A
	jp	WaitForVInt

; ---------------------------------------------------------------- the enemy name box

; LABEL_30ED: the screen under the name box (stock columns c14-c23 to $D928, the new c10-c13
; to LongEnemyBoxExtra, c8-c9 to LongEnemyBoxExtra2) and under the HP box ($D978)
LongEnemyBoxSave:
	ld	hl, $D928
	ld	de, $781C
	ld	bc, $0414
	call	LABEL_3AA6
	ld	hl, LongEnemyBoxExtra
	ld	de, $781C - 2 * LONG_XA
	ld	bc, $0400 + 2 * LONG_XA
	call	LABEL_3AA6
.IF LONG_XB > 0
	ld	hl, LongEnemyBoxExtra2
	ld	de, $781C - 2 * LONG_X
	ld	bc, $0400 + 2 * LONG_XB
	call	LABEL_3AA6
.ENDIF
	ld	hl, $D978
	ld	de, $7830
	ld	bc, $0A10
	jp	LABEL_3AA6

; LABEL_3105: the name box, LONG_X cells wider than the stock's
LongEnemyBox:
	ld	de, $781C - 2 * LONG_X
	ld	bc, LONG_W * 256
	call	LongBorder
	push	de
	call	LongEnemyPtr
	pop	de
	ld	c, 0
	call	LongRowName
	ld	c, 1
	call	LongRowName		; (keeps hl)
	ld	bc, LONG_W * 256 + 1
	jp	LongBorder

; LABEL_319E: the screen back under the HP box (unless the enemy is $49) and the name box
LongEnemyBoxRestore:
	ld	a, ($C2E6)
	cp	$49
	jr	z, +
	ld	hl, $D978
	ld	de, $7830
	ld	bc, $0A10
	call	LABEL_3A57
+:	ld	hl, $D928
	ld	de, $781C
	ld	bc, $0414
	call	LABEL_3A57
	ld	hl, LongEnemyBoxExtra
	ld	de, $781C - 2 * LONG_XA
	ld	bc, $0400 + 2 * LONG_XA
	call	LABEL_3A57
.IF LONG_XB > 0
	ld	hl, LongEnemyBoxExtra2
	ld	de, $781C - 2 * LONG_X
	ld	bc, $0400 + 2 * LONG_XB
	call	LABEL_3A57
.ENDIF
	ret

; ---------------------------------------------------------------- the equipment box

; LABEL_3707: party member c's weapon, armour and shield, LONG_X cells wider than the stock box
LongEquipBox:
	push	bc
	ld	hl, $D928
	ld	de, $7A8C
	ld	bc, $0814
	call	LABEL_3AA6
	ld	hl, LongSharedExtra
	ld	de, $7A8C - 2 * LONG_XA
	ld	bc, $0800 + 2 * LONG_XA
	call	LABEL_3AA6
.IF LONG_XB > 0
	ld	hl, LongSharedExtra2
	ld	de, $7A8C - 2 * LONG_X
	ld	bc, $0800 + 2 * LONG_XB
	call	LABEL_3AA6
.ENDIF
	pop	bc
	ld	a, c			; Char_stats + 16 * member + weapon
	add	a, a
	add	a, a
	add	a, a
	add	a, a
	add	a, weapon
	ld	l, a
	ld	h, Char_stats >> 8
	ld	de, $7A8C - 2 * LONG_X
	ld	bc, LONG_W * 256
	call	LongBorder
	ld	b, 3
-:	push	bc
	push	hl
	ld	a, (hl)
	push	de
	call	LongItemPtr
	pop	de
	ld	c, 0
	call	LongRowName
	ld	c, 1
	call	LongRowName
	pop	hl
	inc	hl
	pop	bc
	djnz	-
	ld	bc, LONG_W * 256 + 1
	jp	LongBorder

; LABEL_374D: the screen back under the equipment box
LongEquipBoxRestore:
	ld	hl, $D928
	ld	de, $7A8C
	ld	bc, $0814
	call	LABEL_3A57
	ld	hl, LongSharedExtra
	ld	de, $7A8C - 2 * LONG_XA
	ld	bc, $0800 + 2 * LONG_XA
	call	LABEL_3A57
.IF LONG_XB > 0
	ld	hl, LongSharedExtra2
	ld	de, $7A8C - 2 * LONG_X
	ld	bc, $0800 + 2 * LONG_XB
	call	LABEL_3A57
.ENDIF
	ret

; ---------------------------------------------------------------- the shop list

; The shop list is LONG_X cells wider than the stock's (the money box stays at c22). Its rows are still
; written by the stock code (LABEL_38D9's row writer): LongShopName writes the left frame and
; LONG_W name cells from LONG_X cells left of the stock's place, and the stock writes on from c15 - the
; blank, the price, the right frame - where it would have after its 8 name cells.

; LABEL_38CD: the screen under it (the stock c6-c21 to $D8A4, c2-c5 to LongSharedExtra, c0-c1
; to LongSharedExtra2)
LongShopSave:
	ld	hl, $D8A4
	ld	de, $780C
	ld	bc, $0820
	call	LABEL_3AA6
	ld	hl, LongSharedExtra
	ld	de, $780C - 2 * LONG_XA
	ld	bc, $0800 + 2 * LONG_XA
	call	LABEL_3AA6
.IF LONG_XB > 0
	ld	hl, LongSharedExtra2
	ld	de, $780C - 2 * LONG_X
	ld	bc, $0800 + 2 * LONG_XB
	call	LABEL_3AA6
.ENDIF
	ret

; LABEL_3999: the screen back
LongShopRestore:
	ld	hl, $D8A4
	ld	de, $780C
	ld	bc, $0820
	call	LABEL_3A57
	ld	hl, LongSharedExtra
	ld	de, $780C - 2 * LONG_XA
	ld	bc, $0800 + 2 * LONG_XA
	call	LABEL_3A57
.IF LONG_XB > 0
	ld	hl, LongSharedExtra2
	ld	de, $780C - 2 * LONG_X
	ld	bc, $0800 + 2 * LONG_XB
	call	LABEL_3A57
.ENDIF
	ret

; the top border; de comes back a row down at c6, where the stock rows begin
LongShopTop:
	ld	de, $780C - 2 * LONG_X
	ld	bc, (14 + LONG_X) * 256
	call	LongBorder
	ld	hl, 2 * LONG_X
	add	hl, de
	ex	de, hl
	ret

; the bottom border, de at c6 of its row
LongShopBottom:
	ld	hl, -2 * LONG_X
	add	hl, de
	ex	de, hl
	ld	bc, (14 + LONG_X) * 256 + 1
	jp	LongBorder

; item b's row c at de (c6): the frame and LONG_W cells. Returns with the VDP at c15 and
; interrupts off, as the stock row writer goes on
LongShopName:
	ld	a, b
	push	de
	call	LongItemPtr
	pop	de
	push	de
	ld	a, e
	sub	2 * LONG_X
	ld	e, a
	jr	nc, +
	dec	d
+:	di
	rst	$08
	call	LongRowCells
	pop	de
	ret

; ---------------------------------------------------------------- the inventory

; The inventory is LONG_X cells wider than the stock's (its right edge stays at c31): the top border,
; the money line, the NEXT rows (from 9 items), 8 items, the bottom border. The money line is
; the stock one (LABEL_35C4) drawn from c22, its left frame blanked, the new cells before it.

; LABEL_3521: the screen under it (the stock c22-c31 to $DC04, c18-c21 to LongSharedExtra,
; c16-c17 to LongSharedExtra2)
LongInvSave:
	ld	hl, $DC04
	ld	de, $78AC
	ld	bc, $1514
	call	LABEL_3AA6
	ld	hl, LongSharedExtra
	ld	de, $78AC - 2 * LONG_XA
	ld	bc, $1500 + 2 * LONG_XA
	call	LABEL_3AA6
.IF LONG_XB > 0
	ld	hl, LongSharedExtra2
	ld	de, $78AC - 2 * LONG_X
	ld	bc, $1500 + 2 * LONG_XB
	call	LABEL_3AA6
.ENDIF
	ret

; LABEL_3656: the screen back
LongInvRestore:
	ld	hl, $DC04
	ld	de, $78AC
	ld	bc, $1514
	call	LABEL_3A57
	ld	hl, LongSharedExtra
	ld	de, $78AC - 2 * LONG_XA
	ld	bc, $1500 + 2 * LONG_XA
	call	LABEL_3A57
.IF LONG_XB > 0
	ld	hl, LongSharedExtra2
	ld	de, $78AC - 2 * LONG_X
	ld	bc, $1500 + 2 * LONG_XB
	call	LABEL_3A57
.ENDIF
	ret

; LABEL_352D: the inventory's contents
LongInventory:
.IF vwf_windows == 1
	call	WinToTopMark		; vwf_windows: a page drawn again takes the same tiles
.ENDIF
	ld	de, $78AC - 2 * LONG_X
	ld	bc, LONG_W * 256
	call	LongBorder
	; the money line
	push	de
	di
	rst	$08
	ld	a, $F3
	out	(Port_VDPData), a
	push	af
	pop	af
	ld	a, $11
	out	(Port_VDPData), a
	ld	b, LONG_X - 1
-:	ld	a, $C0
	out	(Port_VDPData), a
	push	af
	pop	af
	ld	a, $10
	out	(Port_VDPData), a
	djnz	-
	ei
	pop	de
	push	de
	ld	hl, 2 * LONG_X
	add	hl, de
	ex	de, hl
	call	LABEL_35C4		; c22-c31, de a row down
	pop	de
	push	de
	ld	hl, 2 * LONG_X
	add	hl, de
	ex	de, hl
	di
	rst	$08			; its left frame, c22, blank
	ld	a, $C0
	out	(Port_VDPData), a
	push	af
	pop	af
	ld	a, $10
	out	(Port_VDPData), a
	ei
	pop	de
	ld	hl, $0040
	add	hl, de
	ex	de, hl			; the row below the money line
	ld	a, (Inventory_curr_num)
	cp	9
	jr	c, +
	ld	hl, LongNextRows
	ld	bc, $0200 + 2 * (10 + LONG_X)
	call	LABEL_3A68
+:	ld	a, ($C299)
	ld	hl, Inventory
	add	a, l
	ld	l, a
	ld	b, 8
-:	push	bc
	push	hl
	ld	a, (hl)
	push	de
	call	LongItemPtr
	pop	de
	ld	c, 0
	call	LongRowName
	ld	c, 1
	call	LongRowName
	pop	hl
	inc	hl
	pop	bc
	djnz	-
	ld	bc, LONG_W * 256 + 1
	jp	LongBorder

.include "ext\longitems_data.asm"
