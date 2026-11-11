; Nuclear Land - the squad: health, leader, actions (1-4, T, U) and the message line
;
; Members: 0 Vesna (talker), 1 Dials (tinker), 2 Maren (medic), 3 Rook (scout). The leader's colour is
; the squad sprite's colour. A member at 0 health is sick and can't be chosen as leader; a leader who
; falls sick stays leader and can still walk, so the squad never gets stuck.

HP_MAX = 32
HOT_DAMAGE = 4                  ; to every member, per step onto a hot spot
HEAL_AMOUNT = 12                ; Maren's treatment, to every member
HEAL_COOLDOWN = 16              ; steps before Maren can treat again
MAREN_RECOVER_STEPS = 16        ; steps on radiation-free tiles for a sick Maren to recover...
MAREN_RECOVER_HP = 4            ; ...to this much health

!zone squad_init
squad_init
        ldx #3
-       lda #HP_MAX
        sta squad_hp,x
        dex
        bpl -
        lda #0
        sta leader
        sta actions_done
        sta refusals
        sta heal_cool
        sta maren_rec
        sta hot_steps
        sta heals_done
        lda #$ff
        sta talk_target
        lda #ACT_NONE
        sta act_prev
        sta act_pending
        jsr leader_colour
!ifdef KNOW_HATCH {             ; tests/test_skills.py: the squad already knows Pip's word
        lda #KW_HATCH
        jsr known_add
}
!ifdef PROOFS {                 ; tests/test_ending.py: the first PROOFS proofs are already known
        ldy #0
-       cpy #PROOFS
        beq +
        lda proof_kw,y
        jsr known_add
        iny
        bne -
+
}
        lda #<msg_arrive
        ldx #>msg_arrive
        jmp msg_set

; squad_act: run the pending action, if any, while the leader stands still
!zone squad_act
squad_act
        lda act_pending
        cmp #ACT_NONE
        beq .out
        ldx glide_dir
        cpx #DIR_NONE
        bne .out
        ldx #ACT_NONE
        stx act_pending
        inc actions_done
        cmp #ACT_TALK
        bcc +
        beq act_talk
        jmp act_use
+       jmp act_lead
.out    rts

; act_lead: A = member to lead
!zone act_lead
act_lead
        tax
        lda squad_hp,x
        bne .ok
        inc refusals
        txa
        jsr msg_member
        lda #<msg_too_sick_lead
        ldx #>msg_too_sick_lead
        jmp msg_add
.ok     stx leader
        jsr leader_colour
        txa
        jsr msg_member
        lda #<msg_takes_lead
        ldx #>msg_takes_lead
        jmp msg_add

; act_talk: the first person next to the leader (up, down, left, right) becomes the talk target
!zone act_talk
act_talk
        jsr adjacent_person
        bcs .found
        lda #T_VOSS_BODY        ; Voss is a figure on the basement map
        jsr near_tile
        bcs .voss
        lda #T_VOSS_HEAD
        jsr near_tile
        bcs .voss
        lda #$ff
        sta talk_target
        lda #<msg_nobody
        ldx #>msg_nobody
        jmp msg_set
.voss   lda #CAST_VOSS
        ldx #$ff
        jmp talk_enter_cast
.found  stx talk_target
        ldy people_cast,x       ; someone with dialogue: the talking screen
        cpy #$ff
        beq +
        lda dlg_hi,y
        beq +
        jmp talk_enter
+       lda people_name_lo,x    ; msg_set wants A = lo, X = hi
        pha
        lda people_name_hi,x
        tax
        pla
        jsr msg_set
        lda #<msg_nothing_yet
        ldx #>msg_nothing_yet
        jmp msg_add

; adjacent_person: C=1 and X = people index of the first person next to the leader (up, down,
; left, right); C=0 if nobody. Clobbers A, Y, zp_tmp, zp_row.
!zone adjacent_person
adjacent_person
        ldy #0
.dir    lda leader_x
        clc
        adc dir_dx,y
        sta zp_tmp
        lda leader_y
        clc
        adc dir_dy,y
        sta zp_row
        sty pp_dir
        jsr person_at
        bcs .out
        ldy pp_dir
        iny
        cpy #4
        bne .dir
        clc
.out    rts

; act_use: the leader's skill (U). Each skill works at its own spots and says so on the message
; line; anywhere else it reports that there is nothing here for it. Every spot can be used again:
; the Known list holds a word once, and an open gate or hatch says it stands open.
;   Vesna next to Brandt     the gate opens, Brandt is met at Open
;   Dials beside the valve   TAPPED joins Known
;   Dials beside the hatch   with HATCH known: forced open (the way down, next)
;   Maren next to Jory       his fever is treated once, he is met at Open; otherwise the squad heal
;   Rook on the cart tracks  TRACKS joins Known
CAST_BRANDT = 1                 ; cast indexes (tools/make_map.py CAST)
CAST_JORY   = 3
CAST_VOSS   = 7
OPEN        = 2                 ; trust tier

!zone act_use
act_use
        lda leader
        beq vesna_use
        cmp #1
        beq dials_use
        cmp #2
        bne rook_use
        jmp maren_use

!zone rook_use
rook_use
        lda #T_RUTS_H
        jsr on_tile
        bcs .found
        lda #T_RUTS_V
        jsr on_tile
        bcs .found
        lda #<msg_skill_r
        ldx #>msg_skill_r
        jmp msg_set
.found  lda #KW_TRACKS
        jsr known_add
        lda #<msg_tracks
        ldx #>msg_tracks
        jmp msg_set

!zone vesna_use
vesna_use
        jsr adjacent_person
        bcc .none
        lda people_cast,x
        cmp #CAST_BRANDT
        bne .none
        lda gate_opened
        beq +
        lda #<msg_gate_open
        ldx #>msg_gate_open
        jmp msg_set
+       lda #1
        sta gate_opened
        ldx #CAST_BRANDT
        jsr meet_open
        jsr open_gate
        lda #<msg_persuade
        ldx #>msg_persuade
        jmp msg_set
.none   lda #<msg_skill_v
        ldx #>msg_skill_v
        jmp msg_set

!zone dials_use
dials_use
        lda #T_VALVE
        jsr near_tile
        bcc .hatch
        lda #KW_TAPPED
        jsr known_add
        lda #<msg_tapped
        ldx #>msg_tapped
        jmp msg_set
.hatch  lda #T_HATCH_OPEN
        jsr near_tile
        bcc +
        lda #<msg_hatch_open
        ldx #>msg_hatch_open
        jmp msg_set
+       lda #T_HATCH
        jsr near_tile
        bcc .none
        lda #KW_HATCH           ; Pip's word for it: without it Dials doesn't know to look
        jsr known_has
        bcc .none
        lda #1
        sta hatch_opened
        lda #T_HATCH_OPEN
        jsr cell_set
        lda #<msg_forced
        ldx #>msg_forced
        jmp msg_set
.none   lda #<msg_skill_d
        ldx #>msg_skill_d
        jmp msg_set

; meet_open: cast member X counts as met, at Open trust or better (talk_meet then leaves them be)
meet_open
        lda #1
        sta met,x
        lda trust,x
        cmp #OPEN
        bcs +
        lda #OPEN
        sta trust,x
+       rts

; open_gate: every gate cell becomes the passable tile below it (gen/<map>.inc gate table)
!zone open_gate
open_gate
        ldx #0
.g      cpx #GATE_N
        bcs .out
        stx og_i
        lda gate_x,x
        sta zp_tmp
        lda gate_y,x
        sta zp_row
        lda gate_open,x
        jsr cell_set
        ldx og_i
        inx
        bne .g
.out    rts

; on_tile: C=1 if the leader stands on tile A. Clobbers A, Y, zp_tmp, zp_row, zp_src.
on_tile
        sta nt_code
        lda leader_x
        sta zp_tmp
        lda leader_y
        sta zp_row
        jsr map_cell_ptr
        ldy #0
        lda (zp_src),y
        cmp nt_code
        beq +
        clc
        rts
+       sec
        rts

; near_tile: C=1 and (zp_tmp, zp_row) = the cell if tile A is next to the leader (up, down, left,
; right). Clobbers A, Y, zp_src.
!zone near_tile
near_tile
        sta nt_code
        ldy #0
.dir    lda leader_x
        clc
        adc dir_dx,y
        sta zp_tmp
        lda leader_y
        clc
        adc dir_dy,y
        sta zp_row
        sty nt_dir
        jsr map_cell_ptr
        ldy #0
        lda (zp_src),y
        ldy nt_dir
        cmp nt_code
        beq .yes
        iny
        cpy #4
        bne .dir
        clc
        rts
.yes    sec
        rts

; cell_set: map cell (zp_tmp, zp_row) becomes tile A, and so does the screen on show (character and
; colour) if the cell is in view. The hidden buffer is rebuilt from the map on the next step, and
; talk_leave redraws from it, so the change stays. Only called while the leader stands still.
!zone cell_set
cell_set
        sta cs_code
        jsr map_cell_ptr
        ldy #0
        lda cs_code
        sta (zp_src),y
        lda zp_tmp
        sec
        sbc cam_x
        cmp #VIEW_COLS
        bcs .out
        sta cs_col
        lda zp_row
        sec
        sbc cam_y
        cmp #MAP_ROWS
        bcs .out
        clc
        adc #ROW_MAP
        tax
        lda row_off_lo,x
        clc
        adc cs_col
        sta zp_dst
        sta zp_col
        lda row_off_hi,x
        adc #0
        tay
        clc
        adc #>COLRAM
        sta zp_col+1
        tya
        ldx vis_buf
        clc
        adc screen_page_tbl,x
        sta zp_dst+1
        ldy #0
        lda cs_code
        sta (zp_dst),y
        tax
        lda tilecolors,x
        sta (zp_col),y
.out    rts

!zone maren_use
maren_use
        lda squad_hp+2
        bne +
        lda #<msg_maren_sick
        ldx #>msg_maren_sick
        jmp msg_set
+       lda jory_treated        ; next to an untreated Jory: treat his fever
        bne .squad
        jsr adjacent_person
        bcc .squad
        lda people_cast,x
        cmp #CAST_JORY
        bne .squad
        lda #1
        sta jory_treated
        ldx #CAST_JORY
        jsr meet_open
        lda #<msg_jory
        ldx #>msg_jory
        jmp msg_set
.squad  jsr leader_rad
        cmp #8
        bne +
        lda #<msg_too_hot
        ldx #>msg_too_hot
        jmp msg_set
+       lda heal_cool
        beq +
        lda #<msg_rest
        ldx #>msg_rest
        jmp msg_set
+       ldx #3
-       lda squad_hp,x
        clc
        adc #HEAL_AMOUNT
        cmp #HP_MAX+1
        bcc +
        lda #HP_MAX
+       sta squad_hp,x
        dex
        bpl -
        lda #HEAL_COOLDOWN
        sta heal_cool
        inc heals_done
        lda #<msg_treats
        ldx #>msg_treats
        jmp msg_set

; the_end: leaving Voss once he has named Corwin. The ending screen in the walking charset: the
; good ending with two or more of the four proofs on the Known list, the open one with fewer
; (gen/dialogue.inc end_good / end_open, from dialogue/ending.txt), how many the squad found, and
; THE END. The game stops here: interrupts off, the screen stays.
!zone the_end
the_end
        sei
        lda #0
        sta VIC_IRQEN
        sta VIC_SPREN
        lda #$ff
        sta VIC_IRQ
        lda #D011_OFF
        sta VIC_CTRL1
        lda #%00001000          ; 40 columns, no scroll
        sta VIC_CTRL2
        lda #D018_A
        sta VIC_MEM
        lda #COL_BLACK
        sta VIC_BORDER
        lda #>SCREEN_A
        jsr clear_screen
        ldx #0
        lda #COL_LGREY
-       sta COLRAM,x
        sta COLRAM+$100,x
        sta COLRAM+$200,x
        sta COLRAM+$2e8,x
        inx
        bne -
        lda #0                  ; the proofs found
        sta end_n
        ldy #3
-       lda proof_kw,y
        jsr known_has           ; (keeps Y)
        bcc +
        inc end_n
+       dey
        bpl -
        lda end_n
        cmp #2
        bcc +
        lda #<end_good
        ldx #>end_good
        bne ++
+       lda #<end_open
        ldx #>end_open
++      sta zp_src
        stx zp_src+1
        lda #<(SCREEN_A + END_TOP*40 + 2)
        sta zp_dst
        lda #>(SCREEN_A + END_TOP*40 + 2)
        sta zp_dst+1
.line   ldy #0
        lda (zp_src),y
        cmp #$ff
        beq .done
-       lda (zp_src),y
        beq .eol
        sta (zp_dst),y
        iny
        bne -
.eol    iny                     ; past the 0: the next row's text
        tya
        clc
        adc zp_src
        sta zp_src
        bcc +
        inc zp_src+1
+       jsr .down
        jmp .line
.done   jsr .down               ; a blank row, then the count
        ldy #0
        ldx #0
-       lda txt_found,x
        beq +
        sta (zp_dst),y
        inx
        iny
        bne -
+       lda end_n
        clc
        adc #'0'
        sta (zp_dst),y
        iny
        ldx #0
-       lda txt_found2,x
        beq +
        sta (zp_dst),y
        inx
        iny
        bne -
+       ldx #7
-       lda txt_the_end,x
        sta SCREEN_A + 22*40 + 16,x
        dex
        bpl -
        lda #1
        sta game_over
        lda #D011_TXT
        sta VIC_CTRL1
.stop   jmp .stop
.down   lda zp_dst              ; zp_dst one row down
        clc
        adc #40
        sta zp_dst
        bcc +
        inc zp_dst+1
+       rts

proof_kw    !byte KW_CARTS, KW_BARRELS, KW_TRACKS, KW_TAPPED
txt_found   !scr "the squad found ", 0
txt_found2  !scr " of the 4 proofs.", 0
txt_the_end !scr "the end."
end_n       !byte 0
game_over   !byte 0

; squad_step: once per completed step (from on_step_end) - radiation, Maren's recovery, cooldown
!zone squad_step
squad_step
        jsr leader_rad
        cmp #8
        bne .nothot
        ldx #3                  ; on a hot spot: everyone takes HOT_DAMAGE, floored at 0
-       lda squad_hp,x
        sec
        sbc #HOT_DAMAGE
        bcs +
        lda #0
+       sta squad_hp,x
        dex
        bpl -
        inc hot_steps
        lda #<msg_hot
        ldx #>msg_hot
        jsr msg_set
        jmp .cool
.nothot cmp #0                  ; radiation-free tile: a sick Maren slowly recovers
        bne .cool
        lda squad_hp+2
        bne .cool
        inc maren_rec
        lda maren_rec
        cmp #MAREN_RECOVER_STEPS
        bne .cool
        lda #MAREN_RECOVER_HP
        sta squad_hp+2
        lda #0
        sta maren_rec
        lda #<msg_better
        ldx #>msg_better
        jsr msg_set
.cool   lda heal_cool
        beq +
        dec heal_cool
+       lda #1
        sta hud_dirty
        rts

; leader_rad: A = radiation level at the leader's cell
leader_rad
        lda leader_x
        sta zp_tmp
        lda leader_y
        sta zp_row
        jmp rad_at

; leader_colour: squad sprite colour = leader's colour
leader_colour
        ldx leader
        lda member_col,x
        sta VIC_SPR0COL
        rts

; ---- message line ----
; msg_set: message = 0-terminated screen-code string at X:A (A = lo). msg_add appends.
!zone msg
msg_set
        pha
        lda #0
        sta msg_len
        lda #' '
        ldy #39
-       sta msg_buf,y
        dey
        bpl -
        pla
msg_add
        sta zp_src
        stx zp_src+1
        ldy #0
        ldx msg_len
-       lda (zp_src),y
        beq .end
        cpx #40
        bcs .end
        sta msg_buf,x
        inx
        iny
        bne -
.end    stx msg_len
        lda #1
        sta hud_dirty
        rts

; msg_member: message = member A's name (then msg_add the rest)
msg_member
        tax
        lda member_name_lo,x
        pha
        lda member_name_hi,x
        tax
        pla
        jmp msg_set

; ---- data ----
member_col     !byte COL_WHITE, COL_LBLUE, COL_LGREEN, COL_ORANGE
member_name_lo !byte <name_vesna, <name_dials, <name_maren, <name_rook
member_name_hi !byte >name_vesna, >name_dials, >name_maren, >name_rook
name_vesna !scr "vesna", 0
name_dials !scr "dials", 0
name_maren !scr "maren", 0
name_rook  !scr "rook", 0

msg_arrive        !scr "the squad arrives in cinderhill.", 0
msg_takes_lead    !scr " takes the lead.", 0
msg_too_sick_lead !scr " is too sick to lead.", 0
msg_nobody        !scr "nobody is close enough to talk to.", 0
msg_nothing_yet   !scr " has nothing to say yet.", 0
msg_skill_v       !scr "vesna finds nobody to persuade.", 0
msg_skill_d       !scr "dials finds nothing to fix.", 0
msg_skill_r       !scr "rook finds no tracks here.", 0
msg_hot           !scr "hot spot! the squad takes radiation.", 0
msg_better        !scr "maren feels better.", 0
msg_treats        !scr "maren treats the squad.", 0
msg_rest          !scr "maren needs to rest first.", 0
msg_too_hot       !scr "too hot here to treat anyone.", 0
msg_maren_sick    !scr "maren is too sick to help.", 0
msg_tracks        !scr "rook: cart tracks lead to the storehouse", 0
msg_persuade      !scr "vesna talks brandt into opening up.", 0
msg_gate_open     !scr "the gate stands open.", 0
msg_tapped        !scr "dials: someone tapped the coolant line!", 0
msg_forced        !scr "dials forces the hatch. stairs go down.", 0
msg_hatch_open    !scr "the hatch stands open.", 0
msg_jory          !scr "maren treats jory's fever.", 0

squad_hp     !fill 4, HP_MAX
leader       !byte 0
talk_target  !byte $ff
actions_done !byte 0
refusals     !byte 0
heal_cool    !byte 0
maren_rec    !byte 0
hot_steps    !byte 0
heals_done   !byte 0
gate_opened  !byte 0
hatch_opened !byte 0
jory_treated !byte 0
nt_code      !byte 0
nt_dir       !byte 0
cs_code      !byte 0
cs_col       !byte 0
og_i         !byte 0
msg_len      !byte 0
msg_buf      !fill 40, ' '
