"""M3 Task 5: the keyword parser, trust tiers and the Known list agree with the rules model
(tests/talksim.py) for each leader; Review Focus 5: an overfull Known list shows the newest keywords
that fit on its two rows, whole words only, and leaves the next row alone."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'tools'))
import vice  # noqa: E402
import talkview  # noqa: E402
import make_dialogue  # noqa: E402
from talksim import Talk, VESNA, DIALS, MAREN  # noqa: E402

WORDS = 'tanks name job tanks wat wate banana name corwin'.split()     # TYPESCRIPT 5


def run(autowalk, leader):
    prg = vice.build({'AUTOWALK': autowalk, 'TYPESCRIPT': 5})
    lab = vice.labels(prg)
    t = 9.0
    trust, kn, kids, conv, cn = vice.memread(prg, lab['trust'], 1, wait_s=t, extra_reads=[
        (t, lab['known_n'], 1), (t, lab['known_ids'], 32), (t, lab['conv_text'], 15 * 24), (t, lab['conv_n'], 1)])
    m = Talk('h')
    lines = list(m.enter(leader))
    trust_after_meet = m.trust
    for w in WORDS:
        lines += ['> ' + w.upper()] + m.ask(w, leader)
    got = [talkview.text(conv[i * 24:i * 24 + 24]) for i in range(cn[0])]
    want = lines[-15:]
    name = ['Vesna', 'Dials', 'Maren', 'Rook'][leader]
    vice.check(trust[0] == m.trust, f'{name}: trust {trust[0]} == model {m.trust}')
    vice.check(list(kids[:kn[0]]) == m.known, f'{name}: Known ids {list(kids[:kn[0]])} == model {m.known}')
    vice.check(got == want, f'{name}: conversation matches the model ({got[-3:]})')
    return m, trust_after_meet, lines


def main():
    d = make_dialogue.parse_all()[0]['h']
    m, start, lines = run(18, DIALS)
    vice.check(start == 0 and d['topics']['TANKS']['else'][0] in lines, 'Dials: starts Wary, first TANKS deflected')
    m, start, _ = run(19, MAREN)
    vice.check(m.trust == 3, 'Maren (favoured): trust reaches Friendly')
    m, start, _ = run(20, VESNA)
    vice.check(start == 1, 'Vesna at the first meeting: starts Guarded')

    # Review Focus 5: 30 known keywords (KNOWNTEST preloads them) - only the newest that fit show
    prg = vice.build({'AUTOWALK': 18, 'TYPESCRIPT': 6, 'KNOWNTEST': 1})
    lab = vice.labels(prg)
    rows, kn, kids = vice.memread(prg, 0xc400 + 19 * 40, 120, wait_s=8.0, extra_reads=[
        (8.0, lab['known_n'], 1), (8.0, lab['known_ids'], 32)])
    words = [make_dialogue.parse_all()[1][i] for i in kids[:kn[0]]]
    shown, width = [], len('KNOWN: ')
    for w in reversed(words):
        if width + len(w) > 80:
            break
        shown.insert(0, w)
        width += len(w) + 1
    want = vice.scr(('KNOWN: ' + ' '.join(shown)).ljust(80))
    vice.check(kn[0] >= 20 and rows[:80] == want, f'Known rows hold the newest {len(shown)} of {kn[0]}: {rows[:80]!r}')
    vice.check(rows[80:120].startswith(vice.scr('DIALS LEADS. ASK ABOUT:')), 'the row below is untouched')


if __name__ == '__main__':
    main()
