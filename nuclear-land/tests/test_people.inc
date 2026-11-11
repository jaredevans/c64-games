; Three standing test people for the test map (-DTESTMAP=1 -DTEST_PEOPLE=1), off every AUTOWALK route.
; P1 stands right of the wall block x32-36 y12-16 (tests/test_people_glue.py); P2/P3 cross the map
; window's top/bottom edges during AUTOWALK=9 (tests/test_people_window.py).
PEOPLE_N = 3
people_x0  !byte 37, 45, 39
people_y0  !byte 14, 12, 28
people_col !byte 3, 10, 5       ; cyan, light red, green
people_ptr !byte SPR_ADULT_PTR, SPR_ADULT_PTR, SPR_ADULT_PTR
people_cast !byte $ff, $ff, $ff ; nobody has dialogue
people_bx0 !byte $ff, $ff, $ff  ; nobody wanders
people_by0 !byte 0, 0, 0
people_bx1 !byte 0, 0, 0
people_by1 !byte 0, 0, 0
people_name_lo !byte <people_name_0, <people_name_1, <people_name_2
people_name_hi !byte >people_name_0, >people_name_1, >people_name_2
people_name_0 !scr "person a", 0
people_name_1 !scr "person b", 0
people_name_2 !scr "person c", 0
