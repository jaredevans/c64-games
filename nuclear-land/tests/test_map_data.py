"""M2 Task 1: generated map data obeys the spec's rules (pure Python, no VICE).

Both maps: 2-row blocked top/bottom border, radiation field = max(0, 8 - 2*chebyshev distance to the
nearest hot tile), an unclamped start, hot tiles never cut off any reachable cell (gate shut or open),
every reachable cell has a place name, the charset budget holds. Cinderhill: the seven townspeople in
sprite order, each reachable without crossing a hot tile, Pip's wander box, hot-spot clusters, the
reactor dome. Test map: the M1 layout plus two hot tiles and no people."""
import json
import sys
from collections import deque
from pathlib import Path

NL = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(NL / 'tools'))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_map  # noqa: E402
from vice import check  # noqa: E402

W, H = 64, 48


def inc_consts(path):
    out = {}
    for line in path.read_text().splitlines():
        if '=' in line and not line.lstrip().startswith(';'):
            k, v = (s.strip() for s in line.split('=', 1))
            out[k] = int(v.lstrip('$'), 16) if v.startswith('$') else int(v)
    return out


def check_map(name):
    meta = make_map.convert(name)
    gen = NL / 'gen'
    tiles = inc_consts(gen / 'tiles.inc')
    bb = tiles['BLOCK_BASE']
    mp = (gen / f'{name}.bin').read_bytes()
    rad = (gen / f'{name}_rad.bin').read_bytes()
    js = json.loads((gen / f'{name}.json').read_text())
    check(js == json.loads(json.dumps(meta)), f'{name}: json matches convert() result')
    check(len(mp) == W * H and len(rad) == W * H, f'{name}: 64x48 map and radiation field')

    gate = {tiles[k] for k in tiles if k.startswith('T_GATE')}

    def code(x, y):
        return mp[y * W + x]

    def blocked(x, y, gate_open=False):
        c = code(x, y)
        return c >= bb and not (gate_open and c in gate)

    hot = {tuple(h) for h in meta['hot']}
    border = [(x, y) for y in range(H) for x in range(W) if x in (0, W - 1) or y in (0, 1, H - 2, H - 1)]
    check(all(blocked(x, y) for x, y in border), f'{name}: border (cols 0/63, rows 0,1,46,47) all blocked')
    check(all(not blocked(x, y) for x, y in hot), f'{name}: hot tiles are passable')

    def cheb(a, b):
        return max(abs(a[0] - b[0]), abs(a[1] - b[1]))
    want = [max(0, 8 - 2 * min((cheb((x, y), h) for h in hot), default=99)) for y in range(H) for x in range(W)]
    check(list(rad) == want, f'{name}: radiation field = max(0, 8 - 2*chebyshev distance)')

    sx, sy = meta['start']
    check(not blocked(sx, sy) and 19 <= sx <= 44 and 9 <= sy <= 39, f'{name}: start {sx},{sy} passable, camera unclamped')

    people = meta['people']
    pcells = {(p['x'], p['y']) for p in people}

    def reach(avoid_hot=False, gate_open=False):
        seen = {(sx, sy)}
        q = deque(seen)
        while q:
            x, y = q.popleft()
            for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
                n = (x + dx, y + dy)
                if n in seen or blocked(*n, gate_open=gate_open) or n in pcells or (avoid_hot and n in hot):
                    continue
                seen.add(n)
                q.append(n)
        return seen

    for g in (False, True):
        check(reach(True, g) == reach(False, g) - hot,
              f'{name}: hot tiles never cut anything off (gate {"open" if g else "shut"})')

    def place_of(c):
        for p in meta['places']:
            r = p['rect']
            if r is None or (r[0] <= c[0] <= r[2] and r[1] <= c[1] <= r[3]):
                return p['name']
        return None
    check(meta['places'][-1]['rect'] is None, f'{name}: last place is the default')
    check(all(place_of(c) for c in reach(gate_open=True)), f'{name}: every reachable cell has a place name')
    check(all(len(p['name']) <= 14 for p in meta['places']), f'{name}: place names <= 14 chars')
    check(tiles['TILE_LAST'] <= 0xff and meta['n_passable'] <= 64 and meta['n_blocked'] <= 128,
          f'{name}: charset budget (last ${tiles["TILE_LAST"]:02x}, {meta["n_passable"]} passable, '
          f'{meta["n_blocked"]} blocked)')
    for g in ('G_BAR0', 'G_BAR1', 'G_BAR2', 'G_BAR3', 'G_BAR4', 'G_METER_OFF', 'G_METER_ON'):
        check(g in tiles, f'{name}: UI glyph {g} exported')
    return meta, mp, hot, reach, blocked, tiles


def main():
    meta, mp, hot, reach, blocked, tiles = check_map('cinderhill')
    people = meta['people']
    check([p['letter'] for p in people] == list('hbtjopc'), 'cinderhill: seven townspeople in sprite order')
    safe = reach(avoid_hot=True)
    start = tuple(meta['start'])
    for p in people:
        c = (p['x'], p['y'])
        nb = [(c[0] + d[0], c[1] + d[1]) for d in ((0, -1), (0, 1), (-1, 0), (1, 0))]
        check(not blocked(*c) and c not in hot and c != start and any(n in safe for n in nb),
              f'cinderhill: {p["name"]} at {c} reachable without crossing a hot spot')
    check(len({(p['x'], p['y']) for p in people}) == 7, 'cinderhill: townspeople on distinct cells')
    pip = people[5]
    bx0, by0, bx1, by1 = pip['box']
    free = [(x, y) for y in range(by0, by1 + 1) for x in range(bx0, bx1 + 1) if not blocked(x, y) and (x, y) not in hot]
    check(bx0 <= pip['x'] <= bx1 and by0 <= pip['y'] <= by1 and len(free) >= 12,
          f'cinderhill: Pip inside his wander box ({len(free)} free cells)')
    check(all(p['box'] is None for i, p in enumerate(people) if i != 5), 'cinderhill: only Pip wanders')

    def clusters(cells):
        cells, n = set(cells), 0
        while cells:
            n += 1
            q = [cells.pop()]
            while q:
                x, y = q.pop()
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        if (x + dx, y + dy) in cells:
                            cells.remove((x + dx, y + dy))
                            q.append((x + dx, y + dy))
        return n
    near = min(max(abs(h[0] - start[0]), abs(h[1] - start[1])) for h in hot)
    check(12 <= len(hot) <= 30 and clusters(hot) >= 3 and near >= 6,
          f'cinderhill: {len(hot)} hot tiles in {clusters(hot)} clusters, nearest {near} cells from the start')
    dome = sorted((i % 64, i // 64) for i, c in enumerate(mp) if f'T_DOME_00' in tiles and
                  tiles['T_DOME_00'] <= c <= tiles['T_DOME_35'])
    xs, ys = {d[0] for d in dome}, {d[1] for d in dome}
    check(len(dome) == 24 and len(xs) == 6 and len(ys) == 4 and max(xs) - min(xs) == 5 and max(ys) - min(ys) == 3,
          'cinderhill: reactor dome is one 6x4 picture')
    x0, y0 = min(xs), min(ys)
    check(all(mp[(y0 + r) * 64 + x0 + c] == tiles[f'T_DOME_{r}{c}'] for r in range(4) for c in range(6)),
          'cinderhill: dome cells in picture order')

    # M5 skill spots. Dials's valve and hatch are behind the dome, inside the compound: reachable
    # only through the open gate, each with a free side, and no cell is beside both (U there would be
    # ambiguous). Rook's cart tracks are outside the back fence, reachable with the gate shut.
    shut, opened = reach(), reach(gate_open=True)

    def cells(t):
        return [(i % 64, i // 64) for i, c in enumerate(mp) if c == tiles[t]]

    def sides(c):
        return [(c[0] + d[0], c[1] + d[1]) for d in ((0, -1), (0, 1), (-1, 0), (1, 0))]
    valve, hatch, ruts = cells('T_VALVE'), cells('T_HATCH'), cells('T_RUTS_H') + cells('T_RUTS_V')
    check(len(valve) == 1 and len(hatch) == 1, f'cinderhill: one valve {valve}, one hatch {hatch}')
    for what, c in (('valve', valve[0]), ('hatch', hatch[0])):
        check(blocked(*c) and not any(n in shut for n in sides(c)) and any(n in opened for n in sides(c)),
              f'cinderhill: the {what} at {c} is blocked and reachable only through the open gate')
    check(not set(sides(valve[0])) & set(sides(hatch[0])), 'cinderhill: no cell is beside both valve and hatch')
    check(len(ruts) >= 8 and all(not blocked(*c) and c in shut for c in ruts),
          f'cinderhill: {len(ruts)} cart-track cells, all passable and reachable with the gate shut')
    check(valve[0][1] - 1 == min(y for _, y in ruts) + 1, 'cinderhill: the tracks run just outside the back fence')
    mi = inc_consts(NL / 'gen' / 'cinderhill.inc')
    gates = cells('T_GATE')
    check(mi['GATE_N'] == len(gates) == 3, f'cinderhill: GATE_N = {mi["GATE_N"]} gate cells')
    gtext = (NL / 'gen' / 'cinderhill.inc').read_text()
    want_x = 'gate_x !byte ' + ', '.join(str(x) for x, _ in gates)
    want_y = 'gate_y !byte ' + ', '.join(str(y) for _, y in gates)
    want_t = 'gate_open !byte ' + ', '.join(str(mp[(y + 1) * 64 + x]) for x, y in gates)
    check(want_x in gtext and want_y in gtext and want_t in gtext and
          all(mp[(y + 1) * 64 + x] < tiles['BLOCK_BASE'] for x, y in gates),
          'cinderhill: gate table - each gate cell opens to the passable tile below it')
    brandt = next(p for p in people if p['letter'] == 'b')
    check(any(n in shut for n in sides((brandt['x'], brandt['y']))), 'cinderhill: Brandt has a free side outside the gate')

    meta, mp, hot, *_ = check_map('testmap')
    check(inc_consts(NL / 'gen' / 'testmap.inc')['GATE_N'] == 0, 'testmap: no gate (GATE_N = 0)')
    check(hot == {(10, 21), (11, 21)} and tuple(meta['start']) == (29, 19) and meta['people'] == [],
          'testmap: hot tiles (10,21),(11,21), start (29,19), nobody else')


if __name__ == '__main__':
    main()
