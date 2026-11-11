; Nuclear Land - townspeople: hardware sprites 1..PEOPLE_N (at most 7), one per person
;
; Each person stands on a map cell. A sprite's screen position follows the same formula as the
; leader's, from the camera and this frame's fine scroll, so people move with the map pixel for pixel:
;   sx = 24 + (x - cam_x)*8 + fine_x + ox        sy = 50 + (ROW_MAP + y - cam_y)*8 - 8 + fine_y + oy
; ox/oy are a mover's pixel offsets mid-step (-7..7, 0 at rest).
;
; Visibility: a sprite is shown only when 0 <= x - cam_x <= 39 and 76 <= sy <= 189. Its DMA then
; covers raster 75..209 at most - never the top split (lines 62-74) or the bottom split (210-218) -
; and no pixel lands outside the map window. People pop in/out at the window's top/bottom edges.
; Left/right edges need nothing: the 38-column border covers sprites.
;
; Movers (wander box bx0 != $ff; Pip in Cinderhill) step one cell at a time while the leader is idle:
; target inside the box, passable, not hot, not the leader, not another person. A step sets the new
; cell at once (the old one stays occupied as the from-cell until ox/oy reach 0, 1 px per frame).

PEOPLE_WAIT0 = 40               ; frames before a mover's first step

!zone people_init
people_init
        ldx #0
        cpx #PEOPLE_N
        beq .done
-       lda people_x0,x
        sta people_x,x
        sta people_fx,x
        lda people_y0,x
        sta people_y,x
        sta people_fy,x
        lda #0
        sta people_ox,x
        sta people_oy,x
        lda #PEOPLE_WAIT0
        sta people_wait,x
        lda people_col,x
        sta VIC_SPR0COL+1,x
        lda people_ptr,x
        sta SCREEN_A + $3f8 + 1,x
        sta SCREEN_B + $3f8 + 1,x
        inx
        cpx #PEOPLE_N
        bne -
.done   ldx #63                 ; kid shape after the adult/leader shape
-       lda kid_shape,x
        sta SPRITES + 64,x
        dex
        bpl -
        lda #1
        sta lfsr
        rts

; person_at: C=1 and X = index if a person occupies cell (zp_tmp, zp_row) - their cell, or the cell
; they are still stepping out of. Keeps zp_tmp/zp_row. Clobbers A, X.
!zone person_at
person_at
        ldx #0
        cpx #PEOPLE_N
        beq .none
-       lda people_x,x
        cmp zp_tmp
        bne +
        lda people_y,x
        cmp zp_row
        beq .hit
+       lda people_ox,x
        ora people_oy,x
        beq +
        lda people_fx,x
        cmp zp_tmp
        bne +
        lda people_fy,x
        cmp zp_row
        beq .hit
+       inx
        cpx #PEOPLE_N
        bne -
.none   clc
        rts
.hit    sec
        rts

; people_update: once per frame - movers glide on, or (leader idle) maybe start a step
!zone people_update
people_update
        ldx #0
        cpx #PEOPLE_N
        bne .loop
        rts
.loop   lda people_bx0,x
        cmp #$ff
        beq .next
        lda people_ox,x         ; mid-step: 1 px closer to the cell
        ora people_oy,x
        beq .rest
        lda people_ox,x
        jsr toward0
        sta people_ox,x
        lda people_oy,x
        jsr toward0
        sta people_oy,x
        jmp .next
.rest   lda glide_dir           ; only while the leader stands still
        cmp #DIR_NONE
        bne .next
        dec people_wait,x
        bne .next
        stx pp_i
        jsr people_try_step
        ldx pp_i
        jsr lfsr_next
        and #31
        clc
        adc #40
        sta people_wait,x
.next   inx
        cpx #PEOPLE_N
        bne .loop
        rts

; toward0: A (signed) moved 1 toward 0
!zone toward0
toward0
        cmp #0
        beq +
        bmi ++
        sec
        sbc #1
+       rts
++      clc
        adc #1
        rts

; people_try_step: person pp_i tries a step in a random direction
!zone people_try_step
people_try_step
        jsr lfsr_next
        and #3
        tay
        ldx pp_i
        lda people_x,x
        clc
        adc dir_dx,y
        sta zp_tmp
        lda people_y,x
        clc
        adc dir_dy,y
        sta zp_row
        sty pp_dir
        lda zp_tmp              ; inside the wander box?
        cmp people_bx0,x
        bcc .no
        lda people_bx1,x
        cmp zp_tmp
        bcc .no
        lda zp_row
        cmp people_by0,x
        bcc .no
        lda people_by1,x
        cmp zp_row
        bcc .no
        lda zp_tmp              ; not the leader's cell
        cmp leader_x
        bne +
        lda zp_row
        cmp leader_y
        beq .no
+       jsr person_at           ; not another person
        bcs .no
        jsr map_cell_ptr        ; passable
        ldy #0
        lda (zp_src),y
        cmp #BLOCK_BASE
        bcs .no
        jsr rad_at              ; not hot
        cmp #8
        beq .no
        ldx pp_i                ; go: from-cell = old cell, offset = -8 * direction
        ldy pp_dir
        lda people_x,x
        sta people_fx,x
        lda people_y,x
        sta people_fy,x
        lda zp_tmp
        sta people_x,x
        lda zp_row
        sta people_y,x
        lda step_ox,y
        sta people_ox,x
        lda step_oy,y
        sta people_oy,x
.no     rts

; lfsr_next: 8-bit Galois LFSR (taps $B8), A = new value
!zone lfsr_next
lfsr_next
        lda lfsr
        lsr
        bcc +
        eor #$b8
+       sta lfsr
        rts

; people_place: write sprites 1..PEOPLE_N for this frame's camera and fine scroll (call after
; walk_update and sprite_place, before the top split at raster 62). Clobbers A, X, Y.
!zone people_place
people_place
        lda #1                  ; leader always on
        sta spr_enable
        lda VIC_SPRMSB
        and #1
        sta pp_msb
        ldx #0
        cpx #PEOPLE_N
        bne .pl
        jmp .out
.pl     lda pp_bit_tbl,x
        sta pp_bit
        lda people_x,x          ; dx = x - cam_x, visible iff 0..39 (unsigned)
        sec
        sbc cam_x
        cmp #40
        bcs .next
        sta pp_dx
        lda people_y,x          ; dy = y - cam_y, must be 0..MAP_ROWS-1
        sec
        sbc cam_y
        cmp #MAP_ROWS
        bcs .next
        asl                     ; sy = 58 + dy*8 + fine_y + oy (fits a byte: <= 58+136+7+7)
        asl
        asl
        clc
        adc #58
        adc fine_y
        clc
        adc people_oy,x
        cmp #76
        bcc .next
        cmp #190
        bcs .next
        pha
        txa
        asl
        tay                     ; Y = 2*i: sprite i+1 registers at VIC_SPR0X+2+Y / VIC_SPR0Y+2+Y
        pla
        sta VIC_SPR0Y+2,y
        lda #0                  ; sx = 24 + dx*8 + fine_x + ox, 9 bits
        sta pp_hi
        lda pp_dx
        asl
        rol pp_hi
        asl
        rol pp_hi
        asl
        rol pp_hi
        clc
        adc #24
        bcc +
        inc pp_hi
+       clc
        adc fine_x
        bcc +
        inc pp_hi
+       clc
        adc people_ox,x
        sta VIC_SPR0X+2,y
        lda people_ox,x         ; signed add: carry means "no borrow" for a negative offset
        bmi +
        bcc ++
        inc pp_hi
        jmp ++
+       bcs ++
        dec pp_hi
++      lda pp_hi
        and #1
        beq +
        lda pp_msb
        ora pp_bit
        sta pp_msb
+       lda spr_enable
        ora pp_bit
        sta spr_enable
.next   inx
        cpx #PEOPLE_N
        beq .out
        jmp .pl
.out    lda spr_enable
        sta VIC_SPREN
        lda pp_msb
        sta VIC_SPRMSB
        rts

pp_bit_tbl !byte 2, 4, 8, 16, 32, 64, 128
step_ox    !byte 0, 0, 8, $f8      ; -8 * dx: up, down, left, right
step_oy    !byte 8, $f8, 0, 0

kid_shape                       ; shorter figure (Pip), same 8px column, rows 7-15
        !fill 7*3, 0
        !byte %00011000,0,0
        !byte %00111100,0,0
        !byte %00011000,0,0
        !byte %00111100,0,0
        !byte %01011010,0,0
        !byte %00011000,0,0
        !byte %00100100,0,0
        !byte %00100100,0,0
        !byte %01100110,0,0
        !fill 12*3, 0
        !byte 0

; runtime state
people_x    !fill 7, 0
people_y    !fill 7, 0
people_fx   !fill 7, 0
people_fy   !fill 7, 0
people_ox   !fill 7, 0
people_oy   !fill 7, 0
people_wait !fill 7, 0
