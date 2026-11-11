"""M3 Task 2: dialogue scripts -> gen/dialogue.inc, and the Python rules model (talksim) the asm is
tested against. Rules (spec): trust tiers 0-3; below an answer's tier the person deflects, trust
unchanged; first real answer to a topic +1, +1 more if a favoured member leads; repeats and unknown
words change nothing; Vesna leading at the first meeting starts the person one tier higher;
CAPITALISED words in answers join the Known list. Matching: equal, or both >= 4 letters and the first
4 agree."""
import sys
import tempfile
from pathlib import Path

NL = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(NL / 'tools'))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_dialogue  # noqa: E402
from talksim import Talk, VESNA, DIALS, MAREN  # noqa: E402
from vice import check  # noqa: E402


def main():
    d = make_dialogue.build()
    h = d['people']['h']
    check(all(len(line) <= 24 for p in d['people'].values() for line in make_dialogue.all_lines(p)),
          'every text line fits 24 columns')
    check(h['start'] == 0 and h['favours'] == [MAREN], 'Hesper starts Wary and favours Maren')
    check(d['keywords'][:4] == ['NAME', 'JOB', 'REACTOR', 'VOSS'], 'initial Known ids 0-3')
    check((NL / 'gen' / 'dialogue.inc').exists(), 'gen/dialogue.inc written')

    # M5: the skill spots' words have ids (after every answer's word, so no id moves), no topic
    # reveals them, and the asm gets an id constant for every keyword
    kw = d['keywords']
    check(kw[-2:] == ['TRACKS', 'TAPPED'] and len(kw) == 28, f'TRACKS and TAPPED end the dictionary ({len(kw)} words)')
    check(not any(w in t['reveals'] for p in d['people'].values() for t in p['topics'].values()
                  for w in ('TRACKS', 'TAPPED')), 'no answer reveals TRACKS or TAPPED')
    inc = (NL / 'gen' / 'dialogue.inc').read_text()
    check(all(f'KW_{w} = {i}\n' in inc for i, w in enumerate(kw)), 'gen/dialogue.inc has KW_<WORD> = id for every keyword')

    # M5 the ending: Voss's CORWIN topic index for the trigger, and the two ending texts
    # (dialogue/ending.txt), wrapped to the ending screen's 36 columns, each fitting its rows
    v = d['people']['v']
    check(f"TOPIC_V_CORWIN = {v['order'].index('CORWIN')}\n" in inc, 'gen/dialogue.inc has TOPIC_V_CORWIN')
    end = d['ending']
    check(set(end) == {'good', 'open'}, 'ending.txt has the good and the open ending')
    for k, ls in end.items():
        check(all(len(ln) <= make_dialogue.END_WIDTH for ln in ls) and 3 <= len(ls) <= make_dialogue.END_ROWS
              and '' in ls, f'ending {k}: {len(ls)} lines of at most {make_dialogue.END_WIDTH} columns, paragraphs apart')
        check(f'end_{k}\n' in inc, f'gen/dialogue.inc has end_{k}')
    check(' '.join(end['good'][:2]) == 'The squad brings Abel Voss up out of the dark.', 'good ending starts as written')

    t = Talk('h')
    t.enter(DIALS)
    defl = t.ask('TANKS', DIALS)
    check(t.trust == 0 and defl == h['topics']['TANKS']['else'], 'Wary: TANKS deflected, trust 0')
    t.ask('NAME', DIALS)
    check(t.trust == 1, 'NAME: trust 1')
    t.ask('JOB', DIALS)
    check(t.trust == 2, 'JOB: trust 2 (Open)')
    known0 = list(t.known)
    ans = t.ask('TANKS', DIALS)
    kw = d['keywords']
    check(ans == h['topics']['TANKS']['say'] and kw.index('CORWIN') in t.known and kw.index('CARAVAN') in t.known
          and t.known[:len(known0)] == known0, 'Open: TANKS answers, Known gains CORWIN and CARAVAN')
    check(t.ask('wate', DIALS) == t.ask('WATER', DIALS), 'WATE matches WATER')
    tr = t.trust
    check(t.ask('WAT', DIALS) == h['unknown'] and t.ask('BANANA', DIALS) == h['unknown'] and t.trust == tr,
          'WAT and BANANA: unknown, trust unchanged')
    t.ask('NAME', DIALS)
    check(t.trust == tr, 'asking NAME again changes nothing')

    m = Talk('h')
    m.enter(MAREN)
    m.ask('NAME', MAREN)
    check(m.trust == 2, 'Maren leading: NAME gives 2')
    m.ask('JOB', MAREN)
    check(m.trust == 3, 'trust caps at 3')
    v = Talk('h')
    v.enter(VESNA)
    check(v.trust == 1, "Vesna at the first meeting: Hesper starts Guarded")
    v.enter(DIALS)
    check(v.trust == 1, 'the bonus is fixed: meeting again changes nothing')

    with tempfile.TemporaryDirectory() as td:
        (Path(td) / 'bad.txt').write_text('person h\nname X\nrole Y\nstart WARY\ngreet Hi.\n'
                                          'deflect No.\nunknown What?\ntopic PUMP\n  tier WARY\n  say A.\n'
                                          'topic PUMPS\n  tier WARY\n  say B.\n')
        try:
            make_dialogue.build(Path(td), Path(td) / 'out.inc')
            check(False, 'PUMP and PUMPS (same first 4 letters) rejected')
        except ValueError:
            check(True, 'PUMP and PUMPS (same first 4 letters) rejected')
    base = 'person h\nname X\nrole Y\nstart WARY\ngreet Hi.\ndeflect No.\nunknown What?\n'
    for why, body in (('a 25-letter word (no line fits 24 columns)',
                       'topic PUMP\n  tier WARY\n  say ' + 'A' * 25 + '\n'),
                      ('an answer longer than the 15-line conversation area',
                       'topic PUMP\n  tier WARY\n  say ' + 'word ' * 80 + '\n'),
                      ('33 topics (32 asked-bits per person)',
                       ''.join(f'topic K{chr(65 + i // 26)}{chr(65 + i % 26)}X\n  tier WARY\n  say A.\n' for i in range(33)))):
        with tempfile.TemporaryDirectory() as td:
            (Path(td) / 'bad.txt').write_text(base + body)
            try:
                make_dialogue.build(Path(td), Path(td) / 'out.inc')
                check(False, f'rejected: {why}')
            except ValueError:
                check(True, f'rejected: {why}')


if __name__ == '__main__':
    main()
