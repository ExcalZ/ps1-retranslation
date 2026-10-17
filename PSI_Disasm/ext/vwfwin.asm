; vwf_windows: every window's text in the series face (docs/pipeline.md 6). Bank 35, with the
; renderer (needs vwf_cutscene, long_names and long_item_names).
;
; A window map marks a text run: its first cell is (string id, attribute $30), each further
; cell the run owns (0, $30) - attribute bit 5, which the VDP ignores. The stock map copy calls
; WinRowCheck (bank 0) for each row (LABEL_3A68, LABEL_3A8D): a row with a mark comes here
; (WinRow), which writes its cells and draws each run in the face into tiles of the screen's
; pool; any other row the stock copies. Window code of our own (the name lists) draws its
; names with WinRun directly. String ids: WinStrings (ext/vwfwin_data.asm, from gentext),
; $F0-$F3 the party's names (LongNames).
;
; The pool: tiles the screen leaves free while windows are up (WinPools), in order. In a battle
; the font's letters and the tiles above the enemy's graphics to $19F, none of which a round
; touches ($1FF is no use: the sprite table's upload writes it every frame), then the effects' $1A0-$1BF
; and the dialogue's $EC-$FF, which only a list open between rounds reaches. On the interaction
; screen the tiles above the person's graphics to $1A9, then $1B0-$1BF, then the letters. In a
; dungeon $101-$1BF (the still view shows none of them; a step draws them anew), then the
; letters. Elsewhere none: a run falls back to the stock capitals. The tops of the enemies' and
; people's graphics: ext/vwfwin_tops.asm (tools/vwfwin_tops.py).
;
; A window takes tiles from WinPos up. The screen save under a window (LABEL_3AA6 -> WinSave)
; records WinPos with its buffer; that buffer coming back (a map row from RAM -> WinRow) gives
; the tiles taken since back. A new screen (kind, enemy or person) starts the pool afresh.
; Letters lent come back at the next fade-out (VwfFadeWait, WinFontDirty).

; ---------------------------------------------------------------- the pool

; the screen's pool: on a new screen WinPos and the marks start afresh
WinEnsurePool:
	push	bc
	push	de
	push	hl
	ld	a, (Game_mode)
	and	$1F
	ld	bc, $0000		; c: the kind (0 none), b: the enemy or person
	cp	$0B
	jr	nz, +
	ld	c, 3			; a dungeon
	jr	WinEP_Key
+:	cp	$0C
	jr	c, WinEP_Key
	cp	$0E
	jr	nc, WinEP_Key
	ld	a, ($C29D)
	or	a
	jr	z, +
	ld	c, 1			; a battle: its enemy
	ld	a, ($C2E6)
	and	$7F
	ld	b, a
	jr	WinEP_Key
+:	ld	c, 2			; the interaction screen: its person
	ld	a, ($C2DC)
	ld	b, a
WinEP_Key:
	ld	a, (WinKind)
	cp	c
	jr	nz, +
	ld	a, (WinKeyId)
	cp	b
	jr	z, WinEP_End
+:	ld	a, c
	ld	(WinKind), a
	ld	a, b
	ld	(WinKeyId), a
	xor	a
	ld	(WinPos), a
	ld	(WinDepth), a
	ld	hl, WinEnemyTops
	ld	a, c
	cp	1
	jr	z, +
	ld	hl, WinPersonTops
	ld	a, b
	cp	WinPersonCount
	jr	c, +
	ld	a, $AA			; a person past the table: no tiles above it
	jr	++
+:	ld	e, b
	ld	d, 0
	add	hl, de
	ld	a, (hl)
++:	ld	(WinDyn), a
WinEP_End:
	pop	hl
	pop	de
	pop	bc
	ret

; hl = the tile at pool position a; carry if the pool has none there
WinPoolTile:
	push	bc
	push	de
	ld	c, a
	ld	a, (WinKind)
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, WinPools
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a			; the kind's ranges: first tile (2 bytes), last tile's low byte
WinPT_Range:
	ld	e, (hl)
	inc	hl
	ld	d, (hl)
	inc	hl
	ld	a, d
	or	e
	jr	z, WinPT_None		; the end
	ld	a, d
	inc	a
	jr	nz, +
	ld	a, (WinDyn)		; $FFFF: above the enemy's or person's graphics
	ld	e, a
	ld	d, 1
+:	ld	a, (hl)
	inc	hl
	sub	e
	jr	c, WinPT_Range		; empty
	inc	a
	ld	b, a			; the range's count
	ld	a, c
	cp	b
	jr	c, +
	sub	b
	ld	c, a
	jr	WinPT_Range
+:	add	a, e
	ld	l, a
	ld	h, d
	pop	de
	pop	bc
	or	a
	ret
WinPT_None:
	pop	de
	pop	bc
	scf
	ret

WinPools:
.dw	WinPoolNone, WinPoolBattle, WinPoolField, WinPoolDungeon
WinPoolNone:
.dw	0
WinPoolBattle:
.dw	$00CB
.db	$EB			; the letters and marks
.dw	$FFFF
.db	$9F			; above the enemy
.dw	$01A0
.db	$BF			; the effects' (a list between rounds only)
.dw	$00EC
.db	$FF			; the dialogue's (likewise)
.dw	0
WinPoolField:
.dw	$FFFF
.db	$A9			; above the person
.dw	$01B0
.db	$BF
.dw	$00CB
.db	$EB
.dw	0
WinPoolDungeon:
.dw	$0101
.db	$BF
.dw	$00CB
.db	$EB
.dw	0

; a font letter lent (tile hl): the font comes back at the next fade-out
WinFontNote:
	ld	a, h
	or	a
	ret	nz
	ld	a, l
	cp	$CB
	ret	c
	cp	$EC
	ret	nc
	ld	a, 1
	ld	(WinFontDirty), a
	ret

; ---------------------------------------------------------------- the marks

; a buffer's key: its address's low byte xor its high byte (one byte, and no two of the
; buffers the windows save to share one: $D700-$DE64, $DF20, $DFC8, $DFE8, $C790, $DEA0-$DEE8)
WinKeyOf:
	ld	a, l
	xor	h
	ret

; LABEL_3AA6 (WinSaveHook): the screen under a window (b rows from VRAM de) is saved to the
; buffer at WinSrc. Its mark: the key and WinPos. The rows join the region saved last (a
; run drawn there is a new window over an old one: it takes new tiles).
WinSave:
	push	bc
	push	de
	call	WinEnsurePool
	; the region saved last: these rows, with any saved just before them
	ld	h, b
	ld	l, 0
	srl	h
	rr	l
	srl	h
	rr	l			; b * $40
	add	hl, de			; the end
	ld	a, (WinLastSave)
	or	a
	jr	z, WinSave_New
	push	hl			; consecutive saves: the region grows to cover both
	ld	hl, (WinFreshLo)
	or	a
	sbc	hl, de			; old start - new start
	pop	hl
	jr	c, +			; the old start is lower: kept
	ld	(WinFreshLo), de
+:	push	de
	ld	de, (WinFreshHi)
	push	hl
	or	a
	sbc	hl, de			; new end - old end
	pop	hl
	pop	de
	jr	c, WinSave_Mark		; the old end is higher: kept
	ld	(WinFreshHi), hl
	jr	WinSave_Mark
WinSave_New:
	ld	(WinFreshLo), de
	ld	(WinFreshHi), hl
WinSave_Mark:
	ld	a, 1
	ld	(WinLastSave), a
	; the mark
	ld	a, (WinDepth)
	cp	WIN_MARKS
	jr	nc, +			; too deep: this window's tiles stay taken until the screen ends
	ld	c, a
	inc	a
	ld	(WinDepth), a
	ld	hl, (WinSrc)
	call	WinKeyOf
	ld	b, a
	ld	a, c
	add	a, a
	ld	e, a
	ld	d, 0
	ld	hl, WinMarks
	add	hl, de
	ld	(hl), b
	inc	hl
	ld	a, (WinPos)
	ld	(hl), a
+:	pop	de
	pop	bc
	ret

; the buffer at hl comes back. Its mark on top (windows close in the order they opened): WinPos
; back to what it was when the buffer was saved. A mark lower down (a window restored while
; later ones stay up): only that mark goes, so no tile a window still shows is given back; its
; own tiles come back when a window under it closes.
WinRelease:
	call	WinKeyOf
	ld	e, a
	ld	a, (WinDepth)
	or	a
	ret	z
	ld	c, a
WinRel_Next:
	dec	c			; from the top down
	ld	a, c
	add	a, a
	ld	l, a
	ld	h, 0
	push	de
	ld	de, WinMarks
	add	hl, de
	pop	de
	ld	a, (hl)
	cp	e
	jr	z, WinRel_Found
	ld	a, c
	or	a
	jr	nz, WinRel_Next
	ret
WinRel_Found:
	inc	hl
	ld	b, (hl)			; its WinPos
	ld	a, (WinDepth)
	dec	a
	ld	(WinDepth), a
	cp	c
	jr	nz, WinRel_Drop
	ld	a, b			; the top mark: its tiles back
	ld	(WinPos), a
	ret
WinRel_Drop:
	sub	c			; the marks above it, moved down over it
	add	a, a
	ld	b, 0
	push	bc
	ld	c, a
	dec	hl			; its mark
	ld	d, h
	ld	e, l
	inc	hl
	inc	hl			; the one above
	ldir
	pop	bc
	ret

; WinPos back to the top mark's (a window drawing its contents again in place)
WinToTopMark:
	ld	a, (WinDepth)
	or	a
	ret	z
	add	a, a
	dec	a
	ld	e, a
	ld	d, 0
	ld	hl, WinMarks
	add	hl, de
	ld	a, (hl)
	ld	(WinPos), a
	ret

; ---------------------------------------------------------------- the money line

; LABEL_35C4 (the money box, the inventory: b = 8) and LABEL_35BC (the status window: b = 12)
; via WinMoneyHook, the VDP at the line's first cell (de), interrupts off: the left frame, then
; the label and the amount ("Meseta 2000", WinMoneyString then the digits without leading
; zeros) in the face over the 8 or 10 cells the stock gives the label and the digits. Returns
; with the VDP at the right frame's cell, interrupts off, as the stock's digits leave it.
WinMoney:
	ld	a, b
	cp	8
	ld	b, 8
	jr	z, +
	ld	b, 10
+:	push	bc
	ld	a, $F3			; the left frame
	out	(Port_VDPData), a
	push	af
	pop	af
	ld	a, $11
	out	(Port_VDPData), a
	ei
	push	de
	ld	hl, (Current_money)
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
	pop	de
	ld	hl, VwfDigits		; from the first digit that is not 0 (the last always)
	ld	b, 5
-:	ld	a, (hl)
	cp	$30
	jr	nz, +
	inc	hl
	djnz	-
	dec	hl
	inc	b
+:	ld	(WinCont), hl
	ld	a, b
	ld	(WinContN), a
	pop	bc
	inc	de
	inc	de			; past the frame
	ld	hl, WinMoneyString
	ld	c, $FF
	call	WinRun
	di
	rst	$08			; the right frame's cell
	ret

; ---------------------------------------------------------------- the status window's labels

; LABEL_2FD8 (WinLabelHook): the label's 8 cells at WinSrc (bank 0: the frame, then a marked run
; of 7, gentext) at de: the frame, then the run in the face; a row without a mark (the LV row,
; LABEL_3865) as the stock writes it. Returns with the VDP past the label
; and interrupts off, as the stock's 16 bytes leave it for the digits.
WinLabel:
	call	WinEnsurePool
	ld	hl, (WinSrc)
	inc	hl
	inc	hl
	inc	hl
	bit	5, (hl)			; the second cell's attribute: a marked run?
	ld	hl, (WinSrc)
	jr	nz, WinLabel_Face
	di				; no (the LV row): its 16 bytes, as the stock writes them
	rst	$08
	ld	b, 16
-:	ld	a, (hl)
	out	(Port_VDPData), a
	inc	hl
	djnz	-
	ret
WinLabel_Face:
	ld	c, (hl)
	inc	hl
	ld	b, (hl)
	inc	hl
	call	WinCell			; the frame
	ld	a, (hl)
	call	WinStrPtr
	ld	b, 7
	call	WinRun
	di
	rst	$08
	ret

; ---------------------------------------------------------------- the spell lists

; LABEL_3478: list WinSpellListA (a character's battle or field spells) with b of them, one cell
; wider than the stock's 6 so a name in the face may take 5 cells: WinSpellMaps, 12 rows of 7
; cells a list, and WinSpellBlank for the rows past the spells (ext/vwfwin_data.asm, gentext,
; from bank 27's maps). The screen under it: the stock buffer $DB74 for the stock columns,
; WinSpellExtra for the new one at c12.
WinSpellList:
	push	bc
	ld	hl, $DB74
	ld	de, $7A0C
	ld	bc, $0C0C
	call	LABEL_3AA6
	ld	hl, WinSpellExtra
	ld	de, $7A18
	ld	bc, $0C02
	call	LABEL_3AA6
	pop	bc
	ld	a, (WinSpellListA)
	ld	l, a
	ld	h, 0
	ld	d, h
	ld	e, l
	add	hl, hl
	add	hl, hl
	add	hl, de			; 5a
	add	hl, hl
	add	hl, hl
	add	hl, de			; 21a
	add	hl, hl
	add	hl, hl
	add	hl, hl			; 168a: 12 rows of 14 bytes
	ld	de, WinSpellMaps
	add	hl, de
	ld	de, $7A0C
	ld	a, b
	or	a
	jr	z, WinSpellList_None
	add	a, a
	inc	a
	ld	b, a			; the top border, then two rows a spell
	ld	c, 14
	push	bc
	call	LABEL_3A68
	pop	bc
	push	de			; the rest from the blank list, the same rows on
	ld	l, b
	ld	h, 0
	add	hl, hl
	ld	d, h
	ld	e, l
	add	hl, hl
	add	hl, hl
	add	hl, hl
	or	a
	sbc	hl, de			; 14 bytes a row
	ld	de, WinSpellBlank
	add	hl, de
	pop	de
	ld	a, 12
	sub	b
	ld	b, a
	ld	c, 14
	jp	LABEL_3A68
WinSpellList_None:
	ld	hl, WinSpellBlank
	ld	bc, $0C0E
	jp	LABEL_3A68

; LABEL_34C9: the screen back under the spell list
WinSpellRestore:
	ld	hl, $DB74
	ld	de, $7A0C
	ld	bc, $0C0C
	call	LABEL_3A57
	ld	hl, WinSpellExtra
	ld	de, $7A18
	ld	bc, $0C02
	jp	LABEL_3A57

; ---------------------------------------------------------------- map rows

; a map row (WinRowCheck): WinSrc in bank WinSrcBank, c bytes, de its VRAM address. A row from
; RAM is a saved screen coming back: the marks are released and the stock copies it (WinDone
; 0). Otherwise the row is written here, each run drawn in the face (WinDone 1, WinSrc past it).
WinRow:
	push	bc
	push	de
	xor	a
	ld	(WinDone), a
	ld	hl, (WinSrc)
	ld	a, h
	cp	$C0
	jr	c, +
	call	WinRelease
	jr	WinRow_End
+:	call	WinEnsurePool
	ld	a, 1
	ld	(WinDone), a
	ld	a, c
	srl	a
	ld	(WinLeft), a
WinRow_Cell:
	ld	a, (WinLeft)
	or	a
	jr	z, WinRow_End
	dec	a
	ld	(WinLeft), a
	call	WinSrcByte
	ld	c, a			; the tile (a run's string id)
	call	WinSrcByte		; the attribute
	bit	5, a
	jr	nz, WinRow_Run
	ld	b, a
	call	WinCell
	jr	WinRow_Cell
WinRow_Run:
	ld	a, c
	ld	(WinStrId), a
	ld	b, 1			; the cells the run owns
-:	ld	a, (WinLeft)
	or	a
	jr	z, +
	call	WinPeek
	jr	nz, +
	call	WinSrcByte
	call	WinSrcByte
	ld	hl, WinLeft
	dec	(hl)
	inc	b
	jr	-
+:	ld	a, (WinStrId)
	call	WinStrPtr		; (c: its length)
	call	WinRun
	jr	WinRow_Cell
WinRow_End:
	pop	de
	pop	bc
	ret

; a = the next source byte (WinSrc moves on)
WinSrcByte:
	push	hl
	ld	hl, (WinSrc)
	ld	a, (WinSrcBank)
	call	FarRead
	inc	hl
	ld	(WinSrc), hl
	pop	hl
	ret

; z if the next cell continues a run: (0, attribute bit 5)
WinPeek:
	push	hl
	ld	hl, (WinSrc)
	ld	a, (WinSrcBank)
	call	FarRead
	or	a
	jr	nz, +
	inc	hl
	ld	a, (WinSrcBank)
	call	FarRead
	and	$20
	xor	$20
+:	pop	hl
	ret

; hl = the codes of string a, c the most it has (a party name 6, a string $65-ended)
WinStrPtr:
	push	de
	ld	c, $FF
	cp	$F0
	jr	c, +
	ld	c, 6
	and	$03			; party member k: LongNames + 6k
	ld	l, a
	add	a, a
	add	a, l
	add	a, a
	ld	l, a
	ld	h, 0
	ld	de, LongNames
	add	hl, de
	pop	de
	ret
+:	ld	l, a
	ld	h, 0
	add	hl, hl
	ld	de, WinStrings
	add	hl, de
	ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	pop	de
	ret

; the cell (tile c, attribute b) at de; de moves on
WinCell:
	di
	rst	$08
	ld	a, c
	out	(Port_VDPData), a
	push	af
	pop	af
	ld	a, b
	out	(Port_VDPData), a
	ei
	inc	de
	inc	de
	ret

; the cell (tile hl) at de, attribute $30: a text cell (priority) and bit 5, which the VDP
; ignores and the map copy never sees (it scans maps in ROM, not saved screens), so the harness
; can tell the face's cells (work/scripts/lib.lua); de moves on
WinCellTile:
	di
	rst	$08
	ld	a, l
	out	(Port_VDPData), a
	push	af
	pop	af
	ld	a, h
	or	$30
	out	(Port_VDPData), a
	ei
	inc	de
	inc	de
	ret

; ---------------------------------------------------------------- a run

; the codes at hl (at most c of them; $65 ends them sooner) in the face over b cells at de, in
; tiles from the pool; de moves past the cells. A run drawn again in place (outside the region saved last) keeps the
; tiles its cells already show and takes new ones only for cells that had none. Out of tiles:
; the stock capitals instead.
WinRun:
	push	bc
	ld	(WinStr), hl
	ld	(WinRunVram), de
	ld	a, c
	ld	(WinJ), a		; the codes left
	ld	a, b
	ld	(WinCells), a
	add	a, a
	add	a, a
	add	a, a
	ld	(VwfLimit), a
	ld	a, (WinPos)
	ld	(WinP0), a
	; in place? (de outside the region saved last)
	push	hl
	ld	hl, (WinRunVram)
	ld	de, (WinFreshLo)
	or	a
	sbc	hl, de
	ld	a, 1
	jr	c, +			; below it
	ld	hl, (WinRunVram)
	ld	de, (WinFreshHi)
	or	a
	sbc	hl, de
	ld	a, 1
	jr	nc, +			; past it
	xor	a			; inside: a new window, new tiles
+:	ld	(WinReuse), a
	ld	de, (WinRunVram)
	xor	a
	ld	(WinLastSave), a
	ld	(WinNewMax), a
	ld	(VwfPen), a
	ld	hl, VwfRow
	ld	b, 16
-:	ld	(hl), a
	inc	hl
	djnz	-
	pop	hl
WinRun_Char:
	ld	a, (WinJ)
	or	a
	jr	z, WinRun_Next
	dec	a
	ld	(WinJ), a
	ld	a, (hl)
	cp	Dialogue_Terminator65
	jr	z, WinRun_Next
	push	hl
	push	de
	call	WinDraw
	pop	de
	pop	hl
	jr	c, WinRun_Fallback
	inc	hl
	jr	WinRun_Char
WinRun_Next:			; a second part (WinContN codes at WinCont) goes on at the pen
	ld	a, (WinContN)
	or	a
	jr	z, WinRun_Write
	ld	(WinJ), a
	xor	a
	ld	(WinContN), a
	ld	hl, (WinCont)
	jr	WinRun_Char
WinRun_Write:
	; the tiles the ink took: (pen - 1) / 8 + 1, none for an empty run
	ld	a, (VwfPen)
	or	a
	jr	z, +
	dec	a
	rrca
	rrca
	rrca
	and	$1F
	inc	a
+:	ld	(WinJ), a		; k
	ld	a, (WinCells)
	ld	b, a
	ld	c, 0			; the cell
-:	ld	a, (WinJ)
	cp	c
	jr	z, +
	jr	c, +
	push	bc
	call	WinTileFor
	call	WinFontNote
	call	WinCellTile
	pop	bc
	inc	c
	djnz	-
	jr	++
+:	push	bc
	ld	bc, $10C0		; the blank
	call	WinCell
	pop	bc
	inc	c
	djnz	-
++:	ld	a, (WinNewMax)		; the pool moves on by the new tiles only
	ld	b, a
	ld	a, (WinP0)
	add	a, b
	ld	(WinPos), a
	pop	bc
	ret
WinRun_Fallback:
	ld	de, (WinRunVram)
	ld	hl, (WinStr)
	ld	a, (WinCells)
	ld	b, a
-:	ld	a, (hl)
	cp	Dialogue_Terminator65
	jr	nz, +
	ld	a, $20
	dec	hl			; stay on the end
+:	inc	hl
	push	bc
	push	hl
	ld	c, 1
	call	LongGlyph
	ld	c, a
	ld	b, $10
	call	WinCell
	pop	hl
	pop	bc
	djnz	-
	ld	a, (WinP0)
	ld	(WinPos), a		; nothing taken
	pop	bc
	ret

; hl = the tile for the run's cell c; carry if the pool has none. In place, a cell already
; showing the face keeps its tile; any other takes pool position WinP0 + c.
WinTileFor:
	ld	a, (WinReuse)
	or	a
	jr	z, WinTF_New
	push	de
	ld	hl, (WinRunVram)
	ld	a, c
	add	a, a
	ld	e, a
	ld	d, 0
	add	hl, de
	ld	a, h
	and	$3F			; a read address
	di
	push	af
	ld	a, l
	out	(Port_VDPAddress), a
	pop	af
	out	(Port_VDPAddress), a
	push	af
	pop	af
	in	a, (Port_VDPData)
	ld	e, a
	push	af
	pop	af
	in	a, (Port_VDPData)
	ei
	bit	5, a
	jr	z, +
	and	1
	ld	h, a
	ld	l, e
	pop	de
	or	a
	ret
+:	pop	de
WinTF_New:
	ld	a, c
	inc	a
	push	hl
	ld	hl, WinNewMax
	cp	(hl)
	jr	c, +
	ld	(hl), a
+:	pop	hl
	ld	a, (WinP0)
	add	a, c
	jp	WinPoolTile

; draw code a at the pen into the run's tiles (VwfDraw's way); carry if the pool has no tile
WinDraw:
	sub	$20
	jp	c, WinDraw_Ok		; below the face
	cp	$60
	jp	nc, WinDraw_Ok
	ld	e, a
	ld	d, 0
	ld	hl, VwfAdvance
	add	hl, de
	ld	a, (hl)
	or	a
	jp	z, WinDraw_Ok		; a code with no glyph
	ld	(VwfAdv), a
	ld	a, (VwfLimit)
	ld	b, a
	ld	a, (VwfPen)
	cp	b
	jp	nc, WinDraw_Ok		; past the run: clipped (linecheck prevents it)
	ex	de, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	de, VwfGlyphs
	add	hl, de
	ld	a, (VwfPen)
	and	7
	ld	(VwfShift), a
	ld	de, VwfRow
	ld	b, 8
WinDraw_Row:
	push	bc
	ld	a, (VwfShift)
	ld	b, a
	inc	b
	ld	a, (hl)
	ld	c, 0
	jr	+
-:	srl	a
	rr	c
+:	djnz	-
	ex	de, hl
	or	(hl)
	ld	(hl), a
	ld	a, l
	add	a, 8
	ld	l, a
	ld	(hl), c
	sub	7
	ld	l, a
	ex	de, hl
	inc	hl
	pop	bc
	djnz	WinDraw_Row
	ld	a, (VwfPen)
	call	WinTileAt
	ret	c
	call	WinUploadRow
	ld	a, (VwfPen)
	ld	d, a
	ld	a, (VwfAdv)
	add	a, d
	ld	(VwfPen), a
	xor	d
	and	$F8
	jr	z, WinDraw_Ok		; still in the same tile
	ld	hl, VwfRow + 8
	ld	de, VwfRow
	ld	bc, 8
	ldir
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
	jr	nc, WinDraw_Ok
	call	WinTileAt
	ret	c
	call	WinUploadRow
WinDraw_Ok:
	or	a
	ret

; hl = the tile under pen a; carry if the pool has none
WinTileAt:
	rrca
	rrca
	rrca
	and	$1F
	ld	c, a
	jp	WinTileFor

; VwfRow uploaded as tile hl: plane 0 the background, plane 1 the ink
WinUploadRow:
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	a, h
	or	$40
	ld	d, a
	ld	e, l
	ld	hl, VwfRow
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

.include "ext\vwfwin_tops.asm"
.include "ext\vwfwin_data.asm"
