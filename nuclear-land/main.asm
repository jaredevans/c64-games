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
        lda #>SCREEN_A
        jsr clear_screen
        lda #>SCREEN_B
        jsr clear_screen
        jsr clear_colram
        lda #START_CX
        sta cam_x
        lda #START_CY
        sta cam_y
        lda #>SCREEN_A
        jsr view_draw_full
        jsr hud_draw
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
        jsr irq_init
main_loop
        lda frame_ready
        beq main_loop
        lda #0
        sta frame_ready
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

!source "irq.asm"
!source "charset.asm"
!source "view.asm"
!source "hud.asm"

!if * > VIC_BANK {
        !error "code/data overran $C000 (VIC bank 3)"
}
