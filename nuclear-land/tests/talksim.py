"""Python model of the talking-screen rules (the asm in talkrules.asm must agree with it)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'tools'))
import make_dialogue  # noqa: E402

VESNA, DIALS, MAREN, ROOK = range(4)
_DATA = None


def data():
    global _DATA
    if _DATA is None:
        _DATA = make_dialogue.parse_all()
    return _DATA


class Talk:
    """One person's conversation state plus the squad's Known list."""

    def __init__(self, letter, known=None):
        self.p = data()[0][letter]
        self.keywords = data()[1]
        self.trust = 0
        self.met = False
        self.asked = set()
        self.known = list(known) if known is not None else list(range(len(make_dialogue.INITIAL_KNOWN)))

    def enter(self, leader):
        if not self.met:
            self.trust = min(3, self.p['start'] + (1 if leader == VESNA else 0))
            self.met = True
        return self.p['greet']

    def ask(self, word, leader):
        for name in self.p['order']:
            t = self.p['topics'][name]
            if any(make_dialogue.matches(word, k) for k in t['keys']):
                if self.trust < t['tier']:
                    return t['else']
                if name not in self.asked:
                    self.asked.add(name)
                    self.trust = min(3, self.trust + 1 + (1 if leader in self.p['favours'] else 0))
                for w in t['reveals']:
                    i = self.keywords.index(w)
                    if i not in self.known:
                        self.known.append(i)
                return t['say']
        return self.p['unknown']


class StubTalk(Talk):
    """M3 Task 4's talk_ask before the rules exist: every word gets the 'unknown' answer, trust 0."""

    def enter(self, leader):
        self.met = True
        return self.p['greet']

    def ask(self, word, leader):
        return self.p['unknown']
