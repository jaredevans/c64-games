; Nuclear Land - raster IRQ chain for the walking screen
;
; Bands:  status  = screen row 0  (raster 51-58), YSCROLL 3, 40 cols
;         spacer  = screen row 1  (raster 59-66, blank)
;         map     = screen rows 2-19, starting on raster 67+fine_y, YSCROLL (3+fine_y)&7, 38 cols,
;                   XSCROLL fine_x
;         HUD     = screen rows 20-23 on raster 219-250, YSCROLL 3, 40 cols
;
; Vertical fine scroll uses FLD only: a badline may be DELAYED (idle lines, black) but never brought
; forward. An early badline - one that arrives before the current row has shown all 8 lines -
; re-fetches that row and shifts every row below it by 8 pixels. So:
;   top:    IRQ_MAP on line 62 writes YSCROLL 4 (next match line 68), then on line 67 the final
;           value, so row 2's badline lands on 67+fine_y, after row 1 has completed.
;   bottom: YSCROLL 3 is written on line 212 (lines 212-218 never match 3), so the next badline
;           is exactly line 219 and fetches screen row 20 (the HUD's first row). For fine_y<=1 the
;           map's row 20 would badline on 211/212 first, so IRQ_HUD comes on line 206 and parks
;           YSCROLL 5 (lines 206-212 never match 5) before the line-212 write. The stage-1 value
;           must avoid every line up to AND including 212: a badline is decided at the start of a
;           line, before the IRQ handler can write. $d016 goes back to 40 cols on line 218.
; Never write a YSCROLL equal to the current line's (raster & 7): that starts a badline mid-line.

FINE_REST_X  = 4
FINE_REST_Y  = 4
IRQ_TOP_LINE = 16
IRQ_MAP_LINE = 62
MAP_FINAL_LINE = 67
HUD_STAGE1_LINE = 206
HUD_STAGE2_LINE = 212
HUD_D016_LINE = 218
D011_STD     = %00011011        ; DEN, RSEL, YSCROLL 3
D011_BASE    = %00011000        ; DEN, RSEL, YSCROLL 0
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

; wait_line: busy-wait until the raster (low byte) reaches A
!macro wait_line .l {
-       lda VIC_RASTER
        cmp #.l
        bcc -
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
        lda #HUD_STAGE2_LINE    ; k>=2: one write of YSCROLL 3 on line 212 (after row 19's
        ldx map_k               ; badline at 203+k, before row 20's would-be badline at 211+k)
        cpx #2
        bcs +
        lda #HUD_STAGE1_LINE    ; k<=1: row 20 would badline on 211/212, so first park YSCROLL 5
+       sta hud_line            ; on line 206 (lines 206-212 are 6,7,0,1,2,3,4 - never 5)
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
        lda map_k
        beq .map_done           ; k=0: YSCROLL 3 already gives row 2 on line 67
        lda #D011_BASE | 4      ; stage 1: next match is line 68 (lines 62-67 are 6,7,0,1,2,3)
        sta VIC_CTRL1
        lda map_k
        cmp #1
        beq .map_done           ; k=1: YSCROLL 4 is the final value
        +wait_line MAP_FINAL_LINE
        lda map_d011            ; stage 2 on line 67 (67&7=3, never equal to (3+k)&7 for k>=2)
        sta VIC_CTRL1
.map_done
        lda #<irq_hud
        sta $0314
        lda #>irq_hud
        sta $0315
        lda hud_line
        sta VIC_RASTER
        lda #1
        sta VIC_IRQ
        jmp $ea81

irq_hud                         ; line 206 (k<=1) or 212 (k>=2), after the last map row's badline
        lda hud_line
        cmp #HUD_STAGE2_LINE
        beq +
        lda #D011_BASE | 5      ; stage 1 (k<=1 only)
        sta VIC_CTRL1
        +wait_line HUD_STAGE2_LINE
+
        lda #D011_STD           ; lines 212-218 are 4,5,6,7,0,1,2 -> next badline exactly 219
        sta VIC_CTRL1
        +wait_line HUD_D016_LINE
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
hud_line !byte HUD_STAGE2_LINE
