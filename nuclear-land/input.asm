; Nuclear Land - keyboard input (no joystick)
;
; Movement keys: arrow keys = C64 cursor keys (CRSR-down / CRSR-right; with either SHIFT they mean
; up / left - VICE sends SHIFT itself for the host's up/left arrows), and I (up) J (left) K (down)
; L (right). Priority when several are held: up > down > left > right.
;
; Matrix (write $dc00 row select, read $dc01, active low):
;   row 0: bit2 CRSR-right, bit7 CRSR-down     row 1: bit0 3, bit3 4, bit7 LSHIFT
;   row 2: bit6 T        row 3: bit6 U         row 4: bit1 I, bit2 J, bit5 K
;   row 5: bit2 L        row 6: bit4 RSHIFT    row 7: bit0 1, bit3 2
;
; Action keys 1-4 (leader), T (talk), U (use skill) act once per press: input_read latches an action
; in act_pending when the decoded action changes to a new one (holding a key never repeats it;
; rolling from one key to another counts both); squad_act runs it when the leader stands still.

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
        lda #%11111011
        sta CIA1_PRA
        lda CIA1_PRB
        sta kb_row2
        lda #%11110111
        sta CIA1_PRA
        lda CIA1_PRB
        sta kb_row3
        lda #%01111111
        sta CIA1_PRA
        lda CIA1_PRB
        sta kb_row7
        lda #$ff
        sta CIA1_PRA
}
        jsr decode_keys
        sta cur_dir
        jsr decode_action       ; latch an action when it changes to a new one (so a key pressed
        cmp act_prev            ; while another is still held counts once the first is released)
        sta act_prev
        beq +
        cmp #ACT_NONE
        beq +
        sta act_pending
+       rts

; decode_action: kb_row1/2/3/7 -> A = ACT_LEAD0..3, ACT_TALK, ACT_USE or ACT_NONE.
; Pure. Priority 1 > 2 > 3 > 4 > T > U.
decode_action
        lda kb_row7
        and #%00000001
        beq .a1
        lda kb_row7
        and #%00001000
        beq .a2
        lda kb_row1
        and #%00000001
        beq .a3
        lda kb_row1
        and #%00001000
        beq .a4
        lda kb_row2
        and #%01000000
        beq .at
        lda kb_row3
        and #%01000000
        beq .au
        lda #ACT_NONE
        rts
.a1     lda #ACT_LEAD0
        rts
.a2     lda #ACT_LEAD0+1
        rts
.a3     lda #ACT_LEAD0+2
        rts
.a4     lda #ACT_LEAD0+3
        rts
.at     lda #ACT_TALK
        rts
.au     lda #ACT_USE
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
K7_1     = $fe                  ; row 7 bit 0
K7_2     = $f7                  ; row 7 bit 3
K1_3     = $fe                  ; row 1 bit 0
K1_4     = $f7                  ; row 1 bit 3
K2_T     = $bf                  ; row 2 bit 6
K3_U     = $bf                  ; row 3 bit 6
K1_3LSH  = $7e                  ; 3 + LSHIFT

ACTTEST_N = 12
; acttest: one 8-byte entry per case (rows 0-7, active low); order matches tests/test_decode_keys.py
!macro act8 .r0, .r1, .r2, .r3, .r4, .r5, .r6, .r7 { !byte .r0, .r1, .r2, .r3, .r4, .r5, .r6, .r7 }

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

; acttest_run: decode_action and decode_keys for every acttest case
acttest_run
        ldx #0
-       txa
        asl
        asl
        asl
        tay
        lda acttest_cases,y
        sta kb_row0
        lda acttest_cases+1,y
        sta kb_row1
        lda acttest_cases+2,y
        sta kb_row2
        lda acttest_cases+3,y
        sta kb_row3
        lda acttest_cases+4,y
        sta kb_row4
        lda acttest_cases+5,y
        sta kb_row5
        lda acttest_cases+6,y
        sta kb_row6
        lda acttest_cases+7,y
        sta kb_row7
        lda #DIR_NONE
        sta cur_dir
        stx zp_tmp
        jsr decode_action
        ldx zp_tmp
        sta acttest_act,x
        jsr decode_keys
        ldx zp_tmp
        sta acttest_dir,x
        inx
        cpx #ACTTEST_N
        bne -
        rts
acttest_cases
        +act8 K_NONE, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE   ; none
        +act8 K_NONE, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE, K7_1     ; 1
        +act8 K_NONE, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE, K7_2     ; 2
        +act8 K_NONE, K1_3,   K_NONE, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE   ; 3
        +act8 K_NONE, K1_4,   K_NONE, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE   ; 4
        +act8 K_NONE, K_NONE, K2_T,   K_NONE, K_NONE, K_NONE, K_NONE, K_NONE   ; T
        +act8 K_NONE, K_NONE, K_NONE, K3_U,   K_NONE, K_NONE, K_NONE, K_NONE   ; U
        +act8 K_NONE, K_NONE, K2_T,   K_NONE, K_NONE, K_NONE, K_NONE, K7_1     ; 1+T
        +act8 K_NONE, K_NONE, K2_T,   K3_U,   K_NONE, K_NONE, K_NONE, K_NONE   ; T+U
        +act8 K_NONE, K_NONE, K_NONE, K3_U,   K_NONE, K5_L,   K_NONE, K_NONE   ; L+U
        +act8 K_NONE, K1_LSH, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE   ; LSHIFT alone
        +act8 K0_CRSRD, K1_3LSH, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE ; 3+LSHIFT+CRSR-down
acttest_act
        !fill ACTTEST_N, $ee
acttest_dir
        !fill ACTTEST_N, $ee
}

!ifdef AUTOWALK {
; Script entries: frames (0 = end: all keys up forever; $ff = restart), then rows 0-7.
!macro hold .n, .r0, .r1, .r4, .r5, .r6 { !byte .n, .r0, .r1, K_NONE, K_NONE, .r4, .r5, .r6, K_NONE }
!macro idle .n { !byte .n, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE }
!macro press .n, .row, .val {   ; one action key (row .row = .val) held .n frames
        !byte .n
        !for r, 0, 7 {
                !if r = .row { !byte .val } else { !byte K_NONE }
        }
}

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
        sta kb_row2
        iny
        lda (script_ptr),y
        sta kb_row3
        iny
        lda (script_ptr),y
        sta kb_row4
        iny
        lda (script_ptr),y
        sta kb_row5
        iny
        lda (script_ptr),y
        sta kb_row6
        iny
        lda (script_ptr),y
        sta kb_row7
        lda script_ptr
        clc
        adc #9
        sta script_ptr
        bcc .play
        inc script_ptr+1
.play   dec script_left
        rts
.ended  lda #K_NONE
        sta kb_row0
        sta kb_row1
        sta kb_row2
        sta kb_row3
        sta kb_row4
        sta kb_row5
        sta kb_row6
        sta kb_row7
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
!if AUTOWALK = 8 {              ; tests/test_people_glue.py: right 15, left 15, forever
        +hold 120, K_NONE, K_NONE, K_NONE, K5_L, K_NONE
        +hold 120, K_NONE, K_NONE, K4_J, K_NONE, K_NONE
        !byte $ff
}
!if AUTOWALK = 9 {              ; tests/test_people_window.py: down 4, up 4, forever
        +hold 32, K_NONE, K_NONE, K4_K, K_NONE, K_NONE
        +hold 32, K_NONE, K_NONE, K4_I, K_NONE, K_NONE
        !byte $ff
}
!if AUTOWALK = 10 {             ; tests/test_people_block.py: right 8 to (37,19), up 4, bump P1
        +hold 64, K_NONE, K_NONE, K_NONE, K5_L, K_NONE
        +hold 48, K_NONE, K_NONE, K4_I, K_NONE, K_NONE
        +idle 1
}
!if AUTOWALK = 6 {              ; tests/test_radiation.py: 8 hot steps, refused 3, recover, heal, rest
        +hold 152, K_NONE, K_NONE, K4_J, K_NONE, K_NONE      ; (29,19) -> (10,19)
        +hold 16, K_NONE, K_NONE, K4_K, K_NONE, K_NONE       ; (10,20), (10,21) = hot 1
        !for i, 1, 7 {                                       ; hot 2..8, ending on (11,21)
                !if i & 1 { +hold 8, K_NONE, K_NONE, K_NONE, K5_L, K_NONE } else { +hold 8, K_NONE, K_NONE, K4_J, K_NONE, K_NONE }
        }
        +press 2, 1, K1_3                                    ; Maren is sick: refused
        +idle 4
        +hold 16, K_NONE, K_NONE, K4_I, K_NONE, K_NONE       ; (11,19)
        +hold 160, K_NONE, K_NONE, K_NONE, K5_L, K_NONE      ; (31,19): x=15..31 radiation-free
        +press 2, 1, K1_3
        +idle 4
        +press 2, 3, K3_U                                    ; heal
        +idle 4
        +press 2, 3, K3_U                                    ; must rest
        +idle 1
}
!if AUTOWALK = 15 {             ; tests/test_radiation.py: the 8 hot steps only
        +hold 152, K_NONE, K_NONE, K4_J, K_NONE, K_NONE
        +hold 16, K_NONE, K_NONE, K4_K, K_NONE, K_NONE
        !for i, 1, 7 {
                !if i & 1 { +hold 8, K_NONE, K_NONE, K_NONE, K5_L, K_NONE } else { +hold 8, K_NONE, K_NONE, K4_J, K_NONE, K_NONE }
        }
        +idle 1
}
!if AUTOWALK = 16 {             ; README preview: up the main street to the reactor gate
        +hold 80, K_NONE, K_NONE, K4_I, K_NONE, K_NONE
        +idle 1
}
!macro to_hesper {              ; Cinderhill start (32,24) -> (5,17), just below Hesper (5,16)
        +hold 16, K_NONE, K_NONE, K4_I, K_NONE, K_NONE       ; (32,22)
        +hold 216, K_NONE, K_NONE, K4_J, K_NONE, K_NONE      ; west along the street to (5,22)
        +hold 40, K_NONE, K_NONE, K4_I, K_NONE, K_NONE       ; (5,17)
}
!if AUTOWALK = 18 {             ; tests/test_talk_*.py: to Hesper, Dials leads, T
        +to_hesper
        +press 2, 7, K7_2
        +idle 4
        +press 2, 2, K2_T
        +idle 1
}
!if AUTOWALK = 27 {             ; tests/test_talk_cast.py: up the road to (32,14) beside Brandt, Dials leads, T
        +hold 80, K_NONE, K_NONE, K4_I, K_NONE, K_NONE       ; (32,24) -> (32,14)
        +press 2, 7, K7_2
        +idle 4
        +press 2, 2, K2_T
        +idle 1
}
!if AUTOWALK = 28 {             ; tests/test_portrait_reu.py: Hesper, Brandt, Hesper again (TYPESCRIPT 10 leaves twice)
        +to_hesper
        +press 2, 7, K7_2
        +idle 4
        +press 2, 2, K2_T
        +idle 1
        +hold 40, K_NONE, K_NONE, K4_K, K_NONE, K_NONE       ; (5,17) -> (5,22)
        +hold 216, K_NONE, K_NONE, K_NONE, K5_L, K_NONE      ; east along the street to (32,22)
        +hold 64, K_NONE, K_NONE, K4_I, K_NONE, K_NONE       ; up the road to (32,14), beside Brandt
        +press 2, 2, K2_T
        +idle 1
        +hold 64, K_NONE, K_NONE, K4_K, K_NONE, K_NONE       ; (32,22)
        +hold 216, K_NONE, K_NONE, K4_J, K_NONE, K_NONE      ; (5,22)
        +hold 40, K_NONE, K_NONE, K4_I, K_NONE, K_NONE       ; (5,17), below Hesper
        +press 2, 2, K2_T
        +idle 1
}
; M5 skill spots (tests/test_skills.py)
!macro steps .n, .r4, .r5 { +hold .n*GLIDE_FRAMES, K_NONE, K_NONE, .r4, .r5, K_NONE }
!macro use {
        +press 2, 3, K3_U
        +idle 4
}
!macro to_brandt {              ; start (32,24) -> (32,14), beside Brandt (31,14), facing the gate
        +steps 10, K4_I, K_NONE
}
!macro into_yard {              ; Vesna (leading from the start) opens the gate, the squad walks in to (32,12)
        +to_brandt
        +use
        +steps 2, K4_I, K_NONE
}
!macro to_valve {               ; (32,12) -> (30,4), beside the valve (31,4); Dials leads
        +press 2, 7, K7_2
        +idle 4
        +steps 2, K4_I, K_NONE
        +steps 3, K4_J, K_NONE
        +steps 6, K4_I, K_NONE
        +steps 1, K_NONE, K5_L
}
!macro valve_to_hatch {         ; (30,4) -> (35,4), beside the hatch (34,4), round the dome
        +steps 1, K4_J, K_NONE
        +steps 6, K4_K, K_NONE
        +steps 7, K_NONE, K5_L
        +steps 6, K4_I, K_NONE
        +steps 1, K4_J, K_NONE
}
!macro to_jory {                ; start (32,24) -> (5,39), beside Jory (4,39); Maren leads
        +steps 8, K4_K, K_NONE
        +steps 9, K4_J, K_NONE
        +steps 7, K4_K, K_NONE
        +steps 18, K4_J, K_NONE
        +press 2, 1, K1_3
        +idle 4
}
!if AUTOWALK = 29 {             ; Rook on the cart tracks at (44,19), U twice
        +steps 4, K4_I, K_NONE
        +steps 11, K_NONE, K5_L
        +steps 1, K4_I, K_NONE
        +steps 1, K_NONE, K5_L
        +press 2, 1, K1_4
        +idle 4
        +use
        +use
}
!if AUTOWALK = 30 {             ; Vesna: bump the shut gate, open it, walk in
        +to_brandt
        +idle 4
        +hold 12, K_NONE, K_NONE, K4_I, K_NONE, K_NONE       ; (32,13) is the shut gate: a bump
        +idle 4
        +use
        +steps 2, K4_I, K_NONE
        +idle 1
}
!if AUTOWALK = 31 {             ; Vesna: open the gate, U again, no walking
        +to_brandt
        +use
        +use
        +idle 1
}
!if AUTOWALK = 32 {             ; Dials at the valve, U twice
        +into_yard
        +to_valve
        +use
        +use
        +idle 1
}
!if AUTOWALK = 33 {             ; Dials at the hatch
        +into_yard
        +to_valve
        +valve_to_hatch
        +use
        +idle 1
}
!if AUTOWALK = 34 {             ; Dials at the hatch, U twice
        +into_yard
        +to_valve
        +valve_to_hatch
        +use
        +use
        +idle 1
}
!if AUTOWALK = 35 {             ; Maren treats Jory, U again (the squad), then talks to Jory
        +to_jory
        +use
        +use
        +press 2, 2, K2_T
        +idle 1
}
!if AUTOWALK = 36 {             ; Maren treats Jory
        +to_jory
        +use
        +idle 1
}
!if AUTOWALK = 19 {             ; Maren leads
        +to_hesper
        +press 2, 1, K1_3
        +idle 4
        +press 2, 2, K2_T
        +idle 1
}
!if AUTOWALK = 20 {             ; Vesna leads (first-meeting bonus)
        +to_hesper
        +press 2, 2, K2_T
        +idle 1
}
!if AUTOWALK = 21 {             ; tests/test_talk_leave.py: AUTOWALK=18 without the T
        +to_hesper
        +press 2, 7, K7_2
        +idle 4
}
!if AUTOWALK = 22 {             ; tests/test_talk_leave.py: talk, leave, step away and back, talk again
        +to_hesper
        +press 2, 7, K7_2
        +idle 4
        +press 2, 2, K2_T
        +idle 1
        +hold 8, K_NONE, K_NONE, K4_J, K_NONE, K_NONE
        +hold 8, K_NONE, K_NONE, K_NONE, K5_L, K_NONE
        +press 2, 2, K2_T
        +idle 1
}
!if AUTOWALK = 23 {             ; review #1: T pressed while K (down) is held, then leave
        +to_hesper
        +press 2, 7, K7_2
        +idle 4
        !byte 1, K_NONE, K_NONE, K2_T, K_NONE, K4_K, K_NONE, K_NONE, K_NONE   ; 1 frame: K is up again after
        +idle 1
}
!if AUTOWALK = 25 {             ; review #5: talk, leave, then 2 scrolling steps down
        +to_hesper
        +press 2, 7, K7_2
        +idle 4
        +press 2, 2, K2_T
        +idle 1
        +hold 16, K_NONE, K_NONE, K4_K, K_NONE, K_NONE
        +idle 1
}
!if AUTOWALK = 26 {             ; review #5 reference: the same 2 steps down, no talk
        +to_hesper
        +press 2, 7, K7_2
        +idle 4
        +hold 16, K_NONE, K_NONE, K4_K, K_NONE, K_NONE
        +idle 1
}
!if AUTOWALK = 13 {             ; tests/test_actions.py: AUTOWALK=10's route, then T (held), 2, U
        +hold 64, K_NONE, K_NONE, K_NONE, K5_L, K_NONE
        +hold 48, K_NONE, K_NONE, K4_I, K_NONE, K_NONE
        +press 60, 2, K2_T
        +idle 4
        +press 2, 7, K7_2
        +idle 4
        +press 2, 3, K3_U
        +idle 1
}
!if AUTOWALK = 17 {             ; tests/test_actions.py: key rollover 2 -> 3
        +press 6, 7, K7_2
        !byte 4, K_NONE, K1_3, K_NONE, K_NONE, K_NONE, K_NONE, K_NONE, K7_2  ; 2 and 3 both down
        +press 6, 1, K1_3
        +idle 1
}
!if AUTOWALK = 14 {             ; tests/test_actions.py: T at the start, nobody adjacent
        +press 30, 2, K2_T
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
