; Nuclear Land - walking charset: ROM font (codes 0..TILE_FIRST-1) + generated tiles

; charset_init: copy ROM uppercase font codes 0..TILE_FIRST-1 into CHARSET, then the tiles.
; Expects interrupts disabled.
charset_init
        lda #0                  ; clear the whole 2 KB charset (unused codes stay blank)
        tax
-       !for p, 0, 7 { sta CHARSET + p*$100,x }
        inx
        bne -
        lda #$33                ; char ROM visible at $d000, I/O off
        sta $01
        ldx #0
-       lda $d000,x             ; codes 0-31
        sta CHARSET,x
        lda $d100,x             ; codes 32-63
        sta CHARSET+$100,x
        inx
        bne -
        lda #$37
        sta $01
        ; tiles: TILE_FIRST*8 .. (TILE_LAST+1)*8
        lda #<tiles_src
        sta zp_src
        lda #>tiles_src
        sta zp_src+1
        lda #<(CHARSET + TILE_FIRST*8)
        sta zp_dst
        lda #>(CHARSET + TILE_FIRST*8)
        sta zp_dst+1
        ldx #>(tiles_end - tiles_src + 255)     ; whole pages (over-copy past the end is harmless)
        ldy #0
-       lda (zp_src),y
        sta (zp_dst),y
        iny
        bne -
        inc zp_src+1
        inc zp_dst+1
        dex
        bne -
        rts

tiles_src
        !binary "gen/tiles.bin"
tiles_end
        !fill 256, 0            ; pad so the whole-page copy never reads into code it shouldn't need
tilecolors
        !binary "gen/tilecolors.bin"
