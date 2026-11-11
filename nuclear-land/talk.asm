; Nuclear Land - the talking screen (layout A): portrait beside the conversation
;
; Screen rows 0-18 are a hi-res bitmap (bitmap at TALK_BITMAP, cell colours in SCREEN_A): the
; portrait fills columns 0-15, the header and conversation columns 16-39. Rows 19-23 are text
; (screen SCREEN_B, the walking charset): Known keywords (rows 19-20), "<leader> leads. ask about:",
; the input prompt, a hint. Its own raster chain switches modes at the end of raster line 202 (in
; the right border), so the row-19 badline on line 203 already fetches text.
;
; The portrait's eye whites and irises are hardware sprites over the bitmap (a hi-res cell can't
; hold skin, black and white): see eyes_setup. Portraits and eyes don't fit in memory with the
; whole cast's dialogue, so each is loaded from disk on entering (portrait_load).
;
; Entering trashes the walking screen buffers and the sprite shapes ($E000 is the bitmap);
; talk_leave rebuilds everything from game state.

TALK_BITMAP  = $e000
TALK_CELLCOL = SCREEN_A
TALK_TEXT    = SCREEN_B
D011_BMP     = %00111011        ; BMM, DEN, RSEL, YSCROLL 3
D011_TXT     = %00011011
D011_OFF     = %00001011        ; display off (border colour), RSEL, YSCROLL 3
D018_TALKBMP = ((SCREEN_A - VIC_BANK) / $400) << 4 | %1000     ; cells $C000, bitmap $E000
EYE_SPR_MEM  = SCREEN_B         ; eye sprites: rows 0-18 of the text screen are never shown while talking
EYE_SPR_PTR  = (EYE_SPR_MEM - VIC_BANK) / 64
TALK_IRQ_TOP = 16
TALK_IRQ_SPLIT = 200
TALK_SPLIT_LINE = 202
ROW_KNOWN    = 19
ROW_LEADS    = 21
ROW_PROMPT   = 22
ROW_THINT    = 23
REU_CMD      = $df01            ; RAM Expansion Unit (1700/1750/1764, or an emulated one)
REU_C64      = $df02            ; 2 bytes: C64 address
REU_ADDR     = $df04            ; 3 bytes: REU address (lo, hi, bank)
REU_LEN      = $df07            ; 2 bytes: length
REU_CTRL     = $df0a            ; address control: 0 = both addresses count up
REU_STASH    = $90              ; C64 -> REU, now (bit 4: don't wait for a write to $FF00)
REU_FETCH    = $91              ; REU -> C64, now
REU_SLOT     = $1000            ; REU bytes per cached face (bank 0, slot = cast index)
ROW_LOADING  = 11
SETMSG       = $ff90
SETLFS       = $ffba
SETNAM       = $ffbd
LOAD         = $ffd5            ; through the $0330 vector, so fastload cartridges speed it up
KSTATUS      = $90              ; KERNAL I/O status
KDEVICE      = $ba              ; the device the game was loaded from
SCNKEY       = $ff9f
GETIN        = $ffe4
KEYBUF       = $0277
KEYBUF_N     = $c6

; talk_enter: X = people index of the person to talk to (who has dialogue). talk_enter_cast: A = cast
; index, X = people index or $ff for Voss (a figure on the basement map, not a townsperson sprite).
!zone talk_enter
talk_enter
        lda people_cast,x
talk_enter_cast
        stx talk_people_i
        sta talk_person
        tax
        lda dlg_lo,x
        sta dlg_ptr
        lda dlg_hi,x
        sta dlg_ptr+1
        sei
        lda #0
        sta VIC_SPREN
        lda #D011_OFF
        sta VIC_CTRL1
        ldx #>TALK_BITMAP       ; clear the bitmap ($E000-$FFFF, RAM under the KERNAL ROM)
        lda #0
        jsr fill_pages_32
        lda #>TALK_CELLCOL      ; cell colours: black on black
        sta zp_dst+1
        lda #0
        jsr fill_1k
        lda #>TALK_TEXT
        jsr clear_screen
!ifdef PORTRAIT_OF {                    ; tests/test_portraits_all.py: show cast PORTRAIT_OF's portrait
        lda #PORTRAIT_OF
        sta talk_person
}
        jsr portrait_load
        jsr portrait_blit
        jsr eyes_setup
        jsr talk_meet
        jsr talk_header
        jsr conv_reset          ; the greeting opens the conversation
        ldy #DLG_GREET
        jsr dlg_word_to_txt
        lda #COL_LGREY
        sta bm_fg
        jsr conv_lines
!ifdef KNOWNTEST {
        jsr knowntest_fill
}
        jsr talk_bottom
        jsr SCNKEY              ; the T key may still be down: register it, then drop it
        lda #0
        sta KEYBUF_N
        sta input_len
        lda #<talk_irq_top
        sta $0314
        lda #>talk_irq_top
        sta $0315
        lda #TALK_IRQ_TOP
        sta VIC_RASTER
        lda #1
        sta VIC_IRQ
        lda #MODE_TALK
        sta game_mode
        cli
        rts

; fill_pages_32: 32 pages from X*256 with A
!zone fill
fill_pages_32
        stx zp_dst+1
        ldy #0
        sty zp_dst
        ldx #32
-       sta (zp_dst),y
        iny
        bne -
        inc zp_dst+1
        dex
        bne -
        rts
; fill_1k: 4 pages from zp_dst+1 (hi) with A
fill_1k
        ldy #0
        sty zp_dst
        ldx #4
-       sta (zp_dst),y
        iny
        bne -
        inc zp_dst+1
        dex
        bne -
        rts

; portrait_load: the talk person's portrait and eye sprites into PORTRAIT_BUF: the file
; "FACE <cast letter>" (tools/make_disk.py) is the portrait (gen/portrait_<name>.bin) followed by
; its eye sprites (gen/eyes_<name>.bin). Skipped when that person's face is already there. With an
; REU, a face loaded once is kept there and fetched by DMA after that, so only the first visit to
; each person reads the disk. While the disk is read, the screen shows "you approach <name>..."
; (plain text mode: the KERNAL's serial routines CLI, so the raster split can't run). If the load
; fails the portrait is black and has no eye sprites, and the next visit tries again.
; Called with the display off and IRQs disabled; leaves them so.
!zone portrait_load
portrait_load
        lda talk_person
        cmp face_loaded
        bne +
        rts                     ; already there
+       sta face_loaded
        tax
        lda reu_present
        beq .disk
        lda eye_bit_8,x
        and face_cached
        beq .disk
        jsr face_slot           ; cached: one DMA, no disk
        lda #REU_FETCH
        jmp reu_xfer
.disk   lda cast_letter,x
        sta face_name + FACE_NAME_LEN - 1
        lda #0                  ; the KERNAL's serial routines CLI: no raster IRQs while loading
        sta VIC_IRQEN
        lda #1
        sta VIC_IRQ
        jsr loading_show
        lda #0
        jsr SETMSG              ; no "SEARCHING FOR" / "LOADING"
        lda KDEVICE
        cmp #8
        bcs +
        lda #8                  ; started some other way (injected): assume drive 8
+       tax
        lda #1
        ldy #0                  ; secondary address 0: load to X/Y, not the file's own address
        jsr SETLFS
        lda #FACE_NAME_LEN
        ldx #<face_name
        ldy #>face_name
        jsr SETNAM
        lda #0                  ; load, not verify
        ldx #<PORTRAIT_BUF
        ldy #>PORTRAIT_BUF
        jsr LOAD
        sei
        php
        lda #D011_OFF
        sta VIC_CTRL1
        inc face_disk_loads
        plp
        bcs .fail
        lda KSTATUS
        and #%10000011          ; device not present, timeouts (bit 6 = end of file is normal)
        bne .fail
        lda reu_present         ; keep it for next time
        beq .on
        ldx talk_person
        jsr face_slot
        lda #REU_STASH
        jsr reu_xfer
        ldx talk_person
        lda eye_bit_8,x
        ora face_cached
        sta face_cached
        jmp .on
.fail   lda #$ff                ; try again next time
        sta face_loaded
        lda #<PORTRAIT_BUF      ; black portrait, no eyes
        sta zp_dst
        lda #>PORTRAIT_BUF
        sta zp_dst+1
        ldx #>(PORTRAIT_EYES + 1 - PORTRAIT_BUF + 255)
        ldy #0
        tya
-       sta (zp_dst),y
        iny
        bne -
        inc zp_dst+1
        dex
        bne -
.on     lda #1
        sta VIC_IRQEN
        sta VIC_IRQ
.out    rts

; loading_show: "you approach <name>..." on row ROW_LOADING of the (otherwise empty) text screen,
; and that screen on: plain text mode, steady without IRQs
!zone loading_show
loading_show
        jsr talk_name
        sta zp_src
        stx zp_src+1
        ldx #0
-       lda txt_approach,x
        beq +
        sta TALK_TEXT + ROW_LOADING*40 + 8,x
        inx
        bne -
+       ldy #0
-       lda (zp_src),y
        beq +
        sta TALK_TEXT + ROW_LOADING*40 + 8,x
        inx
        iny
        bne -
+       ldy #0
-       lda txt_dots,y
        beq +
        sta TALK_TEXT + ROW_LOADING*40 + 8,x
        inx
        iny
        bne -
+       ldx #39
        lda #COL_LGREY
-       sta COLRAM + ROW_LOADING*40,x
        dex
        bpl -
        lda #D018_B
        sta VIC_MEM
        lda #D016_STD
        sta VIC_CTRL2
        lda #D011_TXT
        sta VIC_CTRL1
        rts

; face_slot: REU transfer of PORTRAIT_BUF..PORTRAIT_END for cast index X (slot X * REU_SLOT)
face_slot
        lda #<PORTRAIT_BUF
        sta reu_c64
        lda #>PORTRAIT_BUF
        sta reu_c64+1
        lda #0
        sta reu_off
        txa
        asl
        asl
        asl
        asl
        sta reu_off+1           ; X * $1000
        lda #<(PORTRAIT_END - PORTRAIT_BUF)
        sta reu_len
        lda #>(PORTRAIT_END - PORTRAIT_BUF)
        sta reu_len+1
        rts

; reu_xfer: A = REU_STASH or REU_FETCH: reu_len bytes between C64 reu_c64 and REU bank 0 reu_off.
; The CPU waits while the REU copies.
!zone reu_xfer
reu_xfer
        pha
        lda reu_c64
        sta REU_C64
        lda reu_c64+1
        sta REU_C64+1
        lda reu_off
        sta REU_ADDR
        lda reu_off+1
        sta REU_ADDR+1
        lda #0
        sta REU_ADDR+2
        sta REU_CTRL
        lda reu_len
        sta REU_LEN
        lda reu_len+1
        sta REU_LEN+1
        pla
        sta REU_CMD
        rts

; reu_detect (at start): reu_present = 1 if an REU answers. Its address registers must read back
; what was written (without an REU, $DFxx reads are whatever was last on the bus), and a byte
; stashed and fetched back must survive, twice with different values.
!zone reu_detect
reu_detect
        lda #0
        sta reu_present
        ldx #3
-       txa
        eor #$a5
        sta REU_C64,x
        dex
        bpl -
        ldx #3
-       txa
        eor #$a5
        cmp REU_C64,x
        bne .out
        dex
        bpl -
        lda #<reu_probe
        sta reu_c64
        lda #>reu_probe
        sta reu_c64+1
        lda #0
        sta reu_off
        lda #$f0                ; REU $00F000: above the 8 face slots
        sta reu_off+1
        lda #1
        sta reu_len
        lda #0
        sta reu_len+1
        lda #$5a
        jsr .probe
        bne .out
        lda #$a5
        jsr .probe
        bne .out
        inc reu_present
.out    rts
.probe  sta reu_probe           ; stash A, clear it, fetch it back: Z = 1 if it survived
        pha
        lda #REU_STASH
        jsr reu_xfer
        lda #0
        sta reu_probe
        lda #REU_FETCH
        jsr reu_xfer
        pla
        cmp reu_probe
        rts

; portrait_blit: the talk person's 16x19-cell portrait into bitmap columns 0-15
!zone portrait_blit
portrait_blit
        lda #<PORTRAIT_BUF
        sta zp_src
        lda #>PORTRAIT_BUF
        sta zp_src+1
        lda #<TALK_BITMAP
        sta zp_dst
        lda #>TALK_BITMAP
        sta zp_dst+1
        ldx #19
.bmrow  ldy #127                ; 16 cells x 8 bytes, contiguous in the source
-       lda (zp_src),y
        sta (zp_dst),y
        dey
        bpl -
        lda zp_src
        clc
        adc #128
        sta zp_src
        bcc +
        inc zp_src+1
+       lda zp_dst              ; next bitmap row: +320
        clc
        adc #<320
        sta zp_dst
        lda zp_dst+1
        adc #>320
        sta zp_dst+1
        dex
        bne .bmrow
        lda #<TALK_CELLCOL      ; zp_src now points at the 304 colour bytes
        sta zp_dst
        lda #>TALK_CELLCOL
        sta zp_dst+1
        ldx #19
.colrow ldy #15
-       lda (zp_src),y
        sta (zp_dst),y
        dey
        bpl -
        lda zp_src
        clc
        adc #16
        sta zp_src
        bcc +
        inc zp_src+1
+       lda zp_dst
        clc
        adc #40
        sta zp_dst
        bcc +
        inc zp_dst+1
+       dex
        bne .colrow
        rts

; talk_bottom: the text rows 19-23 and their colours
!zone talk_bottom
talk_bottom
        jsr known_draw
        ldx leader              ; row 21: "<leader> leads. ask about:"
        lda member_name_lo,x
        sta zp_src
        lda member_name_hi,x
        sta zp_src+1
        ldy #0
-       lda (zp_src),y
        beq +
        sta TALK_TEXT + ROW_LEADS*40,y
        iny
        bne -
+       ldx #0
-       lda txt_leads,x
        beq +
        sta TALK_TEXT + ROW_LEADS*40,y
        iny
        inx
        bne -
+       ldx #39
-       lda txt_hint,x
        sta TALK_TEXT + ROW_THINT*40,x
        lda #COL_LGREY
        sta COLRAM + ROW_KNOWN*40,x
        sta COLRAM + (ROW_KNOWN+1)*40,x
        sta COLRAM + ROW_LEADS*40,x
        lda #COL_YELLOW
        sta COLRAM + ROW_PROMPT*40,x
        lda #COL_DGREY
        sta COLRAM + ROW_THINT*40,x
        dex
        bpl -
        ; fall through: the prompt

; prompt_draw: "> " + the typed word on row 22
prompt_draw
        lda #'>'
        sta TALK_TEXT + ROW_PROMPT*40
        lda #' '
        ldx #38
-       sta TALK_TEXT + ROW_PROMPT*40 + 1,x
        dex
        bpl -
        ldx #0
-       cpx input_len
        beq +
        lda input_buf,x
        sta TALK_TEXT + ROW_PROMPT*40 + 2,x
        inx
        bne -
+       lda #G_METER_ON         ; cursor
        sta TALK_TEXT + ROW_PROMPT*40 + 2,x
        rts

; known_draw: "known: " + the squad's known keywords on rows 19-20. Whole words only: a word that
; doesn't fit on row 19 starts row 20; when they don't all fit, the oldest are left out.
!zone known_draw
known_draw
        lda #' '
        ldx #79
-       sta TALK_TEXT + ROW_KNOWN*40,x
        dex
        bpl -
        ldx #0
-       lda txt_known,x
        beq +
        sta TALK_TEXT + ROW_KNOWN*40,x
        inx
        bne -
+       jsr known_first
        jsr known_start
.word   cpy known_n
        beq .out
        sty kd_i
        jsr known_place         ; kd_col = where this word goes (row 19 or 20)
        ldy kd_i
        lda known_ids,y
        jsr kw_ptr
        ldy #0
        ldx kd_col
-       lda (zp_src),y
        beq +
        sta TALK_TEXT + ROW_KNOWN*40,x
        inx
        iny
        cpy #KW_LEN
        bne -
+       ldy kd_i
        iny
        bne .word
.out    rts

; known_start: layout cursor at row 19, after "known: "
known_start
        lda #0
        sta kd_row
        lda #7
        sta kd_w
        rts

; known_place: lay out word kd_i: C=1 if it doesn't fit (no rows left); else kd_col = its cell
; (0-79 from row 19's start) and the cursor moves past it and a space
!zone known_place
known_place
        ldy kd_i
        lda known_ids,y
        jsr kw_ptr
        ldy #0
-       lda (zp_src),y          ; Y = length
        beq +
        iny
        cpy #KW_LEN
        bne -
+       sty kd_len
        tya
        clc
        adc kd_w
        cmp #41
        bcc .fits
        lda kd_row              ; past column 40: next row, if there is one
        bne .full
        inc kd_row
        lda #0
        sta kd_w
.fits   lda kd_row              ; kd_col = row * 40 + column
        beq +
        lda #40
+       clc
        adc kd_w
        sta kd_col
        lda kd_w
        clc
        adc kd_len
        adc #1
        sta kd_w
        clc
        rts
.full   sec
        rts

; known_first: Y = the oldest keyword such that it and all newer ones fit (whole words, 2 rows)
!zone known_first
known_first
        ldy #0
.try    sty kd_s
        jsr known_start
.next   cpy known_n
        beq .ok
        sty kd_i
        jsr known_place
        bcs .drop
        ldy kd_i
        iny
        bne .next
.drop   ldy kd_s                ; doesn't fit: leave out one more of the oldest
        iny
        bne .try
.ok     ldy kd_s
        rts

; kw_ptr: zp_src = kw_text + A * 12
kw_ptr
        sta zp_tmp
        lda #0
        sta zp_src+1
        lda zp_tmp              ; *12 = *8 + *4
        asl
        rol zp_src+1
        asl
        rol zp_src+1
        sta zp_src
        ldx zp_src+1
        asl
        rol zp_src+1
        clc
        adc zp_src
        sta zp_src
        txa
        adc zp_src+1
        sta zp_src+1
        lda zp_src
        clc
        adc #<kw_text
        sta zp_src
        lda zp_src+1
        adc #>kw_text
        sta zp_src+1
        rts

; talk_frame: once per frame while talking
!zone talk_frame
talk_frame
!ifdef TYPESCRIPT {
        jsr ts_step
}
        jsr SCNKEY
        jsr GETIN
        cmp #0
        beq +
        jmp talk_key
+       rts

; talk_leave: back to the town, rebuilt from game state
!zone talk_leave
talk_leave
        lda talk_person         ; Voss has named Corwin: leaving ends the game
        cmp #CAST_VOSS
        bne +
        lda asked + CAST_VOSS*4 + (TOPIC_V_CORWIN >> 3)
        and #1 << (TOPIC_V_CORWIN & 7)
        beq +
        jmp the_end
+       sei
        lda #D011_OFF
        sta VIC_CTRL1
        lda #>SCREEN_A
        jsr clear_screen
        lda #>SCREEN_B
        jsr clear_screen
        jsr clear_colram
        lda #0
        sta vis_buf
        lda #>SCREEN_A
        jsr view_draw_full
        jsr status_init
        jsr sprites_restore
        jsr eyes_restore
        lda #<msg_leave
        ldx #>msg_leave
        jsr msg_set
        jsr talk_name
        jsr msg_add
        lda #<msg_dot
        ldx #>msg_dot
        jsr msg_add
        jsr hud_draw
        lda #ACT_NONE
        sta act_pending
        lda #MODE_WALK
        sta game_mode
        lda #<irq_top           ; the walking raster chain again (irq_top restores $D011/16/18)
        sta $0314
        lda #>irq_top
        sta $0315
        lda #IRQ_TOP_LINE
        sta VIC_RASTER
        lda #1
        sta VIC_IRQ
        cli
        rts

; talk_name: X:A (A = lo) = the screen-code name of who is being talked to
talk_name
        ldx talk_people_i
        bmi +
        lda people_name_lo,x
        pha
        lda people_name_hi,x
        tax
        pla
        rts
+       lda #<name_voss
        ldx #>name_voss
        rts
name_voss !scr "voss", 0

; sprites_restore: sprite shapes and pointers after the bitmap overwrote them
!zone sprites_restore
sprites_restore
        ldx #63
-       lda leader_shape,x
        sta SPRITES,x
        lda kid_shape,x
        sta SPRITES + 64,x
        dex
        bpl -
        lda #SPR_LEADER_PTR
        sta SCREEN_A + $3f8
        sta SCREEN_B + $3f8
        ldx #0
        cpx #PEOPLE_N
        beq +
-       lda people_ptr,x
        sta SCREEN_A + $3f8 + 1,x
        sta SCREEN_B + $3f8 + 1,x
        inx
        cpx #PEOPLE_N
        bne -
+       rts

; eyes_setup: the talk person's eye sprites (PORTRAIT_EYES: count, then per sprite x, y,
; colour, 0 and 64 bytes of data; x, y are portrait pixels). Saves the walking screen's sprite
; registers first (eyes_restore puts them back). Sets talk_spren, which talk_irq_top enables.
!zone eyes_setup
eyes_setup
        ldx #16
-       lda VIC_SPR0X,x         ; $D000-$D010: positions and X MSBs
        sta spr_save,x
        dex
        bpl -
        ldx #7
-       lda VIC_SPR0COL,x
        sta spr_save_col,x
        dex
        bpl -
        lda VIC_SPRMC
        sta spr_save_mc
        lda #0
        sta talk_spren
        sta VIC_SPRMSB
        sta VIC_SPRMC
        sta VIC_SPRXEXP
        sta VIC_SPRYEXP
        sta VIC_SPRPRI          ; in front of the bitmap
        lda #<PORTRAIT_EYES     ; loaded with the portrait (count 0 if the load failed)
        sta zp_src
        lda #>PORTRAIT_EYES
        sta zp_src+1
        ldy #0
        lda (zp_src),y
        sta eye_n
        inc zp_src
        bne +
        inc zp_src+1
+       ldx #0
.spr    cpx eye_n
        beq .out
        stx eye_i
        txa
        asl
        tax                     ; X = 2 * sprite
        ldy #0
        lda (zp_src),y
        clc
        adc #24                 ; VIC X of bitmap column 0
        sta VIC_SPR0X,x
        iny
        lda (zp_src),y
        clc
        adc #50                 ; VIC Y of bitmap row 0
        sta VIC_SPR0Y,x
        ldx eye_i
        iny
        lda (zp_src),y
        sta VIC_SPR0COL,x
        txa
        clc
        adc #EYE_SPR_PTR
        sta SCREEN_A + $3f8,x
        lda eye_mem_lo,x
        sta zp_dst
        lda #>EYE_SPR_MEM
        sta zp_dst+1
        lda zp_src              ; skip x, y, colour, pad
        clc
        adc #4
        sta zp_src
        bcc +
        inc zp_src+1
+       ldy #63
-       lda (zp_src),y
        sta (zp_dst),y
        dey
        bpl -
        lda zp_src
        clc
        adc #64
        sta zp_src
        bcc +
        inc zp_src+1
+       lda talk_spren
        ora eye_bit,x
        sta talk_spren
        inx
        bne .spr
.out    rts

; eyes_restore: the walking screen's sprite registers, as eyes_setup found them
!zone eyes_restore
eyes_restore
        ldx #16
-       lda spr_save,x
        sta VIC_SPR0X,x
        dex
        bpl -
        ldx #7
-       lda spr_save_col,x
        sta VIC_SPR0COL,x
        dex
        bpl -
        lda spr_save_mc
        sta VIC_SPRMC
        lda spr_enable
        sta VIC_SPREN
        rts

; ---- raster chain while talking ----
talk_irq_top                    ; line 16: bitmap mode for rows 0-18, only the eye sprites
        lda #D011_BMP
        sta VIC_CTRL1
        lda #D016_STD
        sta VIC_CTRL2
        lda #D018_TALKBMP
        sta VIC_MEM
        lda talk_spren
        sta VIC_SPREN
        lda #<talk_irq_split
        sta $0314
        lda #>talk_irq_split
        sta $0315
        lda #TALK_IRQ_SPLIT
        sta VIC_RASTER
        lda #1
        sta VIC_IRQ
        jmp $ea81

talk_irq_split                  ; line 200: text mode from row 19 (badline 203)
        +wait_line TALK_SPLIT_LINE
        ldy #8                  ; ~40 cycles: past the visible part of line 202 (into the border)
-       dey
        bne -
        lda #D011_TXT
        sta VIC_CTRL1
        lda #D018_B
        sta VIC_MEM
        lda #1
        sta frame_ready
        lda #<talk_irq_top
        sta $0314
        lda #>talk_irq_top
        sta $0315
        lda #TALK_IRQ_TOP
        sta VIC_RASTER
        lda #1
        sta VIC_IRQ
        jmp $ea81

!ifdef TYPESCRIPT {
; ts_step: test hook - type the next character of the script whenever the keyboard buffer is empty,
; 3 frames apart (the script pauses while walking: it only runs from talk_frame)
!zone ts_step
ts_step
        lda KEYBUF_N
        bne .out
        lda ts_wait
        beq +
        dec ts_wait
.out    rts
+       ldy ts_pos
        lda ts_text,y
        beq .out
        sta KEYBUF
        lda #1
        sta KEYBUF_N
        inc ts_pos
        lda #3
        sta ts_wait
        rts
ts_pos  !byte 0
ts_wait !byte 0
ts_text
!if TYPESCRIPT = 1 {            ; tests/test_talk_leave.py: leave at once
        !byte 13
}
!if TYPESCRIPT = 4 {            ; tests/test_talk_text.py: 8 questions, stay
        !pet "water", 13, "pump", 13, "name", 13, "job", 13, "keepers", 13, "reactor", 13, "voss", 13
        !pet "tanks", 13
}
!if TYPESCRIPT = 5 {            ; tests/test_talk_rules.py
        !pet "tanks", 13, "name", 13, "job", 13, "tanks", 13, "wat", 13, "wate", 13, "banana", 13
        !pet "name", 13, "corwin", 13
}
!if TYPESCRIPT = 6 {            ; tests/test_talk_rules.py (KNOWNTEST)
        !pet "name", 13
}
!if TYPESCRIPT = 7 {            ; tests/test_talk_leave.py: ask once, leave
        !pet "name", 13, 13
}
!if TYPESCRIPT = 10 {           ; tests/test_portrait_reu.py: leave the first two talks at once
        !byte 13, 13
}
!if TYPESCRIPT = 9 {            ; tests/test_talk_cast.py: Brandt
        !pet "name", 13, "gate", 13, "voss", 13
}
!if TYPESCRIPT = 11 {           ; tests/test_skills.py: Jory, after Maren's treatment
        !pet "name", 13
}
!if TYPESCRIPT = 12 {           ; tests/test_basement.py: Voss, one question, leave
        !pet "name", 13, 13
}
!if TYPESCRIPT = 13 {           ; tests/test_ending.py: Voss names Corwin, leave
        !pet "corwin", 13, 13
}
!if TYPESCRIPT = 3 {            ; tests/test_talk_input.py: junk, 14 letters, 3 DEL, RETURN, DEL, RETURN
        !pet "12!x", 13, "abcdefghijklmn", 20, 20, 20, 13, 20, 13
}
!if TYPESCRIPT = 8 {            ; tests/test_talk_input.py: junk, then 14 letters (prompt state)
        !pet "12!x", 13, "abcdefghijklmn"
}
        !byte 0
}

; ---- data ----
cast_letter !text "HBTJOPCV"     ; by cast index (tools/make_map.py CAST, then Voss)
face_name   !text "FACE H"       ; the last letter is the cast letter
FACE_NAME_LEN = 6
face_loaded !byte $ff           ; cast index whose face is in PORTRAIT_BUF ($ff: none)
face_cached !byte 0             ; bit per cast index: that face is in the REU
face_disk_loads !byte 0         ; faces read from disk (tests)
reu_present !byte 0
reu_probe   !byte 0
reu_c64     !word 0
reu_off     !word 0
reu_len     !word 0
eye_bit_8   !byte 1, 2, 4, 8, 16, 32, 64, 128
txt_approach !scr "you approach ", 0
txt_dots    !scr "...", 0
eye_mem_lo  !byte 0, 64, 128, 192
eye_bit     !byte 1, 2, 4, 8
eye_n       !byte 0
eye_i       !byte 0
talk_spren  !byte 0
spr_save    !fill 17, 0
spr_save_col !fill 8, 0
spr_save_mc !byte 0
txt_known  !scr "known: ", 0
txt_leads  !scr " leads. ask about:", 0
txt_hint   !scr "return on an empty line: leave          "
msg_leave  !scr "you leave ", 0
msg_dot    !scr ".", 0
talk_people_i !byte 0
talk_person   !byte 0
input_len     !byte 0
input_buf     !fill 12, ' '
kd_col        !byte 0
trust         !fill 8, 0          ; by cast index (Task 5: the rules)
kd_i          !byte 0
kd_w          !byte 0
kd_row        !byte 0
kd_len        !byte 0
kd_s          !byte 0
known_n       !byte 4
known_ids     !byte 0, 1, 2, 3
              !fill 28, 0
