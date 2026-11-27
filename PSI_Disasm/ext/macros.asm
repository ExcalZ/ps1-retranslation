; battle_macros: the battle's commands with macros, as PS II's (docs/pipeline.md 6). Bank 35,
; with vwf_windows, whose runs and pool it draws in (needs vwf_windows).
;
; * Each round opens with one window at r1 c1: Command, Macro, Talk, Flee (MacroTopMap, 7 cells
;   wide). Command asks the members one by one as the stock does, Fight / Magic / Item
;   (MacroCmdMap; B on the first member goes back to the first window). Macro opens the slots
;   A-H (r1 c8) and, under them, the slot's commands (the preview, r11 c8): C on a slot that is
;   set gives each member its command and starts the round (MacroApply). Talk and Flee are the
;   stock's, by the first member who can act. A slot's letter is red when it is empty, amber
;   when a party member's line cannot be carried out as set (MacroLineEval: the member down, MP
;   short, the item gone, the target down; a line not set is Fight, white), and those lines are
;   amber in the preview:
;   window cells on the sprite palette, inked in its red 21 or amber 22 (WinInk).
; * The field menu has a fifth entry, Macro, before Save (MacroFieldMap, 13 rows): the slots and
;   the preview, then the members (the preview's lines), then Fight / Magic / Item (r1 c12),
;   the member's battle spells (the stock list) and whom a healing spell is for (the stock
;   party menu), or an item (the stock inventory).
; * A macro is 4 lines of 2 bytes (MacroData, ext/vwf_ram.asm), saved with the game. A slot with
;   every line 0 is empty. A line not set, or one its member cannot carry out (no spell there,
;   MP short, the item gone, the spell's target down, Chat or Tele), fights instead.
;
; Hooks (ps1.asm): the member's question in the round loop (LABEL_108A: MacroAsk, MacroResult),
; LABEL_30C3 (MacroMenuSave), LABEL_30E1 (MacroMenuRestore), the field menu's 6 entries and
; LABEL_36DD / LABEL_36EF / LABEL_36FB (MacroFieldOpen / Draw / Close).
;
; The battle's two windows share r1-r11 c1-c7, saved at the round's start in $D8A4 and
; MacroExtra. They keep MACRO_MENU_TILES pool tiles from MacroP0 for their runs: a change of
; window puts the screen back without giving the tiles back (MacroMenuRaw) and draws the new one
; on the same tiles. The preview likewise draws every line afresh from MacroPrevBase, the pool
; position its window was saved at, so a slot change takes no more tiles than its lines need.
; Window buffers: the slots $DB08, the preview $DA18 (the dialogue window's, closed first), the
; editor's commands $D928.

.include "ext\macros_data.asm"

.define MACRO_SLOTS_VRAM	$7850		; r1 c8: 10 rows x 3 cells
.define MACRO_PREV_VRAM		$7AD0		; r11 c8: 6 rows x 19 cells
.define MACRO_CMD_VRAM		$7858		; r1 c12: 7 rows x 6 cells (the editor)

; ---------------------------------------------------------------- the battle

; LABEL_30C3: the round's windows' screen saved (r1-r11 c1-c7) and their tiles kept
MacroMenuSave:
	ld	hl, $D8A4
	ld	de, $7842
	ld	bc, $0B0C
	call	LABEL_3AA6
	ld	hl, MacroExtra
	ld	de, $784E
	ld	bc, $0B02
	call	LABEL_3AA6
	ld	a, (WinPos)
	ld	(MacroP0), a
	add	a, MACRO_MENU_TILES
	ld	(WinPos), a
	xor	a
	ld	(MacroShown), a
	ld	(MacroInCmd), a
	ret

; LABEL_30E1: the screen back under them (the marks released, the top one first)
MacroMenuRestore:
	ld	hl, MacroExtra
	ld	de, $784E
	ld	bc, $0B02
	call	LABEL_3A57
	ld	hl, $D8A4
	ld	de, $7842
	ld	bc, $0B0C
	call	LABEL_3A57
	xor	a
	ld	(MacroShown), a
	ret

; the member $C267 can act: MacroResult the command (BattleMenu_OptionTbl: 0 Fight, 1 Magic,
; 2 Item, 3 Talk, 4 Run), $FF back to the member before, $FE every member's command set
MacroAsk:
	call	LABEL_3105		; the enemy's name box, as the stock does first
	ld	a, (MacroInCmd)
	or	a
	jr	nz, MacroAsk_Cmd
	call	MacroIsFirst
	jr	nz, MacroAsk_Command	; a member before this one acts: Command was chosen
MacroAsk_Top:
	ld	a, 1
	call	MacroMenuShow
	ld	hl, $7882
	ld	(Cursor_pos), hl
	ld	a, 3
	ld	(Option_total_num), a
	ld	a, (MacroTopLast)	; the cursor on the last choice (CheckOptionSelect's start)
	and	3
	ld	($C26B), a
	ld	($C26C), a
	ld	a, $FF
	ld	($C268), a
	xor	a
	ld	($C26D), a
	call	OptionSelect_Loop
	bit	Button_1, c
	jr	nz, MacroAsk_Top	; B: stays, as on the stock's first member
	ld	(MacroTopLast), a
	or	a
	jr	z, MacroAsk_Command
	dec	a
	jr	z, MacroAsk_Macro
	add	a, 2			; Talk 3, Run 4: the stock's, with the member's name box
	push	af
	call	LABEL_2EAC
	pop	af
	ld	(MacroResult), a
	ret
MacroAsk_Macro:
	call	MacroBattleSlots
	jr	nz, MacroAsk_Top
	ld	a, $FE
	ld	(MacroResult), a
	ret
MacroAsk_Command:
	ld	a, 1
	ld	(MacroInCmd), a
MacroAsk_Cmd:
	ld	a, 2
	call	MacroMenuShow
	call	LABEL_2EAC		; the member's name box
	ld	hl, $7882
	ld	(Cursor_pos), hl
	ld	a, 2
	ld	(Option_total_num), a
	call	CheckOptionSelect
	bit	Button_1, c
	jr	nz, MacroAsk_Back
	ld	(MacroResult), a
	ret
MacroAsk_Back:
	ld	a, $FF
	ld	(MacroResult), a
	call	MacroIsFirst
	ret	nz			; LABEL_1121: the name box back, the member before
	call	LABEL_2ECD
	xor	a
	ld	(MacroInCmd), a
	jr	MacroAsk_Top

; nz if member a acts this round, as the stock's round loop asks it (LABEL_1074, LABEL_108A):
; in the party and alive, HP left, not paralysed
MacroCanAct:
	call	IsCharacterAlive
	ret	z
	inc	hl
	ld	a, (hl)			; HP
	or	a
	ret	z
	ld	de, $000C
	add	hl, de
	ld	a, (hl)			; the rounds paralysed
	or	a
	jr	nz, +
	inc	a
	ret
+:	xor	a
	ret

; z if no member before $C267 acts (the round's first question)
MacroIsFirst:
	ld	a, ($C267)
	or	a
	ret	z
	ld	b, a
	ld	c, 0
-:	ld	a, c
	call	MacroCanAct
	ret	nz
	inc	c
	djnz	-
	xor	a
	ret

; window a (1 the first, 2 the commands) at r1 c1, its runs on the tiles from MacroP0. Another
; window up: the screen under it back first.
MacroMenuShow:
	ld	b, a
	ld	a, (MacroShown)
	or	a
	jr	z, +
	cp	b
	jr	z, +
	push	bc
	call	MacroMenuRaw
	pop	bc
+:	ld	a, b
	ld	(MacroShown), a
	call	VwfMenuFont
	ld	a, (MacroP0)
	ld	de, $7842
	ld	hl, $7842 + 11 * $40
	call	MacroPoolAt
	ld	a, (MacroShown)
	cp	1
	ld	hl, MacroTopMap
	ld	bc, $090E
	jr	z, +
	ld	hl, MacroCmdMap
	ld	bc, $070C
+:	ld	de, $7842
	call	LABEL_3A68
	jp	MacroPoolBack

; the screen saved under the battle's windows written back as it is (no marks released)
MacroMenuRaw:
	ld	hl, $D8A4
	ld	de, $7842
	ld	bc, $0B0C
	call	MacroRawRows
	ld	hl, MacroExtra
	ld	de, $784E
	ld	bc, $0B02
; b rows of c bytes from hl to VRAM de
MacroRawRows:
	push	bc
	push	de
	di
	rst	$08
	ld	b, c
-:	ld	a, (hl)
	out	(Port_VDPData), a
	inc	hl
	djnz	-
	ei
	pop	de
	ex	de, hl
	ld	bc, $0040
	add	hl, bc
	ex	de, hl
	pop	bc
	djnz	MacroRawRows
	ret

; Macro: the slots; z when one was used (the members' commands set, $C267 = 4)
MacroBattleSlots:
	call	MacroSlotsOpen
-:	ld	a, 1
	call	MacroSlotPick
	bit	Button_1, c
	jr	nz, +
	call	MacroSlotEmpty
	jr	z, -			; an empty slot does nothing
	call	MacroApply
	call	MacroSlotsClose
	xor	a
	ret
+:	call	MacroSlotsClose
	or	1
	ret

; each member who acts gets the slot's command (LABEL_1BB9's record), or Fight
MacroApply:
	xor	a
MacroApply_Next:
	ld	($C267), a
	call	MacroCanAct
	jr	z, +			; as the stock skips them
	call	MacroLineEval
	call	LABEL_1BB9
+:	ld	a, ($C267)
	inc	a
	cp	4
	jr	c, MacroApply_Next
	ld	($C267), a
	ret

; member ($C267)'s line of slot MacroSlot as LABEL_1BB9 records it: c the command, b the spell
; or item, a the third byte; carry if it cannot be carried out as set (no spell at that place,
; Chat or Tele, MP short, the target down, the item not held): then Fight. A line not set
; fights, with no carry (it is not amber).
MacroLineEval:
	ld	a, ($C267)
	call	MacroLineOf
	ld	e, (hl)
	inc	hl
	ld	b, (hl)
	ld	a, e
	and	$0F
	cp	3
	jr	z, MacroLineEval_Magic
	cp	4
	jr	z, MacroLineEval_Item
	ld	bc, $0001		; Fight, or not set (a member who joined since): Fight
	xor	a
	ret
MacroLineEval_Item:
	ld	a, b
	push	bc
	call	Inventory_FindFreeSlot
	pop	bc
	jr	nz, MacroLineEval_Fight
	ld	c, 4
	xor	a
	ret
MacroLineEval_Fight:
	ld	bc, $0001
	xor	a
	scf
	ret
MacroLineEval_Magic:
	call	MacroSpellOf		; a = the spell, carry if the member has none there
	jr	c, MacroLineEval_Fight
	cp	MagicID_Chat
	jr	nc, MacroLineEval_Fight	; Chat and Tele act at once: not in a macro
	ld	b, a
	push	bc
	push	de
	call	LABEL_1B87		; MP short: carry
	pop	de
	pop	bc
	jr	c, MacroLineEval_Fight
	ld	c, 3
	bit	6, e
	jr	z, +
	ld	a, e			; whom it is for: still up?
	rrca
	rrca
	rrca
	rrca
	and	3
	push	af
	push	bc
	call	MacroCanTarget
	pop	bc
	jr	z, ++
	pop	af
	or	a
	ret
++:	pop	af
	jr	MacroLineEval_Fight
+:	ld	a, b			; the stock's third byte: 0 for the attack spells (LABEL_1AD0),
	sub	MagicID_Fire		; the caster for the others (LABEL_1AFD)
	cp	MagicID_Rope - MagicID_Fire + 1
	jr	c, +
	ld	a, ($C267)
	or	a
	ret
+:	xor	a
	ret

; a = the ink of member a's line in slot MacroSlot: 6 amber if the member cannot act or the
; line cannot be carried out as set (MacroLineEval), else 0
MacroLineInk:
	ld	b, a
	ld	a, ($C267)
	push	af
	ld	a, b
	ld	($C267), a
	call	MacroCanAct
	ld	a, 6
	jr	z, +
	call	MacroLineEval
	ld	a, 6
	jr	c, +
	xor	a
+:	ld	b, a
	pop	af
	ld	($C267), a
	ld	a, b
	ret

; a = the ink of slot a's letter: 5 red empty, 6 amber if a party member's line is amber, else 0
MacroSlotInk:
	ld	hl, MacroSlot
	ld	b, (hl)
	ld	(hl), a
	push	bc
	call	MacroSlotEmpty
	ld	a, 5
	jr	z, MacroSlotInk_End
	xor	a
-:	push	af
	call	MacroLineInk
	or	a
	jr	nz, +
	pop	af
	inc	a
	ld	hl, Party_curr_num
	cp	(hl)
	jr	z, -
	jr	c, -
	xor	a
	jr	MacroSlotInk_End
+:	pop	bc			; the member
	ld	a, 6
MacroSlotInk_End:
	pop	bc
	ld	hl, MacroSlot
	ld	(hl), b
	ret

; slot a's letter (r2 + a, c9) in its colour, on its own tile (MacroSlotBase + a)
MacroLetter:
	ld	(MacroK), a
	call	MacroSlotInk
	ld	(WinInk), a
	ld	a, (MacroK)
	ld	e, a
	ld	d, 0
	ld	hl, MacroLetterIds
	add	hl, de
	ld	a, (hl)
	call	WinStrPtr		; hl, c
	push	bc
	push	hl
	ld	a, (MacroK)
	ld	l, a
	ld	h, 0
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	de, MACRO_SLOTS_VRAM + $40 + 2
	add	hl, de
	ex	de, hl			; de = its cell
	ld	h, d
	ld	l, e
	inc	hl
	inc	hl
	ld	a, (MacroSlotBase)
	ld	b, a
	ld	a, (MacroK)
	add	a, b
	call	MacroPoolAt
	pop	hl
	pop	bc
	ld	b, 1
	call	WinRun
	xor	a
	ld	(WinInk), a
	jp	MacroPoolBack

; nz if member a can be healed (LABEL_188E's test: in the party and alive)
MacroCanTarget:
	call	IsCharacterAlive
	ret

; a = the spell at place b of member ($C267)'s battle list; carry if there is none
MacroSpellOf:
	ld	a, ($C267)
	cp	2
	jr	z, MacroSpellOf_None	; Odin has no magic
	ld	c, a
	add	a, a
	add	a, a
	add	a, a
	add	a, a
	ld	hl, Char_stats + battle_magic_num
	add	a, l
	ld	l, a
	adc	a, h
	sub	l
	ld	h, a
	ld	a, b
	cp	(hl)
	jr	nc, MacroSpellOf_None	; not learnt (yet)
	ld	a, c
	cp	3
	jr	nz, +
	dec	a
+:	ld	c, a
	add	a, a
	add	a, a
	add	a, c			; 5 a list
	add	a, b
	ld	l, a
	ld	h, 0
	push	de
	ld	de, BattleMagicList
	add	hl, de
	pop	de
	ld	a, (hl)
	and	$1F
	or	a
	ret
MacroSpellOf_None:
	scf
	ret

; ---------------------------------------------------------------- the slots and the preview

; the slots (r1 c8) and the preview (r11 c8) saved and drawn, the dialogue window closed first
; (the preview saves into its buffer)
MacroSlotsOpen:
	call	LABEL_3464
	call	VwfMenuFont
	ld	hl, $DB08
	ld	de, MACRO_SLOTS_VRAM
	ld	bc, $0A06
	call	LABEL_3AA6
	ld	hl, MacroSlotMap
	ld	de, MACRO_SLOTS_VRAM
	ld	bc, $0A06
	call	LABEL_3A68
	ld	a, (WinPos)		; the letters, a tile each
	ld	(MacroSlotBase), a
	xor	a
-:	push	af
	call	MacroLetter
	pop	af
	inc	a
	cp	8
	jr	c, -
	ld	a, (MacroSlotBase)
	add	a, 8
	ld	(WinPos), a
	ld	hl, $DA18
	ld	de, MACRO_PREV_VRAM
	ld	bc, $0626
	call	LABEL_3AA6
	ld	a, (WinPos)
	ld	(MacroPrevBase), a
	xor	a
	ld	(MacroPrevLen), a	; no commands drawn yet
	ld	hl, MacroPrevMap
	ld	de, MACRO_PREV_VRAM
	ld	bc, $0626
	call	LABEL_3A68
	jp	MacroPreview

MacroSlotsClose:
	ld	hl, $DA18
	ld	de, MACRO_PREV_VRAM
	ld	bc, $0626
	call	LABEL_3A57
	ld	hl, $DB08
	ld	de, MACRO_SLOTS_VRAM
	ld	bc, $0A06
	jp	LABEL_3A57

; the cursor on the slots from MacroSlot; a: 1 the preview follows it. a = the slot, c the buttons
MacroSlotPick:
	ld	hl, MACRO_SLOTS_VRAM + $40
	ld	(MacroSelVram), hl
	ld	b, a
	ld	a, 8
	ld	(MacroSelN), a
	ld	a, (MacroSlot)
	and	7
	ld	(MacroSelIdx), a
	ld	a, b
	call	MacroSelect
	ld	(MacroSlot), a
	ret

; hl = slot MacroSlot's line for member a
MacroLineOf:
	add	a, a
	ld	l, a
	ld	a, (MacroSlot)
	and	7
	add	a, a
	add	a, a
	add	a, a
	add	a, l
	ld	l, a
	ld	h, 0
	push	de
	ld	de, MacroData
	add	hl, de
	pop	de
	ret

; z if slot MacroSlot is empty
MacroSlotEmpty:
	xor	a
	call	MacroLineOf
	ld	b, 8
	xor	a
-:	or	(hl)
	inc	hl
	djnz	-
	or	a
	ret

; the preview: slot MacroSlot, a line a member (the name, then the command; amber if the member
; cannot carry it out as set), its runs on new tiles from MacroPrevBase. Drawn line by line on
; the tiles the one on screen shows, a new line took an old line's tiles before that line was
; drawn again (it garbled for a frame or two while browsing). So the names go first, on the
; same tiles every time (MacroPrevBase up: the same text, uploaded whole, shows no change), and
; the commands are counted (WinMeasure, nothing drawn) and drawn where the commands on screen
; are not. Each member's command keeps a fixed place, as wide as that member's widest command
; in any slot (MacroCmdW): browsing, a line changes only its own tiles, and a line that stays
; the same shows no change at all. If those places do not fit the pool: below the commands on
; screen if they fit there, else above; with no room for both (a battle's pool), right after the
; names. Either way line by line, an old command blanked only when the new line would take its
; tiles (MacroPreviewSeq)
MacroPreview:
	call	MacroSlotEmpty
	ld	a, 0
	jr	nz, +
	inc	a
+:	ld	(MacroEmpty), a
	ld	a, (MacroPrevBase)
	ld	de, MACRO_PREV_VRAM
	ld	hl, MACRO_PREV_VRAM + 6 * $40
	call	MacroPoolAt
	xor	a
	ld	(MacroPrevDry), a
	ld	(MacroPrevPart), a
	call	MacroPreviewLines	; the names
	ld	a, (WinPos)		; the commands' fixed places, if they fit
	ld	c, a
	ld	a, (MacroPrevAt)
	push	af			; (the commands on screen)
	ld	a, c
	ld	(MacroPrevAt), a
	xor	a
-:	push	af
	push	bc
	call	MacroCmdW
	pop	bc
	ld	e, a
	ld	d, 0
	pop	af
	ld	hl, MacroPrevW
	push	de
	ld	e, a
	add	hl, de
	pop	de
	ld	(hl), e
	inc	a
	cp	4
	jr	c, -
	ld	a, 4
	call	MacroCmdOffset		; their end
	cp	c
	jr	z, MacroPreview_Fixed	; none
	dec	a
	push	bc
	call	WinPoolTile
	pop	bc
	jr	c, MacroPreview_Loose
MacroPreview_Fixed:
	pop	af
	ld	a, 2
	ld	(MacroPrevPart), a
	ld	a, c
	jr	MacroPreview_At
MacroPreview_Loose:
	pop	af
	ld	(MacroPrevAt), a
	ld	a, 1
	ld	(MacroPrevPart), a
	ld	(MacroPrevDry), a
	xor	a
	ld	(MacroPrevN), a
	call	MacroPreviewLines	; the commands' tiles, counted
	ld	a, (MacroPrevLen)
	or	a
	ld	a, (WinPos)		; none on screen yet: right after the names
	jr	z, MacroPreview_At
	ld	b, a
	ld	a, (MacroPrevAt)
	sub	b			; the room below the commands on screen
	jr	c, +
	ld	hl, MacroPrevN
	cp	(hl)
	ld	a, b
	jr	nc, MacroPreview_At
+:	ld	a, (MacroPrevAt)
	ld	hl, MacroPrevLen
	add	a, (hl)			; above them
	ld	c, a
	ld	a, (MacroPrevN)
	or	a
	jr	z, +
	add	a, c
	dec	a
	push	bc
	call	WinPoolTile		; their last tile there?
	pop	bc
	jr	c, MacroPreview_Blank
+:	ld	a, c
	jr	MacroPreview_At
MacroPreview_Blank:
	ld	a, b
MacroPreview_At:
	ld	(MacroPrevAt), a
	ld	(WinPos), a
	call	MacroPreviewSeq		; the commands
	ld	a, (MacroPrevAt)
	ld	b, a
	ld	a, (WinPos)
	sub	b
	ld	(MacroPrevLen), a
	jp	MacroPoolKeep

; the commands from WinPos on, a line at a time: its tiles counted, then any old command on
; screen (this line's or a later one's, not drawn again yet) whose tiles it would take blanked,
; then drawn. An old command starting on the same tile as the new one is its own line's,
; replaced cell for cell, and stays
MacroPreviewSeq:
	xor	a
MacroPS_Line:
	ld	(MacroSeqM), a
	ld	a, (MacroPrevPart)	; fixed places: the line's own
	cp	2
	jr	nz, +
	ld	a, (MacroSeqM)
	call	MacroCmdOffset
	ld	(WinPos), a
+:	ld	a, 1
	ld	(MacroPrevDry), a
	xor	a
	ld	(MacroPrevN), a
	ld	a, (MacroSeqM)
	call	MacroPreviewLine
	ld	a, (MacroPrevN)
	or	a
	jr	z, MacroPS_Draw
	ld	a, (MacroSeqM)
MacroPS_Old:
	ld	(MacroSeqJ), a
	call	MacroCmdOld		; a = its first position, b = its tiles
	ld	c, a
	ld	a, b
	or	a
	jr	z, MacroPS_Next
	ld	a, (MacroSeqJ)
	ld	hl, MacroSeqM
	cp	(hl)
	jr	nz, +
	ld	a, (WinPos)
	cp	c
	jr	z, MacroPS_Next		; its own, from the same tile
+:	ld	a, (WinPos)		; o < p + n and p < o + l: it would take them
	ld	hl, MacroPrevN
	add	a, (hl)
	cp	c
	jr	c, MacroPS_Next
	jr	z, MacroPS_Next
	ld	a, c
	add	a, b
	ld	hl, WinPos
	cp	(hl)
	jr	c, MacroPS_Next
	jr	z, MacroPS_Next
	ld	a, (MacroSeqJ)
	call	MacroCmdBlank
MacroPS_Next:
	ld	a, (MacroSeqJ)
	inc	a
	cp	4
	jr	c, MacroPS_Old
MacroPS_Draw:
	xor	a
	ld	(MacroPrevDry), a
	ld	a, (MacroSeqM)
	call	MacroPreviewLine
	ld	a, (MacroSeqM)
	inc	a
	cp	4
	jr	c, MacroPS_Line
	ld	a, (MacroPrevPart)	; fixed places: the pool past all four
	cp	2
	ret	nz
	ld	a, 4
	call	MacroCmdOffset
	ld	(WinPos), a
	ret

; a = the pool position of line a's fixed place: MacroPrevAt and the widths before it
MacroCmdOffset:
	push	bc
	push	hl
	ld	b, a
	ld	a, (MacroPrevAt)
	ld	c, a
	ld	hl, MacroPrevW
-:	ld	a, b
	or	a
	jr	z, +
	ld	a, c
	add	a, (hl)
	ld	c, a
	inc	hl
	dec	b
	jr	-
+:	ld	a, c
	pop	hl
	pop	bc
	ret

; a = the tiles of member a's widest command in any slot
MacroCmdW:
	push	bc
	push	de
	push	hl
	ld	e, a
	ld	a, (MacroSlot)
	push	af
	ld	a, (MacroEmpty)
	push	af
	ld	a, (MacroLineM)
	push	af
	ld	d, 0			; the widest so far
	xor	a
MacroCW_Slot:
	push	af
	ld	(MacroSlot), a
	push	de
	call	MacroSlotEmpty
	ld	a, 0
	jr	nz, +
	inc	a
+:	ld	(MacroEmpty), a
	pop	de
	ld	a, e
	ld	(MacroLineM), a
	call	MacroCmdCodes		; (keeps de)
	ld	b, 12
	call	WinMeasure
	cp	d
	jr	c, +
	ld	d, a
+:	pop	af
	inc	a
	cp	8
	jr	c, MacroCW_Slot
	pop	af
	ld	(MacroLineM), a
	pop	af
	ld	(MacroEmpty), a
	pop	af
	ld	(MacroSlot), a
	xor	a
	ld	(WinContN), a
	ld	a, d
	pop	hl
	pop	de
	pop	bc
	ret

; de = line a's command, its first cell (r12 + a, c14)
MacroCmdCell:
	ld	l, a
	ld	h, 0
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	de, MACRO_PREV_VRAM + $40 + 12
	add	hl, de
	ex	de, hl
	ret

; a = the first pool position of the tiles line a's command shows, b = how many (0: none)
MacroCmdOld:
	call	MacroCmdCell
	ld	(WinRunVram), de	; (WinCellRead's run)
	ld	c, 0
	call	WinCellRead
	jr	c, MacroCO_None
	push	hl			; its first tile
	ld	e, 1
-:	inc	c
	ld	a, c
	cp	12
	jr	nc, +
	call	WinCellRead
	jr	c, +
	inc	e
	jr	-
+:	pop	hl
	push	de
	ld	b, h
	ld	c, l
	call	WinPoolPos
	pop	de
	jr	c, MacroCO_None
	ld	b, e
	ret
MacroCO_None:
	ld	b, 0
	ret

; line a's command cells blank (12)
MacroCmdBlank:
	call	MacroCmdCell
	ld	b, 12
-:	push	bc
	ld	bc, $10C0
	call	WinCell
	pop	bc
	djnz	-
	ret

; WinRun, or with MacroPrevDry its tiles counted into MacroPrevN (de moved on as WinRun does)
MacroPrevRun:
	ld	a, (MacroPrevDry)
	or	a
	jp	z, WinRun
	call	WinMeasure
	push	hl
	ld	hl, MacroPrevN
	add	a, (hl)
	ld	(hl), a
	ld	a, b
	add	a, a
	ld	l, a
	ld	h, 0
	add	hl, de
	ex	de, hl
	pop	hl
	xor	a
	ld	(WinContN), a		; used, as WinRun uses it
	ret

; the preview's four lines (MacroPrevRun): the names (MacroPrevPart 0) or the commands (1)
MacroPreviewLines:
	xor	a
-:	push	af
	call	MacroPreviewLine
	pop	af
	inc	a
	cp	4
	jr	c, -
	ret

; the preview's line a (as MacroPreviewLines)
MacroPreviewLine:
	ld	(MacroLineM), a
	call	MacroPreviewInk
	ld	a, (MacroLineM)
	ld	l, a			; de = its first text cell: r12 + m, c9
	ld	h, 0
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	de, MACRO_PREV_VRAM + $40 + 2
	add	hl, de
	ex	de, hl
	ld	a, (MacroPrevPart)
	or	a
	jr	nz, MacroPreview_Cmd
	xor	a
	ld	(WinContN), a
	ld	hl, MacroNone
	ld	c, 1
	ld	a, (Party_curr_num)
	ld	b, a
	ld	a, (MacroLineM)
	cp	b
	jr	z, +
	jr	nc, ++			; not in the party: blank
+:	ld	l, a			; the name (LongNames)
	add	a, a
	add	a, l
	add	a, a
	ld	l, a
	ld	h, 0
	push	de
	ld	de, LongNames
	add	hl, de
	pop	de
	ld	c, 6
++:	ld	b, 5
	call	MacroPrevRun
	jr	MacroPreview_Next
MacroPreview_Cmd:
	ld	hl, 10			; c14: the command
	add	hl, de
	ex	de, hl
	call	MacroCmdCodes
	ld	b, 12
	call	MacroPrevRun
MacroPreview_Next:
	xor	a
	ld	(WinInk), a
	ret

MacroNone:
.db Dialogue_Terminator65

; WinInk for the preview's line MacroLineM: none for an empty slot or a member not in the party
MacroPreviewInk:
	xor	a
	ld	(WinInk), a
	ld	a, (MacroEmpty)
	or	a
	ret	nz
	ld	a, (Party_curr_num)
	ld	b, a
	ld	a, (MacroLineM)
	cp	b
	jr	z, +
	ret	nc
+:	call	MacroLineInk
	ld	(WinInk), a
	ret

; hl = the codes of member MacroLineM's command (c the most), a target's name in WinCont: none
; for an empty slot or a member not in the party; Fight for a line not set
MacroCmdCodes:
	xor	a
	ld	(WinContN), a
	ld	hl, MacroNone
	ld	c, 1
	ld	a, (MacroEmpty)
	or	a
	ret	nz
	ld	a, (Party_curr_num)
	ld	b, a
	ld	a, (MacroLineM)
	cp	b
	jr	z, +
	ret	nc
+:	push	de
	call	MacroLineOf
	ld	e, (hl)
	inc	hl
	ld	b, (hl)
	ld	a, e
	and	$0F
	cp	3
	jr	z, MacroCmd_Magic
	cp	4
	jr	z, MacroCmd_Item
MacroCmd_Fight:
	pop	de
	ld	a, MACRO_FIGHT
	jp	WinStrPtr
MacroCmd_Item:
	ld	l, b			; LongItems + 14 * the item
	ld	h, 0
	ld	d, h
	ld	e, l
	add	hl, hl
	add	hl, hl
	add	hl, hl
	or	a
	sbc	hl, de
	add	hl, hl
	ld	de, LongItems
	add	hl, de
	ld	c, 14
	pop	de
	ret
MacroCmd_Magic:
	ld	a, (MacroLineM)
	cp	2
	jr	z, MacroCmd_Fight
	cp	3
	jr	nz, +
	dec	a
+:	ld	c, a
	add	a, a
	add	a, a
	add	a, c
	add	a, b
	ld	l, a
	ld	h, 0
	push	de
	ld	de, MacroSpellIds
	add	hl, de
	pop	de
	ld	a, (hl)
	or	a
	jr	z, MacroCmd_Fight
	call	WinStrPtr		; (de kept)
	bit	6, e
	jr	z, +
	push	hl			; a target: a space and its name after the spell
	push	bc
	ld	a, e
	rrca
	rrca
	rrca
	rrca
	and	3
	ld	l, a
	add	a, a
	add	a, l
	add	a, a
	ld	l, a
	ld	h, 0
	ld	de, LongNames
	add	hl, de
	ld	de, MacroTgt + 1
	ld	bc, 6
	ldir
	ld	a, MACRO_SPACE
	ld	(MacroTgt), a
	ld	hl, MacroTgt
	ld	(WinCont), hl
	ld	a, 7
	ld	(WinContN), a
	pop	bc
	pop	hl
+:	pop	de
	ret

; ---------------------------------------------------------------- the pool

; runs drawn from pool position a over the region de-hl (new tiles, none reused); MacroPoolBack
; puts WinPos and the region saved last back, MacroPoolKeep the region only (WinPos stays past
; the runs' tiles)
MacroPoolAt:
	push	af
	ld	a, (WinPos)
	ld	(MacroKeep), a
	push	hl
	ld	hl, (WinFreshLo)
	ld	(MacroKeep + 2), hl
	ld	hl, (WinFreshHi)
	ld	(MacroKeep + 4), hl
	pop	hl
	ld	(WinFreshLo), de
	ld	(WinFreshHi), hl
	pop	af
	ld	(WinPos), a
	ret
MacroPoolBack:
	ld	a, (MacroKeep)
	ld	(WinPos), a
MacroPoolKeep:
	ld	hl, (MacroKeep + 2)
	ld	(WinFreshLo), hl
	ld	hl, (MacroKeep + 4)
	ld	(WinFreshHi), hl
	ret

; ---------------------------------------------------------------- a list, a line a row

; the cursor at MacroSelVram + $40 * MacroSelIdx, MacroSelN lines, blinking as the stock's
; (tile $F0 over the left frame $F3); a: 1 a move redraws the preview of the slot under it.
; a = the line, c the buttons; B leaves the frame, C the cursor
MacroSelect:
	ld	(MacroSelHook), a
	xor	a
	ld	($C268), a		; the stock cursor off
	ld	(MacroBlink), a
MacroSelect_Loop:
	ld	a, (MacroBlink)
	inc	a
	ld	(MacroBlink), a
	and	$08
	ld	a, $F0
	jr	z, +
	ld	a, $F3
+:	call	MacroCursorPut
	ld	a, $08
	call	WaitForVInt
	ld	a, (Ctrl_1_pressed)
	ld	c, a
	and	Button_1_Mask | Button_2_Mask
	jr	nz, MacroSelect_Done
	ld	a, c
	and	ButtonUp_Mask | ButtonDown_Mask
	jr	z, MacroSelect_Loop
	ld	a, $F3
	call	MacroCursorPut
	ld	a, (MacroSelIdx)
	bit	ButtonUp, c
	jr	z, ++
	or	a
	jr	nz, +
	ld	a, (MacroSelN)
+:	dec	a
	jr	+++
++:	inc	a
	ld	hl, MacroSelN
	cp	(hl)
	jr	c, +++
	xor	a
+++:	ld	(MacroSelIdx), a
	xor	a
	ld	(MacroBlink), a
	ld	a, (MacroSelHook)
	or	a
	jr	z, MacroSelect_Loop
	ld	a, (MacroSelIdx)
	ld	(MacroSlot), a
	call	MacroPreview
	jr	MacroSelect_Loop
MacroSelect_Done:
	push	bc
	ld	a, $F0
	bit	Button_1, c
	jr	z, +
	ld	a, $F3
+:	call	MacroCursorPut
	pop	bc
	ld	a, (MacroSelIdx)
	ret

; tile a (the low byte only, as the stock cursor) at the cursor's cell
MacroCursorPut:
	push	af
	ld	a, (MacroSelIdx)
	ld	l, a
	ld	h, 0
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	add	hl, hl
	ld	de, (MacroSelVram)
	add	hl, de
	ex	de, hl
	pop	af
	di
	push	af
	rst	$08
	pop	af
	out	(Port_VDPData), a
	ei
	ret

; ---------------------------------------------------------------- the field menu

; LABEL_36DD: the field menu, 13 rows (r1-r13 c1-c6): the stock buffer and MacroExtra (r12-r13)
MacroFieldOpen:
	ld	hl, $D8A4
	ld	de, $7842
	ld	bc, $0B0C
	call	LABEL_3AA6
	ld	hl, MacroExtra
	ld	de, $7B02
	ld	bc, $020C
	call	LABEL_3AA6
; LABEL_36EF: drawn again (after an entry)
MacroFieldDraw:
	call	VwfMenuFont
	ld	hl, MacroFieldMap
	ld	de, $7842
	ld	bc, $0D0C
	jp	LABEL_3A68

; LABEL_36FB
MacroFieldClose:
	ld	hl, MacroExtra
	ld	de, $7B02
	ld	bc, $020C
	call	LABEL_3A57
	ld	hl, $D8A4
	ld	de, $7842
	ld	bc, $0B0C
	jp	LABEL_3A57

; PlayerMenu_Macro: the slots, then a slot's members, then a member's command
MacroEdit:
	call	MacroSlotsOpen
MacroEdit_Slots:
	ld	a, 1
	call	MacroSlotPick
	bit	Button_1, c
	jp	nz, MacroSlotsClose
	xor	a
	ld	(MacroMember), a
MacroEdit_Members:
	ld	hl, MACRO_PREV_VRAM + $40
	ld	(MacroSelVram), hl
	ld	a, (Party_curr_num)
	inc	a
	ld	(MacroSelN), a
	ld	a, (MacroMember)
	ld	(MacroSelIdx), a
	xor	a
	call	MacroSelect
	bit	Button_1, c
	jr	nz, MacroEdit_Slots
	ld	(MacroMember), a
	call	MacroSetLine
	ld	a, (MacroSlot)		; the letter's colour may change
	call	MacroLetter
	call	MacroPreview
	jr	MacroEdit_Members

; Fight, Magic or Item for member MacroMember of slot MacroSlot (r1 c12); B keeps the line
MacroSetLine:
	ld	hl, $D928
	ld	de, MACRO_CMD_VRAM
	ld	bc, $070C
	call	LABEL_3AA6
	ld	hl, MacroCmdMap
	ld	de, MACRO_CMD_VRAM
	ld	bc, $070C
	call	LABEL_3A68
MacroSetLine_Ask:
	ld	hl, MACRO_CMD_VRAM + $40
	ld	(Cursor_pos), hl
	ld	a, 2
	ld	(Option_total_num), a
	call	CheckOptionSelect
	bit	Button_1, c
	jr	nz, MacroSetLine_Close
	or	a
	jr	z, MacroSetLine_Fight
	dec	a
	jr	z, MacroSetLine_Magic
	call	MacroPickItem		; z: a = the item
	jr	nz, MacroSetLine_Ask
	ld	b, a
	ld	a, 4
	jr	MacroSetLine_Store
MacroSetLine_Fight:
	ld	bc, $0001
	ld	a, c
	jr	MacroSetLine_Store
MacroSetLine_Magic:
	call	MacroPickSpell		; z: a = the command byte, b = the place
	jr	nz, MacroSetLine_Ask
MacroSetLine_Store:
	push	af
	ld	a, (MacroMember)
	call	MacroLineOf
	pop	af
	ld	(hl), a
	inc	hl
	ld	(hl), b
MacroSetLine_Close:
	ld	hl, $D928
	ld	de, MACRO_CMD_VRAM
	ld	bc, $070C
	jp	LABEL_3A57

; the member's battle spells (the stock list); a healing one asks whom for (the stock party
; menu). z: a = the line's command byte, b = the spell's place
MacroPickSpell:
	ld	a, (MacroMember)
	ld	($C267), a		; MacroSpellOf's member
	cp	2
	jr	z, MacroPick_None	; Odin has no magic
	ld	c, a
	add	a, a
	add	a, a
	add	a, a
	add	a, a
	ld	hl, Char_stats + battle_magic_num
	add	a, l
	ld	l, a
	adc	a, h
	sub	l
	ld	h, a
	ld	a, (hl)
	or	a
	jr	z, MacroPick_None
	ld	b, a
	ld	a, c
	cp	3
	jr	nz, +
	dec	a
+:	push	bc
	call	LABEL_3478
	ld	hl, $7A8C
	ld	(Cursor_pos), hl
	pop	bc
	ld	a, b
	dec	a
	ld	(Option_total_num), a
	call	CheckOptionSelect
	push	af
	push	bc
	call	LABEL_34C9
	pop	bc
	pop	af
	bit	Button_1, c
	jr	nz, MacroPick_None
	ld	(MacroIdx), a
	ld	b, a
	call	MacroSpellOf
	jr	c, MacroPick_None
	cp	MagicID_Chat
	jr	nc, MacroPick_None	; Chat and Tele act at once: not in a macro
	cp	MagicID_Heal
	jr	z, MacroPick_Target
	cp	MagicID_Cure
	jr	z, MacroPick_Target
	cp	MagicID_Help
	jr	z, MacroPick_Target
	ld	a, 3
	jr	MacroPick_Done
MacroPick_Target:
	ld	c, Button_2_Mask	; Alisa alone: LABEL_3682 returns at once, a = 0
	call	LABEL_3682		; a = the member
	push	af
	push	bc
	call	LABEL_36CC
	pop	bc
	pop	af
	bit	Button_1, c
	jr	nz, MacroPick_None
	and	3
	rlca
	rlca
	rlca
	rlca
	or	$43			; Magic, with a target
MacroPick_Done:
	ld	hl, MacroIdx
	ld	b, (hl)
	cp	a
	ret
MacroPick_None:
	or	1
	ret

; an item (the stock inventory); z: a = the item
MacroPickItem:
	ld	a, (Inventory_curr_num)
	or	a
	jr	z, MacroPick_None
	call	LABEL_34D5
	call	LABEL_3656
	bit	Button_1, c
	jr	nz, MacroPick_None
	ld	a, (CurrentItem)
	cp	a
	ret
