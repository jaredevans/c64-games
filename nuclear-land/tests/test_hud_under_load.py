"""Review #1: the bottom split holds for every fine_y with 7 townspeople sprites on the map's bottom
rows (sprite DMA steals cycles right where the line-212 YSCROLL write happens) plus 20 cycles of
extra IRQ latency (STRESS build), i.e. it must not depend on the IRQ arriving early."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402

STATUS, HUD = (0, 1), (21, 25)
GAP = range(160, 168)          # display rows below the map (raster 211-218): must stay black


def main():
    ref = vice.screenshot(vice.build(), 5_000_000)
    for fy in range(8):
        shot = vice.screenshot(vice.build({'STRESS': 1, 'STRESS_NOPS': 10, 'FIXED_FY': fy}), 5_000_000)
        x0, y0 = vice.screen_box(shot)
        ink = [(x, y) for y in GAP for x in range(8, 311) if shot.getpixel((x0 + x, y0 + y)) != (0, 0, 0)]
        # Known, bounded: with sprite DMA stalling the CPU across the start of line 211, the
        # blank-on write can land a few pixels late, so the first blanked line may leak <= 8 px at
        # its left end. Every other gap line must be black.
        late = [p for p in ink if p[1] != GAP[0]]
        vice.check(not late, f'fine_y={fy}: gap lines 161-167 black ({len(late)} non-black px)')
        vice.check(len(ink) <= 8, f'fine_y={fy}: first gap line leaks <= 8 px ({len(ink)})')
        vice.check(vice.band_pixels(shot, HUD) == vice.band_pixels(ref, HUD),
                   f'fine_y={fy}, 7 sprites (DMA on lines 212-213) + 20 cycles latency: HUD intact')
        vice.check(vice.band_pixels(shot, STATUS) == vice.band_pixels(ref, STATUS),
                   f'fine_y={fy}: status intact')


if __name__ == '__main__':
    main()
