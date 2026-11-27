; hospital_everyone: the hospital (LABEL_298D) with Everyone after the party's names in its
; party menu (docs/pipeline.md 6). Bank 35, beside long_names' party menu maps, which it draws
; (LABEL_3A68 reads the current slot-2 bank). Needs long_names and vwf_windows.
;
; The stock routine, line for line, but for the menu and Everyone: the hook at LABEL_298D
; far-calls Hospital, and the messages go through HospMsg (bank 0), since ShowDialogue_B12
; pages the messages' bank into slot 2, where this code runs.
;
; * The menu (HospMenu): the party's names, then Everyone, then the bottom edge: 2n + 3 rows for
;   n members, at r9 c2 as the stock's (LABEL_3665) or, with four members (11 rows; at r9 they
;   would reach the dialogue window's top at r18), at r7. With one member there is no menu, as
;   in the stock. The screen under it goes to the stock party menu's buffers, which are longer
;   by two rows: the stock 6 columns to $DDA8 (to $DE2B: $DE14 is the item actions', the second
;   party menu's, the spaceport's and BUY / SELL's, none of which opens in the hospital; the
;   YES / NO box's $DE64 is after it), the two columns more to LongPartyExtraA (44 bytes, to
;   $DECB: into LongPartyExtraB, the second party menu's only). Their keys are the stock
;   menu's, so the windows' marks (WinSave, WinRelease) work as they do for it.
; * Everyone: the fee is the sum of each living member's stock fee (max HP - HP + max MP - MP,
;   in 8 bits as the stock computes it: what choosing them one by one would cost); a member who
;   is down is left out (the hospital treats no one dead: the church's business). Nobody to
;   treat: HospAllNone, and the menu again. Else HospAllCost and the stock's money box and
;   YES / NO; paid, every living member's HP and MP are restored, the stock's "Thank you for
;   waiting" (LABEL_B12_B938), and the hospital closes (nobody else can need treatment).

Hospital:
	ld	hl, LABEL_B12_B8C8	; "This is the hospital. Do you need treatment?"
	call	HospMsg
	call	ShowYesNoPrompt
	jp	nz, Hosp_Bye
Hosp_Ask:
	ld	a, (Party_curr_num)
	or	a
	ld	hl, LABEL_B12_B925	; "Who needs treatment?"
	call	nz, HospMsg
	call	HospMenu		; a = the choice, c = the buttons
	bit	Button_1, c
	jp	nz, Hosp_Close
	ld	b, a
	ld	a, (Party_curr_num)
	or	a
	jr	z, +
	inc	a
	cp	b
	jp	z, Hosp_All		; Everyone
+:	ld	a, b
	ld	(CurrentCharacter), a
	call	IsCharacterAlive
	jr	nz, +
	ld	hl, LABEL_B12_B730	; "{NAME} is already dead."
	call	HospMsg
	jp	Hosp_Again

+:	push	hl
	pop	iy
	ld	a, (iy+1)
	cp	(iy+6)
	jr	nz, +
	ld	a, (iy+2)
	cp	(iy+7)
	jr	nz, +
	ld	hl, LABEL_B12_B96B	; "There's nothing wrong with {NAME}."
	call	HospMsg
	ld	a, (Party_curr_num)
	or	a
	jr	nz, Hosp_Again
	ld	hl, LABEL_B12_B964
	call	HospMsg
	jp	LABEL_3464

+:	call	HospFee
	ld	l, a
	ld	h, $00
	ld	(CurrentDialogueNumber), hl
	ld	hl, LABEL_B12_B8E0	; "The exam and treatment come to {NUMBER} meseta."
	call	HospCharge
	jr	nz, Hosp_Again
	call	HospHeal
	call	HospThanks
	ld	a, (Party_curr_num)
	or	a
	jp	z, LABEL_3464
	ld	hl, LABEL_B12_B90A	; "Does anyone else need treatment?"
	call	HospMsg
	call	ShowYesNoPrompt
	jr	nz, Hosp_Close

Hosp_Again:
	call	HospMenuClose
	ld	a, (Party_curr_num)
	or	a
	jp	nz, Hosp_Ask
Hosp_Close:
	call	HospMenuClose
Hosp_Bye:
	ld	hl, LABEL_B12_B951	; "I see. I'm sorry I couldn't help. Please take care."
	call	HospMsg
	jp	LABEL_3464

Hosp_All:
	call	HospAllFee		; hl = the fee, c = the members who need treatment
	ld	a, c
	or	a
	jr	nz, +
	ld	hl, HospAllNone		; "You're all in good health."
	call	HospMsg
	jr	Hosp_Again
+:	ld	(CurrentDialogueNumber), hl
	ld	hl, HospAllCost		; "Treatment for everyone comes to {NUMBER} meseta."
	call	HospCharge
	jr	nz, Hosp_Again
	call	HospHealAll
	call	HospThanks
	call	HospMenuClose
	jp	LABEL_3464

; the quote at hl for the fee in CurrentDialogueNumber, the money box, YES / NO. z: paid (the
; money box still up, showing what is left). nz: declined (the box closed). Short of money: the
; stock's ending (LABEL_2A5E), not back here.
HospCharge:
	call	HospMsg
	call	LABEL_39E9
	call	ShowYesNoPrompt
	push	af
	call	nz, LABEL_3A12
	pop	af
	ret	nz
	ld	de, (CurrentDialogueNumber)
	ld	hl, (Current_money)
	or	a
	sbc	hl, de
	jr	c, +
	ld	(Current_money), hl
	call	LABEL_39F7
	ld	a, $C1			; the healing sound
	ld	($C004), a
	xor	a
	ret
+:	pop	hl			; HospCharge's return
	call	LABEL_3A12
	call	HospMenuClose
	ld	hl, LABEL_B12_BD57	; "Looks like you're short on money."
	call	HospMsg
	jp	LABEL_3464

; "Thank you for waiting. Take care." and the money box closed
HospThanks:
	ld	hl, LABEL_B12_B938
	call	HospMsg
	jp	LABEL_3A12

; a = the member at iy's fee, as the stock's: max HP - HP + max MP - MP, in 8 bits
HospFee:
	ld	a, (iy+6)
	sub	(iy+1)
	ld	b, a
	ld	a, (iy+7)
	sub	(iy+2)
	add	a, b
	ret

; the member at iy: HP and MP to their maximum
HospHeal:
	ld	a, (iy+6)
	ld	(iy+1), a
	ld	a, (iy+7)
	ld	(iy+2), a
	ret

; hl = the sum of the living members' fees, c = how many of them need treatment
HospAllFee:
	ld	iy, Char_stats
	ld	hl, $0000
	ld	a, (Party_curr_num)
	inc	a
	ld	b, a
	ld	c, 0
-:	bit	0, (iy+0)
	jr	z, ++			; down: not the hospital's
	ld	a, (iy+1)
	cp	(iy+6)
	jr	nz, +
	ld	a, (iy+2)
	cp	(iy+7)
	jr	z, ++			; nothing wrong
+:	inc	c
	push	bc
	call	HospFee
	ld	e, a
	ld	d, 0
	add	hl, de
	pop	bc
++:	ld	de, 16
	add	iy, de
	djnz	-
	ret

; every living member's HP and MP to their maximum
HospHealAll:
	ld	iy, Char_stats
	ld	a, (Party_curr_num)
	inc	a
	ld	b, a
-:	bit	0, (iy+0)
	call	nz, HospHeal
	ld	de, 16
	add	iy, de
	djnz	-
	ret

; ---------------------------------------------------------------- the menu

; the party menu with Everyone: a = the choice (Party_curr_num + 1 is Everyone), c = the
; buttons (CheckOptionSelect). With one member, no menu: a = 0, c = 0.
HospMenu:
	ld	a, (Party_curr_num)
	or	a
	ld	c, a
	ret	z
	inc	a
	ld	(Option_total_num), a	; the members, then Everyone
	call	HospMenuAt
	ld	hl, $DDA8		; the stock 6 columns
	ld	c, $0C
	call	LABEL_3AA6
	call	HospMenuExtra		; the two more
	call	LABEL_3AA6
	call	HospMenuAt
	push	de
	ld	a, (Party_curr_num)
	inc	a
	add	a, a
	ld	b, a			; the top edge and the names
	ld	c, $10
	ld	hl, LongPartyRows
	call	LABEL_3A68
	ld	hl, LongPartyAll	; a blank row and Everyone
	ld	bc, $0210
	call	LABEL_3A68
	ld	hl, LongPartyEnd
	ld	bc, $0110
	call	LABEL_3A68
	pop	hl
	ld	de, $0040
	add	hl, de
	ld	(Cursor_pos), hl	; the first name's row
	jp	CheckOptionSelect

; the screen back under it, as saved
HospMenuClose:
	ld	a, (Party_curr_num)
	or	a
	ret	z
	call	HospMenuAt
	ld	hl, $DDA8
	ld	c, $0C
	call	LABEL_3A57
	call	HospMenuExtra
	jp	LABEL_3A57

; de = the menu's top left, b = its rows (2n + 3: Party_curr_num 1-3 gives 7, 9, 11)
HospMenuAt:
	ld	a, (Party_curr_num)
	ld	de, $7A44		; r9 c2, the stock's
	cp	3
	jr	c, +
	ld	de, $79C4		; four members: r7 c2, clear of the dialogue window
+:	add	a, a
	add	a, 5
	ld	b, a
	ret

; its two columns beyond the stock 6: de on the screen, b rows, hl their buffer, c bytes a row
HospMenuExtra:
	call	HospMenuAt
	ld	hl, $000C
	add	hl, de
	ex	de, hl
	ld	hl, LongPartyExtraA
	ld	c, $04
	ret
