"""Milestone 5: down the hatch to Voss and back up.

With the hatch forced open (KNOW_HATCH), a step onto it takes the squad down to the basement's
arrival cell: the camera is pinned (BCAM_X, BCAM_Y), the screen on show is the basement, the leader
sprite stands on the leader's cell, the status line names the basement and there is no radiation.
In the basement the squad walks with the camera still (the sprite glides), T next to Voss opens his
conversation (cast 7, not a townsperson sprite), and leaving it puts the squad back where it was.
A step onto the stairs takes the squad back up to the yard beside the hatch."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402

WAIT = 10.0
GEN = vice.NL / 'gen'
FULL = (GEN / 'cinderhill.bin').read_bytes() + (GEN / 'cinderhill_below.bin').read_bytes()


def consts(name):
    out = {}
    for ln in (GEN / name).read_text().splitlines():
        k, _, v = ln.partition(' = ')
        if v and ' ' not in k:
            out[k] = int(v[1:], 16) if v.startswith('$') else int(v)
    return out


MAP = consts('cinderhill.inc')


def run(autowalk, extra=None):
    prg = vice.build({'AUTOWALK': autowalk, 'KNOW_HATCH': 1, **(extra or {})})
    lab = vice.labels(prg)
    names = ['leader_x', 'leader_y', 'cam_x', 'cam_y', 'vis_buf', 'game_mode', 'underground', 'talk_person',
             'squad_hp']
    reads = [(WAIT, lab[n], 4 if n == 'squad_hp' else 1) for n in names]
    reads += [(WAIT, 0xc000, 1000), (WAIT, 0xc400, 1000), (WAIT, 0xd000, 17), (WAIT, 0xc000 + 22 * 40, 40)]
    got = vice.memread(prg, lab['met'], 8, wait_s=WAIT, extra_reads=reads)
    st = {n: (got[1 + i][0] if n != 'squad_hp' else list(got[1 + i])) for i, n in enumerate(names)}
    st['met'] = got[0]
    st['scr'] = got[-4] if st['vis_buf'] == 0 else got[-3]
    st['vic'] = got[-2]
    st['msg'] = got[-1]
    return st, lab


def opened_map():
    """The map as the squad leaves it on every route here: gate open, hatch forced."""
    t = consts('tiles.inc')
    m = bytearray(FULL)
    for x, y, code in zip(*(MAP_TABLES[k] for k in ('gate_x', 'gate_y', 'gate_open'))):
        m[y * 64 + x] = code
    m[m.index(bytes([t['T_HATCH']]))] = t['T_HATCH_OPEN']
    return bytes(m)


def tables(name):
    out = {}
    for ln in (GEN / name).read_text().splitlines():
        k, _, v = ln.partition(' !byte ')
        if k.startswith('gate_'):
            out[k] = [int(x) for x in v.split(', ')]
    return out


MAP_TABLES = tables('cinderhill.inc')


def check_view(st, where):
    cx, cy = st['cam_x'], st['cam_y']
    m = opened_map()
    want = bytes(m[(cy + r) * 64 + cx + c] for r in range(18) for c in range(40))
    got = st['scr'][2 * 40:20 * 40]
    vice.check(got == want, f'{where}: the screen on show is the map at camera ({cx},{cy})')
    lx, ly = st['leader_x'], st['leader_y']
    sx = 24 + (lx - cx) * 8 + 4
    sy = 50 + (2 + ly - cy) * 8 - 8 + 4
    vic = st['vic']
    vice.check(vic[0] + 256 * (vic[16] & 1) == sx and vic[1] == sy,
               f'{where}: leader sprite on the leader cell ({vic[0] + 256 * (vic[16] & 1)},{vic[1]} == {sx},{sy})')


def main():
    down, up = (MAP['DOWN_X'], MAP['DOWN_Y']), (MAP['UP_X'], MAP['UP_Y'])
    bcam = (MAP['BCAM_X'], MAP['BCAM_Y'])

    st, _ = run(37)
    vice.check((st['leader_x'], st['leader_y']) == down and st['underground'] == 1,
               f"down the hatch: leader at {(st['leader_x'], st['leader_y'])} == {down}")
    vice.check((st['cam_x'], st['cam_y']) == bcam, f"camera pinned at {(st['cam_x'], st['cam_y'])} == {bcam}")
    check_view(st, 'basement')
    vice.check(st['scr'][13:27] == vice.scr('BASEMENT'.ljust(14)), f"status line: {st['scr'][13:27]!r}")
    vice.check(st['scr'][32:40] == bytes([consts('tiles.inc')['G_METER_OFF']] * 8) and st['squad_hp'] == [32] * 4,
               'no radiation underground, nobody hurt')
    vice.check(st['msg'] == vice.scr('THE SQUAD CLIMBS DOWN INTO THE DARK.'.ljust(40)), f"message: {st['msg']!r}")

    # walk to Voss (15 right, 3 down: the camera stays), T, ask NAME, leave
    st, _ = run(38, {'TYPESCRIPT': 12})
    vice.check((st['cam_x'], st['cam_y']) == bcam and (st['leader_x'], st['leader_y']) == (down[0] + 15, down[1] + 3),
               f"walking underground moves the sprite, not the camera: leader {(st['leader_x'], st['leader_y'])}")
    vice.check(st['met'][7] == 1 and st['talk_person'] == 7 and st['game_mode'] == 0,
               f"talked to Voss and left (met {list(st['met'])}, person {st['talk_person']}, mode {st['game_mode']})")
    check_view(st, 'back from Voss')
    vice.check(st['msg'] == vice.scr('YOU LEAVE VOSS.'.ljust(40)), f"message: {st['msg']!r}")

    st, _ = run(39)
    vice.check((st['leader_x'], st['leader_y']) == up and st['underground'] == 0,
               f"up the stairs: leader at {(st['leader_x'], st['leader_y'])} == {up}")
    vice.check((st['cam_x'], st['cam_y']) == (up[0] - 19, 0), f"town camera clamped at the top: {(st['cam_x'], st['cam_y'])}")
    check_view(st, 'back in the yard')
    vice.check(st['scr'][13:27] == vice.scr('REACTOR YARD'.ljust(14)), f"status line: {st['scr'][13:27]!r}")
    vice.check(st['msg'] == vice.scr('THE SQUAD CLIMBS BACK UP INTO THE YARD.'.ljust(40)), f"message: {st['msg']!r}")


if __name__ == '__main__':
    main()
