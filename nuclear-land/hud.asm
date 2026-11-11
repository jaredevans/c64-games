; Nuclear Land - squad strip: screen rows 20-23 (ROW_HUD), shown on raster 219-250, both buffers
;
;   row 20  member m at col 10m: '>' if leader, then the name - yellow (leader), light red (sick),
;           white
;   row 21  health: cols 10m+1..10m+8, cell i = G_BAR[clamp(hp - 4i, 0, 4)] in green; "sick" in
;           light red at 0
;   row 22  message line (light grey)
;   row 23  key hints (dark grey), fixed

ROW_NAMES = ROW_HUD
ROW_BARS  = ROW_HUD + 1
ROW_MSG   = ROW_HUD + 2
ROW_HINT  = ROW_HUD + 3

; hud_draw: the whole strip, at start (before the IRQ chain runs)
!zone hud_draw
hud_draw
        ldx #39
-       lda hud_hint,x
        sta SCREEN_A + ROW_HINT*40,x
        sta SCREEN_B + ROW_HINT*40,x
        lda #COL_DGREY
        sta COLRAM + ROW_HINT*40,x
        lda #COL_LGREY
        sta COLRAM + ROW_MSG*40,x
        dex
        bpl -
        jmp hud_rows

; hud_update: redraw rows 20-22 if something changed - never while the strip is on screen
!zone hud_update
hud_update
        lda hud_dirty
        bne +
        rts
+
-       lda VIC_CTRL1           ; raster >= 256: fine
        bmi hud_rows
        lda VIC_RASTER
        cmp #219
        bcc hud_rows
        cmp #251
        bcc -
; hud_rows: rows 20-22 + their colours
hud_rows
        lda #0
        sta hud_dirty
        ldx #39                 ; message line
-       lda msg_buf,x
        sta SCREEN_A + ROW_MSG*40,x
        sta SCREEN_B + ROW_MSG*40,x
        dex
        bpl -
        ldx #39                 ; clear names/bars rows
        lda #' '
-       sta SCREEN_A + ROW_NAMES*40,x
        sta SCREEN_B + ROW_NAMES*40,x
        sta SCREEN_A + ROW_BARS*40,x
        sta SCREEN_B + ROW_BARS*40,x
        dex
        bpl -
        lda #0
        sta hud_m
.member ldx hud_m
        lda hud_col_tbl,x
        sta hud_c               ; first column of this member
        ; colour: yellow if leader, light red if sick, else white
        lda #COL_WHITE
        ldy squad_hp,x
        bne +
        lda #COL_LRED
+       cpx leader
        bne +
        lda #COL_YELLOW
+       sta hud_namecol
        ; '>' marker
        lda #' '
        cpx leader
        bne +
        lda #'>'
+       ldy hud_c
        sta SCREEN_A + ROW_NAMES*40,y
        sta SCREEN_B + ROW_NAMES*40,y
        ; name
        lda member_name_lo,x
        sta zp_src
        lda member_name_hi,x
        sta zp_src+1
        ldy #0
-       lda (zp_src),y
        beq +
        sty zp_tmp
        pha
        tya
        clc
        adc hud_c
        tay
        iny
        pla
        sta SCREEN_A + ROW_NAMES*40,y
        sta SCREEN_B + ROW_NAMES*40,y
        ldy zp_tmp
        iny
        bne -
+       ldy hud_c               ; name colours: cols c..c+9
        ldx #10
        lda hud_namecol
-       sta COLRAM + ROW_NAMES*40,y
        iny
        dex
        bne -
        ; health bar or "sick"
        ldx hud_m
        lda squad_hp,x
        sta zp_row              ; hp left to draw
        bne .bar
        ldy hud_c
        ldx #0
-       lda hud_sick,x
        sta SCREEN_A + ROW_BARS*40+1,y
        sta SCREEN_B + ROW_BARS*40+1,y
        lda #COL_LRED
        sta COLRAM + ROW_BARS*40+1,y
        iny
        inx
        cpx #8
        bne -
        jmp .nextm
.bar    ldy hud_c
        ldx #8
-       lda zp_row              ; cell = min(4, hp left)
        cmp #4
        bcc +
        lda #4
+       sta zp_tmp
        lda zp_row
        sec
        sbc zp_tmp
        sta zp_row
        stx hud_k
        ldx zp_tmp
        lda bar_glyph,x
        sta SCREEN_A + ROW_BARS*40+1,y
        sta SCREEN_B + ROW_BARS*40+1,y
        lda #COL_GREEN
        sta COLRAM + ROW_BARS*40+1,y
        ldx hud_k
        iny
        dex
        bne -
.nextm  inc hud_m
        lda hud_m
        cmp #4
        beq +
        jmp .member
+       rts

hud_col_tbl !byte 0, 10, 20, 30
bar_glyph   !byte G_BAR0, G_BAR1, G_BAR2, G_BAR3, G_BAR4
hud_sick    !scr "sick    "
hud_hint    !scr "1-4 leader  t talk  u use skill         "
hud_m       !byte 0
hud_c       !byte 0
hud_k       !byte 0
hud_namecol !byte 0
