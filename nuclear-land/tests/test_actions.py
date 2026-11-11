"""M2 Task 5 / Review Focus 4: action keys act once per press. Next to a person, T (held 60 frames)
records them as the talk target once; 2 makes Dials the leader (sprite turns light blue); U shows
Dials's skill line. The squad strip is the same in both screen buffers."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402
from c64render import nearest_index, set_palette  # noqa: E402

SPRITE_BOX = (19 * 8, 11 * 8 - 8, 16, 24)
LBLUE = 14


def main():
    set_palette(vice.palette())
    prg = vice.build({'TESTMAP': 1, 'TEST_PEOPLE': 1, 'AUTOWALK': 13})
    lab = vice.labels(prg)
    t = 8.0
    a, b, tt, acts, lead = vice.memread(prg, 0xc000 + 20 * 40, 160, wait_s=t, extra_reads=[
        (t, 0xc400 + 20 * 40, 160), (t, lab['talk_target'], 1), (t, lab['actions_done'], 1), (t, lab['leader'], 1)])
    vice.check(tt[0] == 0, f'talk target = person 0 (P1 above the leader): {tt[0]:#04x}')
    vice.check(acts[0] == 3, f'3 actions (T held 60 frames counts once): {acts[0]}')
    vice.check(lead[0] == 1, f'leader = Dials: {lead[0]}')
    vice.check(a == b, 'squad strip identical in both screen buffers')
    vice.check(a[80:120] == vice.scr('DIALS FINDS NOTHING TO FIX.'.ljust(40)), f'message line: {a[80:120]!r}')
    bars = [a[40 + 10 * m + 1:40 + 10 * m + 9] for m in range(4)]
    vice.check(all(bar == bytes([lab['G_BAR4']] * 8) for bar in bars), 'all four health bars full')
    vice.check(a[0:40] == vice.scr(' VESNA    >DIALS     MAREN     ROOK     '), f'names row, Dials marked: {a[0:40]!r}')
    shot = vice.screenshot(prg, 5_000_000 + 400 * vice.CYCLES_PER_FRAME)
    shot.save(vice.BUILD / 'actions.png')
    x0, y0 = vice.screen_box(shot)
    bx, by, bw, bh = SPRITE_BOX
    blue = sum(1 for x in range(bx, bx + bw) for y in range(by, by + bh)
               if nearest_index(shot.getpixel((x0 + x, y0 + y))) == LBLUE)
    vice.check(blue >= 40, f'leader sprite is light blue ({blue} px)')

    # rollover: 2 held, 3 pressed while 2 is still down, then 2 released - the 3 must still count
    prg = vice.build({'TESTMAP': 1, 'AUTOWALK': 17})
    lab = vice.labels(prg)
    lead, acts = vice.memread(prg, lab['leader'], 1, wait_s=4.0, extra_reads=[(4.0, lab['actions_done'], 1)])
    vice.check(lead[0] == 2 and acts[0] == 2, f'rollover 2 -> 3: leader {lead[0]} (want 2), actions {acts[0]} (want 2)')

    prg = vice.build({'TESTMAP': 1, 'AUTOWALK': 14})
    lab = vice.labels(prg)
    row, tt = vice.memread(prg, 0xc000 + 22 * 40, 40, wait_s=4.0, extra_reads=[(4.0, lab['talk_target'], 1)])
    vice.check(row == vice.scr('NOBODY IS CLOSE ENOUGH TO TALK TO.'.ljust(40)) and tt[0] == 0xff,
               f'T with nobody adjacent: {row!r}, target {tt[0]:#04x}')


if __name__ == '__main__':
    main()
