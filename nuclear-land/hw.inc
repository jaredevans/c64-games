; Nuclear Land - hardware registers and memory map

; ---- VIC-II ----
VIC_SPR0X   = $d000
VIC_SPR0Y   = $d001
VIC_SPRMSB  = $d010
VIC_CTRL1   = $d011     ; bits0-2 YSCROLL, bit3 RSEL, bit4 DEN, bit5 BMM, bit7 raster bit8
VIC_RASTER  = $d012
VIC_SPREN   = $d015
VIC_CTRL2   = $d016     ; bits0-2 XSCROLL, bit3 CSEL, bit4 MCM
VIC_MEM     = $d018
VIC_IRQ     = $d019
VIC_IRQEN   = $d01a
VIC_SPRMC   = $d01c
VIC_BORDER  = $d020
VIC_BG0     = $d021
VIC_SPR0COL = $d027
COLRAM      = $d800

; ---- CIA ----
CIA1_PRA    = $dc00     ; keyboard column select (write)
CIA1_PRB    = $dc01     ; keyboard row read
CIA1_ICR    = $dc0d
CIA2_PRA    = $dd00     ; bits0-1 VIC bank (inverted)

; ---- memory map (VIC bank 3) ----
VIC_BANK    = $c000
SCREEN_A    = $c000
SCREEN_B    = $c400
CHARSET     = $c800
SPRITES     = $e000
SPR_LEADER_PTR = (SPRITES - VIC_BANK) / 64          ; 128
SPR_ADULT_PTR  = SPR_LEADER_PTR                     ; townspeople use the leader's figure...
SPR_KID_PTR    = SPR_LEADER_PTR + 1                 ; ...except Pip
D018_A      = ((SCREEN_A - VIC_BANK) / $400) << 4 | ((CHARSET - VIC_BANK) / $800) << 1
D018_B      = ((SCREEN_B - VIC_BANK) / $400) << 4 | ((CHARSET - VIC_BANK) / $800) << 1

; ---- walking-screen layout (character rows) ----
ROW_STATUS  = 0
ROW_SPACER1 = 1
ROW_MAP     = 2         ; first map row
MAP_ROWS    = 18        ; rows 2-19
ROW_HUD     = 20        ; screen rows 20-23, displayed on raster 219-250 (after the FLD gap)
VIEW_COLS   = 40

; ---- map ----
MAP_W       = 64
MAP_H       = 48
LEADER_COL  = 19        ; leader's band cell when the camera is free
LEADER_ROW  = 9

; ---- colours ----
COL_BLACK = 0
COL_WHITE = 1
COL_CYAN  = 3
COL_YELLOW = 7
COL_LRED  = 10
COL_DGREY = 11
COL_LGREY = 15

; ---- zero page ----
cam_x       = $02
cam_y       = $03
zp_src      = $04       ; 2 bytes
zp_dst      = $06       ; 2 bytes
zp_col      = $08       ; 2 bytes
zp_tmp      = $0a
zp_row      = $0b
fine_x      = $0c       ; map-band XSCROLL 0..7
fine_y      = $0d       ; map-band pixel offset 0..7 (see irq.asm)
vis_buf     = $0e       ; 0 = SCREEN_A shown, 1 = SCREEN_B
frame_ready = $0f       ; set by IRQ_HUD each frame
frame_count = $10       ; 2 bytes
kb_row0     = $12       ; raw keyboard matrix rows (active low): CRSR keys
kb_row1     = $13       ; LSHIFT
kb_row4     = $14       ; I J K
kb_row5     = $15       ; L
kb_row6     = $16       ; RSHIFT
cur_dir     = $17       ; decoded direction this frame (DIR_* or DIR_NONE)
leader_x    = $18       ; leader's map cell
leader_y    = $19
glide_dir   = $1a       ; DIR_* while gliding, DIR_NONE when idle
glide_p     = $1b       ; pixel of the current glide, 1..GLIDE_FRAMES
bcam_x      = $1c       ; camera the back buffer is being built for
bcam_y      = $1d
steps_done  = $1e       ; 2 bytes (tests)
bumps       = $20       ; blocked step attempts (tests)
view_page   = $21       ; screen page (hi byte) view_build writes to
view_colhi  = $22       ; colour destination hi byte: >COLRAM or >COLBUF
view_cx     = $23       ; camera view_build reads from
view_cy     = $24
view_row    = $25       ; first view row to build
view_end    = $26       ; one past the last view row
script_ptr  = $27       ; 2 bytes (AUTOWALK)
script_left = $29       ; frames left in the current script entry
glide_spr   = $2a       ; 1 = this glide moves the sprite (camera clamped), 0 = scrolls the map
spr_x       = $2b       ; 2 bytes: leader sprite X (VIC coordinates)
spr_y       = $2d       ; leader sprite Y
spr_off_x   = $2e       ; leader's cell offset from the view centre (signed), updated per step
spr_off_y   = $2f
pp_i        = $30       ; people.asm scratch
pp_dir      = $31
pp_dx       = $32
pp_hi       = $33
pp_msb      = $34
pp_bit      = $35
spr_enable  = $36       ; $D015 shadow (bit 0 = leader, bits 1-7 = people)
lfsr        = $37       ; people_update's random source
heavy_job   = $38       ; walk_heavy's job this frame (HEAVY_*)

; ---- directions ----
DIR_UP    = 0
DIR_DOWN  = 1
DIR_LEFT  = 2
DIR_RIGHT = 3
DIR_NONE  = $ff

COLBUF      = $b800     ; 1 KB colour staging buffer, same layout as colour RAM
