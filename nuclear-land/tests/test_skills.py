"""Milestone 5: the squad's skills at the skill spots (U with the right leader in the right place).

- Rook on the cart tracks outside the back fence: TRACKS joins Known (once, however often U is used).
- Vesna next to Brandt: the gate opens (map and the screen on show, colours too), Brandt is met at
  Open, and the squad can walk through. U again: the gate already stands open.
- Dials beside the valve behind the dome: TAPPED joins Known (once).
- Dials beside the hatch: without HATCH known, nothing to fix; with it (KNOW_HATCH seeds the word),
  the hatch is forced open on the map and the screen. U again: it stands open.
- Maren next to Jory: the fever is treated, Jory is at Open (the M4 lock is lifted) and answers;
  Maren's squad treatment is untouched, and U next to a treated Jory treats the squad as before.
Each script ends idle, so the state read after it is settled."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'tools'))
import vice  # noqa: E402
import make_dialogue  # noqa: E402
from c64render import set_palette  # noqa: E402

MSG = 0xc000 + 22 * 40          # the squad strip's message line (same in both buffers)
WAIT = 9.0
KW = make_dialogue.parse_all()[1]
T_ADDR = {}


def line(text):
    return vice.scr(text.upper().ljust(40))


def run(autowalk, reads, extra=None):
    """Build with AUTOWALK (+ extra defines), read the message line and the named labels/addresses."""
    d = {'AUTOWALK': autowalk, **(extra or {})}
    prg = vice.build(d)
    lab = vice.labels(prg)
    plan = [(WAIT, lab[n] + off if isinstance(n, str) else n, ln) for n, off, ln in reads]
    got = vice.memread(prg, MSG, 40, wait_s=WAIT, extra_reads=plan)
    if not plan:                # (memread returns bare bytes when there are no extra reads)
        got = [got]
    return prg, lab, got[0], got[1:]


def tiles():
    out = {}
    for ln in (vice.NL / 'gen' / 'tiles.inc').read_text().splitlines():
        k, _, v = ln.partition(' = ')
        if v.startswith('$'):
            out[k] = int(v[1:], 16)
    return out


def main():
    set_palette(vice.palette())
    t = tiles()
    gate = [(31, 13), (32, 13), (33, 13)]
    hatch, valve = (34, 4), (31, 4)

    # Rook: to the tracks at (44,19), Rook leads, U twice
    prg, lab, msg, (kn, kids) = run(29, [('known_n', 0, 1), ('known_ids', 0, 32)])
    vice.check(msg == line('rook: cart tracks lead to the storehouse'), f'Rook on the tracks: {msg!r}')
    ids = list(kids[:kn[0]])
    vice.check(ids.count(KW.index('TRACKS')) == 1 and kn[0] == 5, f'TRACKS joins Known once ({kn[0]} known)')
    shot = vice.screenshot(prg, 5_009_500 + 700 * vice.CYCLES_PER_FRAME)
    shot.save(vice.BUILD / 'skill_rook.png')
    x0, y0 = vice.screen_box(shot)
    ink = sum(1 for x in range(39 * 8, 40 * 8) for y in range(22 * 8, 24 * 8) if   # (the strip shows lower)
               shot.getpixel((x0 + x, y0 + y)) != (0, 0, 0))
    vice.check(ink > 0, f'the 40th letter of the message shows on screen ({ink} px)')

    # Vesna: up to Brandt, bump the shut gate, U, walk through to (32,12)
    _, lab, msg, (ly, bumps, tr, met, gopen, gmap) = run(30, [
        ('leader_y', 0, 1), ('bumps', 0, 1), ('trust', 1, 1), ('met', 1, 1), ('gate_opened', 0, 1),
        ('map_data', 13 * 64 + 31, 3)])
    vice.check(msg == line('vesna talks brandt into opening up.'), f'Vesna next to Brandt: {msg!r}')
    vice.check(bumps[0] > 0 and ly[0] == 12, f'the shut gate blocked ({bumps[0]} bumps), the open one lets the squad in (y {ly[0]})')
    vice.check(tr[0] == 2 and met[0] == 1, f'Brandt met, at Open (trust {tr[0]}, met {met[0]})')
    vice.check(gopen[0] == 1 and list(gmap) == [t['T_ROAD'], t['T_ROAD_LANE_V'], t['T_ROAD']],
               f'gate cells are road on the map: {list(gmap)}')

    # Vesna: U, U without walking - the screen on show and colour RAM were patched; U again
    _, lab, msg, (vb, cx, cy, sa, sb, col, cols) = run(31, [
        ('vis_buf', 0, 1), ('cam_x', 0, 1), ('cam_y', 0, 1), (0xc000, 0, 1000), (0xc400, 0, 1000),
        (0xd800, 0, 1000), ('tilecolors', 0, 256)])
    vice.check(msg == line('the gate stands open.'), f'U again: {msg!r}')
    scr = sa if vb[0] == 0 else sb
    offs = [(2 + y - cy[0]) * 40 + x - cx[0] for x, y in gate]
    want = [t['T_ROAD'], t['T_ROAD_LANE_V'], t['T_ROAD']]
    vice.check([scr[o] for o in offs] == want, f'open gate on the screen on show: {[scr[o] for o in offs]}')
    vice.check([col[o] & 15 for o in offs] == [cols[c] for c in want], 'and in colour RAM')

    # Dials at the valve: through the gate, Dials leads, (30,4), U twice
    _, lab, msg, (kn, kids) = run(32, [('known_n', 0, 1), ('known_ids', 0, 32)])
    vice.check(msg == line('dials: someone tapped the coolant line!'), f'Dials at the valve: {msg!r}')
    ids = list(kids[:kn[0]])
    vice.check(ids.count(KW.index('TAPPED')) == 1 and kn[0] == 5, f'TAPPED joins Known once ({kn[0]} known)')

    # Dials at the hatch (35,4): HATCH unknown, then known
    _, lab, msg, (hm,) = run(33, [('map_data', hatch[1] * 64 + hatch[0], 1)])
    vice.check(msg == line('dials finds nothing to fix.') and hm[0] == t['T_HATCH'],
               f'HATCH not known: {msg!r}, hatch shut ({hm[0]:#04x})')
    _, lab, msg, (hm, hopen, vb, cx, cy, sa, sb, vm) = run(33, [
        ('map_data', hatch[1] * 64 + hatch[0], 1), ('hatch_opened', 0, 1), ('vis_buf', 0, 1),
        ('cam_x', 0, 1), ('cam_y', 0, 1), (0xc000, 0, 1000), (0xc400, 0, 1000),
        ('map_data', valve[1] * 64 + valve[0], 1)], {'KNOW_HATCH': 1})
    vice.check(msg == line('dials forces the hatch. stairs go down.'), f'HATCH known: {msg!r}')
    scr = sa if vb[0] == 0 else sb
    o = (2 + hatch[1] - cy[0]) * 40 + hatch[0] - cx[0]
    vice.check(hm[0] == t['T_HATCH_OPEN'] and hopen[0] == 1 and scr[o] == t['T_HATCH_OPEN'],
               f'hatch open on the map ({hm[0]:#04x}) and on screen ({scr[o]:#04x})')
    vice.check(vm[0] == t['T_VALVE'], 'the valve is untouched')
    _, lab, msg, _ = run(34, [], {'KNOW_HATCH': 1})
    vice.check(msg == line('the hatch stands open.'), f'U again at the hatch: {msg!r}')

    # Maren next to Jory (at (5,39)): U treats Jory, not the squad
    _, lab, msg, (heals, tr, met, jt) = run(36, [('heals_done', 0, 1), ('trust', 3, 1), ('met', 3, 1), ('jory_treated', 0, 1)])
    vice.check(msg == line("maren treats jory's fever."), f'Maren next to Jory: {msg!r}')
    vice.check(heals[0] == 0 and tr[0] == 2 and met[0] == 1 and jt[0] == 1,
               f'Jory at Open (trust {tr[0]}, met {met[0]}), squad not treated (heals {heals[0]})')
    # ...U again treats the squad; then T and NAME: Jory answers (trust 2 +1 +1 favoured, capped 3)
    _, lab, msg, (heals, tr, mode, who, asked) = run(35, [
        ('heals_done', 0, 1), ('trust', 3, 1), ('game_mode', 0, 1), ('talk_person', 0, 1), ('asked', 3 * 4, 4)],
        {'TYPESCRIPT': 11})
    vice.check(heals[0] == 1, f'U again next to a treated Jory treats the squad (heals {heals[0]})')
    vice.check(mode[0] == 1 and who[0] == 3 and asked[0] & 1 and tr[0] == 3,
               f'talking to Jory: NAME answered (asked {asked[0]:#04x}), trust {tr[0]}')


if __name__ == '__main__':
    main()
