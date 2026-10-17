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
; long_names: the two columns its wider boxes cover beyond the stock 6 (ext/longnames.asm)
.define LongPartyExtraA	$DEA0	; 36 bytes: the party menu at $7A44 (9 rows x 2 cells)
.define LongPartyExtraB	$DEC4	; 36 bytes: the party menu at $7A54
.define LongBoxExtra	$DEE8	; 12 bytes: the name box (3 rows x 2 cells)
