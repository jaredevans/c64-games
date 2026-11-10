"""Task 2: fine scroll moves only the map band; status (row 0) and HUD (rows 21-24) never move."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402

STATUS, HUD, MAP = (0, 1), (21, 25), (2, 20)


def main():
    ref = vice.screenshot(vice.build(), 5_000_000)
    prg = vice.build({'FORCE_FINE': 1})
    base = 5_000_000
    # 8 shots spread over 64 frames, at odd frame offsets so fine_x/fine_y differ between shots
    shots = [vice.screenshot(prg, base + k * 9 * vice.CYCLES_PER_FRAME) for k in range(8)]
    st = [vice.band_pixels(s, STATUS) for s in shots]
    hud = [vice.band_pixels(s, HUD) for s in shots]
    maps = {vice.band_pixels(s, MAP) for s in shots}
    vice.check(all(x == st[0] for x in st), 'status row identical in all 8 shots')
    vice.check(all(x == hud[0] for x in hud), 'HUD rows identical in all 8 shots')
    vice.check(len(maps) >= 2, f'map band moves ({len(maps)} distinct of 8)')
    vice.check(st[0] == vice.band_pixels(ref, STATUS), 'status row matches the static build')
    vice.check(hud[0] == vice.band_pixels(ref, HUD), 'HUD rows match the static build')
    for k in (0, 3):
        shots[k].save(vice.BUILD / f'fixed_strips_{k}.png')


if __name__ == '__main__':
    main()
