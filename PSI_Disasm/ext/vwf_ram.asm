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
.define LongSharedExtra	$DF20	; up to 168 bytes: the LONG_XA columns beside the stock ones of
				; the equipment box, the shop list or the inventory (never open together)
.define LongEnemyBoxExtra	$DFC8	; 32 bytes: the battle's enemy name box (4 rows x LONG_XA cells)
; without vwf_windows only (LONG_XB = 2):
.define LongEnemyBoxExtra2	$DFE8	; 16 bytes: its 2 columns at the left edge (4 rows x 2 cells)
; $C790-$C7FF: no stock code reads or writes it (the naming screen's RAM ends at $C789)
.define LongSharedExtra2	$C790	; up to 84 bytes: the 2 columns at the left edge of the equipment
				; box, the shop list or the inventory (21 rows x 2 cells)
; vwf_windows (ext/vwfwin.asm): the tile pool, its marks, a map row in hand
.define WIN_MARKS	12
.define WinMarks	$C7E4	; WIN_MARKS x 2 bytes: a save buffer's key (WinKeyOf), WinPos then
.define WinDepth	$C7FC	; the marks in use
.define WinFontDirty	$C7FD	; 1: the font's letters were lent (VwfFadeWait reloads the font)
.define WinPos		$C7FE	; the pool's next position
.define WinDone		$C7FF	; 1: WinRow drew the row
.define WinSrc		$DEF4	; 2 bytes: the map row's source
.define WinSrcBank	$DEF6	; its bank
.define WinKind		$DEF7	; the screen's pool: 0 none, 1 battle, 2 interaction, 3 dungeon
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
; the spell list's new column and its list number; $C790 is LongSharedExtra2's only without
; vwf_windows
.define WinSpellExtra	$C790	; 24 bytes: the screen under the spell list's new column (12 x 1)
.define WinSpellListA	$C7A8	; the list LABEL_3478 was asked for
