; Nuclear Land - C64 prototype (walking engine)
; Build: acme -f cbm -l build/labels.txt -o build/nland.prg main.asm   (from nuclear-land/)

!cpu 6502
!source "hw.inc"
!source "gen/tiles.inc"

* = $0801
        !word basic_end, 10
        !byte $9e
        !text "2061"
        !byte 0
basic_end
        !word 0

* = $080d
start
        sei
        lda #$36                ; BASIC ROM out (COLBUF at $B800 must read back as RAM), KERNAL+I/O in
        sta $01
        lda #COL_DGREY
        sta VIC_BORDER
        lda #COL_BLACK
        sta VIC_BG0
        lda CIA2_PRA            ; VIC bank 3 (bits 0-1 = %00)
        and #%11111100
        sta CIA2_PRA
        lda #D018_A
        sta VIC_MEM
        lda #%00011011          ; DEN, RSEL, YSCROLL 3
        sta VIC_CTRL1
        lda #%00001000          ; CSEL (40 cols), XSCROLL 0
        sta VIC_CTRL2
        jsr charset_init
        jsr font_init
        lda #>SCREEN_A
        jsr clear_screen
        lda #>SCREEN_B
        jsr clear_screen
        jsr clear_colram
        lda #MAP_START_X - LEADER_COL       ; maps put the start where the camera is unclamped
        sta cam_x
        lda #MAP_START_Y - LEADER_ROW
        sta cam_y
        lda #>SCREEN_A
        jsr view_draw_full
        jsr sprite_init
        lda #FINE_REST_X
        sta fine_x
        lda #FINE_REST_Y
        sta fine_y
        lda #0
        sta vis_buf
        sta frame_ready
        sta frame_count
        sta frame_count+1
        lda #MODE_WALK
        sta game_mode
        jsr walk_init
        jsr people_init
        jsr squad_init
        jsr hud_draw            ; needs the squad (squad_init)
        jsr status_init         ; needs the leader's cell (walk_init)
!ifdef STRESS {                 ; test mode: 7 more sprites whose DMA covers lines 212-213
        ldx #1
-       lda #SPR_LEADER_PTR
        sta SCREEN_A + $3f8,x
        sta SCREEN_B + $3f8,x
        lda #COL_YELLOW
        sta VIC_SPR0COL,x
        txa
        asl
        tay
        lda stress_x,x
        sta VIC_SPR0X,y
        lda #193                ; active (DMA) on lines 193-213, pixels on 196-208
        sta VIC_SPR0Y,y
        inx
        cpx #8
        bne -
        lda #$ff
        sta VIC_SPREN
}
!ifdef KEYTEST {
        jsr keytest_run
        jsr acttest_run
}
!ifdef AUTOWALK {
        jsr script_init
        jsr tod_start
}
        jsr irq_init
main_loop
        lda frame_ready
        beq main_loop
        lda #0
        sta frame_ready
        lda game_mode
        beq +
        jsr talk_frame
        jmp main_loop
+
        jsr input_read
        jsr squad_act
        jsr walk_update
        jsr people_update
        jsr sprite_place
!ifndef STRESS {                ; (STRESS programs sprites 1-7 itself)
        jsr people_place
}
!ifdef TIMING {
        jsr timing_note
}
!ifdef TIMING {
        lda heavy_job
        sta timing_job
}
        jsr walk_heavy          ; long jobs after the sprites are placed
!ifdef TIMING {
        jsr timing_heavy
}
        jsr hud_update
!ifdef AUTOWALK {
        jsr tod_snapshot
}
!ifdef FIXED_FY {               ; test mode: pin the map band's vertical fine offset
        lda #FIXED_FY
        sta fine_y
}
!ifdef FORCE_FINE {             ; test mode: sweep the map band through every fine position
        lda frame_count
        and #7
        sta fine_x
        lda frame_count
        lsr
        lsr
        lsr
        and #7
        sta fine_y
}
        jmp main_loop

; clear_colram: colour RAM -> black
clear_colram
        ldx #0
        lda #COL_BLACK
-       sta COLRAM,x
        sta COLRAM+$100,x
        sta COLRAM+$200,x
        sta COLRAM+$2e8,x
        inx
        bne -
        rts

; sprite_init: leader figure in sprite 0 over band cell (LEADER_COL, LEADER_ROW)
LEADER_SX = 24 + LEADER_COL*8 + FINE_REST_X
LEADER_SY = 50 + (ROW_MAP + LEADER_ROW)*8 - 8 + FINE_REST_Y
sprite_init
        ldx #63
-       lda leader_shape,x
        sta SPRITES,x
        dex
        bpl -
        lda #SPR_LEADER_PTR
        sta SCREEN_A + $3f8
        sta SCREEN_B + $3f8
        lda #<LEADER_SX
        sta VIC_SPR0X
        lda #LEADER_SY
        sta VIC_SPR0Y
        lda #(>LEADER_SX) & 1
        sta VIC_SPRMSB
        lda #COL_WHITE
        sta VIC_SPR0COL
        lda #0
        sta VIC_SPRMC
        lda #1
        sta VIC_SPREN
        rts

leader_shape                    ; 8px figure in the left column, rows 3-15
        !fill 3*3, 0
        !byte %00011000,0,0
        !byte %00111100,0,0
        !byte %00111100,0,0
        !byte %00011000,0,0
        !byte %01111110,0,0
        !byte %10111101,0,0
        !byte %10111101,0,0
        !byte %10111101,0,0
        !byte %00111100,0,0
        !byte %00100100,0,0
        !byte %00100100,0,0
        !byte %00100100,0,0
        !byte %01100110,0,0
        !fill 5*3, 0
        !byte 0

!ifdef STRESS {
stress_x !byte 0, 40, 70, 100, 130, 200, 230, 250      ; all inside the screen (X >= 24)
}
!source "irq.asm"
!source "input.asm"
!source "walk.asm"
!source "charset.asm"
!source "view.asm"
!source "hud.asm"
!source "status.asm"
!source "squad.asm"
!source "talk.asm"
!source "talktext.asm"
!source "talkrules.asm"
!source "gen/dialogue.inc"
!source "people.asm"
!ifdef TEST_PEOPLE {
!source "tests/test_people.inc"
} else {
!ifdef TESTMAP {
!source "gen/testmap_people.inc"
} else {
!source "gen/cinderhill_people.inc"
}
}
!zone timing
!ifdef TIMING {
; Test hook: the latest raster line (wrapped: lines before 219 belong to the next frame, +312) at
; which the main loop finished placing sprites (late_max) and finished a flip frame's colour copy
; (colour_max)
timing_note
        ldx #0
        beq timing_max
timing_heavy
        lda timing_job
        cmp #HEAVY_COLOURS
        bne +
        ldx #2
        bne timing_max
+       rts
; timing_max: timing_vars[x..x+1] = max(itself, wrapped raster line now)
timing_max
-       lda VIC_RASTER          ; read $D012/$D011 bit 7 as one 9-bit line: retry if $D012 moved
        ldy VIC_CTRL1           ; between (straddling 255->256 or 311->0 gave 511 / 367)
        cmp VIC_RASTER
        bne -
        cpy #$80
        bcc +                   ; line >= 256: same frame
        sta zp_tmp
        lda #1
        bne ++
+       cmp #219
        bcs +
        clc                     ; wrapped into the next frame: +312 = +$138
        adc #$38
        sta zp_tmp
        lda #1
        adc #0
        bne ++
+       sta zp_tmp
        lda #0
++      sta zp_row              ; zp_row:zp_tmp = wrapped line
        cmp timing_vars+1,x
        bcc +++
        bne +
        lda zp_tmp
        cmp timing_vars,x
        bcc +++
+       lda zp_row
        sta timing_vars+1,x
        lda zp_tmp
        sta timing_vars,x
+++     rts
timing_vars
late_max   !word 0
colour_max !word 0
timing_job !byte 0
}
!ifdef TESTMAP {
!source "gen/testmap.inc"
} else {
!source "gen/cinderhill.inc"
}

!if * > COLBUF {
        !error "code/data overran COLBUF ($B800)"
}
