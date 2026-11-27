; fast_walk: shorter animations, preserving the renderer's odd/even VRAM buffers.
; Every view must write the bank the preceding visible view does not use.
; Settled views 0/6 are even: start odd, alternate, finish even. Forward
; has three intermediate views then the caller's still redraw (four vs six renders).
; Reverse has four views; each turn has four vs eight. Never just keep even IDs.
; Unused bytes after each terminator stay padding; LABEL_6AE1 and the deltas do not move.
.db $8A, $6A, $90, $6A, $97, $6A, $A0, $6A, $A9, $6A, $B2, $6A, $BB, $6A, $C4, $6A, $CD, $6A, $D6, $6A
.db $01, $04, $05, $FF, $FF, $FF
.db $05, $02, $01, $00, $FF, $FF, $FF
.db $07, $0A, $0D, $00, $FF, $FF, $FF, $FF, $FF
.db $17, $1A, $1D, $00, $FF, $FF, $FF, $FF, $FF
.db $1F, $22, $25, $00, $FF, $FF, $FF, $FF, $FF
.db $0F, $12, $15, $00, $FF, $FF, $FF, $FF, $FF
.db $0D, $0A, $07, $00, $FF, $FF, $FF, $FF, $FF
.db $25, $22, $1F, $00, $FF, $FF, $FF, $FF, $FF
.db $1D, $1A, $17, $00, $FF, $FF, $FF, $FF, $FF
.db $15, $12, $0F, $00, $FF, $FF, $FF, $FF, $FF
.db $F0, $01
