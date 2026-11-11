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


def main():
    prg = vice.build({'TESTMAP': 1, 'KEYTEST': 1})
    lab = vice.labels(prg)
    out = vice.memread(prg, lab['keytest_out'], len(CASES), wait_s=3.0)
    for (name, want), got in zip(CASES, out):
        vice.check(got == want, f'{name:32s} -> {got:#04x} (want {want:#04x})')


if __name__ == '__main__':
    main()
