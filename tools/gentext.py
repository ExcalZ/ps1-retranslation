"""Write work/dialogue.json and work/script.json into the source.

    python tools/gentext.py [--check] [--dialogue=PATH] [--script=PATH]

* The script is written whole into PSI_Disasm/text/ (textsrc.FILES): dialogue.asm
  (DialogueBlock, the 341 pointers in id order, then the dialogue blocks), cutscenes.asm and
  messages.asm, one label per entry in JSON order; an entry without a label follows the
  previous one (the game reaches it by reading on). The source includes them where the stock
  had them, or in banks 32-34 with relocate_script (ext/banks.asm).
* The name fields (CharacterNames, ItemNames, the first line of each Enemy_* record in
  banks/bank03.asm) are rewritten line by line, only where the bytes change.
* ext/longnames_data.asm (long_names) is written whole from the party's names: LongNames for
  {NAME}, and the name boxes and party menu two cells wider than bank 27's, in capitals. With
  long_names CharacterNames and the stock name_boxes / party_menu maps keep their stock bytes.
* ext/longitems_data.asm (long_item_names) likewise: LongItems and LongEnemies, 14 characters
  each; with long_item_names ItemNames and the enemy records' names keep their stock bytes.
* The tilemap runs of script.json (kind `tilemap`: menus, spell lists, status labels, save
  slots, spaceport, intro caption; tools/tilemaps.py) are written into their maps' `.db`
  lines in ps1.asm, banks/bank27.asm and banks/bank18.asm, through the glyph table
  (LABEL_7D17): the lower tile in the run's row, the upper tile in the row above where the run
  owns it. Only lines whose bytes change are rewritten. The naming screen's key words (kind
  `naming`) go in place into its RLE (LABEL_423C), lower tiles only. Segments of kind
  `readonly` (the rest of the naming screen, the credits) are not written.
* ext/macros_data.asm (battle_macros): its windows' maps from bank 27's battle and field menus,
  with the words of segment macro_words (kind `macro`: no stock text) and battle_menu's.
* ext/longnames_data.asm also ends in the hospital menu's Everyone row (hospital_everyone), from
  segment hospital_words (kind `macro` too: a word with no stock text, in the face).
* An entry of dialogue.json marked `added` is an option's new line, with no stock text (`us` and
  `hex` empty, no `addr`); it is written like any other, and with en = us (checkstock) it is a
  label with no bytes.

An entry whose `en` equals its `us` is written from `hex`: the stock bytes, so with en = us
everywhere the ROM is the stock one (checkstock.py). Any other `en` is encoded for the stock
engine (ps1text.encode_us: upper case, the dictionary; mixed case in the face where
vwf_dialogue / vwf_cutscene draw it). With those options the face's printer does not
auto-wrap, so an entry still in its stock English in a face window is encoded from its `us`
text with every line break written out, re-wrapped where it overflows (tools/stockwrap.py).
The files keep their CRLF endings.
--check writes nothing and fails if a file would change. --encode-all encodes every entry,
the stock ones too (a test of the encoder: the game must still assemble and read the same).
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ps1text as T
import scriptdict
import stockwrap as W
import textsrc as S
import tilemaps as M

WORK = os.path.join(T.ROOT, 'work')
STRING_SAFE = set(range(0x20, 0x5B)) - {0x40}


def tokens(data, names):
    """Bytes -> WLA .db items: strings, define names, $hex."""
    out, run = [], []

    def flush():
        if run:
            out.append('"%s"' % ''.join('\\"' if b == 0x22 else chr(b) for b in run))
            run.clear()

    for b in data:
        if b in STRING_SAFE:
            run.append(b)
            continue
        flush()
        out.append(names.get(b, '$%02X' % b))
    flush()
    return out


def db_lines(data, names):
    """Bytes -> `.db` lines, broken after each new line, page and end code."""
    lines, cur = [], bytearray()
    for b in data:
        cur.append(b)
        if b in (0x60, 0x61) or b in S.TERM_US:
            lines.append(bytes(cur))
            cur = bytearray()
    if cur:
        lines.append(bytes(cur))
    return ['.db ' + ', '.join(tokens(l, names)) for l in lines]


ENCODE_ALL = '--encode-all' in sys.argv


OPTIONS = T.options()
VWF_KINDS = (({'dialogue', 'message'} if OPTIONS.get('vwf_dialogue') == 1 else set())
             | ({'cutscene'} if OPTIONS.get('vwf_cutscene') == 1 else set()))
LONG = OPTIONS.get('long_names') == 1
LONG_ITEMS = OPTIONS.get('long_item_names') == 1
SCRIPT_DICT = OPTIONS.get('script_dictionary') == 1
WIN = OPTIONS.get('vwf_windows') == 1
# vwf_windows: the tilemap segments whose runs are drawn in the face (ext/vwfwin.asm; the status
# window's labels through WinLabel, the money line through WinMoney). The rest keep the fixed
# font: the save slots from the cartridge RAM, the intro caption in a cut-scene.
WIN_SEGMENTS = ('battle_menu', 'field_menu', 'item_menu', 'shop_menu', 'yes_no', 'spells',
                'spaceport', 'status_boxes', 'inventory', 'status_labels')
WIN_PARTY = 0xF0                       # string ids $F0-$F3: the party's names (LongNames)


def win_spell_maps(lines27, defs):
    """vwf_windows: the six spell lists (LABEL_B27_B6DF, 12 rows of 6 cells each) and the blank
    one (LABEL_B27_BA3F) a cell wider before the right frame: a border row gets another frame
    piece, a marked run another cell (5: a spell name in the face up to 40 px), a blank row a
    blank. From bank 27 as the tilemap writer left it (the runs marked)."""
    def stock(label, n):
        return b''.join(b for _, b in M.label_bytes(lines27, label, n, defs))[:n]

    def widen(row):
        cells = [row[i:i + 2] for i in range(0, 12, 2)]
        if cells[0][0] == 0xF1:
            fill = cells[1]
        elif cells[4][1] & 0x20:
            fill = bytes([0, 0x30])
        else:
            fill = bytes([M.BLANK, 0x10])
        return b''.join(cells[:5] + [fill] + cells[5:])

    out = ['; vwf_windows: the spell lists a cell wider (12 rows of 7 cells; from bank 27\'s maps)',
           'WinSpellMaps:']
    lists = stock('LABEL_B27_B6DF', 6 * 144)
    for i in range(0, len(lists), 12):
        out.append('.db ' + ', '.join('$%02X' % b for b in widen(lists[i:i + 12])))
    out.append('WinSpellBlank:')
    blank = stock('LABEL_B27_BA3F', 144)
    for i in range(0, len(blank), 12):
        out.append('.db ' + ', '.join('$%02X' % b for b in widen(blank[i:i + 12])))
    return '\r\n'.join(out) + '\r\n'


def win_run(string_id, cells):
    """A marked run (vwf_windows): (id, $30), then (0, $30) for each further cell."""
    return bytes([string_id, 0x30]) + bytes([0, 0x30]) * (cells - 1)


class WinStrings:
    """The string table of vwf_windows, in the face's codes; id 0 is never a string."""
    def __init__(self):
        self.texts = []
        self.money = 'MST'                  # the money line's label (WinMoneyString)

    def add(self, text):
        if text not in self.texts:
            self.texts.append(text)
        return self.texts.index(text) + 1

    def asm(self):
        charset = T.vwf_charset()
        lines = ['; Generated by tools/gentext.py from work/script.json - do not edit by hand.',
                 '; vwf_windows: the menus\' strings (the face\'s codes, $65-ended) by id; 0 is none.',
                 'WinStrings:', '.dw 0']
        lines += ['.dw WinString%d' % (i + 1) for i in range(len(self.texts))]
        for i, t in enumerate(self.texts):
            codes = [charset[c] for c in t] + [0x65]
            lines.append('WinString%d:\t; %s' % (i + 1, t))
            lines.append('.db ' + ', '.join('$%02X' % c for c in codes))
        # the money line: the label and a space; WinMoney draws the amount after it
        lines.append('WinMoneyString:\t; %s' % self.money)
        lines.append('.db ' + ', '.join('$%02X' % c for c in [charset[c] for c in self.money + ' '] + [0x65]))
        return '\r\n'.join(lines) + '\r\n'


def entry_bytes(e, text, words):
    """text: the entry's text in this build (tools/stockwrap.py: its en, or the stock text
    re-wrapped for the proportional windows)."""
    if ENCODE_ALL and e['en'] == e['us']:
        return T.encode_us(text, words, charset=T.vwf_charset() if e['kind'] in VWF_KINDS else None)
    return W.entry_bytes(e, text, words, OPTIONS)


def field_bytes(run, width, words):
    if run['en'] == run['us']:
        return bytes.fromhex(run['hex'])
    b = T.encode_us(run['en'], words, dictionary=False)
    if any(T.us_kind(x) != 'char' for x in b):
        raise ValueError('a name field holds text only: %r' % run['en'])
    if len(b) > width:
        raise ValueError('%r is %d cells; the field has %d' % (run['en'], len(b), width))
    if len(b) < width:
        b += b'\x65' + b' ' * (width - len(b) - 1)
    return b


def control_names(defs):
    names = {} if SCRIPT_DICT else T.word_names(defs)  # script_dictionary: the codes are other words
    for k, v in defs.items():
        if k.startswith('Dialogue_') and k not in ('Dialogue_flags',) and v in (0x40,) + tuple(range(0x5B, 0x66)):
            names.setdefault(v, k)
    return names


def generate(dialogue, script):
    """{path: new text} for every source file gentext owns."""
    defs = T.defines()
    words = T.us_words(defs)
    names = control_names(defs)
    out = {}

    # ---- the text files (text/dialogue.asm, cutscenes.asm, messages.asm)
    entries = dialogue['entries']
    texts = W.texts(entries, script, OPTIONS)
    if SCRIPT_DICT:                     # the words chosen from this build's script
        digest, words = scriptdict.words(texts.values())
        out[scriptdict.PATH] = scriptdict.asm(words, digest)
    for f, kinds in S.FILES:
        path = os.path.join(T.DISASM, f)
        body = [S.HEADER]
        if 'dialogue' in kinds:
            ids = sorted((x for x in entries if x['kind'] == 'dialogue'), key=lambda x: int(x['id'], 16))
            body += ['DialogueBlock:']
            for i in range(0, len(ids), 8):
                body.append('.dw ' + ', '.join(x['label'] for x in ids[i:i + 8]))
        for n, en in enumerate(x for x in entries if x['kind'] in kinds):
            data = entry_bytes(en, texts[en['id']], words)
            if en['label']:
                body += ([''] if len(body) > 1 else []) + [en['label'] + ':']
            else:
                body.append('; %s: read on from the string above' % en['id'])
            body += db_lines(data, names)
        out[path] = '\r\n'.join(body) + '\r\n'

    # ---- the name fields
    segs = script['segments']
    path = os.path.join(T.DISASM, 'ps1.asm')
    lines = T.read(path).split('\r\n')
    for seg, label in (('party', 'CharacterNames'), ('items', 'ItemNames')):
        i = lines.index(label + ':') + 1
        for run in segs[seg]['runs']:
            while T.parse_db(lines[i], defs) is None:
                i += 1
            if seg == 'party' and LONG or seg == 'items' and LONG_ITEMS:
                want = bytes.fromhex(run['hex'])    # the long tables are read instead
            else:
                want = field_bytes(run, segs[seg]['width'], words)
            if T.parse_db(lines[i], defs) != want:
                lines[i] = '.db\t' + ', '.join(tokens(want, names))
            i += 1
    out[path] = '\r\n'.join(lines)

    path = os.path.join(T.DISASM, 'banks', 'bank03.asm')
    lines = T.read(path).split('\r\n')
    for run in segs['enemies']['runs']:
        i = lines.index(run['label'] + ':') + 1
        while T.parse_db(lines[i], defs) is None:
            i += 1
        want = bytes.fromhex(run['hex']) if LONG_ITEMS else field_bytes(run, 8, words)
        have = T.parse_db(lines[i], defs)
        if len(have) != 8:
            raise ValueError('%s: the name line is not 8 bytes' % run['label'])
        if have != want:
            lines[i] = '.db\t' + ', '.join(tokens(want, names))
    out[path] = '\r\n'.join(lines)

    # ---- the tilemaps
    glyphs = M.us_glyph_table(out[os.path.join(T.DISASM, 'ps1.asm')].split('\r\n'), defs)
    files = {}
    strings = WinStrings()
    for name, seg in segs.items():
        if seg.get('kind') != 'tilemap':
            continue
        path = os.path.join(T.DISASM, *seg['file'].split('/'))
        if path not in files:
            files[path] = (out[path] if path in out else T.read(path)).split('\r\n')
        for run in seg['runs']:
            if LONG and seg is segs.get('name_boxes') or LONG and seg is segs.get('party_menu'):
                run = dict(run, en=run['us'])       # long_names draws its own, wider maps
            if WIN and name == 'money':     # drawn by WinMoney: the stock cells stay
                strings.money = run['en'].strip()
                continue
            if WIN and name in WIN_SEGMENTS and run['en'].strip():
                text = run['en'].strip()
                sid = WIN_PARTY + int(run['id']) if name == 'status_boxes' else strings.add(text)
                lo = win_run(sid, run['cells'])
                up = bytes([M.BLANK, 0x10]) * run['cells'] if run['upper'] else None
            else:
                lo, up = tilemap_bytes(run, glyphs)
            M.write_bytes(files[path], run['label'], run['offset'], lo, defs)
            if up is not None:
                M.write_bytes(files[path], run['label'],
                              run['offset'] - 2 * M.ROW_CELLS[run['label']], up, defs)
    for name, seg in segs.items():
        if seg.get('kind') != 'naming':
            continue
        path = os.path.join(T.DISASM, *seg['file'].split('/'))
        if path not in files:
            files[path] = (out[path] if path in out else T.read(path)).split('\r\n')
        for run in seg['runs']:
            M.write_bytes(files[path], run['label'], run['offset'], naming_bytes(run, glyphs), defs)
    for path, lines in files.items():
        out[path] = '\r\n'.join(lines)
    spell_maps = win_spell_maps(files[os.path.join(T.DISASM, 'banks', 'bank27.asm')], defs) if WIN else ''
    out[os.path.join(T.DISASM, 'ext', 'macros_data.asm')] = macros_data(
        script, strings, files[os.path.join(T.DISASM, 'banks', 'bank27.asm')], defs)
    out[os.path.join(T.DISASM, 'ext', 'longnames_data.asm')] = long_names_data(script, defs, strings)
    out[os.path.join(T.DISASM, 'ext', 'vwfwin_data.asm')] = strings.asm() + spell_maps
    out[os.path.join(T.DISASM, 'ext', 'longitems_data.asm')] = long_items_data(script, strings)
    return out


def macros_data(script, strings, lines27, defs):
    """ext/macros_data.asm (battle_macros, needs vwf_windows): the maps of its windows, their
    runs marked with WinStrings ids, from bank 27's battle and field menus as the tilemap writer
    left them: the round's first window (Command, Macro, battle_menu's Talk and Flee; 7 cells),
    the members' commands (battle_menu's Fight, Magic, Item), the field menu with Macro before
    Save (13 rows), the frames of the slots and the preview, the slot letters' string ids (drawn
    by MacroLetter, each in its colour); then the battle spells' string ids
    by list and place, the string Fight, the code of a space and the pool tiles the battle's two
    windows keep (MACRO_MENU_TILES: the most either one's runs take, as WinRun takes them - the
    stock five-word menu took 15, and a battle's lists between rounds have little more room)."""
    import diafont as F

    def tiles(text, cells):
        """WinRun's tiles for a run: the one under the pen after each glyph, within its cells."""
        return min(cells, F.width(text) // 8 + 1) if text else 0

    head = ['; Generated by tools/gentext.py from work/script.json - do not edit by hand.',
            '; battle_macros (ext/macros.asm): its windows\' maps and the strings it draws.']
    if not WIN:
        return '\r\n'.join(head + ['; (needs vwf_windows: nothing to write)']) + '\r\n'
    segs = script['segments']
    word = {r['id']: r['en'].strip() for r in segs['macro_words']['runs']}
    battle = [r['en'].strip() for r in segs['battle_menu']['runs']]

    def stock(label, n):
        rows = b''.join(b for _, b in M.label_bytes(lines27, label, n, defs))[:n]
        return [rows[i:i + 12] for i in range(0, n, 12)]

    def frame(row, cells):
        """A border row (corner, edge..., corner) or a blank row cells wide."""
        c = [row[i:i + 2] for i in range(0, len(row), 2)]
        return c[0] + c[1] * (cells - 2) + c[-1]

    def text(row, sid, cells):
        return row[:2] + win_run(sid, cells - 2) + row[-2:]

    def menu(rows, sids, cells):
        """A list window: its top, a run a row with a blank row between, its bottom."""
        out = [frame(rows[0], cells)]
        for k, sid in enumerate(sids):
            if k:
                out.append(frame(rows[2], cells))
            out.append(text(rows[1], sid, cells))
        return out + [frame(rows[-1], cells)]

    def dbs(label, rows):
        return [label + ':'] + ['.db ' + ', '.join('$%02X' % b for b in r) for r in rows]

    bm = stock('LABEL_B27_B56B', 132)
    top = [strings.add(word[0]), strings.add(word[1]), strings.add(battle[3]), strings.add(battle[4])]
    cmd = [strings.add(t) for t in battle[:3]]
    lines = head + dbs('MacroTopMap', menu(bm, top, 7)) + dbs('MacroCmdMap', menu(bm, cmd, 6))
    fm = stock('LABEL_B27_BB8B', 132)          # top, 4 entries and their blank rows, then Save
    lines += dbs('MacroFieldMap', fm[:9] + [text(fm[9], strings.add(word[1]), 6), fm[8]] + fm[9:])
    letters = [strings.add(word[2 + k]) for k in range(8)]
    lines += dbs('MacroSlotMap', [frame(bm[0], 3)] + [frame(bm[2], 3)] * 8 + [frame(bm[-1], 3)])
    lines += ["; the slot letters' strings (MacroLetter draws each in its colour)",
              'MacroLetterIds:', '.db ' + ', '.join('$%02X' % s for s in letters)]
    lines += dbs('MacroPrevMap', [frame(bm[0], 19)] + [frame(bm[2], 19)] * 4 + [frame(bm[-1], 19)])
    spells = {r['id']: r['en'].strip() for r in segs['spells']['runs']}
    ids = [strings.add(spells[i]) if spells.get(i) else 0 for i in range(15)]
    lines += ['; the battle spells\' strings (0: none), 5 a list: Alis, Myau, Noah (BattleMagicList)',
              'MacroSpellIds:', '.db ' + ', '.join('$%02X' % i for i in ids)]
    lines += ['.define MACRO_FIGHT $%02X\t; %s' % (cmd[0], battle[0]),
              '.define MACRO_SPACE $%02X' % T.vwf_charset()[' '],
              '.define MACRO_MENU_TILES %d' % max(sum(tiles(t, 5) for t in [word[0], word[1]] + battle[3:5]),
                                                  sum(tiles(t, 4) for t in battle[:3]))]
    return '\r\n'.join(lines) + '\r\n'


LONG_NAME = 6


def long_names_data(script, defs, strings=None):
    """ext/longnames_data.asm (long_names): the party's names for {NAME} in the face's codes,
    and the name boxes and party menu two cells wider than bank 27's, the names in capitals
    (the menus' fixed font has no lower case); then (hospital_everyone, ext/hospital.asm) the
    hospital menu's last entry, a blank row and hospital_words' Everyone marked with its
    WinStrings id (left blank without vwf_windows, which the option needs)."""
    names = [r['en'] for r in script['segments']['party']['runs']]
    charset = T.vwf_charset()
    glyphs = M.us_glyph_table(None, defs)
    bank27 = T.read(os.path.join(T.DISASM, 'banks', 'bank27.asm')).split('\r\n')

    def stock(label, n):
        return b''.join(b for _, b in M.label_bytes(bank27, label, n, defs))[:n]

    def widen(row):
        """Two cells more before the right edge: frame on a border row, blank on a text row."""
        cells = [row[i:i + 2] for i in range(0, len(row), 2)]
        fill = cells[1] if cells[0][0] == 0xF1 else bytes([M.BLANK, 0x10])
        return b''.join(cells[:-1] + [fill, fill] + cells[-1:])

    def with_name(row, name, k):
        if WIN:                         # vwf_windows: the party's name k in the face
            return row[:2] + win_run(WIN_PARTY + k, LONG_NAME) + row[-2:]
        up = name.upper()
        cells = b''
        for ch in up:
            if ch not in T.US_TEXT:
                raise ValueError('party name %r: no capital %r in the menus\' font' % (name, ch))
            cells += bytes([glyphs[T.US_TEXT[ch]][1], 0x10])
        cells += bytes([M.BLANK, 0x10]) * (LONG_NAME - len(up))
        return row[:2] + cells + row[-2:]

    for n in names:
        if len(n) > LONG_NAME:
            raise ValueError('party name %r is longer than %d letters' % (n, LONG_NAME))
    lines = ['; Generated by tools/gentext.py from work/script.json - do not edit by hand.',
             '; long_names: the names for {NAME} (the face\'s codes, $65-padded), then the name boxes',
             '; and the party menu two cells wider than bank 27\'s, with the names in capitals.',
             'LongNames:']
    for n in names:
        codes = [charset[c] for c in n] + [0x65] * (LONG_NAME - len(n))
        lines.append('.db ' + ', '.join('$%02X' % c for c in codes) + '\t; ' + n)
    lines.append('LongNameBoxes:')
    boxes = stock('LABEL_B27_B40B', 4 * 36)
    for k in range(4):
        box = boxes[36 * k:36 * k + 36]
        rows = [widen(box[12 * i:12 * i + 12]) for i in range(3)]
        rows[1] = with_name(rows[1], names[k], k)
        lines += ['.db ' + ', '.join('$%02X' % b for b in r) for r in rows]
    lines.append('LongPartyRows:')
    menu = stock('LABEL_B27_BB1F', 8 * 12)
    rows = [widen(menu[12 * i:12 * i + 12]) for i in range(8)]
    for i in (1, 3, 5, 7):
        rows[i] = with_name(rows[i], names[i // 2], i // 2)
    lines += ['.db ' + ', '.join('$%02X' % b for b in r) for r in rows]
    lines.append('LongPartyEnd:')
    lines.append('.db ' + ', '.join('$%02X' % b for b in widen(stock('LABEL_B27_BB7F', 12))))
    every = script['segments']['hospital_words']['runs'][0]['en'].strip()
    lines.append('LongPartyAll:\t; hospital_everyone: a blank row, then %s' % every)
    last = rows[2][:2] + bytes([M.BLANK, 0x10]) * LONG_NAME + rows[2][-2:]
    if WIN and strings is not None and every:
        last = rows[2][:2] + win_run(strings.add(every), LONG_NAME) + rows[2][-2:]
    lines += ['.db ' + ', '.join('$%02X' % b for b in r) for r in (rows[2], last)]
    return '\r\n'.join(lines) + '\r\n'


LONG_ITEM = 14


def long_items_data(script, strings=None):
    """ext/longitems_data.asm (long_item_names): LongItems (65 x 14) and LongEnemies (75 x 14,
    by record index), the face's codes, $65-padded."""
    charset = T.vwf_charset()
    segs = script['segments']

    def rows(label, runs, count):
        by_id = {int(r['id']): r['en'] for r in runs}
        out = [label + ':']
        for i in range(count):
            name = by_id.get(i, '')
            if len(name) > LONG_ITEM:
                raise ValueError('%s %d: %r is longer than %d characters' % (label, i, name, LONG_ITEM))
            codes = [charset[c] for c in name] + [0x65] * (LONG_ITEM - len(name))
            out.append('.db ' + ', '.join('$%02X' % c for c in codes) + '\t; %d %s' % (i, name))
        return out

    lines = ['; Generated by tools/gentext.py from work/script.json - do not edit by hand.',
             '; long_item_names: the item and enemy names (the face\'s codes, $65-padded).']
    lines += rows('LongItems', segs['items']['runs'], 65)
    lines += rows('LongEnemies', segs['enemies']['runs'], 75)
    # the inventory's NEXT rows (bank 27's, 10 cells) LONG_X cells wider before the right frame
    # (ext/vwf_ram.asm: 2 with vwf_windows, 6 without), so NEXT lines up with the names
    defs = T.defines()
    bank27 = T.read(os.path.join(T.DISASM, 'banks', 'bank27.asm')).split('\r\n')
    stock = bytearray(b''.join(b for _, b in M.label_bytes(bank27, 'LABEL_B27_BAF7', 40, defs))[:40])
    nxt = segs['inventory']['runs'][0]     # NEXT: the stock run, or with vwf_windows marked
    o, n = nxt['offset'], 2 * nxt['cells']
    if WIN and strings is not None:
        stock[o:o + n] = win_run(strings.add(nxt['en'].strip()), nxt['cells'])
        stock[o - 20:o - 20 + n] = bytes([M.BLANK, 0x10]) * nxt['cells']
    else:
        stock[o:o + n] = bytes.fromhex(nxt['hex'])
        stock[o - 20:o - 20 + n] = bytes.fromhex(nxt['upper_hex'])
    lines.append('LongNextRows:')
    for r in (stock[:20], stock[20:]):
        wide = r[:-2] + bytes([M.BLANK, 0x10]) * (2 if WIN else 6) + r[-2:]
        lines.append('.db ' + ', '.join('$%02X' % b for b in wide))
    return '\r\n'.join(lines) + '\r\n'


def tilemap_bytes(run, glyphs):
    """(lower row, upper row or None) of a tilemap run: the stock bytes when en = us."""
    stock = (bytes.fromhex(run['hex']), bytes.fromhex(run.get('upper_hex', '')))
    if run['en'] == run['us'] and not ENCODE_ALL:
        return stock[0], (stock[1] if run['upper'] else None)
    try:
        pairs = M.encode(run['en'], glyphs, run['cells'], run['upper'])
    except ValueError as x:
        raise ValueError('%s %s: %s' % (run['label'], run['id'], x))
    return M.patch(stock, pairs, run['upper'])


def naming_bytes(run, glyphs):
    """The lower tiles of a naming-screen key word (the RLE holds tiles, no attributes)."""
    if run['en'] == run['us'] and not ENCODE_ALL:
        return bytes.fromhex(run['hex'])
    try:
        pairs = M.encode(run['en'], glyphs, run['cells'], False)
    except ValueError as x:
        raise ValueError('naming_keys %s: %s' % (run['id'], x))
    return bytes(t for _, t in pairs)


def main():
    opts = dict(a[2:].split('=', 1) for a in sys.argv[1:] if a.startswith('--') and '=' in a)
    dialogue = json.load(open(opts.get('dialogue', os.path.join(WORK, 'dialogue.json')), encoding='utf-8'))
    script = json.load(open(opts.get('script', os.path.join(WORK, 'script.json')), encoding='utf-8'))
    changed = []
    for path, text in generate(dialogue, script).items():
        if (T.read(path) if os.path.exists(path) else None) != text:
            changed.append(os.path.relpath(path, T.ROOT))
            if '--check' not in sys.argv:
                open(path, 'wb').write(text.encode('latin-1'))
    if '--check' in sys.argv:
        if changed:
            print('would rewrite: ' + ', '.join(changed))
            raise SystemExit(1)
        print('nothing to rewrite')
    else:
        print('rewrote: ' + ', '.join(changed) if changed else 'nothing to rewrite')


if __name__ == '__main__':
    main()
