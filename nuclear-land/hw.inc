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
D018_A      = ((SCREEN_A - VIC_BANK) / $400) << 4 | ((CHARSET - VIC_BANK) / $800) << 1
D018_B      = ((SCREEN_B - VIC_BANK) / $400) << 4 | ((CHARSET - VIC_BANK) / $800) << 1

; ---- walking-screen layout (character rows) ----
ROW_STATUS  = 0
ROW_SPACER1 = 1
ROW_MAP     = 2         ; first map row
MAP_ROWS    = 18        ; rows 2-19
ROW_SPACER2 = 20
ROW_HUD     = 21        ; rows 21-24
VIEW_COLS   = 40

; ---- map ----
MAP_W       = 64
MAP_H       = 48
START_CX    = 10
START_CY    = 10
LEADER_COL  = 19        ; leader's band cell when the camera is free
LEADER_ROW  = 9

; ---- colours ----
COL_BLACK = 0
COL_WHITE = 1
COL_CYAN  = 3
COL_YELLOW = 7
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
