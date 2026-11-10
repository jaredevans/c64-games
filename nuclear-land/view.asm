; Nuclear Land - map view drawing

; row address tables for the map band (screen-relative offsets of rows ROW_MAP..)
row_off_lo
        !for r, 0, 24 { !byte <(r * 40) }
row_off_hi
        !for r, 0, 24 { !byte >(r * 40) }

; view_draw_full: draw the 40 x MAP_ROWS view at (cam_x, cam_y) into screen page in A (hi byte,
; e.g. >SCREEN_A) and colour RAM.
view_draw_full
        sta view_page
        lda #0
        sta zp_row
.row    ; zp_src = testmap + (cam_y + row) * 64 + cam_x
        lda cam_y
        clc
        adc zp_row
        sta zp_tmp              ; map row
        lda #0
        sta zp_src+1
        lda zp_tmp
        asl
        rol zp_src+1
        asl
        rol zp_src+1
        asl
        rol zp_src+1
        asl
        rol zp_src+1
        asl
        rol zp_src+1
        asl
        rol zp_src+1            ; *64
        clc
        adc cam_x
        bcc +
        inc zp_src+1
+       clc
        adc #<testmap
        sta zp_src
        lda zp_src+1
        adc #>testmap
        sta zp_src+1
        ; zp_dst = screen + (ROW_MAP+row)*40 ; zp_col = COLRAM + same
        ldx zp_row
        lda row_off_lo + ROW_MAP,x
        sta zp_dst
        sta zp_col
        lda row_off_hi + ROW_MAP,x
        clc
        adc view_page
        sta zp_dst+1
        lda row_off_hi + ROW_MAP,x
        clc
        adc #>COLRAM
        sta zp_col+1
        ldy #VIEW_COLS-1
-       lda (zp_src),y
        sta (zp_dst),y
        tax
        lda tilecolors,x
        sta (zp_col),y
        dey
        bpl -
        inc zp_row
        lda zp_row
        cmp #MAP_ROWS
        bne .row
        rts

view_page !byte 0

; clear_screen: fill screen page in A (4 x 256 bytes incl. sprite ptrs region; ptrs set after) with
; blank and colour RAM with black.
clear_screen
        sta zp_dst+1
        lda #0
        sta zp_dst
        ldx #4
        ldy #0
        lda #T_BLANK
-       sta (zp_dst),y
        iny
        bne -
        inc zp_dst+1
        dex
        bne -
        rts

testmap
        !binary "gen/testmap.bin"
