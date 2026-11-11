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


if __name__ == '__main__':
    main()
