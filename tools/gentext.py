"""Write work/dialogue.json and work/script.json into the source.

    python tools/gentext.py [--check] [--dialogue=PATH] [--script=PATH]

* The two text regions (textsrc.REGIONS: the dialogue blocks and cut-scenes in ps1.asm, the
  messages in sound/sound_driver.asm) are regenerated whole between BEGIN/END marker comments,
  one label per entry in JSON order; an entry without a label follows the previous one (the
  game reaches it by reading on).
* The name fields (CharacterNames, ItemNames, the first line of each Enemy_* record in
  banks/bank03.asm) are rewritten line by line, only where the bytes change.

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


def entry_bytes(e, words):
    if e['en'] == e['us'] and not ENCODE_ALL:
        return bytes.fromhex(e['hex'])
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

    # ---- the text regions
    entries = dialogue['entries']
    for f, first, follows in S.REGIONS:
        path = os.path.join(T.DISASM, f)
        lines, s, e = S.region_lines(path, first, follows)
        kinds = {'message'} if 'sound' in f else {'dialogue', 'cutscene'}
        body = [S.BEGIN]
        for en in (x for x in entries if x['kind'] in kinds):
            data = entry_bytes(en, words)
            if en['label']:
                body += ['', en['label'] + ':']
            else:
                body.append('; %s: read on from the string above' % en['id'])
            body += db_lines(data, names)
        body.append(S.END)
        if lines[s - 1:s] == [S.BEGIN]:
            s -= 1
            e += 1
        out[path] = '\r\n'.join(lines[:s] + body + lines[e:])

    # ---- the name fields
    segs = script['segments']
    path = os.path.join(T.DISASM, 'ps1.asm')
    lines = out[path].split('\r\n')
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
    return out


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
