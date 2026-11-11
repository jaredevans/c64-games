"""M3 Task 3 / Review Focus 1: RETURN on an empty prompt leaves the talking screen and the town comes
back exactly as it was (map band, status, squad strip; only the message line differs), the leader and
the townspeople are back, walking works, and talking again re-enters."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402
from c64render import nearest_index, set_palette  # noqa: E402

AT = 5_009_500 + 700 * vice.CYCLES_PER_FRAME
CYAN = 3


def main():
    set_palette(vice.palette())
    ref = vice.screenshot(vice.build({'AUTOWALK': 21}), AT)      # same walk, no T
    prg = vice.build({'AUTOWALK': 18, 'TYPESCRIPT': 1})           # T, then RETURN at once
    lab = vice.labels(prg)
    shot = vice.screenshot(prg, AT)
    shot.save(vice.BUILD / 'talk_leave.png')
    mode, msg = vice.memread(prg, lab['game_mode'], 1, wait_s=6.0, extra_reads=[(6.0, 0xc000 + 22 * 40, 40)])
    vice.check(mode[0] == 0, f'back in the town (game_mode {mode[0]})')
    vice.check(msg == vice.scr('YOU LEAVE HESPER.'.ljust(40)), f'message: {msg!r}')
    x0, y0 = vice.screen_box(shot)
    same = lambda a, b: shot.crop((x0, y0 + a, x0 + 320, y0 + b)).tobytes() == ref.crop((x0, y0 + a, x0 + 320, y0 + b)).tobytes()
    vice.check(same(0, 8), 'status line as before')
    # the visible map window is display rows 24-159 (raster 75-210). The split lines around it (74, 211,
    # 218) start/end a few pixels earlier or later depending on where the main loop is when the raster
    # IRQ fires (an M1 trait that differs between builds), so they are not compared here
    vice.check(same(24, 160), 'map band, leader and townspeople as before')
    vice.check(same(168, 184), 'names and health bars as before')
    cyan = sum(1 for y in range(23, 160) for x in range(320) if nearest_index(shot.getpixel((x0 + x, y0 + y))) == CYAN)
    vice.check(cyan >= 40, f'Hesper drawn again ({cyan} cyan px)')

    # TYPESCRIPT 7: ask NAME (Dials: trust 0 -> 1), leave; step away and back, T again (nothing typed)
    prg = vice.build({'AUTOWALK': 22, 'TYPESCRIPT': 7})
    lab = vice.labels(prg)
    mode, steps, trust = vice.memread(prg, lab['game_mode'], 1, wait_s=8.0, extra_reads=[
        (8.0, lab['steps_done'], 2), (8.0, lab['trust'], 1)])
    vice.check(steps[0] | steps[1] << 8 == 36, f'walked 2 more steps after talking ({steps[0] | steps[1] << 8} of 36)')
    vice.check(mode[0] == 1, 'talking to Hesper again re-enters the talking screen')
    vice.check(trust[0] == 1, f'Hesper remembers: trust {trust[0]} after the second meeting (not reset)')


if __name__ == '__main__':
    main()
