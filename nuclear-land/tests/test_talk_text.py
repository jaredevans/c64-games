"""M3 Task 4 / Review Focus 3: the right-hand panel - header (name, role, trust meter) and a long
conversation that scrolls (only the last 15 lines show, newest at the bottom) - is exactly what the
rules model says, drawn with the C64's own upper/lower-case font, and the portrait is untouched."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'tools'))
import vice  # noqa: E402
import make_portrait  # noqa: E402
import talkview  # noqa: E402
from c64render import nearest_index, set_palette  # noqa: E402
from talksim import Talk, StubTalk, DIALS  # noqa: E402

WORDS = ['water', 'pump', 'name', 'job', 'keepers', 'reactor', 'voss', 'tanks']   # TYPESCRIPT 4
AT = 5_009_500 + 1400 * vice.CYCLES_PER_FRAME


def main():
    set_palette(vice.palette())
    prg = vice.build({'AUTOWALK': 18, 'TYPESCRIPT': 4})
    lab = vice.labels(prg)
    font = vice.memread(prg, lab['talk_font'], 1032, wait_s=8.0)
    shot = vice.screenshot(prg, AT)
    shot.save(vice.BUILD / 'talk_text.png')
    t = Talk('h') if 'talk_meet' in lab else StubTalk('h')     # Task 4: answers are a stub
    entries = [(ln, talkview.LGREY) for ln in t.enter(DIALS)]
    for w in WORDS:
        entries.append(('> ' + w.upper(), talkview.YELLOW))
        entries += [(ln, talkview.LGREY) for ln in t.ask(w, DIALS)]
    vice.check(len(entries) > talkview.CONV_LINES, f'conversation longer than the area ({len(entries)} lines)')
    want = talkview.render_panel(font, talkview.panel_rows('HESPER', 'WATER-KEEPER', t.trust, entries))
    x0, y0 = vice.screen_box(shot)
    got = [[nearest_index(shot.getpixel((x0 + 128 + x, y0 + y))) for x in range(192)] for y in range(152)]
    bad = [y for y in range(152) if got[y] != want[y]]
    vice.check(not bad, f'panel matches: header + last 15 lines (bad rows {bad[:8]})')
    portrait = make_portrait.render((vice.NL / 'gen' / 'portrait_hesper.bin').read_bytes())
    pg = [[nearest_index(shot.getpixel((x0 + x, y0 + y))) for x in range(128)] for y in range(152)]
    vice.check(pg == portrait, 'portrait untouched by the scrolling conversation')


if __name__ == '__main__':
    main()
