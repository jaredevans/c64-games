; palette calibration: rows 0-5 = 16 vertical stripes (2 columns each) of colours 0..15
!cpu 6502
* = $0801
        !word +, 10
        !byte $9e
        !text "2061"
        !byte 0
+       !word 0
* = $080d
        sei
        lda #0
        sta $d020
        sta $d021
        ldy #0                  ; y = screen offset 0..239 (rows 0-5)
        ldx #0                  ; x = column 0..39
-       lda #160                ; reverse space = solid block
        sta $0400,y
        txa
        lsr
        and #15
        sta $d800,y
        inx
        cpx #40
        bne +
        ldx #0
+       iny
        cpy #240
        bne -
        jmp *
