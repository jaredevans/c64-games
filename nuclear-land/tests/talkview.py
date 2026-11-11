"""Helpers for talking-screen tests: render the expected right-hand panel from the bitmap font, and
turn stored screen codes back into text."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'tools'))
import make_dialogue  # noqa: E402

WHITE, YELLOW, LGREY = 1, 7, 15
PANEL_COL, PANEL_W = 16, 24
CONV_ROW, CONV_LINES = 4, 15
TIERS = ['WARY', 'GUARDED', 'OPEN', 'FRIENDLY']
BLOCK = 128                     # solid block glyph appended after the 128 font glyphs


def header(name, role, trust):
    """[(codes, colour)] for screen rows 0-2: name, role, 'Trust' + meter + tier word."""
    m = make_dialogue.mixed
    meter = [BLOCK] * (trust + 1) + m('.') * (3 - trust)
    return [[(m(name), WHITE)], [(m(role), LGREY)],
            [(m('Trust '), LGREY), (meter, YELLOW), (m(' ' + TIERS[trust]), LGREY)]]


def conversation(entries):
    """entries: [(text, colour)] in order; returns the last 15 as [[(codes, colour)]]."""
    return [[(make_dialogue.mixed(t), c)] for t, c in entries][-CONV_LINES:]


def render_panel(font, rows):
    """Expected palette indices of the panel (x 128..319, y 0..151): rows = {screen_row: [(codes, colour)]}."""
    out = [[0] * (PANEL_W * 8) for _ in range(152)]
    for r, segs in rows.items():
        col = 0
        for codes, colour in segs:
            for code in codes:
                for y in range(8):
                    byte = font[code * 8 + y]
                    for x in range(8):
                        if byte & (0x80 >> x):
                            out[r * 8 + y][col * 8 + x] = colour
                col += 1
    return out


def panel_rows(name, role, trust, entries):
    rows = dict(enumerate(header(name, role, trust)))
    for i, line in enumerate(conversation(entries)):
        rows[CONV_ROW + i] = line
    return rows


def text(codes):
    """Screen codes (upper/lower-case set) back to ASCII, trailing spaces stripped."""
    s = ''.join(chr(c + 96) if 1 <= c <= 26 else chr(c) if 32 <= c <= 90 else '?' for c in codes)
    return s.rstrip()
