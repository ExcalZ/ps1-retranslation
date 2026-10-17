"""The text codecs of Phantasy Star (SMS), US/EU v3 and Japan, and the source readers.

Text form used in the JSON (both languages):

    {BR}      new line            US $60  JP $54
    {PAGE}    wait, then new line US $61  JP $55   (the window scrolls; the cut-scene clears)
    {CLR}     clear the window    US $5F  JP $53
    {NAME}    party member name   US $5B  JP $4F   (4 cells)
    {ENEMY}   enemy name          US $5C  JP $50   (8 cells)
    {ITEM}    item name           US $5D  JP $51   (8 cells)
    {NUMBER}  a number, 1-5 digits US $5E JP $52
    {NOWAIT}  end, window stays open (a menu or another string follows)  US $62  JP $56
    {TIMED}   end after a short wait (battle) / 208 frames (cut-scene)   US $63  JP $57
    {PAUSE}   end after 208 frames (the ending narration)                US $64  -
    {END}     end after a button                                         US $65  JP $58
    {$xx}     any other byte, kept as is

`render()` turns bytes into this text the way the window shows them: the 18-cell auto-wrap
(docs/pipeline.md 3.4) becomes an explicit {BR}, and dictionary words are spelled out.
`encode_us()` is the inverse for the stock US engine (upper case, the 128-word dictionary,
packed greedily); it writes explicit {BR}s, which the window shows the same way.
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DISASM = os.path.join(ROOT, 'PSI_Disasm')

LINE = 18                                   # cells in a dialogue line
INSERT_WIDTH = {'NAME': 4, 'ENEMY': 8, 'ITEM': 8, 'NUMBER': 5}

US_CODES = {0x5B: 'NAME', 0x5C: 'ENEMY', 0x5D: 'ITEM', 0x5E: 'NUMBER', 0x5F: 'CLR',
            0x60: 'BR', 0x61: 'PAGE', 0x62: 'NOWAIT', 0x63: 'TIMED', 0x64: 'PAUSE',
            0x65: 'END'}
JP_CODES = {0x4F: 'NAME', 0x50: 'ENEMY', 0x51: 'ITEM', 0x52: 'NUMBER', 0x53: 'CLR',
            0x54: 'BR', 0x55: 'PAGE', 0x56: 'NOWAIT', 0x57: 'TIMED', 0x58: 'END'}
TERMINATORS = {'NOWAIT', 'TIMED', 'PAUSE', 'END'}

# JP: one byte per katakana (docs/pipeline.md 3.12)
JP_KANA = ('　'
           'アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨ'
           'ラリルレロワヲンッャュョ'
           'ガギグゲゴザジズゼゾダヂヅデドバビブベボ'
           'パピプペポ。ーァ')               # $4E ァ: tile $A4, once, in ダークファルス
assert len(JP_KANA) == 0x4F


# ---------------------------------------------------------------- byte classes

def us_kind(b):
    """'char', 'word', or the control name."""
    if b >= 0x80:
        return 'word'
    if b >= 0x65:
        return 'END'                        # $66-$7F act as $65 (never used)
    if b in US_CODES:
        return US_CODES[b]
    return 'char'


def jp_kind(b):
    if b >= 0x58:
        return 'END'
    if b in JP_CODES:
        return JP_CODES[b]
    return 'char'


def us_char(b):
    if b == 0x40:
        return "'"
    if 0x20 <= b <= 0x5A and b not in (0x23, 0x24, 0x25, 0x26, 0x28, 0x29, 0x2A, 0x2B,
                                       0x2F, 0x3A, 0x3C, 0x3D, 0x3E):
        return chr(b)
    if 0x20 <= b <= 0x5A:
        return ' ' if b == 0x20 else '{$%02X}' % b   # a blank code: shown as a space in game
    return '{$%02X}' % b


def jp_char(b):
    return JP_KANA[b] if b < len(JP_KANA) else '{$%02X}' % b


# ---------------------------------------------------------------- rendering

def render(data, lang, words=None, wrap=True):
    """Bytes -> the text form, with the window's auto-wrap made explicit.

    data: one string's bytes (to and including its terminator, if any).
    words: the US dictionary, a list of 128 byte strings (needed for US).
    wrap: False for the cut-scene printer, which has no auto-wrap.
    """
    kind = us_kind if lang == 'us' else jp_kind
    char = us_char if lang == 'us' else jp_char
    out = []
    room = LINE
    i = 0

    def wrap_before(nb):
        # the printer, with the line full, looks at the next byte: a printable one, a
        # word or an insert moves it to the next line
        return nb is not None and kind(nb) in ('char', 'word', 'NAME', 'ENEMY', 'ITEM', 'NUMBER')

    while i < len(data):
        b = data[i]
        k = kind(b)
        nxt = data[i + 1] if i + 1 < len(data) else None
        if k == 'char' or k == 'word' or k in INSERT_WIDTH:
            if k == 'char':
                cells = [char(b)]
            elif k == 'word':
                cells = [us_char(c) for c in words[b & 0x7F]]
            else:
                cells = ['{%s}' % k]
            for j, c in enumerate(cells):
                out.append(c)
                room -= INSERT_WIDTH.get(k, 1) if k in INSERT_WIDTH else 1
                if room <= 0 and wrap:
                    if k == 'word' and j + 1 < len(cells):
                        nb = 0x41               # mid-word: the next byte is a letter
                    else:
                        nb = nxt
                    if wrap_before(nb):
                        out.append('{BR}')
                        room = LINE
                    else:
                        room = 0
        else:
            out.append('{%s}' % k if k == 'END' or b in (US_CODES if lang == 'us' else JP_CODES)
                       else '{$%02X}' % b)
            if k in ('BR', 'PAGE', 'CLR'):
                room = LINE
            if k in TERMINATORS:
                if i + 1 < len(data):           # bytes after a terminator: keep them visible
                    out.append(''.join('{$%02X}' % x for x in data[i + 1:]))
                break
        i += 1
    return ''.join(out)


TAG = re.compile(r'\{([^}]*)\}')


def lines(text):
    """The displayed lines of a text form: split at {BR}, {PAGE}, {CLR} and terminators."""
    s = TAG.sub(lambda m: '\n' if m.group(1) in ('BR', 'PAGE', 'CLR') else
                ('' if m.group(1) in TERMINATORS else m.group(0)), text)
    return s.split('\n')


def width(line):
    """Cells a displayed line takes, inserts at their widest."""
    n = 0
    for m in re.finditer(r'\{([^}]*)\}|.', line):
        tag = m.group(1)
        if tag is None:
            n += 1
        elif tag in INSERT_WIDTH:
            n += INSERT_WIDTH[tag]
        elif tag.startswith('$'):
            n += 1
    return n


# ---------------------------------------------------------------- US encoder

US_TAGS = {v: k for k, v in US_CODES.items()}
US_TEXT = {chr(b): b for b in range(0x20, 0x5B)}
US_TEXT["'"] = 0x40
for _b in (0x23, 0x24, 0x25, 0x26, 0x28, 0x29, 0x2A, 0x2B, 0x2F, 0x3A, 0x3C, 0x3D, 0x3E):
    del US_TEXT[chr(_b)]


def encode_us(text, words=None, dictionary=True):
    """The text form -> bytes for the stock US engine. Raises ValueError on a character the
    font lacks. With `dictionary`, runs of text are packed greedily with the 128 words."""
    out = bytearray()
    plain = []

    def flush():
        s = ''.join(plain)
        plain.clear()
        i = 0
        while i < len(s):
            best = None
            if dictionary and words:
                for n, w in enumerate(words):
                    if len(w) >= 2 and s.startswith(w.decode('latin-1').replace('@', "'"), i):
                        if best is None or len(w) > len(words[best]):
                            best = n
            if best is not None:
                out.append(0x80 | best)
                i += len(words[best])
                continue
            c = s[i]
            if c not in US_TEXT:
                raise ValueError('no glyph for %r in %r' % (c, text))
            out.append(US_TEXT[c])
            i += 1

    pos = 0
    for m in TAG.finditer(text):
        plain.append(text[pos:m.start()])
        tag = m.group(1)
        flush()
        if tag in US_TAGS:
            out.append(US_TAGS[tag])
        elif re.fullmatch(r'\$[0-9A-Fa-f]{2}', tag):
            out.append(int(tag[1:], 16))
        else:
            raise ValueError('unknown tag {%s} in %r' % (tag, text))
        pos = m.end()
    plain.append(text[pos:])
    flush()
    return bytes(out)


# ---------------------------------------------------------------- source readers (WLA-DX)

def read(path):
    return open(path, 'rb').read().decode('latin-1')


def defines():
    """Every .define NAME value of ps1.constants.asm."""
    d = {}
    for m in re.finditer(r'(?m)^\.define\s+(\w+)\s+(\$[0-9A-Fa-f]+|\d+)',
                         read(os.path.join(DISASM, 'ps1.constants.asm'))):
        v = m.group(2)
        d[m.group(1)] = int(v[1:], 16) if v.startswith('$') else int(v)
    return d


DB_TOKEN = re.compile(r'\s*("(?:[^"\\]|\\.)*"|\$[0-9A-Fa-f]+|\d+|\w+)\s*(,|;.*|$)')


def parse_db(line, defs):
    """The bytes of one `.db` line (strings, $hex, decimal, define names), or None if the
    line is not a .db line."""
    m = re.match(r'\s*\.db\s', line)
    if not m:
        return None
    out = bytearray()
    pos = m.end()
    while True:
        mm = DB_TOKEN.match(line, pos)
        if not mm:
            raise ValueError('cannot parse .db item in %r' % line)
        tok = mm.group(1)
        if tok.startswith('"'):
            out += re.sub(r'\\(.)', r'\1', tok[1:-1]).encode('latin-1')
        elif tok.startswith('$'):
            out.append(int(tok[1:], 16))
        elif tok.isdigit():
            out.append(int(tok))
        else:
            out.append(defs[tok])
        pos = mm.end()
        if mm.group(2) != ',':
            break
        if not line[pos:].strip():         # a trailing comma (WLA allows it)
            break
    return bytes(out)


def us_words(defs=None):
    """The 128 dictionary words (without their $65), from the source."""
    defs = defs or defines()
    src = read(os.path.join(DISASM, 'ps1.asm')).split('\r\n')
    words = {}
    for i, l in enumerate(src):
        m = re.match(r'Dialogue_Word_Index_([0-9A-F]{2}):', l)
        if m:
            data = bytearray()
            j = i + 1
            while 0x65 not in data:
                b = parse_db(src[j], defs)
                if b is not None:
                    data += b
                j += 1
            words[int(m.group(1), 16)] = bytes(data[:data.index(0x65)])
    return [words[n] for n in range(128)]


def word_names(defs=None):
    """byte -> the Word_* define that names it."""
    defs = defs or defines()
    names = {}
    for k, v in defs.items():
        if k.startswith('Word_') and v not in names:
            names[v] = k
    return names


# ---------------------------------------------------------------- the symbol file

def symbols(path=None):
    """name -> (bank, addr) from a WLA no$gmb symbol file (ps1built.sym)."""
    path = path or os.path.join(DISASM, 'ps1built.sym')
    syms = {}
    for l in open(path, encoding='latin-1'):
        m = re.match(r'([0-9a-fA-F]{2}):([0-9a-fA-F]{4}) (\S+)', l)
        if m:
            syms[m.group(3)] = (int(m.group(1), 16), int(m.group(2), 16))
    return syms


def rom_offset(bank, addr):
    return addr if bank < 2 and addr < 0x8000 else bank * 0x4000 + (addr & 0x3FFF)
