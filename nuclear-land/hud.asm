; Nuclear Land - static status line + squad strip (written into both screen buffers)

HUD_LEN = 4 * 40        ; rows 21-24

; hud_draw: write HUD text into SCREEN_A and SCREEN_B, and HUD colours into colour RAM.
hud_draw
        ldx #HUD_LEN-1
-       lda hud_strip,x
        sta SCREEN_A + ROW_HUD*40,x
        sta SCREEN_B + ROW_HUD*40,x
        lda hud_strip_col,x
        sta COLRAM + ROW_HUD*40,x
        dex
        cpx #$ff
        bne -
        rts

hud_strip
        !scr ">vesna     dials     maren     rook     "      ; row 21
        !scr "                                        "      ; row 22
        !scr "arrows/ijkl move                        "      ; row 23
        !scr "                                        "      ; row 24
hud_strip_col
        !fill 6, COL_YELLOW
        !fill 34, COL_WHITE
        !fill 40, COL_DGREY
        !fill 40, COL_LGREY
        !fill 40, COL_LGREY
