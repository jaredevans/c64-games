; Nuclear Land - leader movement: one tile per step, each step a GLIDE_FRAMES-frame smooth glide
;
; Idle: if a direction is held and the target cell is passable (< BLOCK_BASE), start a glide;
; if blocked, count a bump. Input is only sampled when idle, so releasing a key mid-glide finishes
; that step and queues nothing.
;
; Gliding, pixel p = 1..8 (one per frame): the map band's fine offset follows fine_tbl. Fine offsets
; only span 0..7 around the rest value 4, so each glide does one coarse step where the offset wraps
; (p=4 walking up/left, p=5 walking down/right): show the back buffer, which was built for the
; camera one cell over during p=1..3, and copy its colours into colour RAM.

GLIDE_FRAMES = 8

walk_init
        lda #START_CX + LEADER_COL
        sta leader_x
        lda #START_CY + LEADER_ROW
        sta leader_y
        lda #DIR_NONE
        sta glide_dir
        lda #0
        sta steps_done
        sta steps_done+1
        sta bumps
        rts

; walk_update: once per frame, after input_read
walk_update
        lda glide_dir
        bpl .glide
        lda cur_dir
        bpl +
        rts                     ; idle, nothing held
+       tax
        ; target cell = leader + delta, looked up in the map
        lda leader_x
        clc
        adc dir_dx,x
        sta zp_tmp              ; target x
        lda leader_y
        clc
        adc dir_dy,x
        sta zp_row              ; target y
        jsr map_cell_ptr        ; zp_src -> map[zp_row][zp_tmp]
        ldy #0
        lda (zp_src),y
        cmp #BLOCK_BASE
        bcc .go
        inc bumps
        rts
.go     ldx cur_dir
        stx glide_dir
        lda zp_tmp
        sta leader_x
        lda zp_row
        sta leader_y
        lda cam_x
        clc
        adc dir_dx,x
        sta bcam_x
        lda cam_y
        clc
        adc dir_dy,x
        sta bcam_y
        lda #0
        sta glide_p
        inc steps_done
        bne .glide
        inc steps_done+1

.glide  inc glide_p
        lda glide_dir           ; fine offsets for this pixel
        asl
        asl
        asl
        clc
        adc glide_p
        tax
        lda fine_tbl_x-1,x
        sta fine_x
        lda fine_tbl_y-1,x
        sta fine_y
        lda glide_p             ; p=1..3: build a third of the back buffer each frame
        cmp #4
        bcs .noblk
        jsr build_back_third
        jmp .chk
.noblk  ldx glide_dir
        cmp flip_p,x
        bne .chk
        jsr flip_buffers
.chk    lda glide_p
        cmp #GLIDE_FRAMES
        bne +
        lda #DIR_NONE
        sta glide_dir
+       rts

; build_back_third: view rows (p-1)*6 .. p*6-1 of camera (bcam_x, bcam_y) into the hidden screen,
; colours into COLBUF
build_back_third
        lda vis_buf
        eor #1
        tax
        lda screen_page_tbl,x
        sta view_page
        lda #>COLBUF
        sta view_colhi
        lda bcam_x
        sta view_cx
        lda bcam_y
        sta view_cy
        ldx glide_p
        lda third_start-1,x
        sta view_row
        lda third_start,x
        sta view_end
        jmp view_build

; flip_buffers: show the back buffer from the next frame on; its colours go to colour RAM now
; (we are just past frame_ready, before the next frame's map band)
flip_buffers
        lda vis_buf
        eor #1
        sta vis_buf
        lda bcam_x
        sta cam_x
        lda bcam_y
        sta cam_y
        jmp colbuf_to_colram

; map_cell_ptr: zp_src = testmap + zp_row*64 + zp_tmp
map_cell_ptr
        lda #0
        sta zp_src+1
        lda zp_row
        !for i, 1, 6 {
        asl
        rol zp_src+1
        }
        clc
        adc zp_tmp
        bcc +
        inc zp_src+1
+       clc
        adc #<testmap
        sta zp_src
        lda zp_src+1
        adc #>testmap
        sta zp_src+1
        rts

dir_dx  !byte 0, 0, $ff, 1              ; up, down, left, right
dir_dy  !byte $ff, 1, 0, 0
flip_p  !byte 4, 5, 4, 5
third_start !byte 0, MAP_ROWS/3, 2*MAP_ROWS/3, MAP_ROWS
screen_page_tbl !byte >SCREEN_A, >SCREEN_B
; fine offsets for p = 1..8, per direction (rest = 4)
fine_tbl_x
        !byte 4, 4, 4, 4, 4, 4, 4, 4    ; up
        !byte 4, 4, 4, 4, 4, 4, 4, 4    ; down
        !byte 5, 6, 7, 0, 1, 2, 3, 4    ; left  (content moves right; coarse step at p=4)
        !byte 3, 2, 1, 0, 7, 6, 5, 4    ; right (content moves left; coarse step at p=5)
fine_tbl_y
        !byte 5, 6, 7, 0, 1, 2, 3, 4    ; up    (content moves down; coarse step at p=4)
        !byte 3, 2, 1, 0, 7, 6, 5, 4    ; down  (content moves up; coarse step at p=5)
        !byte 4, 4, 4, 4, 4, 4, 4, 4    ; left
        !byte 4, 4, 4, 4, 4, 4, 4, 4    ; right
