"""Lay out prose for the windows: an edits file whose dialogue entries are plain sentences
becomes one with the line and page breaks written in.

    python tools/wraptext.py PROSE.json OUT.json

Each `dialogue` value is prose: words, inserts ({NAME} ...), and the entry's end code last
({END}, {NOWAIT}, ...; none for an entry that falls through). Each run of prose up to a
{PAGE} the writer put in is broken greedily into lines of the face's width (80 px in the
dialogue window, 120 px in a cut-scene, an insert at its widest), two lines to a page in the
window and four in a cut-scene (tools/stockwrap.py's rewrap). An entry that falls through
ends with {PAGE}, so the next entry starts on a fresh page, as the stock entries do. Breaks
already in the text ({BR}) are kept as written. The `script` part is copied as it is. Then
check with tools/linecheck.py (after applyedits.py) or a trial build.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ps1text as T
import stockwrap as W


def lay_out(text, kind, falls_through, ins):
    px, per_page = (120, 4) if kind == 'cutscene' else (80, 2)
    tags = T.TAG.findall(text)
    end = ''
    if tags and tags[-1] in T.TERMINATORS and text.endswith('{%s}' % tags[-1]):
        end = '{%s}' % tags[-1]
        text = text[:-len(end)]
    if falls_through:
        end = '{PAGE}'
    pages = []
    for part in text.split('{PAGE}'):
        part = part.strip()
        if '{BR}' in part:                 # laid out by hand
            pages.append(part)
        elif part:
            pages.append(W.rewrap(part, px, per_page, ins))
    return '{PAGE}'.join(pages) + end


def main():
    prose = json.load(open(sys.argv[1], encoding='utf-8'))
    root = os.path.dirname(HERE)
    entries = {e['id']: e for e in json.load(open(os.path.join(root, 'work', 'dialogue.json'),
                                                   encoding='utf-8'))['entries']}
    script = json.load(open(os.path.join(root, 'work', 'script.json'), encoding='utf-8'))
    ins = W.insert_px(script)
    out = {'dialogue': {}, 'script': prose.get('script', {})}
    for i, text in prose.get('dialogue', {}).items():
        e = entries.get(i) or entries['LABEL_' + i]
        out['dialogue'][i] = lay_out(text, e['kind'], e.get('falls_through'), ins)
    json.dump(out, open(sys.argv[2], 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('%d entries laid out' % len(out['dialogue']))


if __name__ == '__main__':
    main()
