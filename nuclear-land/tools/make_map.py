"""maps/<name>.txt -> gen/<name>.bin, <name>_rad.bin, <name>.inc, <name>_people.inc, <name>.json.

Map file: 48 grid rows of 64 legend chars, then meta lines:
  start X Y                     leader's start cell (camera must not be clamped there)
  place X0 Y0 X1 Y1 NAME        inclusive rect; first match wins
  place * NAME                  default place (last)
  person LETTER X Y             a townsperson (LETTER from CAST; sprite order = CAST order)
  wander LETTER X0 Y0 X1 Y1     that person wanders inside this inclusive box
Legend: see LEGEND. '.' ground and '^' hot spot pick a variant by position; '@' cells form one
6x4 rectangle that becomes the reactor dome."""
import json
import sys
from pathlib import Path

NL = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(NL / 'tools'))
import make_tiles  # noqa: E402

W, H = 64, 48
LEADER_COL, LEADER_ROW = 19, 9
CAM_MAX_X, CAM_MAX_Y = W - 40 + 1, H - 18
LEGEND = {
    '=': 'ROAD', '-': 'ROAD_LANE_H', '|': 'ROAD_LANE_V', '%': 'ROAD_CRACK',
    ':': 'RUBBLE', '#': 'WALL', 'C': 'CONCRETE', 'W': 'WINDOW', 'D': 'DOOR',
    'R': 'ROOF', 'E': 'ROOF_EDGE', 'F': 'FENCE_H', 'V': 'FENCE_V', '+': 'POST', 'G': 'GATE',
    '!': 'SIGN', 'o': 'BARREL', 'g': 'GLASS', '*': 'PLANTS', '[': 'CAR_L', ']': 'CAR_R',
    'P': 'PUMP', 'S': 'STALL', 'T': 'TENT', 'K': 'CART',
}
# letter: (name, colour, shape)
CAST = {
    'h': ('HESPER', 3, 'adult'), 'b': ('WARDEN BRANDT', 10, 'adult'), 't': ('TAMSIN', 5, 'adult'),
    'j': ('JORY', 9, 'adult'), 'o': ('ODALYS', 4, 'adult'), 'p': ('PIP', 7, 'kid'),
    'c': ('MAYOR CORWIN', 15, 'adult'),
}
SHAPE_PTR = {'adult': 'SPR_ADULT_PTR', 'kid': 'SPR_KID_PTR'}


def parse(name):
    lines = (NL / 'maps' / f'{name}.txt').read_text().splitlines()
    grid = lines[:H]
    assert len(grid) == H, f'{name}: {len(grid)} grid rows, want {H}'
    for y, line in enumerate(grid):
        assert len(line) == W, f'{name} row {y}: {len(line)} cols, want {W}'
    meta = {'start': None, 'places': [], 'people': {}, 'wander': {}}
    for line in lines[H:]:
        f = line.split()
        if not f or f[0].startswith(';'):
            continue
        if f[0] == 'start':
            meta['start'] = [int(f[1]), int(f[2])]
        elif f[0] == 'place' and f[1] == '*':
            meta['places'].append({'name': ' '.join(f[2:]), 'rect': None})
        elif f[0] == 'place':
            meta['places'].append({'name': ' '.join(f[5:]), 'rect': [int(v) for v in f[1:5]]})
        elif f[0] == 'person':
            meta['people'][f[1]] = (int(f[2]), int(f[3]))
        elif f[0] == 'wander':
            meta['wander'][f[1]] = [int(v) for v in f[2:6]]
        else:
            raise ValueError(f'{name}: unknown meta line {line!r}')
    return grid, meta


def convert(name):
    codes = make_tiles.main()
    grid, m = parse(name)
    out = bytearray()
    hot = []
    dome = [(x, y) for y, line in enumerate(grid) for x, ch in enumerate(line) if ch == '@']
    dx0 = dy0 = 0
    if dome:
        dx0, dy0 = min(d[0] for d in dome), min(d[1] for d in dome)
        assert sorted(dome) == sorted((dx0 + c, dy0 + r) for r in range(4) for c in range(6)), \
            f'{name}: @ cells must form one 6x4 rectangle'
    for y, line in enumerate(grid):
        for x, ch in enumerate(line):
            if ch == '.':
                out.append(codes[f'GROUND{(x * 7 + y * 13) % 3}'])
            elif ch == '^':
                out.append(codes[f'HOT{(x + y) % 2}'])
                hot.append([x, y])
            elif ch == '@':
                out.append(codes[f'DOME_{y - dy0}{x - dx0}'])
            elif ch in LEGEND:
                out.append(codes[LEGEND[ch]])
            else:
                raise ValueError(f'{name} ({x},{y}): unknown {ch!r}')
    bb = make_tiles.BLOCK_BASE
    sx, sy = m['start']
    assert out[sy * W + sx] < bb, f'{name}: start {sx},{sy} is blocked'
    assert 0 <= sx - LEADER_COL <= CAM_MAX_X and 0 <= sy - LEADER_ROW <= CAM_MAX_Y, \
        f'{name}: start {sx},{sy} would clamp the camera'
    assert m['places'] and m['places'][-1]['rect'] is None, f'{name}: last place must be "place * NAME"'
    assert all(len(p['name']) <= 14 for p in m['places']), f'{name}: place name > 14 chars'
    assert len(m['people']) <= 7, f'{name}: more than 7 people'
    people = []
    for letter in CAST:
        if letter in m['people']:
            pname, col, shape = CAST[letter]
            x, y = m['people'][letter]
            assert out[y * W + x] < bb, f'{name}: {pname} at {x},{y} stands on a blocked tile'
            people.append({'letter': letter, 'name': pname, 'x': x, 'y': y, 'colour': col, 'shape': shape,
                           'box': m['wander'].get(letter)})
    assert set(m['people']) <= set(CAST), f'{name}: unknown person letters'

    rad = bytearray(W * H)
    for y in range(H):
        for x in range(W):
            d = min((max(abs(x - hx), abs(y - hy)) for hx, hy in hot), default=99)
            rad[y * W + x] = max(0, 8 - 2 * d)

    gen = NL / 'gen'
    (gen / f'{name}.bin').write_bytes(bytes(out))
    (gen / f'{name}_rad.bin').write_bytes(bytes(rad))

    def scr(s):
        return s.lower().replace('"', "'")
    inc = [f'; generated by tools/make_map.py from maps/{name}.txt - do not edit',
           f'MAP_START_X = {sx}', f'MAP_START_Y = {sy}', f'PLACE_N = {len(m["places"])}',
           f'map_data !binary "gen/{name}.bin"', f'map_rad !binary "gen/{name}_rad.bin"']
    rects = [p['rect'] or [0, 0, W - 1, H - 1] for p in m['places']]
    for i, lab in enumerate(('place_x0', 'place_y0', 'place_x1', 'place_y1')):
        inc.append(f'{lab} !byte ' + ', '.join(str(r[i]) for r in rects))
    inc.append('place_name_lo !byte ' + ', '.join(f'<place_name_{i}' for i in range(len(rects))))
    inc.append('place_name_hi !byte ' + ', '.join(f'>place_name_{i}' for i in range(len(rects))))
    for i, p in enumerate(m['places']):
        inc.append(f'place_name_{i} !scr "{scr(p["name"]).ljust(14)}"')
    (gen / f'{name}.inc').write_text('\n'.join(inc) + '\n')

    pinc = [f'; generated by tools/make_map.py from maps/{name}.txt - do not edit',
            f'PEOPLE_N = {len(people)}']

    def row(label, vals):
        pinc.append(f'{label} !byte ' + (', '.join(vals) if vals else '0'))
    row('people_x0', [str(p['x']) for p in people])
    row('people_y0', [str(p['y']) for p in people])
    row('people_col', [str(p['colour']) for p in people])
    row('people_ptr', [SHAPE_PTR[p['shape']] for p in people])
    row('people_cast', [str(list(CAST).index(p['letter'])) for p in people])   # cast index (dialogue)
    for i, lab in enumerate(('people_bx0', 'people_by0', 'people_bx1', 'people_by1')):
        row(lab, [str(p['box'][i]) if p['box'] else ('$ff' if i == 0 else '0') for p in people])
    row('people_name_lo', [f'<people_name_{i}' for i in range(len(people))])
    row('people_name_hi', [f'>people_name_{i}' for i in range(len(people))])
    for i, p in enumerate(people):
        pinc.append(f'people_name_{i} !scr "{scr(p["name"])}", 0')
    (gen / f'{name}_people.inc').write_text('\n'.join(pinc) + '\n')

    meta = {'start': [sx, sy],
            'people': [{k: p[k] for k in ('letter', 'name', 'x', 'y', 'colour', 'box')} for p in people],
            'places': m['places'], 'hot': hot,
            'n_passable': codes['_n_passable'], 'n_blocked': codes['_n_blocked']}
    (gen / f'{name}.json').write_text(json.dumps(meta, indent=1) + '\n')
    return meta


if __name__ == '__main__':
    convert(sys.argv[1] if len(sys.argv) > 1 else 'testmap')
