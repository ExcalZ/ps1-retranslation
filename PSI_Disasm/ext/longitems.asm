; long_item_names: item and enemy names up to 14 characters (docs/pipeline.md 6). Bank 35,
; with the renderer (needs vwf_dialogue).
;
; The names are in ext/longitems_data.asm (gentext writes them from work/script.json):
; LongItems (65 x 14 bytes) and LongEnemies (75 x 14), the face's codes, $65-padded. The
; inserts {ITEM} and {ENEMY} draw them proportionally (VwfItem, VwfEnemy); the windows that
; list them draw them in the menus' fixed font, a-z as capitals (LongRowName, through the
; stock glyph table LABEL_7D17 in bank 1).
;
; Each window that lists names is 6 cells wider, to the left, its right edge where the stock
; has it: the battle's enemy name box at $7810 (r0 c8, 16 cells; the HP box stays at c24),
; the equipment box at $7A80 (r10 c0, 16 cells; the status window stays at c16). The callers'
; stock buffers still take the stock columns; of the 6 new columns the 4 beside the stock ones
; go to LongEnemyBoxExtra / LongSharedExtra and the 2 at the left edge to LongEnemyBoxExtra2 /
; LongSharedExtra2 (ext/vwf_ram.asm).

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

; one row of a name list: the left frame, the 14 codes at hl in row c, the right frame, at de;
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

; the left frame and the 14 codes at hl in row c, to the VDP (its address set, interrupts off)
LongRowCells:
	push	hl
	ld	a, $F3
	out	(Port_VDPData), a
	push	af
	pop	af
	ld	a, $11
	out	(Port_VDPData), a
	ld	b, 14
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
	ld	de, $7814
	ld	bc, $0408
	call	LABEL_3AA6
	ld	hl, LongEnemyBoxExtra2
	ld	de, $7810
	ld	bc, $0404
	call	LABEL_3AA6
	ld	hl, $D978
	ld	de, $7830
	ld	bc, $0A10
	jp	LABEL_3AA6

; LABEL_3105: the name box, 16 cells at $7810
LongEnemyBox:
	ld	de, $7810
	ld	bc, $0E00
	call	LongBorder
	push	de
	call	LongEnemyPtr
	pop	de
	ld	c, 0
	call	LongRowName
	ld	c, 1
	call	LongRowName		; (keeps hl)
	ld	bc, $0E01
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
	ld	de, $7814
	ld	bc, $0408
	call	LABEL_3A57
	ld	hl, LongEnemyBoxExtra2
	ld	de, $7810
	ld	bc, $0404
	jp	LABEL_3A57

; ---------------------------------------------------------------- the equipment box

; LABEL_3707: party member c's weapon, armour and shield, 16 cells at $7A80 (r10 c0)
LongEquipBox:
	push	bc
	ld	hl, $D928
	ld	de, $7A8C
	ld	bc, $0814
	call	LABEL_3AA6
	ld	hl, LongSharedExtra
	ld	de, $7A84
	ld	bc, $0808
	call	LABEL_3AA6
	ld	hl, LongSharedExtra2
	ld	de, $7A80
	ld	bc, $0804
	call	LABEL_3AA6
	pop	bc
	ld	a, c			; Char_stats + 16 * member + weapon
	add	a, a
	add	a, a
	add	a, a
	add	a, a
	add	a, weapon
	ld	l, a
	ld	h, Char_stats >> 8
	ld	de, $7A80
	ld	bc, $0E00
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
	ld	bc, $0E01
	jp	LongBorder

; LABEL_374D: the screen back under the equipment box
LongEquipBoxRestore:
	ld	hl, $D928
	ld	de, $7A8C
	ld	bc, $0814
	call	LABEL_3A57
	ld	hl, LongSharedExtra
	ld	de, $7A84
	ld	bc, $0808
	call	LABEL_3A57
	ld	hl, LongSharedExtra2
	ld	de, $7A80
	ld	bc, $0804
	jp	LABEL_3A57

; ---------------------------------------------------------------- the shop list

; The shop list is 22 cells at $7800 (r0 c0; the money box stays at c22). Its rows are still
; written by the stock code (LABEL_38D9's row writer): LongShopName writes the left frame and
; 14 name cells from 6 cells left of the stock's place, and the stock writes on from c15 - the
; blank, the price, the right frame - where it would have after its 8 name cells.

; LABEL_38CD: the screen under it (the stock c6-c21 to $D8A4, c2-c5 to LongSharedExtra, c0-c1
; to LongSharedExtra2)
LongShopSave:
	ld	hl, $D8A4
	ld	de, $780C
	ld	bc, $0820
	call	LABEL_3AA6
	ld	hl, LongSharedExtra
	ld	de, $7804
	ld	bc, $0808
	call	LABEL_3AA6
	ld	hl, LongSharedExtra2
	ld	de, $7800
	ld	bc, $0804
	jp	LABEL_3AA6

; LABEL_3999: the screen back
LongShopRestore:
	ld	hl, $D8A4
	ld	de, $780C
	ld	bc, $0820
	call	LABEL_3A57
	ld	hl, LongSharedExtra
	ld	de, $7804
	ld	bc, $0808
	call	LABEL_3A57
	ld	hl, LongSharedExtra2
	ld	de, $7800
	ld	bc, $0804
	jp	LABEL_3A57

; the top border; de comes back a row down at c6, where the stock rows begin
LongShopTop:
	ld	de, $7800
	ld	bc, $1400
	call	LongBorder
	ld	hl, 12
	add	hl, de
	ex	de, hl
	ret

; the bottom border, de at c6 of its row
LongShopBottom:
	ld	hl, -12
	add	hl, de
	ex	de, hl
	ld	bc, $1401
	jp	LongBorder

; item b's row c at de (c6): the frame and 14 cells from c0. Returns with the VDP at c15 and
; interrupts off, as the stock row writer goes on
LongShopName:
	ld	a, b
	push	de
	call	LongItemPtr
	pop	de
	push	de
	ld	a, e
	sub	12
	ld	e, a
	jr	nc, +
	dec	d
+:	di
	rst	$08
	call	LongRowCells
	pop	de
	ret

; ---------------------------------------------------------------- the inventory

; The inventory is 16 cells at $78A0 (r2 c16; its right edge stays at c31): the top border,
; the money line, the NEXT rows (from 9 items), 8 items, the bottom border. The money line is
; the stock one (LABEL_35C4) drawn from c22, its left frame blanked, the 6 new cells before it.

; LABEL_3521: the screen under it (the stock c22-c31 to $DC04, c18-c21 to LongSharedExtra,
; c16-c17 to LongSharedExtra2)
LongInvSave:
	ld	hl, $DC04
	ld	de, $78AC
	ld	bc, $1514
	call	LABEL_3AA6
	ld	hl, LongSharedExtra
	ld	de, $78A4
	ld	bc, $1508
	call	LABEL_3AA6
	ld	hl, LongSharedExtra2
	ld	de, $78A0
	ld	bc, $1504
	jp	LABEL_3AA6

; LABEL_3656: the screen back
LongInvRestore:
	ld	hl, $DC04
	ld	de, $78AC
	ld	bc, $1514
	call	LABEL_3A57
	ld	hl, LongSharedExtra
	ld	de, $78A4
	ld	bc, $1508
	call	LABEL_3A57
	ld	hl, LongSharedExtra2
	ld	de, $78A0
	ld	bc, $1504
	jp	LABEL_3A57

; LABEL_352D: the inventory's contents
LongInventory:
	ld	de, $78A0
	ld	bc, $0E00
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
	ld	b, 5
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
	ld	hl, 12
	add	hl, de
	ex	de, hl
	call	LABEL_35C4		; c22-c31, de a row down
	pop	de
	push	de
	ld	hl, 12
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
	ex	de, hl			; c16, the row below the money line
	ld	a, (Inventory_curr_num)
	cp	9
	jr	c, +
	ld	hl, LongNextRows
	ld	bc, $0220
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
	ld	bc, $0E01
	jp	LongBorder

.include "ext\longitems_data.asm"
