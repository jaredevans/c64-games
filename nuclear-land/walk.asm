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
;
; The camera follows the leader (leader on view cell LEADER_COL, LEADER_ROW) but is clamped to
; [0, MAP_W-VIEW_COLS+1] x [0, MAP_H-MAP_ROWS]. When a step would not move the clamped camera, the
; leader sprite glides 8 px instead and the map stays at rest.

CAM_MAX_X = MAP_W - VIEW_COLS + 1      ; view column 39 is always under the 38-col border, so the
                                        ; map's last column must be allowed into view column 38
CAM_MAX_Y = MAP_H - MAP_ROWS

GLIDE_FRAMES = 8

walk_init
        lda #MAP_START_X
        sta leader_x
        lda #MAP_START_Y
        sta leader_y
        lda #DIR_NONE
        sta glide_dir
        lda #0
        sta heavy_job
        sta steps_done
        sta steps_done+1
        sta bumps
        sta glide_spr
        sta spr_off_x
        sta spr_off_y
        lda #<LEADER_SX
        sta spr_x
        lda #>LEADER_SX
        sta spr_x+1
        lda #LEADER_SY
        sta spr_y
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
        bcs .bump
        jsr person_at           ; townspeople block like walls
        bcc .go
.bump   inc bumps
        rts
.go     ldx cur_dir
        stx glide_dir
        lda zp_tmp
        sta leader_x
        lda zp_row
        sta leader_y
        ; new camera = clamp(leader - (LEADER_COL, LEADER_ROW))
        lda leader_x
        sec
        sbc #LEADER_COL
        bcs +
        lda #0
+       cmp #CAM_MAX_X+1
        bcc +
        lda #CAM_MAX_X
+       sta bcam_x
        lda leader_y
        sec
        sbc #LEADER_ROW
        bcs +
        lda #0
+       cmp #CAM_MAX_Y+1
        bcc +
        lda #CAM_MAX_Y
+       sta bcam_y
        ldy #0                  ; glide_spr = camera unchanged
        lda bcam_x
        cmp cam_x
        bne +
        lda bcam_y
        cmp cam_y
        bne +
        iny
+       sty glide_spr
        lda #0
        sta glide_p
        inc steps_done
        bne .glide
        inc steps_done+1

.glide  inc glide_p
        lda glide_spr
        beq .scroll
        jsr sprite_step         ; camera clamped: move the sprite 1 px, map stays at rest
        jmp .chk
.scroll lda glide_dir           ; fine offsets for this pixel
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
        lda glide_p             ; p=1..3: build a third of the back buffer each frame (walk_heavy)
        cmp #4
        bcs .noblk
        lda #HEAVY_BUILD
        sta heavy_job
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
        lda leader_x            ; step done: record the leader's offset from the view centre
        sec
        sbc cam_x
        sec
        sbc #LEADER_COL
        sta spr_off_x
        lda leader_y
        sec
        sbc cam_y
        sec
        sbc #LEADER_ROW
        sta spr_off_y
        jmp on_step_end
+       rts

; on_step_end: once per completed step (scrolling or sprite glide), on its last glide frame - never
; a buffer-flip frame
on_step_end
        jsr squad_step          ; radiation, Maren's recovery, heal cooldown
        jmp status_draw

; sprite_step: move the leader sprite 1 px in glide_dir
sprite_step
        ldx glide_dir
        lda spr_y
        clc
        adc dir_dy,x
        sta spr_y
        lda dir_dx,x
        bmi .sl
        clc
        adc spr_x
        sta spr_x
        bcc +
        inc spr_x+1
+       rts
.sl     lda spr_x               ; dx = -1
        bne +
        dec spr_x+1
+       dec spr_x
        rts

; sprite_place: write the leader sprite position to the VIC (once per frame, after walk_update)
sprite_place
        lda spr_x
        sta VIC_SPR0X
        lda spr_y
        sta VIC_SPR0Y
        lda VIC_SPRMSB
        and #%11111110
        ora spr_x+1
        sta VIC_SPRMSB
        rts

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

; flip_buffers: show the back buffer from the next frame on; its colours go to colour RAM in this
; frame's walk_heavy (after the sprites are placed, still before the next frame's map band)
flip_buffers
        lda vis_buf
        eor #1
        sta vis_buf
        lda bcam_x
        sta cam_x
        lda bcam_y
        sta cam_y
        lda #HEAVY_COLOURS
        sta heavy_job
        rts

; walk_heavy: this frame's long job, run by the main loop after sprite placement: a third of the
; back buffer (glide p=1..3, ~130 raster lines, no deadline - the buffer is hidden) or the colour
; copy of a flip frame (~105 lines, must end before the map band at raster 74)
HEAVY_NONE    = 0
HEAVY_BUILD   = 1
HEAVY_COLOURS = 2
walk_heavy
        ldx heavy_job
        beq +
        lda #HEAVY_NONE
        sta heavy_job
        cpx #HEAVY_BUILD
        beq build_back_third
        jmp colbuf_to_colram
+       rts

; map_cell_ptr: zp_src = map_data + zp_row*64 + zp_tmp
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
        adc #<map_data
        sta zp_src
        lda zp_src+1
        adc #>map_data
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
