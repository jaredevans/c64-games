"""dialogue/*.txt -> gen/dialogue.inc: who says what in the talking screen.

Script format (';' starts a comment):
  person h                     cast letter (h b t j o p c, v = Voss)
  name HESPER
  role WATER-KEEPER
  start WARY                   WARY | GUARDED | OPEN | FRIENDLY
  favours MAREN                VESNA | DIALS | MAREN | ROOK, any number
  greet <text>                 shown on entering
  deflect <text>               default answer below a topic's tier
  unknown <text>               answer to a word the person has no topic for
  topic WATER[,ALIAS...]       then indented lines:
    tier WARY                    minimum trust tier for the real answer
    say <text>                   the answer (several say lines join into one paragraph)
    else <text>                  optional deflection for this topic
CAPITALISED words (3+ letters) in 'say' text join the Known list when that answer is given.
All text is word-wrapped to 24 columns. Matching (asm and tests/talksim.py): a typed word hits a
keyword if equal, or if both have 4+ letters and the first 4 agree; one person's keywords may not
collide under that rule."""
import re
import sys
import textwrap
from pathlib import Path

NL = Path(__file__).resolve().parent.parent
TIERS = ['WARY', 'GUARDED', 'OPEN', 'FRIENDLY']
MEMBERS = ['VESNA', 'DIALS', 'MAREN', 'ROOK']
CAST = 'hbtjopcv'                       # cast index order (make_map CAST, then Voss)
INITIAL_KNOWN = ['NAME', 'JOB', 'REACTOR', 'VOSS']
SKILL_KNOWN = ['TRACKS', 'TAPPED']      # found by the squad's skills (squad.asm), not in any answer
WIDTH = 24
MAX_LINES = 15          # the conversation area: an answer plus its question line must fit
MAX_TOPICS = 32         # talkrules.asm keeps 32 asked-bits per person
CAPS = re.compile(r"\b[A-Z]{3,}\b")


def wrap(text):
    return textwrap.wrap(' '.join(text.split()), WIDTH, break_long_words=False) or ['']


def key(word):
    w = word.upper()
    return (w[:4], len(w)) if len(w) >= 4 else (w, len(w))


def matches(typed, keyword):
    t, k = typed.upper(), keyword.upper()
    return t == k or (len(t) >= 4 and len(k) >= 4 and t[:4] == k[:4])


def parse(path):
    p = {'topics': {}, 'order': [], 'favours': [], 'else_default': None}
    cur = None
    for raw in path.read_text().splitlines():
        line = raw.split(';', 1)[0].rstrip()
        if not line.strip():
            continue
        word, _, rest = line.strip().partition(' ')
        rest = rest.strip()
        indented = line[0].isspace()
        if indented:
            if cur is None:
                raise ValueError(f'{path}: indented line outside a topic: {raw!r}')
            if word == 'tier':
                cur['tier'] = TIERS.index(rest)
            elif word == 'say':
                cur['say_text'] = (cur.get('say_text', '') + ' ' + rest).strip()
            elif word == 'else':
                cur['else_text'] = rest
            else:
                raise ValueError(f'{path}: unknown topic line {raw!r}')
            continue
        cur = None
        if word == 'person':
            p['letter'] = rest
        elif word in ('name', 'role'):
            p[word] = rest
        elif word == 'start':
            p['start'] = TIERS.index(rest)
        elif word == 'favours':
            p['favours'] = [MEMBERS.index(m) for m in rest.split()]
        elif word in ('greet', 'deflect', 'unknown'):
            p[word] = wrap(rest)
        elif word == 'topic':
            words = [w.strip().upper() for w in rest.split(',')]
            cur = {'keys': words}
            p['topics'][words[0]] = cur
            p['order'].append(words[0])
        else:
            raise ValueError(f'{path}: unknown line {raw!r}')
    for name, t in p['topics'].items():
        if 'tier' not in t or 'say_text' not in t:
            raise ValueError(f'{path}: topic {name} needs tier and say')
        t['say'] = wrap(t['say_text'])
        t['else'] = wrap(t['else_text']) if 'else_text' in t else p['deflect']
        t['reveals'] = list(dict.fromkeys(CAPS.findall(t['say_text'])))
    if len(p['topics']) > MAX_TOPICS:
        raise ValueError(f'{path}: {len(p["topics"])} topics, at most {MAX_TOPICS} (one asked-bit each)')
    for line in all_lines(p):
        if len(line) > WIDTH:
            raise ValueError(f'{path}: {line!r} is wider than {WIDTH} columns')
    for name, t in p['topics'].items():
        for kind in ('say', 'else'):
            if len(t[kind]) > MAX_LINES - 1:
                raise ValueError(f'{path}: topic {name} {kind} is {len(t[kind])} lines; at most '
                                 f'{MAX_LINES - 1} fit under the question in the conversation area')
    for kind in ('greet', 'deflect', 'unknown'):
        if len(p[kind]) > MAX_LINES - 1:
            raise ValueError(f'{path}: {kind} is {len(p[kind])} lines, at most {MAX_LINES - 1}')
    keys = [(k, name) for name, t in p['topics'].items() for k in t['keys']]
    for i, (a, _) in enumerate(keys):
        for b, _ in keys[i + 1:]:
            if matches(a, b) or matches(b, a):
                raise ValueError(f'{path}: keywords {a} and {b} collide (same first 4 letters)')
    return p


def all_lines(p):
    yield from p['greet'] + p['deflect'] + p['unknown'] + [p['name'], p['role']]
    for t in p['topics'].values():
        yield from t['say'] + t['else']


def parse_all(src=None):
    src = Path(src or NL / 'dialogue')
    people = {}
    for f in sorted(src.glob('*.txt')):
        p = parse(f)
        people[p['letter']] = p
    keywords = list(INITIAL_KNOWN)
    for p in people.values():
        for name in p['order']:
            for w in p['topics'][name]['reveals']:
                if w not in keywords:
                    keywords.append(w)
    for w in SKILL_KNOWN:
        assert w not in keywords, f'{w} is a skill-spot word: no answer may reveal it'
        keywords.append(w)
    return people, keywords


def mixed(text):
    """Text -> screen codes of the C64 upper/lower-case set (a-z 1-26, A-Z 65-90)."""
    out = []
    for c in text:
        if 'a' <= c <= 'z':
            out.append(ord(c) - 96)
        elif 'A' <= c <= 'Z' or ' ' <= c <= '?':
            out.append(ord(c))
        else:
            raise ValueError(f'character {c!r} has no screen code')
    return out


def upper_codes(word):
    return [ord(c) - 64 for c in word.upper()]


def build(src=None, out=None):
    people, keywords = parse_all(src)
    out = Path(out or NL / 'gen' / 'dialogue.inc')
    a = ['; generated by tools/make_dialogue.py from dialogue/*.txt - do not edit',
         f'KW_N = {len(keywords)}', 'KW_LEN = 12',
         'DLG_NAME = 0', 'DLG_ROLE = 2', 'DLG_START = 4', 'DLG_FAVOUR = 5', 'DLG_NKEYS = 6',
         'DLG_NTOPICS = 7', 'DLG_GREET = 8', 'DLG_DEFLECT = 10', 'DLG_UNKNOWN = 12', 'DLG_KEYS = 14',
         'DLG_TOPICS = 16', 'KEY_SIZE = 6', 'TOPIC_SIZE = 7', 'TOPIC_TIER = 0', 'TOPIC_SAY = 1',
         'TOPIC_ELSE = 3', 'TOPIC_REVEAL = 5']
    a += [f'KW_{w} = {i}' for i, w in enumerate(keywords)]
    a.append('kw_text')
    for w in keywords:
        codes = upper_codes(w)[:12]
        a.append('        !byte ' + ', '.join(str(c) for c in codes + [0] * (12 - len(codes))))
    a.append('dlg_lo !byte ' + ', '.join(f'<dlg_{c}' if c in people else '0' for c in CAST))
    a.append('dlg_hi !byte ' + ', '.join(f'>dlg_{c}' if c in people else '0' for c in CAST))

    def lines(label, ls):
        a.append(label)
        for ln in ls:
            a.append('        !byte ' + ', '.join(str(c) for c in mixed(ln) + [0]))
        a.append('        !byte 0')
    for c, p in people.items():
        pre = f'dlg_{c}'
        mask = sum(1 << m for m in p['favours'])
        keys = [(k, i) for i, name in enumerate(p['order']) for k in p['topics'][name]['keys']]
        a += [pre, f'        !word {pre}_name, {pre}_role',
              f'        !byte {p["start"]}, {mask}, {len(keys)}, {len(p["order"])}',
              f'        !word {pre}_greet, {pre}_deflect, {pre}_unknown, {pre}_keys, {pre}_topics',
              f'{pre}_name   !byte ' + ', '.join(str(x) for x in mixed(p['name']) + [0]),
              f'{pre}_role   !byte ' + ', '.join(str(x) for x in mixed(p['role']) + [0])]
        lines(f'{pre}_greet', p['greet'])
        lines(f'{pre}_deflect', p['deflect'])
        lines(f'{pre}_unknown', p['unknown'])
        a.append(f'{pre}_keys')
        for k, i in keys:
            k4, n = key(k)
            codes = upper_codes(k4)
            a.append('        !byte ' + ', '.join(str(x) for x in codes + [0] * (4 - len(codes)) + [n, i]))
        a.append(f'{pre}_topics')
        for i, name in enumerate(p['order']):
            t = p['topics'][name]
            els = f'{pre}_t{i}_else' if t['else'] is not p['deflect'] else f'{pre}_deflect'
            a.append(f'        !byte {t["tier"]}')
            a.append(f'        !word {pre}_t{i}_say, {els}, {pre}_t{i}_rev')
        for i, name in enumerate(p['order']):
            t = p['topics'][name]
            lines(f'{pre}_t{i}_say', t['say'])
            if t['else'] is not p['deflect']:
                lines(f'{pre}_t{i}_else', t['else'])
            a.append(f'{pre}_t{i}_rev !byte ' + ', '.join(str(keywords.index(w)) for w in t['reveals'] + []) +
                     (', $ff' if t['reveals'] else '$ff'))
    out.write_text('\n'.join(a) + '\n')
    return {'people': people, 'keywords': keywords}


if __name__ == '__main__':
    r = build()
    print(f'{len(r["people"])} people, {len(r["keywords"])} keywords')
