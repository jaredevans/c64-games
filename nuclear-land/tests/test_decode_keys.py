"""Task 3: decode_keys maps raw keyboard-matrix rows to one direction (priority up>down>left>right)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402

UP, DOWN, LEFT, RIGHT, NONE = 0, 1, 2, 3, 0xff
# (case, expected) in the order of the KEYTEST table in input.asm
CASES = [('none', NONE), ('CRSR-down', DOWN), ('LSHIFT+CRSR-down', UP), ('RSHIFT+CRSR-down', UP),
         ('CRSR-right', RIGHT), ('LSHIFT+CRSR-right', LEFT), ('I', UP), ('J', LEFT), ('K', DOWN),
         ('L', RIGHT), ('I+L', UP), ('K+J', DOWN), ('J+L', LEFT), ('CRSR-right+K', DOWN),
         ('SHIFT alone', NONE),
         # VICE host Down+Left and host Up+Right both give SHIFT+CRSR-down+CRSR-right: ambiguous,
         # so keep the previous direction (any of the four could have been pressed), else none
         ('ambiguous, prev none', NONE), ('ambiguous, prev DOWN', DOWN), ('ambiguous, prev LEFT', LEFT),
         ('ambiguous, prev UP', UP), ('ambiguous, prev RIGHT', RIGHT), ('ambiguous LSHIFT, prev DOWN', DOWN),
         ('CRSR-down+CRSR-right (no shift)', DOWN), ('K, prev UP (prev ignored)', DOWN)]


LEAD0, LEAD1, LEAD2, LEAD3, TALK, USE = range(6)
# (case, expected action, expected direction) in the order of the ACTTEST table in input.asm.
# Keys 1/2 = row 7 bits 0/3, 3/4 = row 1 bits 0/3, T = row 2 bit 6, U = row 3 bit 6.
ACT_CASES = [('none', NONE, NONE), ('1', LEAD0, NONE), ('2', LEAD1, NONE), ('3', LEAD2, NONE),
             ('4', LEAD3, NONE), ('T', TALK, NONE), ('U', USE, NONE), ('1+T', LEAD0, NONE),
             ('T+U', TALK, NONE), ('L+U', USE, RIGHT), ('LSHIFT alone', NONE, NONE),
             ('3+LSHIFT+CRSR-down', LEAD2, UP)]


def main():
    prg = vice.build({'TESTMAP': 1, 'KEYTEST': 1})
    lab = vice.labels(prg)
    out = vice.memread(prg, lab['keytest_out'], len(CASES), wait_s=3.0)
    for (name, want), got in zip(CASES, out):
        vice.check(got == want, f'{name:32s} -> {got:#04x} (want {want:#04x})')
    n = len(ACT_CASES)
    acts, dirs = vice.memread(prg, lab['acttest_act'], n, wait_s=3.0, extra_reads=[(3.0, lab['acttest_dir'], n)])
    for (name, want_a, want_d), a, d in zip(ACT_CASES, acts, dirs):
        vice.check((a, d) == (want_a, want_d), f'action {name:22s} -> {a:#04x}, dir {d:#04x}')


if __name__ == '__main__':
    main()
