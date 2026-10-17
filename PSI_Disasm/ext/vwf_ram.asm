; RAM of vwf_dialogue: $DF00-$DF1F. The stock game never reads or writes $DE96-$DFFB
; (work/scripts/vramaudit.lua; its highest buffer, the YES/NO box's at $DE64, ends at $DE95).
.define VwfCharIn	$DF00	; the code VwfGate hands over
.define VwfPen		$DF01	; the pen, in pixels from the line's start
.define VwfSet		$DF02	; the current line's tile set (0 or 1)
.define VwfAdv		$DF03	; the glyph's advance
.define VwfShift	$DF04	; the pen within its tile
.define VwfRow		$DF08	; 8 bytes: the tile under the pen, 1 bpp
.define VwfSpill	$DF10	; 8 bytes: what crosses into the next tile (VwfRow + 8)
.define VwfDigits	$DF18	; 5 bytes: {NUMBER}'s digits
