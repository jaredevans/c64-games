"""Headless VICE helpers for Nuclear Land tests: build, screenshot, label lookup, memory reads."""
import os
import re
import socket
import struct
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image

NL = Path(__file__).resolve().parent.parent          # nuclear-land/
REPO = NL.parent
BUILD = NL / 'build'
X64SC = '/Applications/vice-arm64-gtk3-3.10/bin/x64sc'
CYCLES_PER_FRAME = 19656
# deterministic pixels: pepto palette, no CRT filter (nearest-colour matching in c64render)
# -default ignores the user's vicerc (theirs is NTSC); -pal = the spec's machine
VIDEO = ['-default', '-pal', '-VICIIextpal', '-VICIIpalette', 'pepto-pal.vpl', '-VICIIfilter', '0']

sys.path.insert(0, str(NL / 'tools'))


def _tag(defines):
    return '_'.join(f'{k}{v}' for k, v in sorted(defines.items())) or 'normal'


def build(defines=None):
    """Assemble main.asm with optional -D defines. Returns the PRG path; raises on failure."""
    defines = defines or {}
    BUILD.mkdir(exist_ok=True)
    tag = _tag(defines)
    prg = BUILD / f'nland_{tag}.prg'
    lab = BUILD / f'labels_{tag}.txt'
    cmd = ['acme', '-f', 'cbm', '-l', str(lab), '-o', str(prg)]
    cmd += [f'-D{k}={v}' for k, v in defines.items()]
    cmd += [str(NL / 'main.asm')]
    r = subprocess.run(cmd, cwd=NL, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f'acme failed:\n{r.stdout}{r.stderr}')
    return prg


def labels(prg):
    """Parse the ACME symbol list written next to `prg`. Returns {name: value}."""
    lab = Path(str(prg).replace('nland_', 'labels_').replace('.prg', '.txt'))
    out = {}
    for line in lab.read_text().splitlines():
        m = re.match(r'\s*([A-Za-z_][\w.]*)\s*=\s*\$?([0-9a-fA-F]+)', line)
        if m:
            name, val = m.group(1), m.group(2)
            out[name] = int(val, 16) if '$' in line.split('=')[1] else int(val, 16 if re.search('[a-fA-F]', val) else 10)
    return out


def screenshot(prg, cycles):
    """Run `prg` headless for `cycles` CPU cycles and return the exit screenshot."""
    with tempfile.TemporaryDirectory() as td:
        png = os.path.join(td, 'shot.png')
        # VIDEO (with -default) must come first: -default resets every option given before it
        subprocess.run([X64SC, *VIDEO, '-warp', '-limitcycles', str(int(cycles)), '-autostartprgmode', '1',
                        '-sounddev', 'dummy', '-exitscreenshot', png, '-autostart', str(prg)],
                       capture_output=True, timeout=600)
        if not os.path.exists(png):
            raise RuntimeError('VICE produced no screenshot')
        return Image.open(png).convert('RGB').copy()


def palette():
    """VICE's actual rendered RGB for colours 0..15 under VIDEO flags (measured once, cached)."""
    import json
    cache = BUILD / 'palette.json'
    if cache.exists():
        return [tuple(c) for c in json.loads(cache.read_text())]
    BUILD.mkdir(exist_ok=True)
    prg = BUILD / 'calib.prg'
    r = subprocess.run(['acme', '-f', 'cbm', '-o', str(prg), str(NL / 'tests' / 'calib.asm')],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(r.stdout + r.stderr)
    shot = screenshot(prg, 5_000_000)
    x0, y0 = 32, 23                       # calib border is black, so use the known VICE origin
    pal = [shot.getpixel((x0 + i * 16 + 8, y0 + 20)) for i in range(16)]
    cache.write_text(json.dumps(pal))
    return pal


def screen_box(img):
    """Top-left (x0, y0) of the 320x200 display window: first non-border pixel column/row."""
    border = img.getpixel((0, 0))
    w, h = img.size
    px = img.load()
    x0 = min((x for y in range(h) for x in range(w) if px[x, y] != border), default=None)
    y0 = min((y for y in range(h) for x in range(w) if px[x, y] != border), default=None)
    if x0 is None:
        raise RuntimeError('screen is all border')
    return x0, y0


def _recv_exact(s, n):
    buf = b''
    while len(buf) < n:
        chunk = s.recv(n - len(buf))
        if not chunk:
            raise RuntimeError('monitor connection closed')
        buf += chunk
    return buf


def memread(prg, addr, length, wait_s=4.0, warp=True, port=6510, extra_reads=()):
    """Launch VICE with the binary monitor, let `prg` run `wait_s` seconds, then read memory.

    Returns bytes for (addr, length); if `extra_reads` is a list of (wait_s, addr, length) the
    function returns a list of byte strings, one per read, taken at those later times."""
    args = [X64SC, *VIDEO, '-autostartprgmode', '1', '-sounddev', 'dummy', '-binarymonitor',
            '-binarymonitoraddress', f'ip4://127.0.0.1:{port}', '-autostart', str(prg)]
    if warp:
        args.insert(1, '-warp')
    _port_free_or_die(port)
    # x64sc in bin/ is a wrapper script: run it in its own process group so kill reaps the emulator
    proc = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                            start_new_session=True)
    try:
        s = None
        for _ in range(100):
            try:
                s = socket.create_connection(('127.0.0.1', port), timeout=1)
                break
            except OSError:
                time.sleep(0.1)
        if s is None:
            raise RuntimeError('could not connect to VICE binary monitor')
        s.settimeout(8)
        t0 = time.time()
        reqid = [100]

        def get(a, n):
            reqid[0] += 1
            body = struct.pack('<BHHBH', 0, a, a + n - 1, 0, 0)
            s.sendall(struct.pack('<BBIIB', 0x02, 0x02, len(body), reqid[0], 0x01) + body)
            while True:
                hdr = _recv_exact(s, 12)
                _stx, _api, blen, rtype, err, rid = struct.unpack('<BBIBBI', hdr)
                data = _recv_exact(s, blen)
                if rid == reqid[0] and rtype == 0x01:
                    if err:
                        raise RuntimeError(f'MemGet error {err}')
                    ln = struct.unpack('<H', data[:2])[0]
                    return data[2:2 + ln]

        def resume():
            reqid[0] += 1
            s.sendall(struct.pack('<BBIIB', 0x02, 0x02, 0, reqid[0], 0xaa))

        plan = [(wait_s, addr, length)] + list(extra_reads)
        results = []
        for (w, a, n) in plan:
            time.sleep(max(0, w - (time.time() - t0)))
            results.append(get(a, n))
            resume()
        return results[0] if not extra_reads else results
    finally:
        try:
            os.killpg(proc.pid, 9)
        except ProcessLookupError:
            pass
        proc.wait()
        for _ in range(50):             # wait until the emulator really released the port
            try:
                socket.create_connection(('127.0.0.1', port), timeout=0.2).close()
                time.sleep(0.1)
            except OSError:
                break


def _port_free_or_die(port):
    try:
        socket.create_connection(('127.0.0.1', port), timeout=0.2).close()
    except OSError:
        return
    raise RuntimeError(f'port {port} already in use - a stray VICE is running (pkill -f Resources/bin/x64sc)')


# ---- comparison helpers shared by tests ----
def band_mismatch(shot, expected_idx, cam_rows=(2, 20), cols=(1, 39), ignore_box=None, dx=0, dy=0):
    """Fraction of pixels in the map band whose nearest-palette index differs from expected.

    expected_idx: 2-D list [y][x] of colour indices for the 40x18 view (from c64render).
    ignore_box: (x, y, w, h) in display-window pixels to skip (the sprite).
    dx, dy: the map band's pixel shift on screen (fine_x, fine_y); the expected image is
    sampled at (sx-dx, sy-dy) and pixels shifted in from outside the view are skipped."""
    from c64render import nearest_index, set_palette
    set_palette(palette())
    x0, y0 = screen_box(shot)
    px = shot.load()
    bad = tot = 0
    for vy in range((cam_rows[1] - cam_rows[0]) * 8):
        sy = cam_rows[0] * 8 + vy
        for sx in range(cols[0] * 8, cols[1] * 8):
            if ignore_box and ignore_box[0] <= sx < ignore_box[0] + ignore_box[2] \
                    and ignore_box[1] <= sy < ignore_box[1] + ignore_box[3]:
                continue
            ex, ey = sx - dx, vy - dy
            if not (0 <= ex < len(expected_idx[0]) and 0 <= ey < len(expected_idx)):
                continue
            tot += 1
            if nearest_index(px[x0 + sx, y0 + sy]) != expected_idx[ey][ex]:
                bad += 1
    return bad / max(tot, 1)


def rest_shift(lab):
    """(dx, dy) of the map band at rest: XSCROLL px right, and map row 2 starts on raster 67+fine_y."""
    return lab['FINE_REST_X'], lab['FINE_REST_Y']


def band_pixels(shot, rows):
    """Raw RGB pixels of whole character rows [rows[0], rows[1]) of the display window."""
    x0, y0 = screen_box(shot)
    return shot.crop((x0, y0 + rows[0] * 8, x0 + 320, y0 + rows[1] * 8)).tobytes()


def has_ink(shot, rows):
    x0, y0 = screen_box(shot)
    crop = shot.crop((x0, y0 + rows[0] * 8, x0 + 320, y0 + rows[1] * 8))
    return any(p != (0, 0, 0) for p in crop.getdata())


def check(cond, msg):
    if not cond:
        print('FAIL:', msg)
        sys.exit(1)
    print('ok:', msg)
