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

; decode_keys: kb_row0/1/4/5/6 + cur_dir (last frame's result) -> A = DIR_* or DIR_NONE.
; Pure: reads only those bytes.
; SHIFT + CRSR-down + CRSR-right is ambiguous: VICE produces it both for host Down+Left and for
; host Up+Right. Then the cursor keys are ignored and, unless I/J/K/L say otherwise, the previous
; direction is kept (DIR_NONE if there was none) - never a direction nobody pressed.
decode_keys
        ldx #0                  ; x = 0 no shift, 1 shift, 2 ambiguous (cursor keys ignored)
        lda kb_row1
        and #%10000000
        beq .shift
        lda kb_row6
        and #%00010000
        bne .noshift
.shift  ldx #1
        lda kb_row0
        and #%10000100          ; both CRSR-down and CRSR-right held?
        bne .noshift
        ldx #2
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
        cpx #2
        bne +
        lda cur_dir             ; ambiguous: keep last frame's direction
+       rts
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
!macro keys .r0, .r1, .r4, .r5, .r6 { !byte .r0, .r1, .r4, .r5, .r6, DIR_NONE }
!macro keysp .r0, .r1, .r4, .r5, .r6, .prev { !byte .r0, .r1, .r4, .r5, .r6, .prev }  ; with previous dir
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
KEYTEST_N = 23
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
        iny
        lda (zp_src),y
        sta cur_dir             ; previous frame's direction
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
        adc #6
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
        ; VICE host Down+Left / Up+Right: SHIFT + CRSR-down + CRSR-right (ambiguous)
        +keysp K0_BOTH, K_NONE, K_NONE, K_NONE, K6_RSH, DIR_NONE
        +keysp K0_BOTH, K_NONE, K_NONE, K_NONE, K6_RSH, DIR_DOWN
        +keysp K0_BOTH, K_NONE, K_NONE, K_NONE, K6_RSH, DIR_LEFT
        +keysp K0_BOTH, K_NONE, K_NONE, K_NONE, K6_RSH, DIR_UP
        +keysp K0_BOTH, K_NONE, K_NONE, K_NONE, K6_RSH, DIR_RIGHT
        +keysp K0_BOTH, K1_LSH, K_NONE, K_NONE, K_NONE, DIR_DOWN
        +keys  K0_BOTH, K_NONE, K_NONE, K_NONE, K_NONE      ; CRSR-down+CRSR-right, no shift
        +keysp K_NONE,  K_NONE, K4_K,   K_NONE, K_NONE, DIR_UP  ; prev must not matter
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
        cmp #$ff                ; $ff = restart the script from the top
        bne +
        jsr script_init
        jmp script_step
+
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
!if AUTOWALK = 3 {              ; tests/test_edge_clamp.py: J to the west wall, then bump it
        +hold 240, K_NONE, K_NONE, K4_J, K_NONE, K_NONE
        +idle 1
}
!if AUTOWALK = 5 {              ; tests/test_edge_clamp.py: L to the east wall, then bump it
        +hold 250, K_NONE, K_NONE, K_NONE, K5_L, K_NONE      ; (255 = $ff would mean restart)
        +hold 30, K_NONE, K_NONE, K_NONE, K5_L, K_NONE
        +idle 1
}
!if AUTOWALK = 7 {              ; tests/test_status.py: J to (10,19), K to (10,20) beside the hot spots
        +hold 152, K_NONE, K_NONE, K4_J, K_NONE, K_NONE
        +hold 8, K_NONE, K_NONE, K4_K, K_NONE, K_NONE
        +idle 1
}
!if AUTOWALK = 11 {             ; tests/test_edge_clamp_ns.py: I to the north wall, then bump it
        +hold 144, K_NONE, K_NONE, K4_I, K_NONE, K_NONE
        +idle 1
}
!if AUTOWALK = 12 {             ; tests/test_edge_clamp_ns.py: L to x=40, K to the south wall, bump
        +hold 88, K_NONE, K_NONE, K_NONE, K5_L, K_NONE
        +hold 216, K_NONE, K_NONE, K4_K, K_NONE, K_NONE
        +idle 1
}
!if AUTOWALK = 4 {              ; tests/test_long_run_fps.py: a 21x11 loop forever
        +hold 160, K_NONE, K_NONE, K_NONE, K5_L, K_NONE                ; right 20
        +hold 80, K_NONE, K_NONE, K4_K, K_NONE, K_NONE                 ; down 10
        +hold 160, K_NONE, K_NONE, K4_J, K_NONE, K_NONE                ; left 20
        +hold 80, K_NONE, K_NONE, K4_I, K_NONE, K_NONE                 ; up 10
        !byte $ff
}
        !byte 0

; tod_start: emulated-time reference for tests. CIA2 timer A free-runs on the CPU clock
; (latch $ffff = 65536 cycles per underflow); timer B counts timer A underflows down from $ffff.
; (No interrupts: CIA2 NMIs are disabled in irq_init.)
tod_start
        lda #$ff
        sta $dd04
        sta $dd05
        sta $dd06
        sta $dd07
        lda #%00010001          ; TA: force load, start, continuous, count phi2
        sta $dd0e
        lda #%01010001          ; TB: force load, start, count TA underflows
        sta $dd0f
        rts

; tod_snapshot: frame_count + timer B (cycles/65536, counting down), taken together each frame
tod_snapshot
        lda frame_count
        sta tod_snap
        lda frame_count+1
        sta tod_snap+1
        lda $dd06
        sta tod_snap+2
        lda $dd07
        sta tod_snap+3
        rts
tod_snap !fill 4, 0
}
