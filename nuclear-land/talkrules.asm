; Nuclear Land - conversation rules: keyword matching, trust tiers, the Known list
;
; Matching: a typed word hits a keyword if they are equal, or if both have 4+ letters and their
; first 4 agree (gen/dialogue.inc stores each keyword as its first 4 letters + its length).
; Trust (0 Wary .. 3 Friendly, per person): below a topic's tier the person deflects and nothing
; changes; the first real answer to a topic adds 1, plus 1 if a favoured member leads (max 3).
; Vesna leading at the first meeting starts the person one tier higher. Answers reveal keywords,
; which join the squad's Known list once.

KNOWN_MAX = 32

; talk_meet: on entering - the first meeting sets the person's starting trust
!zone talk_meet
talk_meet
        ldx talk_person
        lda met,x
        bne .out
        lda #1
        sta met,x
        ldy #DLG_START
        lda (dlg_ptr),y
        ldy leader              ; Vesna (0) leads: one tier higher
        bne +
        clc
        adc #1
+       cmp #4
        bcc +
        lda #3
+       sta trust,x
.out    rts

; talk_ask: answer the word in input_buf/input_len
!zone talk_ask
talk_ask
        ldy #DLG_KEYS
        lda (dlg_ptr),y
        sta zp_src
        iny
        lda (dlg_ptr),y
        sta zp_src+1
        ldy #DLG_NKEYS
        lda (dlg_ptr),y
        sta tr_n
.key    lda tr_n
        bne +
        ldy #DLG_UNKNOWN        ; no topic: "never heard of it"
        jmp .lines
+       ldy #4                  ; keyword length
        lda input_len
        cmp #4
        bcc .short
        lda (zp_src),y          ; typed 4+: the keyword must be 4+ too, first 4 letters agree
        cmp #4
        bcc .next
        ldy #3
        bne .cmp
.short  lda (zp_src),y          ; typed 1-3: same length, all letters agree
        cmp input_len
        bne .next
        ldy input_len
        dey
.cmp    lda input_buf,y
        cmp (zp_src),y
        bne .next
        dey
        bpl .cmp
        jmp .hit
.next   lda zp_src
        clc
        adc #KEY_SIZE
        sta zp_src
        bcc +
        inc zp_src+1
+       dec tr_n
        jmp .key

.hit    ldy #5                  ; topic index -> zp_src = topics + index * TOPIC_SIZE
        lda (zp_src),y
        sta tr_t
        ldy #DLG_TOPICS
        lda (dlg_ptr),y
        sta zp_src
        iny
        lda (dlg_ptr),y
        sta zp_src+1
        ldx tr_t
        beq +
-       lda zp_src
        clc
        adc #TOPIC_SIZE
        sta zp_src
        bcc ++
        inc zp_src+1
++      dex
        bne -
+       ldy #TOPIC_TIER
        lda (zp_src),y
        ldx talk_person
        cmp trust,x
        beq .answer
        bcc .answer
        ldy #TOPIC_ELSE         ; not trusted enough: deflect
        lda (zp_src),y
        sta txt_ptr
        iny
        lda (zp_src),y
        sta txt_ptr+1
        jmp .print
.answer ldy #TOPIC_REVEAL       ; keep the reveal list; conv_lines doesn't touch zp_src, but be safe
        lda (zp_src),y
        sta tr_rev
        iny
        lda (zp_src),y
        sta tr_rev+1
        ldy #TOPIC_SAY
        lda (zp_src),y
        sta txt_ptr
        iny
        lda (zp_src),y
        sta txt_ptr+1
        lda #COL_LGREY
        sta bm_fg
        jsr conv_lines
        jsr asked_bit           ; first time: trust grows
        and asked,x
        bne .reveal
        lda tr_bit
        ora asked,x
        sta asked,x
        ldx talk_person
        lda trust,x
        clc
        adc #1
        sta trust,x
        ldy #DLG_FAVOUR
        lda (dlg_ptr),y
        ldy leader
        and member_bit,y
        beq +
        inc trust,x
+       lda trust,x
        cmp #4
        bcc +
        lda #3
        sta trust,x
+
.reveal ldy #0                  ; keywords the answer reveals join the Known list
-       lda (tr_rev),y
        cmp #$ff
        beq .done
        jsr known_add
        iny
        bne -
.done   jsr talk_header
        jmp known_draw

.lines  lda (dlg_ptr),y
        sta txt_ptr
        iny
        lda (dlg_ptr),y
        sta txt_ptr+1
.print  lda #COL_LGREY
        sta bm_fg
        jmp conv_lines

; asked_bit: X = byte of person/topic tr_t in 'asked', A = tr_bit = its bit
asked_bit
        lda talk_person
        asl
        asl
        sta zp_tmp
        lda tr_t
        lsr
        lsr
        lsr
        clc
        adc zp_tmp
        tax
        lda tr_t
        and #7
        tay
        lda member_bit,y        ; (1 << n for n = 0..7)
        sta tr_bit
        rts

; known_add: keyword A joins the Known list unless already there (keeps Y)
!zone known_add
known_add
        ldx #0
-       cpx known_n
        beq +
        cmp known_ids,x
        beq .out
        inx
        bne -
+       cpx #KNOWN_MAX
        bcs .out
        sta known_ids,x
        inc known_n
.out    rts

; known_has: C=1 if keyword A is on the Known list. Clobbers X.
!zone known_has
known_has
        ldx #0
-       cpx known_n
        beq .no
        cmp known_ids,x
        beq .yes
        inx
        bne -
.no     clc
        rts
.yes    sec
        rts

!ifdef KNOWNTEST {
; knowntest_fill: test hook - 30 known keywords (ids cycling through the dictionary)
knowntest_fill
        ldx #0
        ldy #0
-       tya
        sta known_ids,x
        iny
        cpy #KW_N
        bcc +
        ldy #0
+       inx
        cpx #30
        bne -
        stx known_n
        rts
}

member_bit !byte 1, 2, 4, 8, 16, 32, 64, 128
tr_n    !byte 0
tr_t    !byte 0
tr_bit  !byte 0
met     !fill 8, 0
asked   !fill 8*4, 0
