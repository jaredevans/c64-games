"""Task 3: holding a direction chains steps with no stall frame: 96 frames held -> 12 steps."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402


def main():
    prg = vice.build({'AUTOWALK': 2})
    lab = vice.labels(prg)
    g = lab['GLIDE_FRAMES']
    mem = vice.memread(prg, lab['steps_done'], 2, wait_s=6.0)
    steps = mem[0] | mem[1] << 8
    vice.check(steps == 96 // g, f'steps_done {steps} == {96 // g} exactly (GLIDE_FRAMES={g})')


if __name__ == '__main__':
    main()
