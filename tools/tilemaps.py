"""The text stored as VDP tilemaps: menus, status labels, spell lists, the save-slot list, the
spaceport menu, the intro caption, the naming screen's key words (written back by gentext.py),
and the rest of the naming screen and the staff credits (read-only). docs/pipeline.md 3.7-3.9
and section 4.

A tilemap cell is two bytes, (tile, attribute). A menu word is a run of text cells (attribute
$10) holding the lower tile of each character's glyph pair; the glyph's upper tile (the JP
dakuten row; in the US font only `"` and the apostrophe have one) goes in the cell one row
above, when the map has a text row there. Each run here records where its lower row is, how
many cells it has, and whether it owns the row above.

Text form of a run: one character per cell, leading spaces kept, trailing ones dropped. The
window's own letter tiles (attribute $11: H P M E L V) read as those letters; a tile that is
neither is {$xx}. `encode()` turns an `en` back into glyph pairs through the US glyph table
(LABEL_7D17, read from the source).
"""
import os
import re

import ps1text as T

# ---------------------------------------------------------------- the layouts
#
# Each segment: (name, file, about, runs). Each run:
#   (where, label, row, col, cells, upper, jp)
# label: the US tilemap's label; row/col: the cell of the run's first character in that map,
# whose rows are ROW_CELLS[label] cells wide; upper: the run owns the text row above.
# jp: (JP bank:addr of the map, its row width in cells, row, col, cells, upper) or, for the
# status labels, whose JP dakuten row is the shared row 1B:BCDB, an explicit upper address.

ROW_CELLS = {
    'LABEL_B27_B40B': 6, 'LABEL_B27_B4AB': 8, 'LABEL_B27_B4DB': 8, 'LABEL_B27_B50B': 8,
    'LABEL_B27_B53B': 8, 'LABEL_B27_B56B': 6, 'LABEL_B27_B6DF': 6, 'LABEL_B27_BAF7': 10,
    'LABEL_B27_BB1F': 6, 'LABEL_B27_BB8B': 6, 'LABEL_B27_BC0F': 5, 'LABEL_B27_BC55': 6,
    'LABEL_B27_BC91': 5, 'LABEL_3881': 8, 'LABEL_3891': 8, 'LABEL_38A1': 8, 'LABEL_38B1': 8,
    'LABEL_3639': 6, 'LABEL_3AC4': 9, 'LABEL_B18_BE84': 8, 'LABEL_B18_BEF4': 20,
}
BANK27 = os.path.join('banks', 'bank27.asm')
BANK18 = os.path.join('banks', 'bank18.asm')


def _same(label, rows, col, cells, first_upper=False, bank=0x1B):
    """Runs at `rows` of a map the JP has at the same address and size; every row but the
    first word's owns the row above (the gap between two words), `first_upper` the first's."""
    addr = int(label[-4:], 16)
    out = []
    for n, r in enumerate(rows):
        up = first_upper or n > 0
        out.append((label, r, col, cells, up, ((bank, addr), ROW_CELLS[label], r, col, cells, up)))
    return out


def _layout():
    segs = []

    def seg(name, f, about, runs, where):
        segs.append((name, f, about, [(w,) + r for w, r in zip(where, runs)]))

    party = ['Alis', 'Myau', 'Odin', 'Noah']
    seg('name_boxes', BANK27, 'The four one-name boxes (LABEL_B27_B40B, 36 bytes each).',
        [r[:4] + (False, r[5][:5] + (False,)) for r in _same('LABEL_B27_B40B', [1, 4, 7, 10], 1, 4)],
        party)
    seg('status_boxes', BANK27, 'The battle status boxes, a name centred in 6 cells over the HP '
        'and MP row (LABEL_B27_B4AB-B53B).',
        [_same(l, [1], 1, 6)[0] for l in ('LABEL_B27_B4AB', 'LABEL_B27_B4DB', 'LABEL_B27_B50B',
                                          'LABEL_B27_B53B')], party)
    seg('battle_menu', BANK27, 'The battle commands (LABEL_B27_B56B).',
        _same('LABEL_B27_B56B', [1, 3, 5, 7, 9], 1, 4), ['attack', 'magic', 'item', 'talk', 'run'])
    spells, where = [], []
    names = [('Alis', 'battle'), ('Myau', 'battle'), ('Noah', 'battle'),
             ('Alis', 'field'), ('Myau', 'field'), ('Noah', 'field')]
    for n, (who, mode) in enumerate(names):
        rows = [12 * n + 2 * k + 2 for k in range(5)]
        spells += _same('LABEL_B27_B6DF', rows, 1, 4, first_upper=True)
        where += ['%s, %s, slot %d' % (who, mode, k + 1) for k in range(5)]
    seg('spells', BANK27, 'The six spell lists (LABEL_B27_B6DF, 12 rows of 6 cells each; '
        'LABEL_3478 picks one: Noah is list 2, field magic adds 3). The window shows 2n+1 rows '
        'for n known spells. The spells have no other name table.', spells, where)
    seg('inventory', BANK27, 'The inventory\'s "next page" row, drawn from 9 items '
        '(LABEL_B27_BAF7).', _same('LABEL_B27_BAF7', [1], 1, 8, first_upper=True), ['next page'])
    seg('party_menu', BANK27, 'Choose a party member (LABEL_B27_BB1F).',
        _same('LABEL_B27_BB1F', [1, 3, 5, 7], 1, 4), party)
    seg('field_menu', BANK27, 'The field commands (LABEL_B27_BB8B).',
        _same('LABEL_B27_BB8B', [1, 3, 5, 7, 9], 1, 4),
        ['status', 'magic', 'item', 'search', 'save'])
    seg('item_menu', BANK27, 'What to do with an item (LABEL_B27_BC0F).',
        _same('LABEL_B27_BC0F', [1, 3, 5], 1, 3), ['use', 'equip', 'drop'])
    seg('shop_menu', BANK27, 'Buy or sell (LABEL_B27_BC55).',
        _same('LABEL_B27_BC55', [1, 3], 1, 4), ['buy', 'sell'])
    seg('yes_no', BANK27, 'The YES/NO prompt (LABEL_B27_BC91).',
        _same('LABEL_B27_BC91', [1, 3], 1, 3), ['yes', 'no'])
    seg('status_labels', 'ps1.asm', 'The status window\'s labels (bank 0 LABEL_3881-38B1, one row '
        'each; the value follows in the same row). Their upper row is the shared blank row '
        'LABEL_B27_BCDB, so a run here has no upper tiles of its own (the JP\'s dakuten sit in '
        'its JP copy). LV and EP (LABEL_3865, LABEL_3875) are window tiles, not text.',
        [(l, 0, 1, 7, False, ((0, ja), 8, 0, 1, 7, (0x1B, 0xBCDD)))
         for l, ja in (('LABEL_3881', 0x399E), ('LABEL_3891', 0x39AE), ('LABEL_38A1', 0x39BE),
                       ('LABEL_38B1', 0x39CE))],
        ['attack', 'defense', 'max HP', 'max MP'])
    seg('money', 'ps1.asm', 'The meseta label (bank 0 LABEL_3639). The money box shows its first '
        '3 cells; the status window shows 5, the last 2 blank.',
        [('LABEL_3639', 0, 1, 3, False, ((0, 0x3756), 6, 0, 1, 3, False))], ['meseta'])
    seg('save_slots', 'ps1.asm', 'The save-slot list (bank 0 LABEL_3AC4): only the slot numbers, '
        'one cell; the rest of each row is left blank. It is copied to save RAM ($8100) when the '
        'save RAM is formatted and drawn from there, so a change shows only on a fresh save RAM.',
        [r[:5] + (((0, 0x3BE8),) + r[5][1:],) for r in
         _same('LABEL_3AC4', [2, 4, 6, 8, 10], 1, 1, first_upper=True)],
        ['slot %d' % n for n in range(1, 6)])
    seg('spaceport', BANK18, 'The spaceport destinations (bank 18 LABEL_B18_BE84, 7 x 8 cells, '
        'via LABEL_3A21). The JP menu is a 8 x 5 map at 03:BEB2, drawn at $7AAA.',
        [('LABEL_B18_BE84', r, 1, 6, r > 1, ((3, 0xBEB2), 5, jr, 1, 3, True))
         for r, jr in ((1, 2), (3, 4), (5, 6))], ['Gothic', 'Uzo', 'Skure'])
    seg('intro_caption', BANK18, 'The caption before the intro (bank 18 LABEL_B18_BEF4, 5 x 20 '
        'cells at $7886; LABEL_B18_BF20-BF80 fall inside it). The JP caption is a 5 x 15 map at '
        '03:BF02 with its own tiles $B8-$BF (from 10:BF5E): A, W, 年, $BB, 星, $BD, $BE, 区 '
        '($BB, $BD and $BE are kanji not read with certainty: perhaps 春, and 街 for $BE).',
        [('LABEL_B18_BEF4', 1, 1, 18, False, ((3, 0xBF02), 15, 1, 1, 13, False)),
         ('LABEL_B18_BEF4', 3, 1, 18, True, ((3, 0xBF02), 15, 3, 1, 13, True))],
        ['line 1', 'line 2'])
    return segs


LAYOUT = _layout()

# the JP intro caption's own tiles (10:BF5E, loaded at tile $B8); $BB $BD $BE stay {$xx}
JP_CAPTION_TILES = {0xB8: 'A', 0xB9: 'W', 0xBA: '年', 0xBC: '星', 0xBF: '区'}
WINDOW_LETTERS = {0xF4: 'H', 0xF5: 'P', 0xF6: 'M', 0xF7: 'E', 0xFA: 'L', 0xFB: 'V'}
BLANK = 0xC0


# ---------------------------------------------------------------- glyph tables

def us_glyph_table(src_lines=None, defs=None):
    """code -> (upper, lower) for $20-$5A, from LABEL_7D17 in ps1.asm."""
    defs = defs or T.defines()
    lines = src_lines or T.read(os.path.join(T.DISASM, 'ps1.asm')).split('\r\n')
    i = lines.index('LABEL_7D17:') + 1
    data = bytearray()
    while len(data) < 2 * 0x46:
        b = T.parse_db(lines[i], defs)
        if b is not None:
            data += b
        i += 1
    return {c: (data[2 * (c - 0x20)], data[2 * (c - 0x20) + 1]) for c in range(0x20, 0x5B)}


def us_glyph_table_rom(rom):
    o = T.rom_offset(1, 0x7D17)
    return {c: (rom[o + 2 * (c - 0x20)], rom[o + 2 * (c - 0x20) + 1]) for c in range(0x20, 0x5B)}


def us_inverse(glyphs):
    """(upper, lower) -> character, for decoding."""
    inv = {}
    for c in sorted(glyphs, key=lambda c: (c == 0x27, c)):     # the apostrophe is $40
        ch = T.us_char(c)
        if ch.startswith('{'):
            continue                                           # a blank code
        inv.setdefault(glyphs[c], ch)
    return inv


def jp_inverse(jp_rom):
    """(upper, lower) -> kana, from the JP glyph table 02:8000, plus the digits."""
    o = 2 * 0x4000
    inv = {}
    for c in range(len(T.JP_KANA)):
        inv.setdefault((jp_rom[o + 2 * c], jp_rom[o + 2 * c + 1]), T.JP_KANA[c])
    for d in range(10):
        inv.setdefault((BLANK, 0xC1 + d), str(d))
    return inv


# ---------------------------------------------------------------- cells <-> text

def decode(lower, upper, inv, extra=None):
    """Cells -> text form. lower/upper: (tile, attr) byte strings (upper may be None)."""
    out = []
    for i in range(len(lower) // 2):
        t, a = lower[2 * i], lower[2 * i + 1]
        u = upper[2 * i] if upper else BLANK
        if a & 0x01:
            out.append(WINDOW_LETTERS.get(t, '{$%02X}' % t))
        elif (u, t) in inv:
            out.append(inv[(u, t)])
        elif u == BLANK and extra and t in extra:
            out.append(extra[t])
        elif u == BLANK:
            out.append('{$%02X}' % t)
        else:
            out.append('{$%02X:$%02X}' % (u, t))
    return ''.join(out).rstrip(' 　')


CELL = re.compile(r'\{\$([0-9A-Fa-f]{2})\}|.')


def encode(text, glyphs, cells, upper):
    """Text form -> [(upper tile, lower tile)] * cells, through the US glyph table, padded with
    blanks. Raises ValueError on a missing glyph, a run too long, or an upper tile in a run
    without an upper row."""
    pairs = []
    for m in CELL.finditer(text):
        if m.group(1):
            pairs.append((BLANK, int(m.group(1), 16)))
            continue
        c = m.group(0)
        if c not in T.US_TEXT:
            raise ValueError('no glyph for %r in %r' % (c, text))
        pairs.append(glyphs[T.US_TEXT[c]])
    if len(pairs) > cells:
        raise ValueError('%r is %d cells; the run has %d' % (text, len(pairs), cells))
    if not upper and any(u != BLANK for u, _ in pairs):
        raise ValueError('%r needs a tile in the row above, and this run has none' % text)
    return pairs + [(BLANK, BLANK)] * (cells - len(pairs))


def cell_width(text):
    return sum(1 for _ in CELL.finditer(text))


def patch(stock, pairs, upper):
    """The stock (tile, attr) bytes with new tiles, attributes kept: (lower, upper)."""
    lo = bytearray(stock[0])
    up = bytearray(stock[1]) if upper else None
    for i, (u, t) in enumerate(pairs):
        lo[2 * i] = t
        if up is not None:
            up[2 * i] = u
    return bytes(lo), (bytes(up) if up is not None else None)


# ---------------------------------------------------------------- extraction

def addr(bank, a):
    return '%02X:%04X' % (bank, a)


def at(rom, a):
    bank, ad = (int(x, 16) for x in a.split(':'))
    return T.rom_offset(bank, ad)


def extract(us_rom, jp_rom, syms):
    """The tilemap segments of script.json, read from both stock ROMs."""
    glyphs = us_glyph_table_rom(us_rom)
    uinv, jinv = us_inverse(glyphs), jp_inverse(jp_rom)
    segs = {}
    for name, f, about, runs in LAYOUT:
        out = []
        for n, (where, label, row, col, cells, upper, jp) in enumerate(runs):
            bank, base = syms[label]
            rb = 2 * ROW_CELLS[label]
            offset = row * rb + 2 * col
            a = T.rom_offset(bank, base) + offset
            lo = us_rom[a:a + 2 * cells]
            up = us_rom[a - rb:a - rb + 2 * cells] if upper else None
            (jb, ja), jrc, jrow, jcol, jcells, jup = jp
            jo = T.rom_offset(jb, ja) + 2 * (jrow * jrc + jcol)
            r = {'id': n, 'where': where, 'label': label, 'offset': offset, 'cells': cells,
                 'upper': upper, 'addr': addr(bank, base + offset), 'hex': lo.hex().upper()}
            if upper:
                r['upper_hex'] = up.hex().upper()
            r['us'] = decode(lo, up, uinv)
            r['jp_addr'] = addr(jb, 0x8000 + jo % 0x4000 if jb >= 2 else jo)
            r['jp_cells'] = jcells
            if jup is True:
                r['jp_upper'] = addr(jb, 0x8000 + (jo - 2 * jrc) % 0x4000 if jb >= 2 else jo - 2 * jrc)
            elif jup:
                r['jp_upper'] = addr(*jup)
            r['jp'] = jp_text(jp_rom, r, jinv)
            r['en'] = r['us']
            out.append(r)
        segs[name] = {'kind': 'tilemap', 'file': f.replace(os.sep, '/'), 'about': about,
                      'runs': out}
    segs['naming_screen'] = naming_segment(us_rom, jp_rom, uinv, jinv)
    segs['naming_keys'] = naming_keys_segment(us_rom, jp_rom, uinv, jinv)
    segs['credits'] = credits_segment(us_rom, jp_rom)
    return segs


def jp_text(jp_rom, r, jinv=None):
    jinv = jinv or jp_inverse(jp_rom)
    o = at(jp_rom, r['jp_addr'])
    lo = jp_rom[o:o + 2 * r['jp_cells']]
    up = None
    if 'jp_upper' in r:
        u = at(jp_rom, r['jp_upper'])
        up = jp_rom[u:u + 2 * r['jp_cells']]
    return decode(lo, up, jinv, JP_CAPTION_TILES if r['jp_addr'].startswith('03:BF') else None)


def us_text(us_rom, r, uinv):
    o = at(us_rom, r['addr'])
    lo = us_rom[o:o + 2 * r['cells']]
    up = None
    if r['upper']:
        rb = 2 * ROW_CELLS[r['label']]
        up = us_rom[o - rb:o - rb + 2 * r['cells']]
    return lo, up, decode(lo, up, uinv)


# ---------------------------------------------------------------- read-only: naming screen

NAMING = {'us': (0x423C, True), 'jp': (0x4406, False)}     # 01:addr, a blank after each counted tile


def unpack_naming(rom, lang):
    """The naming screen's RLE (LABEL_4166; the JP's at 01:42DA) -> tiles, 32 a row."""
    o, gap = NAMING[lang]
    out = []
    while True:
        n = rom[o]
        o += 1
        if n == 0:
            return out
        if n < 0x80:
            out += [rom[o]] * n
            o += 1
        elif n & 0x40:
            out += list(rom[o:o + (n & 0x3F)])
            o += n & 0x3F
        else:
            for i in range(n & 0x3F):
                out.append(rom[o] + i)
                if gap:
                    out.append(BLANK)
            o += 1


def naming_lines(rom, lang, inv):
    """The screen's text lines, top to bottom. Each tile row is read with the row above as
    its upper tiles; the frame rows, blank rows and rows that hold only upper tiles (the
    dakuten over a row of keys, the `"` key's upper half) are not lines of their own."""
    tiles = unpack_naming(rom, lang)
    rows = [tiles[i:i + 32] for i in range(0, len(tiles), 32)][1:-1]
    uppers = {u for u, _ in inv if u != BLANK}
    lines = []
    for i, row in enumerate(rows):
        if all(t == BLANK for t in row) or all(t == BLANK or t in uppers for t in row):
            continue
        above = rows[i - 1] if i else [BLANK] * len(row)
        lo = bytes(x for t in row for x in (t, 0x10))
        up = bytes(x for t in above for x in (t, 0x10))
        lines.append(decode(lo, up, inv))
    return lines


def naming_segment(us_rom, jp_rom, uinv, jinv):
    return {'kind': 'readonly',
            'about': 'The naming screen (US LABEL_423C, unpacked by LABEL_4166; JP 01:4406, '
                     'unpacked by 01:42DA, consecutive tiles with no blank between). Read-only: '
                     'gentext does not write it (its three key words are naming_keys). A new '
                     'grid also needs a new key table (LABEL_4280).',
            'runs': [{'id': 0, 'us': '{BR}'.join(naming_lines(us_rom, 'us', uinv)),
                      'jp': '{BR}'.join(naming_lines(jp_rom, 'jp', jinv))}]}


# the key words: in the RLE's last literal run (its count byte $CB at LABEL_423C + 47: 11 tiles,
# the words with a blank between), lower tiles only - the row above them is blank
NAMING_LABEL = 'LABEL_423C'
NAMING_KEYS = [('forward', 48), ('delete', 52), ('end', 56)]
NAMING_RUN = 47


def naming_keys_segment(us_rom, jp_rom, uinv, jinv):
    base = NAMING['us'][0]
    jp = [w for w in naming_lines(jp_rom, 'jp', jinv)[-1].split('　') if w][-3:]
    runs = []
    for n, ((where, off), j) in enumerate(zip(NAMING_KEYS, jp)):
        tiles = us_rom[base + off:base + off + 3]
        runs.append({'id': n, 'where': where, 'label': NAMING_LABEL, 'offset': off, 'cells': 3,
                     'upper': False, 'addr': addr(1, base + off), 'hex': tiles.hex().upper(),
                     'us': naming_text(tiles, uinv), 'jp': j})
        runs[-1]['en'] = runs[-1]['us']
    return {'kind': 'naming', 'file': 'ps1.asm',
            'about': 'The naming screen\'s three key words (in LABEL_423C\'s last literal run, '
                     'byte 47: 11 tiles), 3 cells each in the stock font, capitals, no row '
                     'above. gentext writes the lower tiles in place; the JP is from 01:4406.',
            'runs': runs}


def naming_text(tiles, inv):
    return decode(bytes(x for t in tiles for x in (t, 0x10)), None, inv)


# ---------------------------------------------------------------- read-only: credits

CREDITS = (20, 0xBDB8)


def credit_screens(rom):
    """[[(row, col, text)]] for screens 2-15 of LABEL_B20_BDB8."""
    bank, base = CREDITS
    p = T.rom_offset(bank, base)
    ptr = [int.from_bytes(rom[p + 2 * i:p + 2 * i + 2], 'little') for i in range(16)]
    screens = []
    for s in range(2, 16):
        o = T.rom_offset(bank, ptr[s])
        recs = []
        for _ in range(rom[o]):
            a = int.from_bytes(rom[o + 1:o + 3], 'little')
            n = rom[o + 3]
            recs.append(((a - 0xD000) // 64, (a - 0xD000) % 64 // 2,
                         rom[o + 4:o + 4 + n].decode('latin-1')))
            o += 3 + n
        screens.append(recs)
    return screens


def credits_segment(us_rom, jp_rom):
    us, jp = credit_screens(us_rom), credit_screens(jp_rom)
    runs = []
    for n, (u, j) in enumerate(zip(us, jp)):
        runs.append({'id': n + 2,
                     'us': '{BR}'.join(t for _, _, t in u),
                     'us_at': [[r, c] for r, c, _ in u],
                     'jp': '{BR}'.join(t for _, _, t in j),
                     'jp_at': [[r, c] for r, c, _ in j]})
    return {'kind': 'readonly',
            'about': 'The staff credits (LABEL_B20_BDB8: screens 2-15, each a list of (row, col, '
                     'ASCII) records in the credits font, A-Z only; us_at/jp_at give each '
                     'record\'s row and column). Read-only: whether to translate them is the '
                     'owner\'s call. The JP is ASCII too; the US adds FINOS PATA.',
            'runs': runs}


# ---------------------------------------------------------------- the source

def label_bytes(lines, label, n, defs):
    """[(line index, bytes)] of the .db lines from `label:` on, until n bytes; lines that
    are not .db lines (blank, comments, labels inside the map) are skipped."""
    i = lines.index(label + ':') + 1
    out, have = [], 0
    while have < n:
        b = T.parse_db(lines[i], defs)
        if b is not None:
            out.append((i, b))
            have += len(b)
        i += 1
    return out


def write_bytes(lines, label, offset, data, defs):
    """Put `data` at byte `offset` of the map at `label`, rewriting only the .db lines whose
    bytes change (as $xx lists, keeping each line's .db prefix)."""
    pos = 0
    for i, b in label_bytes(lines, label, offset + len(data), defs):
        new = bytearray(b)
        for k in range(len(b)):
            if offset <= pos + k < offset + len(data):
                new[k] = data[pos + k - offset]
        if new != b:
            prefix = re.match(r'\s*\.db\s+', lines[i]).group(0)
            lines[i] = prefix + ', '.join('$%02X' % x for x in new)
        pos += len(b)


def read_bytes(lines, label, offset, n, defs):
    data = b''.join(b for _, b in label_bytes(lines, label, offset + n, defs))
    return data[offset:offset + n]
