"""Milestone 5: the ending. Once Voss has answered CORWIN, leaving his conversation ends the game:
a text screen with the good ending if two or more of the four proofs (CARTS, BARRELS, TRACKS,
TAPPED) are on the Known list, the open ending with fewer, how many the squad found, and THE END.
The game stops there. Leaving Voss without having asked about Corwin doesn't end it.

PROOFS=n seeds the first n proofs into Known (a test hook, like KNOW_HATCH); AUTOWALK 40 also has
Dials find the tap on the way, so 1 seeded + TAPPED = 2 counts the real skill."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'tools'))
import vice  # noqa: E402
import make_dialogue  # noqa: E402

WAIT = 12.0


def screen(kind, found):
    """The ending screen as screen codes, laid out as squad.asm the_end draws it."""
    rows = [' ' * 40] * 25
    lines = make_dialogue.build()['ending'][kind]
    r = make_dialogue.END_TOP
    for ln in lines:
        rows[r] = ('  ' + ln).ljust(40)
        r += 1
    rows[r + 1] = f'  The squad found {found} of the 4 proofs.'.ljust(40)
    rows[22] = 'THE END.'.center(40)
    return b''.join(vice.scr(row) for row in rows)


def run(defines):
    prg = vice.build({'KNOW_HATCH': 1, **defines})
    lab = vice.labels(prg)
    got = vice.memread(prg, lab['game_over'], 1, wait_s=WAIT, extra_reads=[(WAIT, 0xc000, 1000)])
    return prg, got[0][0], got[1]


def main():
    for proofs, kind in ((1, 'open'), (2, 'good')):
        prg, over, scr = run({'AUTOWALK': 38, 'TYPESCRIPT': 13, 'PROOFS': proofs})
        want = screen(kind, proofs)
        bad = [r for r in range(25) if scr[r * 40:r * 40 + 40] != want[r * 40:r * 40 + 40]]
        vice.check(over == 1 and not bad, f'{proofs} proof(s): the {kind} ending (bad rows {bad})')
    shot = vice.screenshot(prg, 5_009_500 + 1600 * vice.CYCLES_PER_FRAME)
    shot.save(vice.BUILD / 'ending.png')
    vice.check(vice.has_ink(shot, (make_dialogue.END_TOP, make_dialogue.END_TOP + 1)) and vice.has_ink(shot, (22, 23)),
               'the ending is on screen')

    prg, over, scr = run({'AUTOWALK': 40, 'TYPESCRIPT': 13, 'PROOFS': 1})
    want = screen('good', 2)
    vice.check(over == 1 and scr == want, 'TAPPED found at the valve counts: 1 seeded + 1 found = the good ending')

    prg, over, _ = run({'AUTOWALK': 38, 'TYPESCRIPT': 12, 'PROOFS': 4})
    vice.check(over == 0, 'leaving Voss without asking about Corwin: no ending')


if __name__ == '__main__':
    main()
