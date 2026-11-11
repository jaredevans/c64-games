; Nuclear Land - talking-screen text: the C64's upper/lower-case font drawn into the bitmap
;
; talk_font holds the 128 glyphs of the character ROM's upper/lower-case set (copied at boot) plus a
; solid block (code BM_BLOCK) for the trust meter. Text is screen codes of that set: a-z 1-26,
; A-Z 65-90, space and punctuation as-is (tools/make_dialogue.py writes the dialogue that way).
;
; The panel right of the portrait: header rows 0-2 (name, role, trust meter), conversation rows
; 4-18 (CONV_LINES lines, columns 16-39). When the conversation is full, each new line scrolls it up.

BM_BLOCK   = 128
PANEL_COL  = 16
CONV_ROW   = 4
CONV_LINES = 15

; font_init: copy the upper/lower-case ROM glyphs ($D800-$DBFF) to talk_font. Interrupts off.
!zone font_init
font_init
        lda #$33                ; char ROM in at $D000-$DFFF, I/O out
        sta $01
        ldx #0
-       !for p, 0, 3 {
        lda $d800 + p*$100,x
        sta talk_font + p*$100,x
        }
        inx
        bne -
        lda #$36
        sta $01
        lda #$ff
        ldx #7
-       sta talk_font + BM_BLOCK*8,x
        dex
        bpl -
        rts

; bm_at: point bm_ptr/bm_cptr at cell (bm_col, bm_row)
!zone bm_at
bm_at
        ldx bm_row
        lda bmrow_lo,x
        sta bm_ptr
        lda bmrow_hi,x
        sta bm_ptr+1
        lda bm_col              ; + col * 8
        asl
        asl
        asl
        bcc +
        inc bm_ptr+1
+       clc
        adc bm_ptr
        sta bm_ptr
        bcc +
        inc bm_ptr+1
+       lda row_off_lo,x
        clc
        adc bm_col
        sta bm_cptr
        lda row_off_hi,x
        adc #>TALK_CELLCOL
        sta bm_cptr+1
        rts

; bm_putc: glyph A at the current cell in colour bm_fg, then move one cell right. Clobbers A, Y.
!zone bm_putc
bm_putc
        sta zp_tmp
        lda #0
        sta bm_src+1
        lda zp_tmp              ; bm_src = talk_font + code * 8
        asl
        rol bm_src+1
        asl
        rol bm_src+1
        asl
        rol bm_src+1
        clc
        adc #<talk_font
        sta bm_src
        lda bm_src+1
        adc #>talk_font
        sta bm_src+1
        ldy #7
-       lda (bm_src),y
        sta (bm_ptr),y
        dey
        bpl -
        lda bm_fg
        asl
        asl
        asl
        asl
        ldy #0
        sta (bm_cptr),y
        lda bm_ptr
        clc
        adc #8
        sta bm_ptr
        bcc +
        inc bm_ptr+1
+       inc bm_cptr
        bne +
        inc bm_cptr+1
+       inc bm_col
        rts

; bm_puts: the 0-terminated text at txt_ptr from (bm_col, bm_row); txt_ptr ends just past the 0
!zone bm_puts
bm_puts
        jsr bm_at
-       ldy #0
        lda (txt_ptr),y
        inc txt_ptr
        bne +
        inc txt_ptr+1
+       cmp #0
        beq +
        jsr bm_putc
        jmp -
+       rts

; bm_pad: spaces up to column 40
bm_pad
-       lda bm_col
        cmp #40
        bcs +
        lda #' '
        jsr bm_putc
        jmp -
+       rts

; talk_header: name, role and the trust meter (rows 0-2 from column 16)
!zone talk_header
talk_header
        ldy #DLG_NAME
        jsr dlg_word_to_txt
        lda #0
        jsr panel_row
        lda #COL_WHITE
        sta bm_fg
        jsr bm_puts
        jsr bm_pad
        ldy #DLG_ROLE
        jsr dlg_word_to_txt
        lda #1
        jsr panel_row
        lda #COL_LGREY
        sta bm_fg
        jsr bm_puts
        jsr bm_pad
        lda #2                  ; "Trust " + meter + " " + tier word
        jsr panel_row
        jsr bm_at
        lda #<txt_trust
        sta txt_ptr
        lda #>txt_trust
        sta txt_ptr+1
        jsr bm_puts_here
        lda #COL_YELLOW
        sta bm_fg
        ldx talk_person
        lda trust,x
        sta zp_row              ; tiers reached = trust + 1
        ldx #0
-       lda #BM_BLOCK
        cpx zp_row
        beq +
        bcc +
        lda #'.'
+       stx kd_i                ; meter cell index (bm_putc clobbers A, Y and zp_tmp)
        jsr bm_putc
        ldx kd_i
        inx
        cpx #4
        bne -
        lda #COL_LGREY
        sta bm_fg
        lda #' '
        jsr bm_putc
        ldx talk_person
        lda trust,x
        tax
        lda tier_lo,x
        sta txt_ptr
        lda tier_hi,x
        sta txt_ptr+1
        jsr bm_puts_here
        jmp bm_pad

; panel_row: bm_row = A, bm_col = PANEL_COL
panel_row
        sta bm_row
        lda #PANEL_COL
        sta bm_col
        rts

; bm_puts_here: like bm_puts, without re-pointing at (bm_col, bm_row)
bm_puts_here
-       ldy #0
        lda (txt_ptr),y
        inc txt_ptr
        bne +
        inc txt_ptr+1
+       cmp #0
        beq +
        jsr bm_putc
        jmp -
+       rts

; dlg_word_to_txt: txt_ptr = the word at (dlg_ptr) + Y
dlg_word_to_txt
        lda (dlg_ptr),y
        sta txt_ptr
        iny
        lda (dlg_ptr),y
        sta txt_ptr+1
        rts

; conv_reset: empty conversation area
conv_reset
        lda #0
        sta conv_n
        rts

; conv_lines: every line of the list at txt_ptr (ends with an empty line), colour bm_fg
!zone conv_lines
conv_lines
-       ldy #0
        lda (txt_ptr),y
        beq +
        jsr conv_line
        jmp -
+       inc txt_ptr             ; skip the list's final 0
        bne +
        inc txt_ptr+1
+       rts

; conv_line: one line (txt_ptr, 0-terminated) at the bottom of the conversation, colour bm_fg.
; The bitmap at $E000 sits under the KERNAL ROM, so the CPU can't read it back: the conversation is
; kept in conv_text/conv_col and a full area scrolls there, then is redrawn (writes only).
!zone conv_line
CONV_SHIFT = (CONV_LINES-1)*24 / 2      ; 168: the shift runs in two halves
conv_line
        lda conv_n
        cmp #CONV_LINES
        bcc .add
        ldx #0                  ; full: shift the stored lines up one - first half, then second
-       lda conv_text+24,x      ; (ascending, so a half never reads bytes it already moved; the
        sta conv_text,x         ; halves must not interleave)
        inx
        cpx #CONV_SHIFT
        bne -
        ldx #0
-       lda conv_text+24+CONV_SHIFT,x
        sta conv_text+CONV_SHIFT,x
        inx
        cpx #CONV_SHIFT
        bne -
        ldx #0
-       lda conv_col+1,x
        sta conv_col,x
        inx
        cpx #CONV_LINES-1
        bne -
        lda #CONV_LINES-1
        jsr conv_store
        jmp conv_redraw
.add    jsr conv_store
        inc conv_n
        jmp conv_draw_line

; conv_lptr: zp_dst = stored line A (keeps A)
conv_lptr
        tax
        lda conv_lo,x
        sta zp_dst
        lda conv_hi,x
        sta zp_dst+1
        txa
        rts

; conv_store: copy the line at txt_ptr (padded with spaces to 24) into stored line A, colour bm_fg.
; Leaves A = the line index; txt_ptr ends just past the 0.
!zone conv_store
conv_store
        sta conv_i
        tax
        lda bm_fg
        sta conv_col,x
        txa
        jsr conv_lptr
        ldy #0
-       lda (txt_ptr),y
        beq +
        sta (zp_dst),y
        iny
        cpy #24
        bne -
        dey                     ; (a full 24-char line: the terminator is at y=24)
        iny
+       tya
        sec                     ; txt_ptr += y + 1 (past the terminator)
        adc txt_ptr
        sta txt_ptr
        bcc +
        inc txt_ptr+1
+       lda #' '                ; pad
-       cpy #24
        bcs +
        sta (zp_dst),y
        iny
        bne -
+       lda conv_i
        rts

; conv_redraw: draw every stored line
conv_redraw
        lda #0
-       pha
        jsr conv_draw_line
        pla
        clc
        adc #1
        cmp #CONV_LINES
        bne -
        rts

; conv_draw_line: stored line A at screen row CONV_ROW + A
!zone conv_draw_line
conv_draw_line
        sta conv_i
        tax
        lda conv_col,x
        sta bm_fg
        txa
        clc
        adc #CONV_ROW
        jsr panel_row
        jsr bm_at
        lda conv_i
        jsr conv_lptr
        lda #0
        sta conv_j
-       ldy conv_j
        lda (zp_dst),y
        jsr bm_putc             ; (clobbers A, Y, zp_tmp - not zp_dst)
        inc conv_j
        lda conv_j
        cmp #24
        bne -
        rts

; ---- typing ----
; talk_key: one GETIN result in A
!zone talk_key
talk_key
        cmp #13
        beq .ret
        cmp #20
        beq .del
        cmp #193                ; shifted letters -> the same letters
        bcc +
        cmp #219
        bcs .out
        sec
        sbc #128
+       cmp #65
        bcc .out
        cmp #91
        bcs .out
        ldx input_len
        cpx #12
        bcs .out
        sec
        sbc #64                 ; screen code 1-26
        sta input_buf,x
        inc input_len
        jmp prompt_draw
.del    lda input_len
        beq .out
        dec input_len
        jmp prompt_draw
.out    rts
.ret    lda input_len
        bne +
        jmp talk_leave
+       ldx #0                  ; "> WORD" in yellow (upper case: +64 in the mixed set)
        lda #'>'
        sta conv_buf
        lda #' '
        sta conv_buf+1
-       lda input_buf,x
        clc
        adc #64
        sta conv_buf+2,x
        inx
        cpx input_len
        bne -
        lda #0
        sta conv_buf+2,x
        lda #<conv_buf
        sta txt_ptr
        lda #>conv_buf
        sta txt_ptr+1
        lda #COL_YELLOW
        sta bm_fg
        jsr conv_line
        jsr talk_ask
        lda #0
        sta input_len
        jmp prompt_draw

; talk_ask: answer the word in input_buf/input_len (Task 5 replaces this stub: always "unknown")
talk_ask
        ldy #DLG_UNKNOWN
        jsr dlg_word_to_txt
        lda #COL_LGREY
        sta bm_fg
        jmp conv_lines

; ---- data ----
bmrow_lo !for r, 0, 19 { !byte <(TALK_BITMAP + r*320) }
bmrow_hi !for r, 0, 19 { !byte >(TALK_BITMAP + r*320) }
txt_trust !byte 84, 18, 21, 19, 20, 32, 0                         ; "Trust "
tier_lo  !byte <tier_0, <tier_1, <tier_2, <tier_3
tier_hi  !byte >tier_0, >tier_1, >tier_2, >tier_3
tier_0   !byte 87, 65, 82, 89, 0                                  ; WARY
tier_1   !byte 71, 85, 65, 82, 68, 69, 68, 0                      ; GUARDED
tier_2   !byte 79, 80, 69, 78, 0                                  ; OPEN
tier_3   !byte 70, 82, 73, 69, 78, 68, 76, 89, 0                  ; FRIENDLY
conv_buf !fill 16, 0
conv_lo  !for i, 0, CONV_LINES-1 { !byte <(conv_text + i*24) }
conv_hi  !for i, 0, CONV_LINES-1 { !byte >(conv_text + i*24) }
conv_i   !byte 0
conv_j   !byte 0
conv_col !fill CONV_LINES, 0
conv_text !fill CONV_LINES*24, ' '
talk_font !fill 128*8 + 8, 0
