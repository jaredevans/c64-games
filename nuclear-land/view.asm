; Nuclear Land - map view drawing
;
; The view is 40 x MAP_ROWS cells; view row r is screen row ROW_MAP+r. Characters go to a screen
; page; colours (looked up per character in tilecolors) go either straight to colour RAM (first
; draw) or to COLBUF, which colbuf_to_colram copies into colour RAM in the frame of a buffer flip.

; row address tables (screen-relative offset of screen row r)
row_off_lo
        !for r, 0, 24 { !byte <(r * 40) }
row_off_hi
        !for r, 0, 24 { !byte >(r * 40) }

; view_build: draw view rows [view_row, view_end) for camera (view_cx, view_cy) into screen page
; view_page, colours to page base view_colhi. Clobbers A, X, Y, zp_src/dst/col, zp_tmp.
view_build
.row    lda view_cy             ; zp_src = map_data + (view_cy + row) * 64 + view_cx
        clc
        adc view_row
        sta zp_tmp
        lda #0
        sta zp_src+1
        lda zp_tmp
        !for i, 1, 6 {
        asl
        rol zp_src+1
        }
        clc
        adc view_cx
        bcc +
        inc zp_src+1
+       clc
        adc #<map_data
        sta zp_src
        lda zp_src+1
        adc #>map_data
        sta zp_src+1
        ldx view_row
        lda row_off_lo + ROW_MAP,x
        sta zp_dst
        sta zp_col
        lda row_off_hi + ROW_MAP,x
        tay
        clc
        adc view_page
        sta zp_dst+1
        tya
        clc
        adc view_colhi
        sta zp_col+1
        ldy #VIEW_COLS-1
-       lda (zp_src),y
        sta (zp_dst),y
        tax
        lda tilecolors,x
        sta (zp_col),y
        dey
        bpl -
        inc view_row
        lda view_row
        cmp view_end
        bne .row
        rts

; view_draw_full: draw the whole view at (cam_x, cam_y) into screen page A, colours to colour RAM
view_draw_full
        sta view_page
        lda #>COLRAM
        sta view_colhi
        lda cam_x
        sta view_cx
        lda cam_y
        sta view_cy
        lda #0
        sta view_row
        lda #MAP_ROWS
        sta view_end
        jmp view_build

; colbuf_to_colram: copy the map band (screen rows ROW_MAP..ROW_MAP+MAP_ROWS-1) of COLBUF to
; colour RAM. Unrolled per row: ~6800 cycles, done right after frame_ready so it finishes before
; the next frame's map band starts.
colbuf_to_colram
        ldx #VIEW_COLS-1
-       !for r, ROW_MAP, ROW_MAP + MAP_ROWS - 1 {
        lda COLBUF + r*40,x
        sta COLRAM + r*40,x
        }
        dex
        bpl -
        rts

; clear_screen: fill screen page in A (all 1 KB) with blank
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

