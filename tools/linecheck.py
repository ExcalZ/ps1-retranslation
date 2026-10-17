"""Check every translated line against its budget.

    python tools/linecheck.py [--all]

Checks each `en` that differs from its `us` (--all: every entry, the stock text included):

* it encodes for the stock engine (upper case, the font's punctuation: tools/ps1text.py);
* dialogue and messages: each line at most 18 cells, inserts at their widest ({NAME} 4,
  {ENEMY} and {ITEM} 8, {NUMBER} 5); the window scrolls, so a message has no line limit.
  With vwf_dialogue: each line at most 80 px in the face (tools/diafont.py), an insert at its
  widest value (the widest party, item or enemy name; {NUMBER} as 99999), any character the
  face has (mixed case);
* cut-scenes: each line at most 20 cells (the picture's width; the JP uses all 20, the US
  18), at most 4 lines a page; the cut-scene printer has no auto-wrap;
* the end code: the same as the stock entry's, or none where the entry falls through;
* name fields: at most their width;
* tilemap runs (menus, spell lists, status labels, save slots, spaceport, intro caption):
  each glyph in the font, at most the run's cells, and an upper tile (the US `"` and
  apostrophe) only where the run owns the row above; the party names in the name boxes, the
  status boxes and the party menu the same as the party table's.

Then the space: the bytes the encoded text takes against the room it has: with
relocate_script a bank each (32 the dialogue after its 682-byte table, 33 the messages, 34 the
cut-scenes); without it, banks 2 and 12 with the bytes free after the stock text.
"""
import json
import re
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ps1text as T
import tilemaps as M
import diafont as F

WORK = os.path.join(T.ROOT, 'work')
FREE = {'02': 183, '0C': 40}           # bytes free after the stock text in banks 2 and 12
BUDGET = {'dialogue': (18, None), 'message': (18, None), 'cutscene': (20, 4)}


def options():
    text = open(os.path.join(T.DISASM, 'ps1.options.asm'), encoding='latin-1').read()
    return {m.group(1): int(m.group(2)) for m in re.finditer(r'(?m)^\.define\s+(\w+)\s+(\d+)', text)}


def end_code(text):
    tags = T.TAG.findall(text)
    return tags[-1] if tags and tags[-1] in T.TERMINATORS else None


def pages(text):
    """Lines grouped by page ({PAGE} and {CLR} start one)."""
    def sub(m):
        tag = m.group(1)
        if tag in T.TERMINATORS:
            return ''
        return {'BR': '\n', 'PAGE': '\f', 'CLR': '\f'}.get(tag, m.group(0))
    return [p.split('\n') for p in T.TAG.sub(sub, text).split('\f')]


def main():
    check_all = '--all' in sys.argv
    dialogue = json.load(open(os.path.join(WORK, 'dialogue.json'), encoding='utf-8'))
    script = json.load(open(os.path.join(WORK, 'script.json'), encoding='utf-8'))
    words = T.us_words()
    problems = []
    relocated = options().get('relocate_script') == 1
    if relocated:                          # banks 32-34, a bank each (dialogue: after its table)
        group = {'dialogue': '32 (dialogue)', 'message': '33 (messages)', 'cutscene': '34 (cut-scenes)'}
        room = {'32 (dialogue)': 0x4000 - 2 * 341, '33 (messages)': 0x4000, '34 (cut-scenes)': 0x4000}
    else:                                  # the stock banks, with the bytes free after the text
        group = {'dialogue': '02', 'cutscene': '02', 'message': '0C'}
        room = None
    used = {g: 0 for g in group.values()}
    stock = {g: 0 for g in group.values()}
    vwf = options().get('vwf_dialogue') == 1
    if vwf:                                # the window in pixels; an insert at its widest value
        segs = script['segments']
        insert_px = {'NAME': max(F.width(r['en']) for r in segs['party']['runs']),
                     'ITEM': max(F.width(r['en']) for r in segs['items']['runs']),
                     'ENEMY': max(F.width(r['en']) for r in segs['enemies']['runs']),
                     'NUMBER': F.width('99999')}
    for e in dialogue['entries']:
        bank = group[e['kind']]
        stock[bank] += len(e['hex']) // 2
        window = vwf and e['kind'] != 'cutscene'
        try:
            used[bank] += len(bytes.fromhex(e['hex']) if e['en'] == e['us'] else
                              T.encode_us(e['en'], words, charset=T.vwf_charset() if window else None))
        except ValueError as x:
            problems.append('%s: %s' % (e['id'], x))
            continue
        if e['en'] == e['us'] and not check_all:
            continue
        width, per_page = BUDGET[e['kind']]
        for page in pages(e['en']):
            for line in page:
                if window:
                    px = sum(insert_px[m.group(1)] if m.group(1) else F.width(m.group(0))
                             for m in re.finditer(r'\{(NAME|ITEM|ENEMY|NUMBER)\}|[^{]', line))
                    if px > F.LINE_PX:
                        problems.append('%s: %d px (%d): %s' % (e['id'], px, F.LINE_PX, line))
                elif T.width(line) > width:
                    problems.append('%s: %d cells (%d): %s' % (e['id'], T.width(line), width, line))
            n = len(page) - (1 if len(page) > 1 and not page[-1] else 0)
            if per_page and n > per_page:
                problems.append('%s: %d lines on a page (%d)' % (e['id'], n, per_page))
        want = None if e.get('falls_through') else end_code(e['us'])
        if end_code(e['en']) != want:
            problems.append('%s: ends in %s, the stock entry in %s' % (e['id'], end_code(e['en']), want))
    glyphs = M.us_glyph_table()
    for name, seg in script['segments'].items():
        if seg.get('kind') == 'readonly':
            continue
        if seg.get('kind') == 'tilemap':
            for r in seg['runs']:
                if r['en'] != r['us'] or check_all:
                    try:
                        M.encode(r['en'], glyphs, r['cells'], r['upper'])
                    except ValueError as x:
                        problems.append('%s %s (%s): %s' % (name, r['id'], r['where'], x))
            continue
        for r in seg['runs']:
            if r['en'] != r['us'] or check_all:
                if len(r['en']) > seg['width']:
                    problems.append('%s %s: %r is %d cells (%d)' % (name, r['id'], r['en'], len(r['en']), seg['width']))
                try:
                    T.encode_us(r['en'], dictionary=False)
                except ValueError as x:
                    problems.append('%s %s: %s' % (name, r['id'], x))
    party = [r['en'] for r in script['segments']['party']['runs']]
    for name in ('name_boxes', 'status_boxes', 'party_menu'):
        for r in script['segments'][name]['runs']:
            if r['en'].strip() != party[r['id']]:
                problems.append('%s %s shows %r; party %d is %r' % (
                    name, r['id'], r['en'].strip(), r['id'], party[r['id']]))
    for p in problems:
        print(p)
    for bank in used:
        have = room[bank] if room else stock[bank] + FREE[bank]
        print('bank %s: %d of %d bytes%s' % (bank, used[bank], have, '  OVER' if used[bank] > have else ''))
        if used[bank] > have:
            problems.append('bank %s over' % bank)
    print('%d problems' % len(problems))
    if problems:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
