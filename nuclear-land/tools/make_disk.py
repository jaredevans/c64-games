"""build/nland.prg + gen/portrait_*.bin + gen/eyes_*.bin -> build/nland.d64, the game disk.

The disk holds the game ("NUCLEAR LAND") and one file per cast member, "FACE <cast letter>"
(h b t j o p c v): that person's portrait (2736 bytes, tools/make_portrait.py) followed by their
eye sprites. The talking screen loads it on entering (talk.asm portrait_load), because the
portraits don't fit in memory together with the whole cast's dialogue.

Usage: python3 tools/make_disk.py [game.prg [disk.d64]]"""
import subprocess
import sys
import tempfile
from pathlib import Path

NL = Path(__file__).resolve().parent.parent
C1541 = '/Applications/vice-arm64-gtk3-3.10/bin/c1541'
# cast letter -> portrait name (tools/make_map.py CAST order, then Voss)
FACES = [('h', 'hesper'), ('b', 'Ilse-Brandt'), ('t', 'Tamsin-Reyes'), ('j', 'Jory-Platt'),
         ('o', 'Odalys-Finch'), ('p', 'Pip'), ('c', 'Silas-Corwin'), ('v', 'Abel-Voss')]
PORTRAIT_BYTES = 2736
MAX_EYES = 1 + 4 * 68


def face_file(name):
    """The bytes of one FACE file: a 2-byte load address (unused: the game loads to its buffer),
    the portrait, then the eye sprites."""
    portrait = (NL / 'gen' / f'portrait_{name}.bin').read_bytes()
    eyes = (NL / 'gen' / f'eyes_{name}.bin').read_bytes()
    if len(portrait) != PORTRAIT_BYTES:
        raise ValueError(f'{name}: portrait is {len(portrait)} bytes, not {PORTRAIT_BYTES}')
    if len(eyes) > MAX_EYES:
        raise ValueError(f'{name}: eye sprites are {len(eyes)} bytes, at most {MAX_EYES}')
    return b'\x00\x00' + portrait + eyes


def build(prg=None, d64=None):
    prg = Path(prg or NL / 'build' / 'nland.prg')
    d64 = Path(d64 or prg.with_suffix('.d64'))
    with tempfile.TemporaryDirectory() as td:
        cmd = [C1541, '-format', 'nuclear land,nl', 'd64', str(d64), '-write', str(prg), 'nuclear land']
        for letter, name in FACES:
            f = Path(td) / f'face_{letter}.bin'
            f.write_bytes(face_file(name))
            cmd += ['-write', str(f), f'face {letter}']
        d64.unlink(missing_ok=True)
        r = subprocess.run(cmd, capture_output=True)        # its output has PETSCII in it: bytes
        if r.returncode != 0 or not d64.exists():
            raise RuntimeError('c1541 failed:\n' + (r.stdout + r.stderr).decode('latin-1'))
    return d64


if __name__ == '__main__':
    print(build(*sys.argv[1:3]))
