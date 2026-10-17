"""Check every translated line against its budget.

    python tools/linecheck.py [--all]

Checks each `en` that differs from its `us` (--all: every entry, the stock text included):

* it encodes for the stock engine (upper case, the font's punctuation: tools/ps1text.py);
* dialogue and messages: each line at most 18 cells, inserts at their widest ({NAME} 4,
  {ENEMY} and {ITEM} 8, {NUMBER} 5); the window scrolls, so a message has no line limit;
* cut-scenes: each line at most 20 cells (the picture's width; the JP uses all 20, the US
  18), at most 4 lines a page; the cut-scene printer has no auto-wrap;
* the end code: the same as the stock entry's, or none where the entry falls through;
* name fields: at most their width.

Then the space: bytes the encoded text takes in bank 2 and bank 12 against what the stock text
and the free bytes after it leave (docs/pipeline.md 3.1).
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ps1text as T

WORK = os.path.join(T.ROOT, 'work')
FREE = {'02': 183, '0C': 40}           # bytes free after the stock text in banks 2 and 12
BUDGET = {'dialogue': (18, None), 'message': (18, None), 'cutscene': (20, 4)}


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
    used = {'02': 0, '0C': 0}
    stock = {'02': 0, '0C': 0}
    for e in dialogue['entries']:
        bank = e['addr'][:2]
        stock[bank] += len(e['hex']) // 2
        try:
            used[bank] += len(bytes.fromhex(e['hex']) if e['en'] == e['us'] else T.encode_us(e['en'], words))
        except ValueError as x:
            problems.append('%s: %s' % (e['id'], x))
            continue
        if e['en'] == e['us'] and not check_all:
            continue
        width, per_page = BUDGET[e['kind']]
        for page in pages(e['en']):
            for line in page:
                if T.width(line) > width:
                    problems.append('%s: %d cells (%d): %s' % (e['id'], T.width(line), width, line))
            n = len(page) - (1 if len(page) > 1 and not page[-1] else 0)
            if per_page and n > per_page:
                problems.append('%s: %d lines on a page (%d)' % (e['id'], n, per_page))
        want = None if e.get('falls_through') else end_code(e['us'])
        if end_code(e['en']) != want:
            problems.append('%s: ends in %s, the stock entry in %s' % (e['id'], end_code(e['en']), want))
    for name, seg in script['segments'].items():
        for r in seg['runs']:
            if r['en'] != r['us'] or check_all:
                if len(r['en']) > seg['width']:
                    problems.append('%s %s: %r is %d cells (%d)' % (name, r['id'], r['en'], len(r['en']), seg['width']))
                try:
                    T.encode_us(r['en'], dictionary=False)
                except ValueError as x:
                    problems.append('%s %s: %s' % (name, r['id'], x))
    for p in problems:
        print(p)
    for bank in ('02', '0C'):
        room = stock[bank] + FREE[bank]
        print('bank %s: %d of %d bytes%s' % (bank, used[bank], room, '  OVER' if used[bank] > room else ''))
        if used[bank] > room:
            problems.append('bank %s over' % bank)
    print('%d problems' % len(problems))
    if problems:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
