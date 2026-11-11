# Nuclear Land

<img src="nuclear-land-preview.png" alt="Nuclear Land walking screen" width="600" />

A prototype post-apocalyptic party RPG for the **Commodore 64**, written from scratch in 6502
assembly, assembled with [ACME](https://sourceforge.net/projects/acme-crossass/) and tested in the
[VICE](https://vice-emu.sourceforge.io/) `x64sc` emulator (PAL). **Work in progress.**

## The game (planned)

Some decades after a nuclear war, the town of **Cinderhill** survives on a small pre-war reactor
that powers its lights, water pump and greenhouse. Lately the reactor has been sputtering, and
**Abel Voss**, the engineer who kept it alive, has vanished. The town has split in two: the
**Keepers** guard the reactor as sacred, while the **Dimmers** want it shut down before it kills
everyone. Rumour says outsiders sabotaged it — and your squad has just walked in.

You explore the ruined town as a four-person squad and talk to the people who live there by
typing keywords. Townspeople are wary of strangers and open up as their trust in you grows; each
conversation gives up a piece of the mystery. The squad:

| Member | Skill |
|--------|-------|
| **Vesna** | Talker |
| **"Dials" Okonkwo** | Tinker |
| **Sister Maren** | Medic |
| **Rook** | Scout |

Combat, an overworld and saving are out of scope for the prototype — the point is the town and
its people.

## Status

**Milestone 1 — walking engine (done).** A 64×48-tile test map scrolls under a single squad
figure:

- Smooth 8-frame glide per tile step in all four directions, chaining with no stall while a key
  is held.
- Hardware fine scroll (`$D016` / `$D011`) with double-buffered coarse scrolling — no tearing.
- The status line and the squad strip stay rock-still while the map scrolls beneath them.
- At the map's edges the camera stops and the figure walks on instead.
- Walls and buildings block movement.
- Runs at a steady 50 fps (PAL).

**Next:** Cinderhill itself — the real town map, townspeople, and the talking screen.

## Running it

From `nuclear-land/`:

```sh
mkdir -p build
acme -f cbm -o build/nland.prg main.asm
x64sc -pal -autostartprgmode 1 -autostart "$PWD/build/nland.prg"
```

Pass an **absolute** path to the PRG — on macOS the `x64sc` wrapper starts VICE from inside the
app bundle, so a relative path isn't found. The game is PAL-only; keep `-pal` if your VICE is
set to NTSC.

### Controls

| Key | Action |
|-----|--------|
| Cursor keys | Move up / down / left / right |
| `I` / `K` / `J` / `L` | Move up / down / left / right |

Both sets always work. There is no joystick support.

## Building the assets

The tile graphics and map binaries in `gen/` are generated and committed. To rebuild them after
editing the tile art in `tools/make_tiles.py` or a map in `maps/`:

```sh
python3 tools/make_map.py testmap     # also regenerates gen/tiles.bin, tilecolors.bin, tiles.inc
```

Maps are plain 64×48 ASCII: `.` ground, `=` road, `:` rubble, `#` wall.

## Tests

The tests run the real PRG headless in VICE, then compare screenshots pixel by pixel and read
game state through VICE's binary monitor. They need Python 3 with Pillow, and they expect VICE at
`/Applications/vice-arm64-gtk3-3.10/bin/x64sc` (set `X64SC` in `tests/vice.py` otherwise).

```sh
python3 tests/run_all.py
```

Each test forces a default PAL machine and never writes to your VICE settings. Special builds
(`-DAUTOWALK=n`, `-DFIXED_FY=n`, `-DSTRESS=1`, …) script the walking, pin the scroll position or
add load so every frame of a glide can be checked.

## How it works

| File | Role |
|------|------|
| `main.asm` | Start-up, memory setup, main loop |
| `irq.asm` | Raster interrupt chain: status line, map band, HUD |
| `walk.asm` | Step glide, camera, collision, edge clamp |
| `view.asm` | Draws the map into the back screen buffer |
| `input.asm` | Keyboard matrix scan (arrows + IJKL) |
| `hud.asm` | Status line and squad strip |
| `charset.asm` | Builds the character set (ROM font + tiles) |
| `hw.inc` | Hardware registers and memory map |

- **Memory:** VIC bank 3 — two screen buffers at `$C000` / `$C400`, the character set at
  `$C800`, the squad sprite at `$E000`. BASIC ROM is banked out so the colour buffer at `$B800`
  reads back as RAM.
- **Character set:** codes 0–63 are the C64 ROM font, copied in at start-up. Tiles start at
  `$40`, and every tile code from `$80` up is impassable, so collision is a single compare.
- **Split screen:** a three-stage raster interrupt chain runs the status line and HUD at
  40 columns with no scroll, and the map band in between at 38 columns with the frame's fine
  scroll.
- **Vertical scrolling:** uses FLD — badlines are only ever *delayed*, never brought forward, so
  rows never get fetched twice and the HUD never slips. The map shows through a fixed window
  (raster lines 74–210), so its top and bottom edges don't bounce as it scrolls.
- **Coarse scrolling:** each step redraws the back buffer in thirds across the first frames of
  the glide, then flips buffers mid-glide. The colour RAM copy is unrolled to fit in the
  flip frame.
