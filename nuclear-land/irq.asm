; Nuclear Land - raster IRQ chain for the walking screen
;
; Bands:  status  = screen row 0  (raster 51-58), YSCROLL 3, 40 cols
;         spacer  = screen row 1  (raster 59-66, blank)
;         map     = screen rows 2-19, starting on raster 67+fine_y, YSCROLL (3+fine_y)&7, 38 cols,
;                   XSCROLL fine_x. Only raster 74-210 is shown (a fixed 137-line window): lines
;                   62-73 and 211-218 are blanked with the "invalid" ECM+BMM mode (pure black,
;                   badline logic untouched), so rows never pop in or out at the band's edges.
;         HUD     = screen rows 20-23 on raster 219-250, YSCROLL 3, 40 cols
;
; Vertical fine scroll uses FLD only: a badline may be DELAYED (idle lines, black) but never brought
; forward. An early badline - one that arrives before the current row has shown all 8 lines -
; re-fetches that row and shifts every row below it by 8 pixels.
;   top:    IRQ_MAP on line 62 parks YSCROLL 4 (lines 62-67 are 6,7,0,1,2,3: no match), then the
;           final value on line 67 (polled), so row 2's badline lands on 67+fine_y after row 1 has
;           completed. Blanking ends on line 74 - or for fine_y=7, whose row 2 badline IS line 74,
;           at the very end of line 73 (an idle line for fine_y=7).
;   bottom: IRQ_HUD on line 206 (after row 19's badline at 203+fine_y for fine_y<=2) parks YSCROLL
;           5 when fine_y<=2 (row 20 would otherwise badline on 211-213). Every later write is
;           polled on a line that can never be a badline: blank on at 211, YSCROLL 3 at 212 (so the
;           next badline is exactly 219 = HUD row 20), blank off + 40 cols at 218. None of them
;           depend on IRQ latency, sprite DMA or what the main loop was doing.
; Never write a YSCROLL equal to the current line's (raster & 7): that starts a badline mid-line.

FINE_REST_X  = 4
FINE_REST_Y  = 4
IRQ_TOP_LINE = 16
IRQ_MAP_LINE = 62
MAP_FINAL_LINE = 67
MAP_SHOW_LINE = 74              ; first visible map line
IRQ_HUD_LINE = 206
HUD_BLANK_LINE = 211            ; first blanked line below the map
HUD_YS3_LINE = 212
HUD_D016_LINE = 218
D011_STD     = %00011011        ; DEN, RSEL, YSCROLL 3
D011_BASE    = %00011000        ; DEN, RSEL, YSCROLL 0
D011_BLANK   = %01100000        ; ECM + BMM: invalid mode, black output
D016_STD     = %00001000        ; CSEL (40 cols), XSCROLL 0

irq_init
        sei
        lda #$7f                ; no CIA interrupts (we scan the keyboard ourselves)
        sta CIA1_ICR
        sta $dd0d
        lda CIA1_ICR
        lda $dd0d
        lda #<irq_top
        sta $0314
        lda #>irq_top
        sta $0315
        lda #IRQ_TOP_LINE
        sta VIC_RASTER
        lda #D011_STD
        sta VIC_CTRL1
        lda #1
        sta VIC_IRQEN
        sta VIC_IRQ             ; ack anything pending
        cli
        rts

; wait_line: busy-wait until the raster (low byte) reaches .l (clobbers A)
!macro wait_line .l {
-       lda VIC_RASTER
        cmp #.l
        bcc -
}

; poll_store: with A preloaded, wait for line .l and store A to .reg as early in that line as
; possible (9-cycle poll + 4-cycle store: lands by ~cycle 13, before the first visible pixel).
; Clobbers X.
!macro poll_store .l, .reg {
-       ldx VIC_RASTER
        cpx #.l
        bcc -
        sta .reg
}

irq_top
        lda #D011_STD
        sta VIC_CTRL1
        lda #D016_STD
        sta VIC_CTRL2
        ldx vis_buf
        lda d018_tbl,x
        sta VIC_MEM
        lda fine_y              ; latch this frame's map-band values
        and #7
        sta map_k
        clc
        adc #3
        and #7
        ora #D011_BASE
        sta map_d011
        lda map_k               ; bottom park value: YSCROLL 5 for k<=2, else the map's own
        cmp #3
        lda #D011_BASE | 5
        bcc +
        lda map_d011
+       sta hud_d011
        lda fine_x
        and #7
        sta map_d016            ; CSEL=0 (38 cols)
        lda #<irq_map
        sta $0314
        lda #>irq_map
        sta $0315
        lda #IRQ_MAP_LINE
        sta VIC_RASTER
        lda #1
        sta VIC_IRQ
        jmp $ea81

irq_map                         ; line 62, inside blank spacer row 1
        lda map_d016
        sta VIC_CTRL2
        ldx map_k
        lda #D011_STD | D011_BLANK      ; k=0: YSCROLL 3 already gives row 2 on line 67
        cpx #0
        beq +
        lda #D011_BASE | 4 | D011_BLANK ; stage 1: next match is line 68
+       sta VIC_CTRL1
        cpx #2
        bcc .map_unblank        ; k=0/1: already final
        +wait_line MAP_FINAL_LINE
        lda map_d011            ; stage 2 on line 67 (67&7=3, never equal to (3+k)&7 for k>=2)
        ora #D011_BLANK
        sta VIC_CTRL1
.map_unblank                    ; (wait_line clobbers A: load the value after waiting)
        cpx #7
        beq .late
        lda map_d011                    ; line 74 is no badline for k<7: CPU free, write lands
        +poll_store MAP_SHOW_LINE, VIC_CTRL1    ; before the line's first pixel
        jmp .map_done
.late   +wait_line MAP_SHOW_LINE-1      ; k=7: row 2's badline is line 74 itself, so unblank at
        ldy #8                          ; the end of line 73 (idle for k=7, and no badline)
-       dey
        bne -
        lda map_d011
        sta VIC_CTRL1
.map_done
        lda #<irq_hud
        sta $0314
        lda #>irq_hud
        sta $0315
        lda #IRQ_HUD_LINE
        sta VIC_RASTER
        lda #1
        sta VIC_IRQ
        jmp $ea81

irq_hud                         ; line 206, after the last map row's badline for k<=2
!ifdef STRESS {                 ; test mode: extra IRQ latency (a busy main loop in M2)
        !fill STRESS_NOPS, $ea
}
        lda hud_d011            ; k<=2: park YSCROLL 5 (lines 206-212 never match 5)
        sta VIC_CTRL1
        lda hud_d011            ; blank from line 211 (never a badline: k=0 is parked)
        ora #D011_BLANK
        +poll_store HUD_BLANK_LINE, VIC_CTRL1
        lda #D011_STD | D011_BLANK      ; lines 212-218 are 4,5,6,7,0,1,2 -> next badline 219
        +poll_store HUD_YS3_LINE, VIC_CTRL1
        +wait_line HUD_D016_LINE        ; line 218 (black idle line, never a badline): switch
        ldy #6                          ; 38 -> 40 cols only after this line's 38-col border
-       dey                             ; compare point (~cycle 18) - switching between the two
        bne -                           ; compare points leaves the border on for the whole line
        lda #D011_STD
        sta VIC_CTRL1
        lda #D016_STD
        sta VIC_CTRL2
        lda #1
        sta frame_ready
        inc frame_count
        bne +
        inc frame_count+1
+       lda #<irq_top
        sta $0314
        lda #>irq_top
        sta $0315
        lda #IRQ_TOP_LINE       ; next frame
        sta VIC_RASTER
        lda #1
        sta VIC_IRQ
        jmp $ea81

d018_tbl !byte D018_A, D018_B
map_k    !byte 0
map_d011 !byte D011_STD
map_d016 !byte 0
hud_d011 !byte D011_STD
