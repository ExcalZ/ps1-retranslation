"""The text regions of the source and of the JP ROM, as lists of strings.

Shared by extract_text.py, gentext.py and test_text.py.

US (from the source):
  * ps1.asm, from `Dialogue_Index_0002:` to the last string before `DialogueWordBlock`: the 341
    dialogue blocks (kind `dialogue`) and the 23 cut-scene strings `LABEL_B49B`-`LABEL_BA54`
    (kind `cutscene`);
  * sound/sound_driver.asm, from `LABEL_B12_B108:` to the end: the 174 messages (kind
    `message`).
A label's bytes are split after each terminator: the first string takes the label as its id,
the others `LABEL.n` (n from 1).

Once gentext.py has run, each region sits between BEGIN/END marker comments; before that the
anchors above find it.
"""
import os
import re

import ps1text as T

BEGIN = '; ==== BEGIN GENERATED TEXT: tools/gentext.py writes this from work/dialogue.json ===='
END = '; ==== END GENERATED TEXT ===='

REGIONS = [
    # (file, first label, the line that follows the region in the stock source)
    ('ps1.asm', 'Dialogue_Index_0002', '; This is a pointer table for the strings below'),
    (os.path.join('sound', 'sound_driver.asm'), 'LABEL_B12_B108', None),
]

TERM_US = {0x62, 0x63, 0x64} | set(range(0x65, 0x80))


def kind_of(label):
    if label.startswith('Dialogue_Index_'):
        return 'dialogue'
    if label.startswith('LABEL_B12_'):
        return 'message'
    return 'cutscene'


def region_lines(path, first, follows):
    """(lines, start, end): the region is lines[start:end] (CRLF split)."""
    lines = T.read(path).split('\r\n')
    if BEGIN in lines:
        s = lines.index(BEGIN) + 1
        return lines, s, lines.index(END, s)
    s = lines.index(first + ':')
    if follows is None:
        e = len(lines)
        while e > s and not lines[e - 1].strip():
            e -= 1
    else:
        e = lines.index(follows)
        while not lines[e - 1].startswith('.db'):
            e -= 1
    return lines, s, e


def split_terminated(data, terms):
    out, cur = [], bytearray()
    for b in data:
        cur.append(b)
        if b in terms:
            out.append(bytes(cur))
            cur = bytearray()
    if cur:
        out.append(bytes(cur))
    return out


def us_strings(defs=None):
    """[(id, label, kind, bytes)] in source order."""
    defs = defs or T.defines()
    out = []
    for f, first, follows in REGIONS:
        lines, s, e = region_lines(os.path.join(T.DISASM, f), first, follows)
        blocks = []
        for l in lines[s:e]:
            m = re.match(r'(\w+):\s*(;.*)?$', l)
            if m:
                blocks.append([m.group(1), bytearray()])
                continue
            b = T.parse_db(l, defs)
            if b is not None:
                blocks[-1][1] += b
            elif l.strip() and not l.strip().startswith(';'):
                raise ValueError('unexpected line in the text region of %s: %r' % (f, l))
        for label, data in blocks:
            for n, part in enumerate(split_terminated(bytes(data), TERM_US)):
                out.append((label if n == 0 else '%s.%d' % (label, n), label, kind_of(label), part))
    return out


# ---------------------------------------------------------------- the JP ROM

JP_TABLE = 0x80B2               # 02:80B2, 341 pointers
JP_BLOCKS_END = 0xAB1F          # dialogue blocks end at 02:AB1E
JP_MESSAGES = (0xAB1F, 0xB8BF)
JP_CUTSCENES = (0xB8BF, 0xBD94)
JP_ITEMS = 0xBD94               # 02:BD94, 65 x 8
JP_PARTY = 0x3326               # 00:3326, 4 x 4
ENEMIES = 0x867F                # 03:867F, 75 x 32 (the same in both ROMs)
TERM_JP = {0x56, 0x57} | set(range(0x58, 0x100))


def jp_blocks(rom):
    """[(addr, bytes)] for the 341 dialogue blocks in id order."""
    base = 2 * 0x4000 - 0x8000
    ptrs = [rom[base + JP_TABLE + 2 * i] | rom[base + JP_TABLE + 2 * i + 1] << 8 for i in range(341)]
    ends = sorted(set(ptrs)) + [JP_BLOCKS_END]
    out = []
    for p in ptrs:
        e = ends[ends.index(p) + 1]
        out.append((p, rom[base + p:base + e]))
    return out


def jp_run(rom, lo, hi):
    """[(addr, bytes)]: the strings of bank 2 lo..hi split after each terminator."""
    base = 2 * 0x4000 - 0x8000
    out, a = [], lo
    for part in split_terminated(rom[base + lo:base + hi], TERM_JP):
        out.append((a, part))
        a += len(part)
    return out
