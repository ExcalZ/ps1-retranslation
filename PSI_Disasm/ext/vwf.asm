; vwf_dialogue: the dialogue window in the series' proportional face (docs/pipeline.md 6).
;
; Bank 35, reached through FarCall from VwfGate (bank 0, in the stock number printer's bytes).
; Each line of the window owns 10 tiles - 80 px: line set 0 is tiles $EC-$F5, set 1 $F6-$FF,
; the only tiles no screen that shows the window uses (work/scripts/vramaudit.lua). A new line
; takes the set the line above does not show: the stock scroll moves the nametable entries of
; line 2 up into line 1, so line 1 keeps its tiles and the new line 2 reuses the other set.
;
; The stock printer still does everything else: the controls, the waits, the scroll, the
; inserts, the dictionary words. Every character it would draw on the window's two text rows
; comes here instead. The stock's own state is respected: de is the line's cell address (its
; upper row: $7CCE line 1, $7D4E line 2), c the line index; b is $12 right after the stock
; starts a line (LABEL_31F4, LABEL_3235), and VwfChar turns it to $11, so the stock never
; counts down to its 18-cell wrap (vwf_dialogue lines are measured in pixels by linecheck).
;
; A glyph is drawn into VwfRow (the 1 bpp rows of the tile under the pen) shifted to the pen,
; the bits that cross into the next tile into VwfSpill; the tile (and the next) are uploaded as
; the stock font draws: plane 0 the background (colour 1), plane 1 the ink (colour 2).

.define VWF_TILES	10		; tiles a line owns: 80 px
.define VWF_SET0	$EC		; set 0 $EC-$F5, set 1 $F6-$FF

VwfChar:
	push	de
	push	hl
	ld	a, b
	cp	$12
	call	z, VwfNewLine
	ld	b, $11
	ld	a, (VwfCharIn)
	call	VwfDraw
	pop	hl
	pop	de
	ret

; {NUMBER}: CurrentDialogueNumber in decimal, no leading zeros, a frame a digit as the stock
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

; a = the first tile of the current line's set
VwfSetBase:
	ld	a, (VwfSet)
	or	a
	ld	a, VWF_SET0
	ret	z
	ld	a, VWF_SET0 + VWF_TILES
	ret

; a new line at de: choose its set, clear its tiles, point the line's lower row at them
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
	xor	a
	ld	(VwfPen), a
	ld	hl, VwfRow
	ld	b, 16
-:	ld	(hl), a
	inc	hl
	djnz	-
	; clear the set's tiles: VRAM = tile * 32
	call	VwfSetBase
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
	di
	rst	$08
	ld	b, VWF_TILES * 8
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
	; the line's lower row (de + $40) shows the set's tiles
	pop	de
	push	de
	ld	hl, $0040
	add	hl, de
	ex	de, hl
	di
	rst	$08
	call	VwfSetBase
	ld	l, a
	ld	b, VWF_TILES
-:	ld	a, l
	out	(Port_VDPData), a
	push	af
	pop	af
	ld	a, $10
	out	(Port_VDPData), a
	inc	l
	djnz	-
	ei
	pop	de
	pop	bc
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
	ld	a, (VwfPen)
	cp	VWF_TILES * 8
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
	rrca
	rrca
	rrca
	and	$1F
	ld	b, a			; b = the tile's place in the line
	call	VwfSetBase
	add	a, b
	ld	c, a			; c = the tile
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
	jp	z, VwfDraw_End		; still in the same tile
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
	ld	a, (VwfPen)
	cp	VWF_TILES * 8
	jp	nc, VwfDraw_End
	rrca
	rrca
	rrca
	and	$1F
	ld	b, a
	call	VwfSetBase
	add	a, b
	ld	c, a
	ld	hl, VwfRow
	call	VwfUpload
VwfDraw_End:
	pop	bc
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
