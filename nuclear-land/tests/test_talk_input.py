"""M3 Task 4 / Review Focus 2: junk typing keeps the prompt sane - only letters A-Z are taken (shown
in upper case), at most 12, DEL deletes one (and does nothing on an empty line), RETURN with a word
asks it, RETURN on an empty line leaves."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402
import talkview  # noqa: E402
from talksim import Talk, StubTalk, DIALS  # noqa: E402


def main():
    # TYPESCRIPT 8: "12!x" RETURN, then 14 letters - and stop (prompt state)
    prg = vice.build({'AUTOWALK': 18, 'TYPESCRIPT': 8})
    lab = vice.labels(prg)
    row = vice.memread(prg, 0xc400 + 22 * 40, 16, wait_s=8.0)
    want = vice.scr('> ABCDEFGHIJKL') + bytes([lab['G_METER_ON']])
    vice.check(row[:15] == want, f'12 letters kept, upper case, cursor after: {row[:15]!r}')

    # TYPESCRIPT 3: the same, then 3 DEL, RETURN, DEL on empty, RETURN on empty (leaves)
    prg = vice.build({'AUTOWALK': 18, 'TYPESCRIPT': 3})
    lab = vice.labels(prg)
    # the conversation as the program stored it (the bitmap itself sits under the KERNAL ROM)
    mode, conv, n = vice.memread(prg, lab['game_mode'], 1, wait_s=8.0, extra_reads=[
        (8.0, lab['conv_text'], 15 * 24), (8.0, lab['conv_n'], 1)])
    vice.check(mode[0] == 0, 'RETURN on an empty line left the conversation')
    t = Talk('h') if 'talk_meet' in lab else StubTalk('h')     # Task 4: answers are a stub
    lines = list(t.enter(DIALS))
    for w in ('X', 'ABCDEFGHI'):
        lines += ['> ' + w] + t.ask(w, DIALS)
    got = [talkview.text(conv[i * 24:i * 24 + 24]) for i in range(n[0])]
    vice.check(got == lines, f'conversation: {got}')


if __name__ == '__main__':
    main()
