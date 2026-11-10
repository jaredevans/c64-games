; Nuclear Land - keyboard input (no joystick)
;
; Movement keys: arrow keys = C64 cursor keys (CRSR-down / CRSR-right; with either SHIFT they mean
; up / left - VICE sends SHIFT itself for the host's up/left arrows), and I (up) J (left) K (down)
; L (right). Priority when several are held: up > down > left > right.
;
; Matrix (write $dc00 row select, read $dc01, active low):
;   row 0: bit2 CRSR-right, bit7 CRSR-down     row 1: bit7 LSHIFT
;   row 4: bit1 I, bit2 J, bit5 K              row 5: bit2 L        row 6: bit4 RSHIFT

; input_read: fill kb_row* (hardware, or the AUTOWALK script), decode into cur_dir
input_read
!ifdef AUTOWALK {
        jsr script_step
} else {
        lda #%11111110
        sta CIA1_PRA
        lda CIA1_PRB
        sta kb_row0
        lda #%11111101
        sta CIA1_PRA
        lda CIA1_PRB
        sta kb_row1
        lda #%11101111
        sta CIA1_PRA
        lda CIA1_PRB
        sta kb_row4
        lda #%11011111
        sta CIA1_PRA
        lda CIA1_PRB
        sta kb_row5
        lda #%10111111
        sta CIA1_PRA
        lda CIA1_PRB
        sta kb_row6
        lda #$ff
        sta CIA1_PRA
}
        jsr decode_keys
        sta cur_dir
        rts

; decode_keys: kb_row0/1/4/5/6 -> A = DIR_* or DIR_NONE. Pure (reads only the kb_row* bytes).
decode_keys
        ldx #0                  ; x = 1 if either shift is down
        lda kb_row1
        and #%10000000
        beq .shift
        lda kb_row6
        and #%00010000
        bne .noshift
.shift  ldx #1
.noshift
        ; up: I, or SHIFT+CRSR-down
        lda kb_row4
        and #%00000010
        beq .up
        cpx #1
        bne +
        lda kb_row0
        and #%10000000
        beq .up
+       ; down: K, or CRSR-down without shift
        lda kb_row4
        and #%00100000
        beq .down
        cpx #0
        bne +
        lda kb_row0
        and #%10000000
        beq .down
+       ; left: J, or SHIFT+CRSR-right
        lda kb_row4
        and #%00000100
        beq .left
        cpx #1
        bne +
        lda kb_row0
        and #%00000100
        beq .left
+       ; right: L, or CRSR-right without shift
        lda kb_row5
        and #%00000100
        beq .right
        cpx #0
        bne +
        lda kb_row0
        and #%00000100
        beq .right
+       lda #DIR_NONE
        rts
.up     lda #DIR_UP
        rts
.down   lda #DIR_DOWN
        rts
.left   lda #DIR_LEFT
        rts
.right  lda #DIR_RIGHT
        rts

; ---------------------------------------------------------------------------------------------
; Test support (assembled only with -DKEYTEST / -DAUTOWALK)

; raw key bytes (active low) for script entries: row0, row1, row4, row5, row6
!macro keys .r0, .r1, .r4, .r5, .r6 { !byte .r0, .r1, .r4, .r5, .r6 }
K_NONE   = $ff
K0_CRSRD = $7f                  ; row 0 bit 7
K0_CRSRR = $fb                  ; row 0 bit 2
K0_BOTH  = $7b
K1_LSH   = $7f                  ; row 1 bit 7
K4_I     = $fd
K4_J     = $fb
K4_K     = $df
K4_KJ    = $db
K5_L     = $fb
K6_RSH   = $ef

!ifdef KEYTEST {
KEYTEST_N = 15
; keytest_run: decode every case in keytest_cases into keytest_out
keytest_run
        lda #<keytest_cases
        sta zp_src
        lda #>keytest_cases
        sta zp_src+1
        ldx #0
-       ldy #0
        lda (zp_src),y
        sta kb_row0
        iny
        lda (zp_src),y
        sta kb_row1
        iny
        lda (zp_src),y
        sta kb_row4
        iny
        lda (zp_src),y
        sta kb_row5
        iny
        lda (zp_src),y
        sta kb_row6
        txa
        pha
        jsr decode_keys
        sta zp_tmp
        pla
        tax
        lda zp_tmp
        sta keytest_out,x
        lda zp_src
        clc
        adc #5
        sta zp_src
        bcc +
        inc zp_src+1
+       inx
        cpx #KEYTEST_N
        bne -
        rts
keytest_cases                   ; order matches tests/test_decode_keys.py
        +keys K_NONE,   K_NONE, K_NONE, K_NONE, K_NONE      ; none
        +keys K0_CRSRD, K_NONE, K_NONE, K_NONE, K_NONE      ; CRSR-down
        +keys K0_CRSRD, K1_LSH, K_NONE, K_NONE, K_NONE      ; LSHIFT+CRSR-down
        +keys K0_CRSRD, K_NONE, K_NONE, K_NONE, K6_RSH      ; RSHIFT+CRSR-down
        +keys K0_CRSRR, K_NONE, K_NONE, K_NONE, K_NONE      ; CRSR-right
        +keys K0_CRSRR, K1_LSH, K_NONE, K_NONE, K_NONE      ; LSHIFT+CRSR-right
        +keys K_NONE,   K_NONE, K4_I,   K_NONE, K_NONE      ; I
        +keys K_NONE,   K_NONE, K4_J,   K_NONE, K_NONE      ; J
        +keys K_NONE,   K_NONE, K4_K,   K_NONE, K_NONE      ; K
        +keys K_NONE,   K_NONE, K_NONE, K5_L,   K_NONE      ; L
        +keys K_NONE,   K_NONE, K4_I,   K5_L,   K_NONE      ; I+L
        +keys K_NONE,   K_NONE, K4_KJ,  K_NONE, K_NONE      ; K+J
        +keys K_NONE,   K_NONE, K4_J,   K5_L,   K_NONE      ; J+L
        +keys K0_CRSRR, K_NONE, K4_K,   K_NONE, K_NONE      ; CRSR-right+K
        +keys K_NONE,   K1_LSH, K_NONE, K_NONE, K_NONE      ; SHIFT alone
keytest_out
        !fill KEYTEST_N, $ee
}

!ifdef AUTOWALK {
; Script entries: frames (0 = end: all keys up forever), then the five row bytes.
!macro hold .n, .r0, .r1, .r4, .r5, .r6 { !byte .n, .r0, .r1, .r4, .r5, .r6 }
!macro idle .n { !byte .n, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE }

script_init
        lda #<walk_script
        sta script_ptr
        lda #>walk_script
        sta script_ptr+1
        lda #0
        sta script_left
        rts

; script_step: advance one frame of the script and load the current entry's key bytes
script_step
        lda script_left
        bne .play
        ldy #0
        lda (script_ptr),y
        beq .ended
        sta script_left
        iny
        lda (script_ptr),y
        sta kb_row0
        iny
        lda (script_ptr),y
        sta kb_row1
        iny
        lda (script_ptr),y
        sta kb_row4
        iny
        lda (script_ptr),y
        sta kb_row5
        iny
        lda (script_ptr),y
        sta kb_row6
        lda script_ptr
        clc
        adc #6
        sta script_ptr
        bcc .play
        inc script_ptr+1
.play   dec script_left
        rts
.ended  lda #K_NONE
        sta kb_row0
        sta kb_row1
        sta kb_row4
        sta kb_row5
        sta kb_row6
        rts

walk_script
!if AUTOWALK = 1 {              ; tests/test_walk_script.py
        +hold 5*GLIDE_FRAMES, K_NONE, K_NONE, K_NONE, K5_L, K_NONE     ; right x5
        +hold 3*GLIDE_FRAMES, K_NONE, K_NONE, K4_I, K_NONE, K_NONE     ; up x2, then bump the wall
        +hold 3, K0_CRSRD, K_NONE, K_NONE, K_NONE, K_NONE             ; CRSR-down, released mid-glide
        +idle 10
        +hold 2*GLIDE_FRAMES, K0_CRSRR, K1_LSH, K_NONE, K_NONE, K_NONE ; SHIFT+CRSR-right = left x2
        +idle 1
}
!if AUTOWALK = 2 {              ; tests/test_step_rate.py
        +hold 96, K_NONE, K_NONE, K_NONE, K5_L, K_NONE
}
        !byte 0
}
