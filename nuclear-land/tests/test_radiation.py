"""M2 Task 6: hot spots drain the whole squad (4 hp per step onto a hot tile, never below 0); a sick
member can't be chosen as leader but a sick leader still walks; Maren recovers on her own after 16
steps away from radiation; Maren heals the squad by 12 and must then rest."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402
from c64render import nearest_index, set_palette  # noqa: E402

LRED, YELLOW = 10, 7


def main():
    set_palette(vice.palette())
    prg = vice.build({'TESTMAP': 1, 'AUTOWALK': 6})
    lab = vice.labels(prg)
    t = 9.0
    rd = [(t, lab[k], n) for k, n in (('hot_steps', 1), ('refusals', 1), ('heals_done', 1), ('squad_hp', 4),
                                       ('leader', 1), ('leader_x', 2))]
    strip, hot, ref, heals, hp, lead, pos = vice.memread(prg, 0xc000 + 20 * 40, 120, wait_s=t, extra_reads=rd)
    vice.check(hot[0] == 8, f'8 steps onto hot tiles: {hot[0]}')
    vice.check(ref[0] == 1, f'choosing sick Maren was refused once: {ref[0]}')
    vice.check(heals[0] == 1, f'Maren healed once (second U: must rest): {heals[0]}')
    vice.check(list(hp) == [12, 12, 16, 12], f'hp after recovery + heal: {list(hp)}')
    vice.check(lead[0] == 2, f'Maren leads: {lead[0]}')
    vice.check(tuple(pos) == (31, 19), f'the sick leader kept walking to (31,19): {tuple(pos)}')
    vice.check(strip[80:120] == vice.scr('MAREN NEEDS TO REST FIRST.'.ljust(40)), f'message: {strip[80:120]!r}')
    b4, b0 = lab['G_BAR4'], lab['G_BAR0']
    vice.check(strip[41:49] == bytes([b4] * 3 + [b0] * 5), 'Vesna 12 hp: 3 full cells')
    vice.check(strip[61:69] == bytes([b4] * 4 + [b0] * 4), 'Maren 16 hp: 4 full cells')

    prg = vice.build({'TESTMAP': 1, 'AUTOWALK': 15})
    lab = vice.labels(prg)
    strip, hp = vice.memread(prg, 0xc000 + 20 * 40, 80, wait_s=6.0, extra_reads=[(6.0, lab['squad_hp'], 4)])
    vice.check(list(hp) == [0, 0, 0, 0], f'8 hot steps from full health: everyone at 0 ({list(hp)})')
    vice.check(all(strip[40 + 10 * m + 1:40 + 10 * m + 9] == vice.scr('SICK    ') for m in range(4)),
               'all four bars read SICK')
    shot = vice.screenshot(prg, 5_000_000 + 400 * vice.CYCLES_PER_FRAME)
    shot.save(vice.BUILD / 'radiation_sick.png')
    x0, y0 = vice.screen_box(shot)

    def name_colour(m):
        cols = [nearest_index(shot.getpixel((x0 + x, y0 + y))) for y in range(168, 176)
                for x in range((10 * m + 1) * 8, (10 * m + 5) * 8)]
        return max({c for c in cols if c}, key=cols.count)
    vice.check(name_colour(0) == YELLOW and all(name_colour(m) == LRED for m in (1, 2, 3)),
               'names: leader yellow, the sick others light red')


if __name__ == '__main__':
    main()
