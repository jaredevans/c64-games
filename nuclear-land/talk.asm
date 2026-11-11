; Nuclear Land - the talking screen (layout A): portrait beside the conversation
;
; Screen rows 0-18 are a hi-res bitmap (bitmap at TALK_BITMAP, cell colours in SCREEN_A): the
; portrait fills columns 0-15, the header and conversation columns 16-39. Rows 19-23 are text
; (screen SCREEN_B, the walking charset): Known keywords (rows 19-20), "<leader> leads. ask about:",
; the input prompt, a hint. Its own raster chain switches modes at the end of raster line 202 (in
; the right border), so the row-19 badline on line 203 already fetches text.
;
; Entering trashes the walking screen buffers and the sprite shapes ($E000 is the bitmap);
; talk_leave rebuilds everything from game state.

TALK_BITMAP  = $e000
TALK_CELLCOL = SCREEN_A
TALK_TEXT    = SCREEN_B
D011_BMP     = %00111011        ; BMM, DEN, RSEL, YSCROLL 3
D011_TXT     = %00011011
D011_OFF     = %00001011        ; display off (border colour), RSEL, YSCROLL 3
D018_TALKBMP = ((SCREEN_A - VIC_BANK) / $400) << 4 | %1000     ; cells $C000, bitmap $E000
TALK_IRQ_TOP = 16
TALK_IRQ_SPLIT = 200
TALK_SPLIT_LINE = 202
ROW_KNOWN    = 19
ROW_LEADS    = 21
ROW_PROMPT   = 22
ROW_THINT    = 23
SCNKEY       = $ff9f
GETIN        = $ffe4
KEYBUF       = $0277
KEYBUF_N     = $c6

; talk_enter: X = people index of the person to talk to (who has dialogue)
!zone talk_enter
talk_enter
        stx talk_people_i
        lda people_cast,x
        sta talk_person
        tax
        lda dlg_lo,x
        sta dlg_ptr
        lda dlg_hi,x
        sta dlg_ptr+1
        sei
        lda #0
        sta VIC_SPREN
        lda #D011_OFF
        sta VIC_CTRL1
        ldx #>TALK_BITMAP       ; clear the bitmap ($E000-$FFFF, RAM under the KERNAL ROM)
        lda #0
        jsr fill_pages_32
        lda #>TALK_CELLCOL      ; cell colours: black on black
        sta zp_dst+1
        lda #0
        jsr fill_1k
        lda #>TALK_TEXT
        jsr clear_screen
        jsr portrait_blit
        jsr talk_header
        jsr conv_reset          ; the greeting opens the conversation
        ldy #DLG_GREET
        jsr dlg_word_to_txt
        lda #COL_LGREY
        sta bm_fg
        jsr conv_lines
        jsr talk_bottom
        jsr SCNKEY              ; the T key may still be down: register it, then drop it
        lda #0
        sta KEYBUF_N
        sta input_len
        lda #<talk_irq_top
        sta $0314
        lda #>talk_irq_top
        sta $0315
        lda #TALK_IRQ_TOP
        sta VIC_RASTER
        lda #1
        sta VIC_IRQ
        lda #MODE_TALK
        sta game_mode
        cli
        rts

; fill_pages_32: 32 pages from X*256 with A
!zone fill
fill_pages_32
        stx zp_dst+1
        ldy #0
        sty zp_dst
        ldx #32
-       sta (zp_dst),y
        iny
        bne -
        inc zp_dst+1
        dex
        bne -
        rts
; fill_1k: 4 pages from zp_dst+1 (hi) with A
fill_1k
        ldy #0
        sty zp_dst
        ldx #4
-       sta (zp_dst),y
        iny
        bne -
        inc zp_dst+1
        dex
        bne -
        rts

; portrait_blit: the talk person's 16x19-cell portrait into bitmap columns 0-15
!zone portrait_blit
portrait_blit
        lda talk_person
        tax
        lda portrait_lo,x
        sta zp_src
        lda portrait_hi,x
        sta zp_src+1
        lda #<TALK_BITMAP
        sta zp_dst
        lda #>TALK_BITMAP
        sta zp_dst+1
        ldx #19
.bmrow  ldy #127                ; 16 cells x 8 bytes, contiguous in the source
-       lda (zp_src),y
        sta (zp_dst),y
        dey
        bpl -
        lda zp_src
        clc
        adc #128
        sta zp_src
        bcc +
        inc zp_src+1
+       lda zp_dst              ; next bitmap row: +320
        clc
        adc #<320
        sta zp_dst
        lda zp_dst+1
        adc #>320
        sta zp_dst+1
        dex
        bne .bmrow
        lda #<TALK_CELLCOL      ; zp_src now points at the 304 colour bytes
        sta zp_dst
        lda #>TALK_CELLCOL
        sta zp_dst+1
        ldx #19
.colrow ldy #15
-       lda (zp_src),y
        sta (zp_dst),y
        dey
        bpl -
        lda zp_src
        clc
        adc #16
        sta zp_src
        bcc +
        inc zp_src+1
+       lda zp_dst
        clc
        adc #40
        sta zp_dst
        bcc +
        inc zp_dst+1
+       dex
        bne .colrow
        rts

; talk_bottom: the text rows 19-23 and their colours
!zone talk_bottom
talk_bottom
        jsr known_draw
        ldx leader              ; row 21: "<leader> leads. ask about:"
        lda member_name_lo,x
        sta zp_src
        lda member_name_hi,x
        sta zp_src+1
        ldy #0
-       lda (zp_src),y
        beq +
        sta TALK_TEXT + ROW_LEADS*40,y
        iny
        bne -
+       ldx #0
-       lda txt_leads,x
        beq +
        sta TALK_TEXT + ROW_LEADS*40,y
        iny
        inx
        bne -
+       ldx #39
-       lda txt_hint,x
        sta TALK_TEXT + ROW_THINT*40,x
        lda #COL_LGREY
        sta COLRAM + ROW_KNOWN*40,x
        sta COLRAM + (ROW_KNOWN+1)*40,x
        sta COLRAM + ROW_LEADS*40,x
        lda #COL_YELLOW
        sta COLRAM + ROW_PROMPT*40,x
        lda #COL_DGREY
        sta COLRAM + ROW_THINT*40,x
        dex
        bpl -
        ; fall through: the prompt

; prompt_draw: "> " + the typed word on row 22
prompt_draw
        lda #'>'
        sta TALK_TEXT + ROW_PROMPT*40
        lda #' '
        ldx #38
-       sta TALK_TEXT + ROW_PROMPT*40 + 1,x
        dex
        bpl -
        ldx #0
-       cpx input_len
        beq +
        lda input_buf,x
        sta TALK_TEXT + ROW_PROMPT*40 + 2,x
        inx
        bne -
+       lda #G_METER_ON         ; cursor
        sta TALK_TEXT + ROW_PROMPT*40 + 2,x
        rts

; known_draw: "known: " + the squad's known keywords on rows 19-20
!zone known_draw
known_draw
        lda #' '
        ldx #79
-       sta TALK_TEXT + ROW_KNOWN*40,x
        dex
        bpl -
        ldx #0
-       lda txt_known,x
        beq +
        sta TALK_TEXT + ROW_KNOWN*40,x
        inx
        bne -
+       stx kd_col
        ldy #0
.word   cpy known_n
        beq .out
        sty kd_i
        lda known_ids,y
        jsr kw_ptr              ; zp_src -> keyword text
        ldy #0
        ldx kd_col
-       lda (zp_src),y
        beq +
        cpx #80
        bcs .out
        sta TALK_TEXT + ROW_KNOWN*40,x
        inx
        iny
        cpy #KW_LEN
        bne -
+       inx                     ; space
        stx kd_col
        ldy kd_i
        iny
        bne .word
.out    rts

; kw_ptr: zp_src = kw_text + A * 12
kw_ptr
        sta zp_tmp
        lda #0
        sta zp_src+1
        lda zp_tmp              ; *12 = *8 + *4
        asl
        rol zp_src+1
        asl
        rol zp_src+1
        sta zp_src
        ldx zp_src+1
        asl
        rol zp_src+1
        clc
        adc zp_src
        sta zp_src
        txa
        adc zp_src+1
        sta zp_src+1
        lda zp_src
        clc
        adc #<kw_text
        sta zp_src
        lda zp_src+1
        adc #>kw_text
        sta zp_src+1
        rts

; talk_frame: once per frame while talking
!zone talk_frame
talk_frame
!ifdef TYPESCRIPT {
        jsr ts_step
}
        jsr SCNKEY
        jsr GETIN
        cmp #0
        beq +
        jmp talk_key
+       rts

; talk_leave: back to the town, rebuilt from game state
!zone talk_leave
talk_leave
        sei
        lda #D011_OFF
        sta VIC_CTRL1
        lda #>SCREEN_A
        jsr clear_screen
        lda #>SCREEN_B
        jsr clear_screen
        jsr clear_colram
        lda #0
        sta vis_buf
        lda #>SCREEN_A
        jsr view_draw_full
        jsr status_init
        jsr sprites_restore
        lda #<msg_leave
        ldx #>msg_leave
        jsr msg_set
        ldx talk_people_i
        lda people_name_lo,x
        pha
        lda people_name_hi,x
        tax
        pla
        jsr msg_add
        lda #<msg_dot
        ldx #>msg_dot
        jsr msg_add
        jsr hud_draw
        lda #ACT_NONE
        sta act_pending
        lda #MODE_WALK
        sta game_mode
        lda #<irq_top           ; the walking raster chain again (irq_top restores $D011/16/18)
        sta $0314
        lda #>irq_top
        sta $0315
        lda #IRQ_TOP_LINE
        sta VIC_RASTER
        lda #1
        sta VIC_IRQ
        cli
        rts

; sprites_restore: sprite shapes and pointers after the bitmap overwrote them
!zone sprites_restore
sprites_restore
        ldx #63
-       lda leader_shape,x
        sta SPRITES,x
        lda kid_shape,x
        sta SPRITES + 64,x
        dex
        bpl -
        lda #SPR_LEADER_PTR
        sta SCREEN_A + $3f8
        sta SCREEN_B + $3f8
        ldx #0
        cpx #PEOPLE_N
        beq +
-       lda people_ptr,x
        sta SCREEN_A + $3f8 + 1,x
        sta SCREEN_B + $3f8 + 1,x
        inx
        cpx #PEOPLE_N
        bne -
+       rts

; ---- raster chain while talking ----
talk_irq_top                    ; line 16: bitmap mode for rows 0-18, no sprites
        lda #D011_BMP
        sta VIC_CTRL1
        lda #D016_STD
        sta VIC_CTRL2
        lda #D018_TALKBMP
        sta VIC_MEM
        lda #0
        sta VIC_SPREN
        lda #<talk_irq_split
        sta $0314
        lda #>talk_irq_split
        sta $0315
        lda #TALK_IRQ_SPLIT
        sta VIC_RASTER
        lda #1
        sta VIC_IRQ
        jmp $ea81

talk_irq_split                  ; line 200: text mode from row 19 (badline 203)
        +wait_line TALK_SPLIT_LINE
        ldy #8                  ; ~40 cycles: past the visible part of line 202 (into the border)
-       dey
        bne -
        lda #D011_TXT
        sta VIC_CTRL1
        lda #D018_B
        sta VIC_MEM
        lda #1
        sta frame_ready
        lda #<talk_irq_top
        sta $0314
        lda #>talk_irq_top
        sta $0315
        lda #TALK_IRQ_TOP
        sta VIC_RASTER
        lda #1
        sta VIC_IRQ
        jmp $ea81

!ifdef TYPESCRIPT {
; ts_step: test hook - type the next character of the script whenever the keyboard buffer is empty,
; 3 frames apart (the script pauses while walking: it only runs from talk_frame)
!zone ts_step
ts_step
        lda KEYBUF_N
        bne .out
        lda ts_wait
        beq +
        dec ts_wait
.out    rts
+       ldy ts_pos
        lda ts_text,y
        beq .out
        sta KEYBUF
        lda #1
        sta KEYBUF_N
        inc ts_pos
        lda #3
        sta ts_wait
        rts
ts_pos  !byte 0
ts_wait !byte 0
ts_text
!if TYPESCRIPT = 1 {            ; tests/test_talk_leave.py: leave at once
        !byte 13
}
!if TYPESCRIPT = 4 {            ; tests/test_talk_text.py: 8 questions, stay
        !pet "water", 13, "pump", 13, "name", 13, "job", 13, "keepers", 13, "reactor", 13, "voss", 13
        !pet "tanks", 13
}
!if TYPESCRIPT = 3 {            ; tests/test_talk_input.py: junk, 14 letters, 3 DEL, RETURN, DEL, RETURN
        !pet "12!x", 13, "abcdefghijklmn", 20, 20, 20, 13, 20, 13
}
!if TYPESCRIPT = 8 {            ; tests/test_talk_input.py: junk, then 14 letters (prompt state)
        !pet "12!x", 13, "abcdefghijklmn"
}
        !byte 0
}

; ---- data ----
portrait_lo !byte <portrait_hesper, 0, 0, 0, 0, 0, 0, 0     ; by cast index
portrait_hi !byte >portrait_hesper, 0, 0, 0, 0, 0, 0, 0
portrait_hesper !binary "gen/portrait_hesper.bin"
txt_known  !scr "known: ", 0
txt_leads  !scr " leads. ask about:", 0
txt_hint   !scr "return on an empty line: leave          "
msg_leave  !scr "you leave ", 0
msg_dot    !scr ".", 0
talk_people_i !byte 0
talk_person   !byte 0
input_len     !byte 0
input_buf     !fill 12, ' '
kd_col        !byte 0
trust         !fill 8, 0          ; by cast index (Task 5: the rules)
kd_i          !byte 0
known_n       !byte 4
known_ids     !byte 0, 1, 2, 3
              !fill 28, 0
