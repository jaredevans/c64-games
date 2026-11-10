"""Python model of the walk rules, for computing expected end states of AUTOWALK scripts.

One step per GLIDE_FRAMES frames; input is sampled only when idle; a blocked target (code >=
BLOCK_BASE) is a bump; the camera follows the leader (leader at band cell (19,9)) and is clamped to
[0, MAP_W-39] x [0, MAP_H-18] (column 39 is always under the border), in which case the leader sprite moves instead."""

DELTA = {0: (0, -1), 1: (0, 1), 2: (-1, 0), 3: (1, 0)}


def simulate(script, map_bytes, start=(29, 19), cam=(10, 10), glide=8, map_w=64, map_h=48,
             block_base=0x80, clamp=True):
    """script: list of (frames, dir or None). Returns dict(leader, cam, steps, bumps)."""
    lx, ly = start
    cx, cy = cam
    steps = bumps = 0
    busy = 0
    frames = [d for n, d in script for _ in range(n)]
    for d in frames + [None] * 64:
        if busy:
            busy -= 1
            continue
        if d is None:
            continue
        dx, dy = DELTA[d]
        tx, ty = lx + dx, ly + dy
        if map_bytes[ty * map_w + tx] >= block_base:
            bumps += 1
            continue
        lx, ly = tx, ty
        steps += 1
        ncx, ncy = lx - 19, ly - 9
        if clamp:
            ncx = max(0, min(map_w - 39, ncx))
            ncy = max(0, min(map_h - 18, ncy))
        cx, cy = ncx, ncy
        busy = glide - 1
    return dict(leader=(lx, ly), cam=(cx, cy), steps=steps, bumps=bumps)
