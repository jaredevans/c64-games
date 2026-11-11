"""Convert the painted portraits in assets/original/ into C64 hi-res portraits.

Each source is a 1888x2240 (16:19) image. The output is assets/<name>_c64_128x152.png (the
file tools/make_portrait.py reads) plus a 4x preview in assets/original/c64_preview/<name>_c64.png.

Rules every output keeps (checked after conversion):
  - only the 16 Pepto colours, 128x152 pixels (512x608 preview = 4x4 chunky pixels);
  - every 8x8 cell is black plus at most one other colour.

How a cell is converted:
  - each character has a small palette ('base'); colours can be added, removed or forced in
    cell rectangles (rects are (col0, row0, col1, row1) in 8x8 cells, inclusive);
  - the cell picks the one colour that best matches its pixels; pixels that are dark, or whose
    own nearest colour is a different one, become black (that is what draws the outlines);
  - gold pixels (keys, chains) force their cells to yellow (at least 'gold_min' of them, default 6); green pixels force their cells to
    the pale green accent, inside the rectangles given for each;
  - 'hair' zones: where hair meets skin inside one cell, the majority wins; a leftover strip of
    the other one that is at most 'thin' pixels wide becomes a thin black line, a thicker one
    takes the winning colour (no thick black gaps between hair and face);
  - 'eyes' rects: in skin cells, light pixels (eye whites, highlights) stay skin colour;
  - 'recolour': [((x, y), colour)] gives the outlined shape at pixel x, y its own colour
    (Pip's slingshot would otherwise be the jacket's brown);
  - 'zoom': (w, h, ox, oy) scales the source to w x h and takes the 128x152 window at ox, oy,
    which moves features against the 8x8 grid (used to line a hairline up with cell edges).

Eyes: a cell can't hold skin, black and white at once, so the eye whites and irises are not in
the portrait. They go in assets/<name>_eyes_128x152.png (on black, same 128x152 frame), which
tools/make_portrait.py turns into hardware sprites drawn over the portrait (one per eye and
colour). The whites are the white pixels of the source inside the character's 'eyebox'
(x0, y0, x1, y1, portrait pixels, end exclusive; or a list of boxes, one per eye); the iris is
what lies between them on each row of the eye, in the character's 'iris' colour. The preview shows the portrait
with the eyes on top, as the game does; c64_preview/contact_sheet.png shows all of them.

Usage (from anywhere):  python3 convert_c64.py [name ...]     (no names = all)
"""
import sys
from pathlib import Path
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ASSETS = HERE.parent
PREVIEW = HERE / 'c64_preview'

PAL = ["000000", "FFFFFF", "68372B", "70A4B2", "6F3D86", "588D43", "352879", "B8C76F",
       "6F4F25", "433900", "9A6759", "444444", "6C6C6C", "9AD284", "6C5EB5", "959595"]
P = np.array([[int(h[i:i + 2], 16) for i in (0, 2, 4)] for h in PAL], float)
W, H = 128, 152
# palette index names, for reading the configs
BLACK, WHITE, RED, CYAN, PURPLE, GREEN, BLUE, YELLOW = range(8)
ORANGE, BROWN, PINK, DGREY, GREY, LGREEN, LBLUE, LGREY = range(8, 16)
#   RED 68372B dark skin/red-brown   ORANGE 6F4F25 coat brown   BROWN 433900 dark olive
#   PINK 9A6759 skin   YELLOW B8C76F gold   LGREEN 9AD284 pale green accent


def srgb2lab(rgb):
    c = rgb / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
    xyz = c @ M.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


PLAB = srgb2lab(P)

# ---------------------------------------------------------------------------------------------
# Per-character settings
# ---------------------------------------------------------------------------------------------
CONFIGS = {
    'hesper': dict(
        src='Hesper.jpeg',
        eyebox=(60, 44, 92, 56),                                       # eye whites (sprites)
        iris=CYAN,
        brow_fix=78,                                                      # no white speck in the left brow
        base=[RED, YELLOW, ORANGE, PINK, GREY, LGREEN],
        add=[((0, 4, 5, 7), [LGREY]), ((1, 8, 7, 14), [LGREY])],         # shine on the ladle, cup and handle
        remove=[((10, 3, 12, 6), [RED])],                                 # no red streak at the temple
        gold=[(10, 15, 12, 18)],                                          # keys (not the hand round them)
    ),
    'Ilse-Brandt': dict(                                                  # the warden
        src='Ilse-Brandt.jpeg',
        eyebox=(64, 44, 98, 54),                                       # eye whites (sprites)
        iris=GREY,
        base=[RED, YELLOW, ORANGE, PINK, GREY, LGREEN, LGREY],
        zoom=(136, 162, 2, 5),
        add=[((0, 5, 5, 13), [DGREY]), ((10, 5, 15, 15), [DGREY])],      # chain-link fence
        remove=[((8, 12, 11, 18), [DGREY, LGREY])],                       # shirt stays mid grey
        green=[(0, 12, 3, 18)],                                           # shoulder patch
        gold=[(4, 12, 15, 18)],                                           # keys and chain
        hair=dict(zones=[(3, 0, 12, 4), (3, 5, 6, 6)], hair_col=LGREY),
        eyes=[(4, 4, 12, 8)],
    ),
    'Abel-Voss': dict(
        src='Abel-Voss.jpeg',
        eyebox=(62, 46, 95, 54),                                       # eye whites (sprites)
        iris=LBLUE,
        brow_fix=78,                                                      # no white speck in the left brow
        base=[RED, YELLOW, ORANGE, PINK, GREY, LGREEN, LGREY],
        remove=[((0, 0, 15, 15), [YELLOW])],                              # yellow only for the coat glow
        hair=dict(zones=[(3, 0, 12, 5), (3, 6, 5, 8), (6, 8, 10, 10)],     # hair, temples, stubble
                  hair_col=LGREY),
        eyes=[(4, 5, 12, 8)],
    ),
    'Silas-Corwin': dict(
        src='Silas-Corwin.jpeg',
        eyebox=(60, 42, 94, 51),                                       # eye whites (sprites)
        iris=CYAN,
        brow_fix=78,                                                      # no white speck in the left brow
        base=[RED, ORANGE, PINK, GREY, LGREY, WHITE, PURPLE],             # white shirt, purple cravat
        remove=[((0, 8, 4, 18), [GREY, LGREY]), ((12, 8, 15, 18), [GREY, LGREY])],  # shirt stays white
        gold=[(7, 15, 14, 18)],                                           # watch chain
        hair=dict(zones=[(4, 0, 11, 3), (4, 4, 5, 6), (10, 4, 11, 6), (4, 7, 11, 10)],  # hair, beard
                  hair_col=LGREY),
        eyes=[(4, 4, 11, 7)],
    ),
    'Jory-Platt': dict(
        src='Jory-Platt.jpeg',
        eyebox=[(62, 48, 72, 54), (84, 48, 92, 54)],                 # eye whites (sprites)
        white_l=58,                                                       # his eyes are in shadow
        iris=LBLUE,
        base=[RED, ORANGE, PINK, GREY, LGREY, CYAN],
        remove=[((0, 3, 4, 13), [GREY]), ((11, 2, 15, 7), [GREY]),         # pillow stays light grey
                ((5, 9, 15, 18), [LGREY]), ((2, 14, 4, 18), [LGREY])],     # blanket stays mid grey
        force=[((3, 10, 6, 13), [LGREY, CYAN, PINK, RED]),                # scarf at his neck
               ((7, 10, 7, 11), [LGREY, CYAN, PINK, RED])],
        eyes=[(4, 3, 11, 8)],
    ),
    'Odalys-Finch': dict(
        src='Odalys-Finch.jpeg',
        eyebox=(62, 45, 96, 56),                                       # eye whites (sprites)
        iris=LGREEN,
        brow_fix=78,                                                      # no white speck in the left brow
        base=[RED, YELLOW, ORANGE, PINK, GREY, LGREY],
        force=[((8, 14, 9, 14), [YELLOW])],                               # the coin in her hand
        eyes=[(4, 5, 12, 9)],
    ),
    'Pip': dict(
        src='Pip.jpeg',
        eyebox=[(63, 51, 73, 56), (85, 53, 93, 57)],                 # eye whites (sprites)
        iris=YELLOW,
        base=[RED, YELLOW, ORANGE, PINK, GREY, LGREEN],
        add=[((3, 0, 13, 8), [DGREY])], remove=[((3, 0, 13, 8), [GREY])],  # dark hair
        hair=dict(zones=[(4, 0, 12, 5), (4, 6, 6, 8), (11, 6, 12, 8)],
                  hair_col=DGREY, hair_cls=(GREY, DGREY, LGREY)),
        eyes=[(4, 5, 12, 10)],
        recolour=[((75, 128), YELLOW)],                                   # the slingshot
    ),
    'Tamsin-Reyes': dict(
        src='Tamsin-Reyes.jpeg',
        eyebox=(64, 45, 96, 55),                                       # eye whites (sprites)
        iris=GREEN,
        brow_fix=78,                                                      # no white speck in the left brow
        base=[RED, YELLOW, ORANGE, PINK, GREY, LGREEN, LGREY],
        remove=[((12, 7, 15, 9), [ORANGE, PINK, RED, GREY, LGREY])],      # the plant's leaves
        eyes=[(4, 5, 12, 9)],
    ),
}


def inrects(cx, cy, rects):
    return any(c0 <= cx <= c1 and r0 <= cy <= r1 for c0, r0, c1, r1 in rects)


def load(cfg):
    im = Image.open(HERE / cfg['src']).convert('RGB')
    w, h = im.size
    tw = round(h * 16 / 19)
    if tw <= w:
        im = im.crop(((w - tw) // 2, 0, (w - tw) // 2 + tw, h))
    else:
        th = round(w * 19 / 16)
        im = im.crop((0, (h - th) // 2, w, (h - th) // 2 + th))
    if cfg.get('zoom'):
        zw, zh, ox, oy = cfg['zoom']
        big = np.asarray(im.resize((zw, zh), Image.BOX), float)
        return big[oy:oy + H, ox:ox + W]
    return np.asarray(im.resize((W, H), Image.BOX), float)


def convert(cfg):
    small = load(cfg)
    lab = srgb2lab(small)
    d = ((lab[:, :, None, :] - PLAB[None, None, :, :]) ** 2).sum(-1)   # H, W, 16
    nb = np.argmin(d[..., 1:], -1) + 1                                   # nearest non-black colour
    isb = d[..., 0] < np.take_along_axis(d, nb[..., None], -1)[..., 0]  # nearer to black
    r, g, b = small[..., 0], small[..., 1], small[..., 2]
    gold = (r > 120) & (g > 90) & (b < 90) & (r - b > 60) & (np.abs(r - g) < 70)
    green = (g > r + 15) & (g > b + 15)
    hair = cfg.get('hair')
    if hair:
        hair_cls = tuple(hair.get('hair_cls', (WHITE, GREY, LGREY)))
        skin_cls = tuple(hair.get('skin_cls', (PINK, RED)))
        hair_col, skin_col = hair['hair_col'], hair.get('skin_col', PINK)
        thin = hair.get('thin', 2)
    idx = np.zeros((H, W), int)
    for cy in range(H // 8):
        for cx in range(W // 8):
            sl = (slice(cy * 8, cy * 8 + 8), slice(cx * 8, cx * 8 + 8))
            cd, n, bk = d[sl], nb[sl], isb[sl]
            al = list(cfg['base'])
            for rect, cols in cfg.get('add', []):
                if inrects(cx, cy, [rect]):
                    al += [c for c in cols if c not in al]
            for rect, cols in cfg.get('remove', []):
                if inrects(cx, cy, [rect]):
                    al = [c for c in al if c not in cols]
            for rect, cols in cfg.get('force', []):
                if inrects(cx, cy, [rect]):
                    al = list(cols)
            if inrects(cx, cy, cfg.get('green', [])) and green[sl].sum() >= 6:
                al = [LGREEN]
            elif inrects(cx, cy, cfg.get('gold', [])) and gold[sl].sum() >= cfg.get('gold_min', 6):
                al = [YELLOW]
            if hair and inrects(cx, cy, hair['zones']):
                hcnt = (np.isin(n, hair_cls) & ~bk).sum()
                scnt = (np.isin(n, skin_cls) & ~bk).sum()
                if hcnt > 0 and scnt > 0:
                    win_hair = hcnt >= scnt
                    c = hair_col if win_hair else skin_col
                    minority = np.isin(n, skin_cls if win_hair else hair_cls) & ~bk
                    colc = np.broadcast_to(minority.sum(0, keepdims=True), (8, 8))
                    rowc = np.broadcast_to(minority.sum(1, keepdims=True), (8, 8))
                    thinmask = minority & (np.minimum(colc, rowc) <= thin)
                    keep = ~bk & ~thinmask & np.isin(n, hair_cls + skin_cls)
                    idx[sl] = np.where(keep, c, 0)
                    continue
            costs = [(np.minimum(cd[..., 0], cd[..., c]).sum(), c) for c in al]
            c = min(costs)[1]
            keep = cd[..., c] < cd[..., 0]
            own = np.array(al)[cd[..., al].argmin(-1)]
            if c == PINK and inrects(cx, cy, cfg.get('eyes', [])):
                keep &= np.isin(own, (PINK, GREY, LGREY))
            elif len(al) > 1:
                keep &= own == c
            idx[sl] = np.where(keep, c, 0)
    for seed, col in cfg.get('recolour', []):
        recolour(idx, seed, col)
    return idx


def recolour(idx, seed, col):
    """Give the shape at seed (x, y) - the same-colour region around it, bounded by its black
    outline - its own colour. A cell can hold one colour, so in each cell the shape touches, the
    majority wins: the shape's colour with the rest of the cell black, or the old colour with the
    shape's pixels black."""
    sx, sy = seed
    old = idx[sy, sx]
    shape = np.zeros((H, W), bool)
    todo = [(sy, sx)]
    while todo:
        y, x = todo.pop()
        if 0 <= y < H and 0 <= x < W and not shape[y, x] and idx[y, x] == old:
            shape[y, x] = True
            todo += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    for cy in range(H // 8):
        for cx in range(W // 8):
            sl = (slice(cy * 8, cy * 8 + 8), slice(cx * 8, cx * 8 + 8))
            n = shape[sl].sum()
            if n == 0:
                continue
            if n >= ((idx[sl] != 0) & ~shape[sl]).sum():
                idx[sl] = np.where(shape[sl], col, 0)
            else:
                idx[sl] = np.where(shape[sl], 0, idx[sl])


def check(idx):
    for cy in range(0, H, 8):
        for cx in range(0, W, 8):
            assert len(set(np.unique(idx[cy:cy + 8, cx:cx + 8])) - {0}) <= 1, (cx, cy)


def run(name):
    idx = convert(CONFIGS[name])
    check(idx)
    rgb = Image.fromarray(P[idx].astype(np.uint8))
    rgb.save(ASSETS / f'{name}_c64_128x152.png')
    shown = P[idx].astype(np.uint8)
    cfg = CONFIGS[name]
    eyes = eye_whites(cfg)
    if eyes is not None:
        iris = irises(cfg, eyes)
        if cfg.get('brow_fix'):
            eyes = drop_brow_whites(eyes, iris, cfg['brow_fix'])
        layer = np.zeros((H, W), int)
        layer[eyes] = WHITE
        layer[iris] = cfg['iris']
        Image.fromarray(P[layer].astype(np.uint8)).save(ASSETS / f'{name}_eyes_128x152.png')
        shown[layer > 0] = P[layer[layer > 0]].astype(np.uint8)
    PREVIEW.mkdir(exist_ok=True)
    Image.fromarray(shown).resize((W * 4, H * 4), Image.NEAREST).save(PREVIEW / f'{name}_c64.png')
    used = sorted({PAL[i] for i in np.unique(idx)})
    n_eye = 0 if eyes is None else int(eyes.sum())
    print(f'{name}: ok, colours {" ".join(used)}, {n_eye} eye-white pixels')


def source_frame(cfg):
    """The full-resolution source, cropped to 16:19, and how portrait pixels map onto it:
    (array, x of portrait column 0, y of portrait row 0, source px per portrait px x, y)."""
    im = Image.open(HERE / cfg['src']).convert('RGB')
    w, h = im.size
    tw = round(h * 16 / 19)
    off = (w - tw) // 2
    a = np.asarray(im, float)
    if cfg.get('zoom'):
        zw, zh, ox, oy = cfg['zoom']
        sx, sy = tw / zw, h / zh
        return a, off + ox * sx, oy * sy, sx, sy
    return a, off, 0.0, tw / W, h / H


def eye_boxes(cfg):
    return cfg['eyebox'] if isinstance(cfg['eyebox'], list) else [cfg['eyebox']]


def eye_whites(cfg, frac=0.3):
    """128x152 bool mask of the eye whites, or None without an 'eyebox'. Measured on the
    full-resolution source (its own pixel grid doesn't line up with ours, so averaging would blur
    a one-pixel white into its black neighbours): a portrait pixel is white when at least 'frac'
    of the source under it is white (lightness 'white_l', default 80)."""
    if 'eyebox' not in cfg:
        return None
    a, ox0, oy0, sx, sy = source_frame(cfg)
    white = np.zeros((H, W), bool)
    for x0, y0, x1, y1 in eye_boxes(cfg):
        for y in range(y0, y1):
            for x in range(x0, x1):
                blk = a[int(round(oy0 + y * sy)):int(round(oy0 + (y + 1) * sy)),
                        int(round(ox0 + x * sx)):int(round(ox0 + (x + 1) * sx))]
                lab = srgb2lab(blk)
                m = (lab[..., 0] >= cfg.get('white_l', 80)) & (np.hypot(lab[..., 1], lab[..., 2]) < 14)
                white[y, x] = m.mean() >= frac
    return white


def drop_brow_whites(whites, iris, x_end):
    """The paintings put a highlight on top of the iris; at 128 px wide it lands a row above the
    eye opening, in the black lid and brow, where it reads as a white speck in the eyebrow. Drop
    white pixels above an eye's iris rows that have no white or iris pixel beside them, left of
    x_end (the characters' 'brow_fix': only their left eye)."""
    out = whites.copy()
    eye = whites | iris
    for y, x in zip(*np.nonzero(whites)):
        if x >= x_end:
            continue
        near = iris[:, max(0, x - 12):x + 13]                 # this eye's iris (eyes are > 12 px apart)
        rows = np.nonzero(near.any(1))[0]
        if len(rows) and y < rows.min() and not (eye[y, x - 1] or eye[y, min(W - 1, x + 1)]):
            out[y, x] = False
    return out


def irises(cfg, whites):
    """128x152 bool mask of the irises. In these paintings an eye is a white corner, the iris
    (dark, often with a white highlight), then the white of the eye; so on each row of an eye the
    iris is the pixels between its leftmost and rightmost light pixel (white, or light grey where
    the eye is in shadow)."""
    lab = srgb2lab(load(cfg))
    light = whites | ((lab[..., 0] > 45) & (np.hypot(lab[..., 1], lab[..., 2]) < 14))
    boxes = eye_boxes(cfg)
    inbox = np.zeros((H, W), bool)
    for x0, y0, x1, y1 in boxes:
        inbox[y0:y1, x0:x1] = True
    light &= inbox
    split = (boxes[0][0] + boxes[-1][2]) / 2 if len(boxes) > 1 else (boxes[0][0] + boxes[0][2]) / 2
    out = np.zeros((H, W), bool)
    halves = []
    for lo, hi in ((0, split), (split, W)):
        half = np.zeros((H, W), bool)
        half[:, int(np.ceil(lo)):int(np.ceil(hi))] = True
        halves.append(half)
        for y in range(H):
            row = [x for x in range(W) if half[y, x] and light[y, x]]
            for x in range(row[0] + 1, row[-1]) if len(row) >= 2 else ():
                if not light[y, x]:
                    out[y, x] = True
    # an eye with whites on one side only (in shadow): copy the other eye's iris width and side
    done = [(out & h).any() for h in halves]
    if done.count(True) == 1:
        src, dst = (halves[0], halves[1]) if done[0] else (halves[1], halves[0])
        iy, ix = np.nonzero(out & src)
        wy, wx = np.nonzero(whites & src)
        dy, dx = np.nonzero(whites & dst)
        if len(dx):
            width = ix.max() - ix.min() + 1
            y = np.bincount(dy).argmax()                     # the eye's fullest row of white
            if ix.mean() < wx.mean():
                x0 = dx[dy == y].min() - width
            else:
                x0 = dx[dy == y].max() + 1
            out[y, x0:x0 + width] = True
    return out


def contact_sheet():
    """All characters' previews (eyes included) in one image: c64_preview/contact_sheet.png."""
    from PIL import ImageDraw
    names = [n for n in CONFIGS if (PREVIEW / f'{n}_c64.png').exists()]
    cols, pad, label = 4, 16, 28
    tw, th = W * 4, H * 4
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * (tw + pad) + pad, rows * (th + label + pad) + pad), (24, 24, 24))
    draw = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        x = pad + (i % cols) * (tw + pad)
        y = pad + (i // cols) * (th + label + pad)
        draw.text((x, y + 6), n, fill=(230, 230, 230))
        sheet.paste(Image.open(PREVIEW / f'{n}_c64.png'), (x, y + label))
    sheet.save(PREVIEW / 'contact_sheet.png')


if __name__ == '__main__':
    for name in sys.argv[1:] or CONFIGS:
        run(name)
    contact_sheet()
