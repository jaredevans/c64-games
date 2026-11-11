"""Milestone 5: RETURN on the ending screen starts a new game.

The ending screen says so on its last row. The run plays to the ending (Voss names Corwin, the
squad leaves), RETURN is pressed there (RESTART_TEST types it), and the game starts over.

The strong check: a breakpoint at boot_done (the end of start-up, just before the interrupts go on)
is hit on the first boot and again after the restart, and the two memory images must agree: zero
page, the whole program with its data (the map included, so the gate and hatch are shut again),
both screens, the character set and colour RAM. Only scratch and test-bookkeeping variables may
differ (ALLOWED below); a game variable that keeps its value into the new game fails this test.
After the restart the squad can walk: the script's last steps run in the new game."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import vice  # noqa: E402

# may differ between the first boot and the restart: scratch the next use rewrites, the talking
# screen's working state (reset on entering a conversation), the portrait cache (kept on purpose:
# PORTRAIT_BUF still holds that face, the REU still holds its faces) and test bookkeeping
ALLOWED = {
    'zp_src', 'zp_dst', 'zp_col', 'zp_tmp', 'zp_row', 'view_page', 'view_colhi', 'view_cx', 'view_cy',
    'view_row', 'view_end', 'script_ptr', 'script_left', 'pp_i', 'pp_dir', 'pp_dx', 'pp_hi', 'pp_msb',
    'pp_bit', 'dlg_ptr', 'bm_ptr', 'bm_cptr', 'bm_src', 'txt_ptr', 'bm_col', 'bm_row', 'bm_fg', 'conv_n',
    'tr_rev', 'kb_row0', 'kb_row1', 'kb_row2', 'kb_row3', 'kb_row4', 'kb_row5', 'kb_row6', 'kb_row7',
    'nt_code', 'nt_dir', 'cs_code', 'cs_col', 'og_i', 'tv_hi', 'tr_n', 'tr_t', 'tr_bit', 'end_n',
    'kd_col', 'kd_i', 'kd_w', 'kd_row', 'kd_len', 'kd_s', 'conv_buf', 'conv_i', 'conv_redraws', 'conv_batch',
    'conv_dirty', 'conv_j', 'conv_col', 'conv_text', 'eye_n', 'eye_i', 'talk_spren', 'spr_save',
    'spr_save_col', 'spr_save_mc', 'talk_people_i', 'talk_person', 'input_len', 'input_buf',
    'face_loaded', 'face_cached', 'face_disk_loads', 'reu_c64', 'reu_off', 'reu_len', 'reu_probe',
    'ts_pos', 'ts_wait', 'tod_snap', 'restarted',
    # set before use in every step or frame: the camera being built, the decoded direction, the
    # glide pixel, the sprite-enable shadow, the raster chain's per-frame values; and the file name
    # portrait_load last asked for
    'bcam_x', 'bcam_y', 'cur_dir', 'glide_p', 'spr_enable', 'map_k', 'map_d011', 'map_d016', 'hud_d011',
    'face_name',
}
WAIT = 8.0


def owner(labels, a):
    """The variable (lower-case label at or below address a) a byte belongs to."""
    best = None
    for name, v in labels.items():
        if name[:1].islower() and '.' not in name and v <= a and (best is None or v > best[1]):
            best = (name, v)
    return best[0] if best else f'${a:04x}'


def main():
    prg = vice.build({'AUTOWALK': 41, 'TYPESCRIPT': 13, 'KNOW_HATCH': 1, 'PROOFS': 2, 'RESTART_TEST': 1})
    lab = vice.labels(prg)
    top = lab['PORTRAIT_BUF']
    regions = [(0x02, 0x4e), (0x0801, top - 0x0801), (0xc000, 0x1000), (0xd800, 1000)]
    hits, later = vice.break_reads(prg, lab['boot_done'], 2, regions, after=[
        (WAIT, lab['leader_x'], 2), (WAIT, lab['game_over'], 1), (WAIT, lab['game_mode'], 1),
        (WAIT, lab['restarted'], 1), (WAIT, lab['known_n'], 1)])
    first, again = hits
    bad = {}
    for (base, _), a, b in zip(regions, first, again):
        colour = base == 0xd800
        for i, (x, y) in enumerate(zip(a, b)):
            differ = (x & 15) != (y & 15) if colour else x != y     # (colour RAM: low nibble only)
            if differ:
                name = owner(lab, base + i) if base < 0xc000 else f'${base + i:04x}'
                if name not in ALLOWED:
                    bad.setdefault(name, []).append(base + i)
    vice.check(not bad, 'the new game starts exactly as the first did: ' +
               (', '.join(f'{n} ({len(v)} bytes from ${v[0]:04x})' for n, v in sorted(bad.items())) or 'no differences'))
    (lx, ly), over, mode, rs, kn = (later[0][0], later[0][1]), later[1][0], later[2][0], later[3][0], later[4][0]
    vice.check(rs == 1 and over == 0 and mode == 0, f'restarted (flag {rs}), no ending, walking (mode {mode})')
    vice.check((lx, ly) == (lab['MAP_START_X'], lab['MAP_START_Y'] - 2) and kn == 4 + 1 + 2,
               f'the squad walks in the new game: leader ({lx},{ly}), {kn} known (4 + HATCH + 2 proofs seeded)')


if __name__ == '__main__':
    main()
