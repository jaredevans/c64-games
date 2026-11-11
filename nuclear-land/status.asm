; Nuclear Land - status line (screen row 0, both buffers): place name + Geiger meter
;
;   cols 0-26  "cinderhill - " + the leader's place name (14 chars, from gen/<map>.inc)   cyan
;   cols 28-30 "rad"                                                                       cyan
;   cols 32-39 Geiger meter: map_rad at the leader (0..8) cells lit         yellow / light red
; The fixed text and all colours are written once by status_init; status_draw rewrites only the
; name and the meter (on start and after every completed step).

STATUS_NAME_COL  = 13
STATUS_METER_COL = 32

!zone status_init
status_init
        ldx #39
-       lda status_fixed,x
        sta SCREEN_A + ROW_STATUS*40,x
        sta SCREEN_B + ROW_STATUS*40,x
        lda status_cols,x
        sta COLRAM + ROW_STATUS*40,x
        dex
        bpl -
        ; fall through

; status_draw: place name + meter for (leader_x, leader_y). Clobbers A, X, Y, zp_src, zp_tmp, zp_row.
!zone status_draw
status_draw
        ldx #0                  ; first place rect containing the leader (the last one is the map)
-       lda leader_x
        cmp place_x0,x
        bcc .next
        lda place_x1,x
        cmp leader_x
        bcc .next
        lda leader_y
        cmp place_y0,x
        bcc .next
        lda place_y1,x
        cmp leader_y
        bcs .found
.next   inx
        cpx #PLACE_N-1
        bne -
.found  lda place_name_lo,x
        sta zp_src
        lda place_name_hi,x
        sta zp_src+1
        ldy #13
-       lda (zp_src),y
        sta SCREEN_A + ROW_STATUS*40 + STATUS_NAME_COL,y
        sta SCREEN_B + ROW_STATUS*40 + STATUS_NAME_COL,y
        dey
        bpl -
        lda leader_x
        sta zp_tmp
        lda leader_y
        sta zp_row
        jsr rad_at
        sta zp_tmp              ; cells < rad are lit
        ldx #0
-       lda #G_METER_OFF
        cpx zp_tmp
        bcs +
        lda #G_METER_ON
+       sta SCREEN_A + ROW_STATUS*40 + STATUS_METER_COL,x
        sta SCREEN_B + ROW_STATUS*40 + STATUS_METER_COL,x
        inx
        cpx #8
        bne -
        rts

; rad_at: A = radiation level (0..8, 8 = on a hot spot) at cell (zp_tmp, zp_row); 0 in the basement
; (rows MAP_H and up: map_rad only covers the town). Clobbers Y, zp_src.
!zone rad_at
rad_at
        lda zp_row
        cmp #MAP_H
        bcc +
        lda #0
        rts
+       jsr map_cell_ptr
        lda zp_src
        clc
        adc #<(map_rad - map_data)
        sta zp_src
        lda zp_src+1
        adc #>(map_rad - map_data)
        sta zp_src+1
        ldy #0
        lda (zp_src),y
        rts

status_fixed
        !scr "cinderhill - "
        !fill 14, ' '
        !scr " rad "
        !fill 8, ' '
status_cols
        !fill 32, COL_CYAN
        !fill 4, COL_YELLOW
        !fill 4, COL_LRED
