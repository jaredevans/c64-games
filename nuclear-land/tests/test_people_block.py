"""M2 Task 4: a townsperson blocks the leader like a wall."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402
from c64render import load_assets  # noqa: E402
from walksim import simulate  # noqa: E402

UP, RIGHT = 0, 3
SCRIPT = [(64, RIGHT), (48, UP), (1, None)]          # must match AUTOWALK=10 in input.asm
PEOPLE = {(37, 14), (45, 12), (39, 28)}              # tests/test_people.inc


def main():
    mp, _, _ = load_assets('testmap')
    want = simulate(SCRIPT, mp, people=PEOPLE)
    vice.check(want['leader'] == (37, 15) and want['bumps'] >= 1, f'model: {want}')
    prg = vice.build({'TESTMAP': 1, 'TEST_PEOPLE': 1, 'AUTOWALK': 10})
    lab = vice.labels(prg)
    pos, bumps = vice.memread(prg, lab['leader_x'], 2, wait_s=6.0, extra_reads=[(6.0, lab['bumps'], 1)])
    vice.check(tuple(pos) == want['leader'], f'leader stopped at {tuple(pos)} below P1')
    vice.check(bumps[0] == want['bumps'], f'bumps {bumps[0]} == {want["bumps"]}')


if __name__ == '__main__':
    main()
