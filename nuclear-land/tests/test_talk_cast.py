"""Milestone 4: someone other than Hesper talks. Up the road to Warden Brandt at the reactor gate,
Dials leads, T, then three questions: her own portrait and eye sprites (loaded from disk, no
PORTRAIT_OF) and the panel (header, trust and answers, as the rules model says from
dialogue/brandt.txt) are pixel-exact."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'tools'))
import vice  # noqa: E402
import make_dialogue  # noqa: E402
import make_portrait  # noqa: E402
import talkview  # noqa: E402
from c64render import nearest_index, set_palette  # noqa: E402
from talksim import Talk, DIALS  # noqa: E402

WORDS = ['name', 'gate', 'voss']        # TYPESCRIPT 9
AT = 5_009_500 + 1400 * vice.CYCLES_PER_FRAME


def main():
    set_palette(vice.palette())
    prg = vice.build({'AUTOWALK': 27, 'TYPESCRIPT': 9})
    lab = vice.labels(prg)
    mode, person, font = vice.memread(prg, lab['game_mode'], 1, wait_s=8.0, extra_reads=[
        (8.0, lab['talk_person'], 1), (8.0, lab['talk_font'], 1032)])
    vice.check(mode[0] == 1 and person[0] == 1, f'talking to Brandt (game_mode {mode[0]}, cast {person[0]})')
    shot = vice.screenshot(prg, AT)
    shot.save(vice.BUILD / 'talk_brandt.png')
    x0, y0 = vice.screen_box(shot)
    want = make_portrait.render((vice.NL / 'gen' / 'portrait_Ilse-Brandt.bin').read_bytes())
    for (x, y), c in make_portrait.render_eyes((vice.NL / 'gen' / 'eyes_Ilse-Brandt.bin').read_bytes()).items():
        want[y][x] = c
    got = [[nearest_index(shot.getpixel((x0 + x, y0 + y))) for x in range(128)] for y in range(152)]
    vice.check(got == want, "Brandt's own portrait and eye sprites pixel-exact")
    people, _ = make_dialogue.parse_all()
    b = people['b']
    t = Talk('b')
    entries = [(ln, talkview.LGREY) for ln in t.enter(DIALS)]
    for w in WORDS:
        entries.append(('> ' + w.upper(), talkview.YELLOW))
        entries += [(ln, talkview.LGREY) for ln in t.ask(w, DIALS)]
    want = talkview.render_panel(font, talkview.panel_rows(b['name'], b['role'], t.trust, entries))
    got = [[nearest_index(shot.getpixel((x0 + 128 + x, y0 + y))) for x in range(192)] for y in range(152)]
    bad = [y for y in range(152) if got[y] != want[y]]
    vice.check(not bad, f"panel: Brandt's header, trust and answers (bad rows {bad[:8]})")


if __name__ == '__main__':
    main()
