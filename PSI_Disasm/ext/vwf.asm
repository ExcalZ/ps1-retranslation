; vwf_dialogue and vwf_cutscene: the series' proportional face in the dialogue window and in
; the cut-scenes (docs/pipeline.md 6).
;
; Bank 35, reached through FarCall from VwfGate (bank 0, in the stock number printer's bytes):
; every character the stock printers would draw on rows 16-23 comes here. The upper row of the
; cell (de) tells the two apart: rows 19 and 21 (bit 6 of e set) are the dialogue window's
; lines, rows 16, 18, 20 and 22 the cut-scene printer's.
;
; Dialogue window: each line owns 10 tiles - 80 px. Set 0 is tiles $EC-$F5, set 1 $F6-$FF, the
; only tiles no screen that shows the window uses (work/scripts/vramaudit.lua). A new line takes
; the set the line above does not show: the stock scroll moves the nametable entries of line 2
; up into line 1, so line 1 keeps its tiles and the new line 2 reuses the other set. The stock
; marks a new line with b = $12 (LABEL_31F4, LABEL_3235); VwfChar turns it to $11, so the stock
; never counts down to its 18-cell wrap.
;
; Cut-scenes: no menu, status or list shares the screen, so the font area is free while one is
; up: line k (0-3) owns tiles $C1 + 15k, 15 tiles - 120 px. $C0 stays the blank the windows
; fill with. The cut-scene printer sets bc to 0 at its entry, at a new line and after a page,
; so b = 0 marks a new line here. VwfCutDirty asks VwfFadeWait (bank 0) to load the stock font
; back when the screen next fades out.
;
; The stock printers still do everything else: the controls, the waits, the scroll, the
; inserts, the dictionary words. A glyph is drawn into VwfRow (the 1 bpp rows of the tile under
; the pen) shifted to the pen, the bits that cross into the next tile into VwfSpill; the tiles
; are uploaded as the stock font draws: plane 0 the background (colour 1), plane 1 the ink.

.define VWF_TILES	10		; tiles a window line owns: 80 px
.define VWF_SET0	$EC		; window set 0 $EC-$F5, set 1 $F6-$FF
.define VWF_CUT_TILES	15		; tiles a cut-scene line owns: 120 px
.define VWF_CUT0	$C1		; cut-scene line k: $C1 + 15k

VwfChar:
	push	de
	push	hl
	bit	6, e
	jr	z, VwfChar_Cut
	ld	a, b
	cp	$12
	call	z, VwfNewLine
	ld	b, $11
	jr	VwfChar_Draw
VwfChar_Cut:
	ld	a, b
	or	a
	call	z, VwfCutNewLine
	ld	b, $11
VwfChar_Draw:
	ld	a, (VwfCharIn)
	call	VwfDraw
	pop	hl
	pop	de
	ret

; {NUMBER} in the window: CurrentDialogueNumber in decimal, no leading zeros, a frame a digit
VwfNumber:
	push	de
	ld	a, b
	cp	$12
	call	z, VwfNewLine
	ld	b, $11
	push	bc
	ld	hl, (CurrentDialogueNumber)
	ld	de, VwfDigits
	ld	bc, 10000
	call	VwfDigit
	ld	bc, 1000
	call	VwfDigit
	ld	bc, 100
	call	VwfDigit
	ld	bc, 10
	call	VwfDigit
	ld	a, l
	add	a, $30
	ld	(de), a
	; draw from the first non-zero digit (the last one always)
	ld	hl, VwfDigits
	ld	b, 4
-:	ld	a, (hl)
	cp	$30
	jr	nz, +
	inc	hl
	djnz	-
+:	inc	b
-:	ld	a, (hl)
	push	bc
	push	hl
	call	VwfDraw
	ld	a, $0A
	call	WaitForVInt
	pop	hl
	pop	bc
	inc	hl
	djnz	-
	pop	bc
	pop	de
	ret

; one decimal digit of hl by bc into (de), hl the rest
VwfDigit:
	ld	a, $2F
-:	inc	a
	or	a
	sbc	hl, bc
	jr	nc, -
	add	hl, bc
	ld	(de), a
	inc	de
	ret

; a new window line at de: choose its set, then start the line
VwfNewLine:
	push	bc
	push	de
	ld	a, e
	cp	$CE
	jr	nz, +
	ld	a, d
	cp	$7C
	jr	nz, +
	xor	a			; line 1 of a fresh window: set 0
	jr	++
+:	ld	a, (VwfSet)		; a later line: the other set
	xor	1
++:	ld	(VwfSet), a
	or	a
	ld	a, VWF_SET0
	jr	z, +
	ld	a, VWF_SET0 + VWF_TILES
+:	ld	(VwfBase), a
	ld	a, VWF_TILES * 8
	ld	(VwfLimit), a
	ld	b, VWF_TILES
	call	VwfStartLine
	pop	de
	pop	bc
	ret

; a new cut-scene line at de (upper row 16, 18, 20 or 22): its tiles, then start the line
VwfCutNewLine:
	push	bc
	push	de
	ld	a, d			; k = 2 * (d - $7C) + (e >= $80)
	sub	$7C
	add	a, a
	bit	7, e
	jr	z, +
	inc	a
+:	ld	b, a			; base = $C1 + 15k
	add	a, a
	add	a, a
	add	a, a
	add	a, a
	sub	b
	add	a, VWF_CUT0
	ld	(VwfBase), a
	ld	a, VWF_CUT_TILES * 8
	ld	(VwfLimit), a
	ld	a, 1
	ld	(VwfCutDirty), a
	ld	b, VWF_CUT_TILES
	call	VwfStartLine
	pop	de
	pop	bc
	ret

; start a line of b tiles from VwfBase at de (the line's upper row): pen 0, the tiles cleared,
; the lower row (de + $40) pointed at them
VwfStartLine:
	push	de
	push	bc
	xor	a
	ld	(VwfPen), a
	ld	hl, VwfRow
	ld	b, 16
-:	ld	(hl), a
	inc	hl
	djnz	-
	ld	a, (VwfBase)
	ld	l, a
	ld	h, 0
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	a, h
	or	$40
	ld	d, a
	ld	e, l
	pop	bc
	push	bc
	ld	a, b
	add	a, a
	add	a, a
	add	a, a
	ld	b, a			; 8 rows a tile
	di
	rst	$08
-:	ld	a, $FF
	out	(Port_VDPData), a
	push	af
	pop	af
	xor	a
	out	(Port_VDPData), a
	push	af
	pop	af
	out	(Port_VDPData), a
	push	af
	pop	af
	out	(Port_VDPData), a
	djnz	-
	ei
	pop	bc
	pop	de
	ld	hl, $0040
	add	hl, de
	ex	de, hl
	di
	rst	$08
	ld	a, (VwfBase)
	ld	l, a
-:	ld	a, l
	out	(Port_VDPData), a
	push	af
	pop	af
	ld	a, $10
	out	(Port_VDPData), a
	inc	l
	djnz	-
	ei
	ret

; draw code a at the pen
VwfDraw:
	push	bc
	sub	$20
	jp	c, VwfDraw_End		; below the face
	cp	$60
	jp	nc, VwfDraw_End
	ld	e, a
	ld	d, 0
	ld	hl, VwfAdvance
	add	hl, de
	ld	a, (hl)
	or	a
	jp	z, VwfDraw_End		; a code with no glyph
	ld	(VwfAdv), a
	ld	a, (VwfLimit)
	ld	b, a
	ld	a, (VwfPen)
	cp	b
	jp	nc, VwfDraw_End		; past the line's tiles: clipped (linecheck prevents it)
	ex	de, hl			; hl = index
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	de, VwfGlyphs
	add	hl, de			; hl = the glyph's rows
	ld	a, (VwfPen)
	and	7
	ld	(VwfShift), a
	ld	de, VwfRow
	ld	b, 8
VwfDraw_Row:
	push	bc
	ld	a, (VwfShift)
	ld	b, a
	inc	b
	ld	a, (hl)			; the glyph row
	ld	c, 0			; the bits that cross into the next tile
	jr	+
-:	srl	a
	rr	c
+:	djnz	-
	ex	de, hl
	or	(hl)
	ld	(hl), a			; VwfRow |= row >> shift
	ld	a, l
	add	a, 8
	ld	l, a
	ld	(hl), c			; VwfSpill = row << (8 - shift)
	sub	7
	ld	l, a			; the next VwfRow
	ex	de, hl
	inc	hl
	pop	bc
	djnz	VwfDraw_Row
	; upload the tile under the pen
	ld	a, (VwfPen)
	call	VwfTileAt
	ld	hl, VwfRow
	call	VwfUpload
	; the pen moves on; if it leaves the tile, the spilled bits are the next tile's
	ld	a, (VwfPen)
	ld	d, a
	ld	a, (VwfAdv)
	add	a, d
	ld	(VwfPen), a
	xor	d
	and	$F8
	jr	z, VwfDraw_End		; still in the same tile
	ld	hl, VwfRow + 8
	ld	de, VwfRow
	ld	bc, 8
	ldir				; VwfRow = VwfSpill
	ld	hl, VwfRow + 8
	ld	b, 8
	xor	a
-:	ld	(hl), a
	inc	hl
	djnz	-
	ld	a, (VwfLimit)
	ld	b, a
	ld	a, (VwfPen)
	cp	b
	jr	nc, VwfDraw_End
	call	VwfTileAt
	ld	hl, VwfRow
	call	VwfUpload
VwfDraw_End:
	pop	bc
	ret

; c = the tile at pen a
VwfTileAt:
	rrca
	rrca
	rrca
	and	$1F
	ld	c, a
	ld	a, (VwfBase)
	add	a, c
	ld	c, a
	ret

; upload 8 rows at hl as tile c: plane 0 the background, plane 1 the ink
VwfUpload:
	push	hl
	ld	l, c
	ld	h, 0
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	a, h
	or	$40
	ld	d, a
	ld	e, l
	pop	hl
	di
	rst	$08
	ld	b, 8
-:	ld	a, (hl)
	cpl
	out	(Port_VDPData), a
	push	af
	pop	af
	ld	a, (hl)
	out	(Port_VDPData), a
	push	af
	pop	af
	xor	a
	out	(Port_VDPData), a
	push	af
	pop	af
	out	(Port_VDPData), a
	inc	hl
	djnz	-
	ei
	ret

.include "ext\vwffont.asm"
