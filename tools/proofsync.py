"""Render tools/proofread.html from proofread_template.html with the dialogue face, the stock
character sets and the build's budgets embedded, so the page works from file:// with no fetch.

    python tools/proofsync.py

The page loads work/dialogue.json and work/script.json (pick both at once), draws each `en` in
the face of tools/diafont.py at linecheck.py's budgets, and exports the changes as an edits file
for tools/trybuild.py and tools/applyedits.py. Run this again after a change to the face, the
engine options or the budgets; the script itself is not embedded (the page reads the JSON).
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import ps1text as T
import diafont as F
import tilemaps as M
import stockwrap as W
import gentext
import linecheck


def main():
    opts = T.options()
    script = json.load(open(os.path.join(ROOT, 'work', 'script.json'), encoding='utf-8'))
    glyphs = M.us_glyph_table()
    cut = W.window_kinds({'vwf_dialogue': 1, 'vwf_cutscene': 1})['cutscene']
    embed = {
        'OPTIONS': opts,
        'FACE': {ch: F.glyph(ch) for ch in sorted(F.CHAR_CODE)},     # (advance, 8 row bytes)
        'LINE_PX': F.LINE_PX,
        'CUT_PX': cut[0], 'CUT_LINES': cut[1],                        # vwf_cutscene
        'BUDGET': {k: list(v) for k, v in linecheck.BUDGET.items()},
        'INSERT_CELLS': T.INSERT_WIDTH,
        # until script.json is loaded: each insert at its widest (stockwrap.insert_px), and the name
        'INSERT_PX': W.insert_px(script),
        'INSERT_SAMPLE': {k: max((r['en'] for r in script['segments'][seg]['runs']), key=F.width)
                          for k, seg in (('NAME', 'party'), ('ITEM', 'items'), ('ENEMY', 'enemies'))},
        'TAGS': sorted(T.US_TAGS), 'TERMINATORS': sorted(T.TERMINATORS),
        'US_TEXT': ''.join(sorted(T.US_TEXT)),                        # the stock font's characters
        'UPPER_CHARS': ''.join(sorted(c for c, b in T.US_TEXT.items() if glyphs[b][0] != M.BLANK)),
        'WIN_SEGMENTS': list(gentext.WIN_SEGMENTS),
    }
    js = '\n'.join('const %s=%s;' % (k, json.dumps(v, ensure_ascii=False, separators=(',', ':')))
                   for k, v in embed.items())
    tpl = open(os.path.join(HERE, 'proofread_template.html'), encoding='utf-8', newline='').read()
    out = tpl.replace('/*EMBED*/', js)
    open(os.path.join(HERE, 'proofread.html'), 'w', encoding='utf-8', newline='').write(out)
    print('wrote tools/proofread.html (%d bytes)' % len(out))


if __name__ == '__main__':
    main()
