; RAM of vwf_dialogue and vwf_cutscene: $DF00-$DF1F. The stock game never reads or writes
; $DE96-$DFFB (work/scripts/vramaudit.lua; its highest buffer, the YES/NO box's at $DE64, ends
; at $DE95).
.define VwfCharIn	$DF00	; the code VwfGate hands over
.define VwfPen		$DF01	; the pen, in pixels from the line's start
.define VwfSet		$DF02	; the current window line's tile set (0 or 1)
.define VwfAdv		$DF03	; the glyph's advance
.define VwfShift	$DF04	; the pen within its tile
.define VwfBase		$DF05	; the current line's first tile
.define VwfLimit	$DF06	; the current line's width in pixels
.define VwfCutDirty	$DF07	; 1: a cut-scene used the font area (VwfFadeWait reloads the font)
.define VwfRow		$DF08	; 8 bytes: the tile under the pen, 1 bpp
.define VwfSpill	$DF10	; 8 bytes: what crosses into the next tile (VwfRow + 8)
.define VwfDigits	$DF18	; 5 bytes: {NUMBER}'s digits
.define WinCont		$DF1D	; 2 bytes, vwf_windows: a run's second part (the money line's amount)
.define WinContN	$DF1F	; its codes (0: none)
; long_names: the two columns its wider boxes cover beyond the stock 6 (ext/longnames.asm)
.define LongPartyExtraA	$DEA0	; 36 bytes: the party menu at $7A44 (9 rows x 2 cells)
.define LongPartyExtraB	$DEC4	; 36 bytes: the party menu at $7A54
.define LongBoxExtra	$DEE8	; 12 bytes: the name box (3 rows x 2 cells)
; long_item_names: how wide its windows are. Each lists names in LONG_W cells, LONG_X more than
; the stock's 8, gained to the left (the right edge stays): with vwf_windows the names are in
; the face, at most 80 px; without it a cell a letter, 14. The LONG_X columns beyond the stock
; ones are saved in two parts: LONG_XA beside them, LONG_XB at the left edge.
.IF vwf_windows == 1
.define LONG_W	10
.define LONG_X	2
.define LONG_XA	2
.define LONG_XB	0
.ELSE
.define LONG_W	14
.define LONG_X	6
.define LONG_XA	4
.define LONG_XB	2
.ENDIF
; long_item_names: the columns its wider windows cover beyond the stock ones
; Equipment can open over the inventory. Its extra columns use the gap after the stock
; equipment buffer ($D928 + 8 * 20), ending before the dialogue buffer at $DA18.
.define LongEquipExtra	$D9C8	; up to 64 bytes: 8 rows x LONG_XA columns
.define LongEquipExtra2	$DA08	; 16 bytes: 8 rows x LONG_XB columns (without vwf_windows)
.define LongSharedExtra	$DF20	; up to 168 bytes: the LONG_XA columns beside the stock ones of
				; the shop list or the inventory (never open together)
.define LongEnemyBoxExtra	$DFC8	; 32 bytes: the battle's enemy name box (4 rows x LONG_XA cells)
; without vwf_windows only (LONG_XB = 2):
.define LongEnemyBoxExtra2	$DFE8	; 16 bytes: its 2 columns at the left edge (4 rows x 2 cells)
; $C790-$C7FF: no stock code reads or writes it (the naming screen's RAM ends at $C789)
.define LongSharedExtra2	$C790	; up to 84 bytes: the 2 columns at the left edge of the equipment
				; shop list or the inventory (21 rows x 2 cells)
; vwf_windows (ext/vwfwin.asm): the tile pool, its marks, a map row in hand
.define WIN_MARKS	12
.define WinMarks	$C7E4	; WIN_MARKS x 2 bytes: a save buffer's key (WinKeyOf), WinPos then
.define WinDepth	$C7FC	; the marks in use
.define WinFontDirty	$C7FD	; 1: the font's letters were lent (VwfFadeWait reloads the font)
.define WinPos		$C7FE	; the pool's next position
.define WinDone		$C7FF	; 1: WinRow drew the row
.define WinSrc		$DEF4	; 2 bytes: the map row's source
.define WinSrcBank	$DEF6	; its bank
.define WinKind		$DEF7	; the screen's pool: 0 none, 1 battle, 2 interaction, 3 dungeon,
				; 4 a dungeon chest, 5 an enemy shown in a talk (LABEL_5FFE)
.define WinKeyId	$DEF8	; its enemy or person
.define WinDyn		$DEF9	; the first tile above the enemy's or person's graphics, - $100
.define WinP0		$DEFA	; the run's first pool position
.define WinCells	$DEFB	; the run's cells
.define WinJ		$DEFC	; the run's next pool position (writing its cells)
.define WinLeft		$DEFD	; the row's cells left
.define WinStrId	$DEFE	; the run's string
.define WinStr		$DE96	; 2 bytes: the run's codes
.define WinRunVram	$DE98	; 2 bytes: the run's first cell
.define WinFreshLo	$DE9A	; 2 bytes: the region saved last, from
.define WinFreshHi	$DE9C	; 2 bytes: to (a run inside it is a new window: new tiles)
.define WinLastSave	$DE9E	; 1: the last thing done was a save (the region grows)
.define WinReuse	$DE9F	; 1: the run is drawn again in place (its cells' tiles kept)
.define WinNewMax	$DEFF	; the run's cells that took new tiles
; in LongEnemyBoxExtra2's room, unused with vwf_windows (LONG_XB = 0)
.define WinBackSrc	$DFE8	; 2 bytes: where the next row of the saved screen coming back would be
.define WinBackVram	$DFEA	; 2 bytes: and where on the screen
.define WinBattleStart	$DFEC	; 1: a battle has begun (LABEL_30ED -> LongEnemyBoxSave) and $C29D is
				; not up yet: LABEL_100F draws the name box first (a dungeon's battle)
.define WinChestDirty	$DFED	; 1: the pool lent a tile of a dungeon chest's pictures ($116-$19F,
				; WinPoolChest): its question (LABEL_28DB -> WinChestAsk) loads them again
.define WinAcc		$DFEE	; WinPoolPos: the positions before the range
.define WinCnt		$DFEF	; WinPoolPos: the range's count
.define WinTop		$DFF0	; WinKeptTop: the position above the kept tiles so far
.define WinForceReuse	$DFF1	; 1: WinRun draws in place whatever the region (LongEnemyBox)
; battle_macros' preview (MacroPreview): where the one on screen took its tiles
.define MacroPrevAt	$DFF2	; its commands' first pool position (the names: MacroPrevBase up)
.define MacroPrevLen	$DFF3	; their tiles (0: none drawn yet)
.define MacroPrevN	$DFF4	; the next ones' tiles (WinMeasure)
.define MacroPrevDry	$DFF5	; 1: MacroPrevRun counts, draws nothing
.define MacroPrevPart	$DFF6	; MacroPreviewLines: 0 the names, 1 the commands, 2 in fixed places
.define MacroSeqM	$DFF7	; MacroPreviewSeq: the line drawn
.define MacroSeqJ	$C7E2	; MacroPreviewSeq: the old line looked at (free: $C790-$C7FF is ours)
.define MacroPrevW	$C790	; 4 bytes in WinSpellExtra, MacroPreview's while it runs (the spell
				; list, whose column they save, is never open then): each member's command width
; the spell list's new column and its list number; $C790 is LongSharedExtra2's only without
; vwf_windows
.define WinSpellExtra	$C790	; 24 bytes: the screen under the spell list's new column (12 x 1)
.define WinSpellListA	$C7A8	; the list LABEL_3478 was asked for
; battle_macros (ext/macros.asm): the eight macros live in the block the save copies and a new
; game clears ($C300-$C6FF; no stock code reads or writes past $C317), so they are saved with
; the game; its state in $C7A9-$C7E3 (free with vwf_windows: LongSharedExtra2 is not used then)
.define MacroData	$C3C0	; 64 bytes: slot k, member m at 8k + 2m: the command (bits 0-3: 1 Fight,
				; 3 Magic, 4 Item; bit 6: a target, bits 4-5 who), then the spell's place in
				; the member's battle list or the item
.define MacroResult	$C7A9	; MacroAsk's answer: a BattleMenu_OptionTbl index, $FF back, $FE a macro
.define MacroExtra	$C7AA	; 24 bytes: the screen beside the stock buffer $D8A4: the first window's
				; seventh column (11 rows) or the field menu's last two rows
.define MacroShown	$C7C2	; the battle window up: 0 none, 1 the first window, 2 the commands
.define MacroInCmd	$C7C3	; 1: this round's commands are asked member by member
.define MacroP0		$C7C4	; the pool position of the battle window's tiles (MACRO_MENU_TILES)
.define MacroSlot	$C7C5	; the slot last chosen
.define MacroSelN	$C7C6	; MacroSelect: the lines
.define MacroSelIdx	$C7C7	; the line under the cursor
.define MacroSelVram	$C7C8	; 2 bytes: the first line's cursor cell
.define MacroSelHook	$C7CA	; 1: a move redraws the preview
.define MacroBlink	$C7CB	; the cursor's blink
.define MacroMember	$C7CC	; the editor's member
.define MacroPrevBase	$C7CD	; the pool position of the preview's tiles
.define MacroKeep	$C7CE	; 6 bytes: WinPos, (WinShownPerson), WinFreshLo, WinFreshHi kept
.define WinShownPerson	$C7CF	; vwf_windows: the person LABEL_617D loaded last (WinPersonHook)
.define MacroTgt	$C7D4	; 7 bytes: a space and a target's name (a preview line's second part)
.define MacroList	$C7DB	; the editor's spell list
.define MacroIdx	$C7DC	; the editor's spell place
.define MacroTopLast	$C7DD	; the first window's last choice
.define MacroEmpty	$C7DE	; 1: the previewed slot is empty
.define MacroLineM	$C7DF	; the preview's member
.define MacroSlotBase	$C7E0	; the pool position of the slot letters' tiles (one each)
.define MacroK		$C7E1	; the slot a letter is drawn for
; vwf_windows: a run's ink. 0 the window's white (colour 2); otherwise the colour, and the run's
; cells take the sprite palette (attribute bit 3), whose 21 and 22 are red and amber while a
; battle or the interaction screen is up (battle_macros' marks: 5 red, 6 amber)
.define WinInk		$C7E3
