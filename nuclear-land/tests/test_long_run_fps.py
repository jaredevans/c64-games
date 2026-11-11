"""Task 4: walking a loop for minutes keeps a steady 50 fps and an untouched HUD."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402


def main():
    prg = vice.build({'TESTMAP': 1, 'AUTOWALK': 4})
    lab = vice.labels(prg)
    # tod_snap = frame_count lo/hi + CIA2 timer B lo/hi, which counts down once per 65536 emulated
    # CPU cycles. This measures fps in C64 time; wall-clock time is useless here because VICE paces
    # itself to the host display.
    a, b = vice.memread(prg, lab['tod_snap'], 4, wait_s=2.0, extra_reads=[(8.0, lab['tod_snap'], 4)])
    frames = ((b[0] | b[1] << 8) - (a[0] | a[1] << 8)) & 0xffff
    ticks = ((a[2] | a[3] << 8) - (b[2] | b[3] << 8)) & 0xffff
    secs = ticks * 65536 / 985248
    vice.check(secs >= 20, f'measured over {secs:.1f} emulated seconds ({ticks} timer ticks)')
    fps = frames / secs
    vice.check(abs(fps - 50.125) <= 0.5, f'{fps:.2f} fps in emulated time (PAL 50.12)')
    ref = vice.screenshot(vice.build({'TESTMAP': 1}), 5_000_000)
    shot = vice.screenshot(prg, 177_000_000)
    shot.save(vice.BUILD / 'long_run.png')
    vice.check(vice.band_pixels(shot, (21, 25)) == vice.band_pixels(ref, (21, 25)),
               'HUD unchanged after 3 minutes of walking')
    vice.check(vice.band_pixels(shot, (0, 1)) == vice.band_pixels(ref, (0, 1)),
               'status row unchanged after 3 minutes of walking')
    steps = vice.memread(prg, lab['steps_done'], 2, wait_s=8.0)
    vice.check((steps[0] | steps[1] << 8) > 20, 'the loop is actually walking')


if __name__ == '__main__':
    main()
