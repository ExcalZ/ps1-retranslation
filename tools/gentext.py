"""Write work/dialogue.json and work/script.json into the source.

    python tools/gentext.py [--check] [--dialogue=PATH] [--script=PATH]

* The script is written whole into PSI_Disasm/text/ (textsrc.FILES): dialogue.asm
  (DialogueBlock, the 341 pointers in id order, then the dialogue blocks), cutscenes.asm and
  messages.asm, one label per entry in JSON order; an entry without a label follows the
  previous one (the game reaches it by reading on). The source includes them where the stock
  had them, or in banks 32-34 with relocate_script (ext/banks.asm).
* The name fields (CharacterNames, ItemNames, the first line of each Enemy_* record in
  banks/bank03.asm) are rewritten line by line, only where the bytes change.
* The tilemap runs of script.json (kind `tilemap`: menus, spell lists, status labels, save
  slots, spaceport, intro caption; tools/tilemaps.py) are written into their maps' `.db`
  lines in ps1.asm, banks/bank27.asm and banks/bank18.asm, through the glyph table
  (LABEL_7D17): the lower tile in the run's row, the upper tile in the row above where the run
  owns it. Only lines whose bytes change are rewritten. Segments of kind `readonly` (the naming
  screen, the credits) are not written.

An entry whose `en` equals its `us` is written from `hex`: the stock bytes, so with en = us
everywhere the ROM is the stock one (checkstock.py). Any other `en` is encoded for the stock
engine (ps1text.encode_us: upper case, the dictionary). The files keep their CRLF endings.
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


VWF = T.options().get('vwf_dialogue') == 1


def entry_bytes(e, words):
    if e['en'] == e['us'] and not ENCODE_ALL:
        return bytes.fromhex(e['hex'])
    if VWF and e['kind'] in ('dialogue', 'message'):    # the window: mixed case, the face
        return T.encode_us(e['en'], words, charset=T.vwf_charset())
    return T.encode_us(e['en'], words)


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
    names = T.word_names(defs)
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
    for f, kinds in S.FILES:
        path = os.path.join(T.DISASM, f)
        body = [S.HEADER]
        if 'dialogue' in kinds:
            ids = sorted((x for x in entries if x['kind'] == 'dialogue'), key=lambda x: int(x['id'], 16))
            body += ['DialogueBlock:']
            for i in range(0, len(ids), 8):
                body.append('.dw ' + ', '.join(x['label'] for x in ids[i:i + 8]))
        for n, en in enumerate(x for x in entries if x['kind'] in kinds):
            data = entry_bytes(en, words)
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
        want = field_bytes(run, 8, words)
        have = T.parse_db(lines[i], defs)
        if len(have) != 8:
            raise ValueError('%s: the name line is not 8 bytes' % run['label'])
        if have != want:
            lines[i] = '.db\t' + ', '.join(tokens(want, names))
    out[path] = '\r\n'.join(lines)

    # ---- the tilemaps
    glyphs = M.us_glyph_table(out[os.path.join(T.DISASM, 'ps1.asm')].split('\r\n'), defs)
    files = {}
    for seg in segs.values():
        if seg.get('kind') != 'tilemap':
            continue
        path = os.path.join(T.DISASM, *seg['file'].split('/'))
        if path not in files:
            files[path] = (out[path] if path in out else T.read(path)).split('\r\n')
        for run in seg['runs']:
            lo, up = tilemap_bytes(run, glyphs)
            M.write_bytes(files[path], run['label'], run['offset'], lo, defs)
            if up is not None:
                M.write_bytes(files[path], run['label'],
                              run['offset'] - 2 * M.ROW_CELLS[run['label']], up, defs)
    for path, lines in files.items():
        out[path] = '\r\n'.join(lines)
    return out


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


def main():
    opts = dict(a[2:].split('=', 1) for a in sys.argv[1:] if a.startswith('--') and '=' in a)
    dialogue = json.load(open(opts.get('dialogue', os.path.join(WORK, 'dialogue.json')), encoding='utf-8'))
    script = json.load(open(opts.get('script', os.path.join(WORK, 'script.json')), encoding='utf-8'))
    changed = []
    for path, text in generate(dialogue, script).items():
        if T.read(path) != text:
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
