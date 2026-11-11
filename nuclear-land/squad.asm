; Nuclear Land - the squad: health, leader, actions (1-4, T, U) and the message line
;
; Members: 0 Vesna (talker), 1 Dials (tinker), 2 Maren (medic), 3 Rook (scout). The leader's colour is
; the squad sprite's colour. A member at 0 health is sick and can't be chosen as leader; a leader who
; falls sick stays leader and can still walk, so the squad never gets stuck.

HP_MAX = 32

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
        lda #$ff
        sta talk_target
        lda #ACT_NONE
        sta act_prev
        sta act_pending
        jsr leader_colour
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
        beq act_talk
        bcs act_use
        jmp act_lead
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
        bcs .found
        ldy pp_dir
        iny
        cpy #4
        bne .dir
        lda #$ff
        sta talk_target
        lda #<msg_nobody
        ldx #>msg_nobody
        jmp msg_set
.found  stx talk_target
        lda people_name_lo,x    ; msg_set wants A = lo, X = hi
        pha
        lda people_name_hi,x
        tax
        pla
        jsr msg_set
        lda #<msg_nothing_yet
        ldx #>msg_nothing_yet
        jmp msg_add

; act_use: the leader's skill. Only Maren's heal does anything in M2 (Task 6); the others report
; that there is nothing here for them.
!zone act_use
act_use
        ldx leader
        cpx #2
        beq maren_use
        lda skill_msg_lo,x
        pha
        lda skill_msg_hi,x
        tax
        pla
        jmp msg_set

maren_use
        rts

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
skill_msg_lo !byte <msg_skill_v, <msg_skill_d, 0, <msg_skill_r
skill_msg_hi !byte >msg_skill_v, >msg_skill_d, 0, >msg_skill_r

msg_arrive        !scr "the squad arrives in cinderhill.", 0
msg_takes_lead    !scr " takes the lead.", 0
msg_too_sick_lead !scr " is too sick to lead.", 0
msg_nobody        !scr "nobody is close enough to talk to.", 0
msg_nothing_yet   !scr " has nothing to say yet.", 0
msg_skill_v       !scr "vesna finds nobody to persuade.", 0
msg_skill_d       !scr "dials finds nothing to fix.", 0
msg_skill_r       !scr "rook finds no tracks here.", 0

squad_hp     !fill 4, HP_MAX
leader       !byte 0
talk_target  !byte $ff
actions_done !byte 0
refusals     !byte 0
msg_len      !byte 0
msg_buf      !fill 40, ' '
