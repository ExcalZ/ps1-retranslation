"""The text the build gives each dialogue.json entry: its `en`, or the stock text re-wrapped.

With vwf_dialogue the window's lines are 80 px and the stock 18-cell auto-wrap never fires
(ext/vwf.asm), so an entry still in its stock English is rebuilt from its `us` text with each
line break written out, and a run of lines that would not fit is re-wrapped: greedy lines of
at most 80 px, two to a page (the window shows two lines at a wait), a {PAGE} added between
pairs. With vwf_cutscene the same for the cut-scenes at 120 px, four to a page. Only the parts
that overflow change; a translated entry (`en` != `us`) is never touched, and a chain of
entries (falls_through) is re-wrapped only when all of it is stock.

    texts(entries, script, opts) -> {id: text}

gentext encodes these texts, linecheck measures them and the harness expects them, so the
working build stays readable while the translation fills it.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ps1text as T
import diafont as F

MARK = '\x00'                          # an entry boundary inside a chain
WAITS = {'PAGE', 'CLR'} | T.TERMINATORS
INSERTS = ('NAME', 'ITEM', 'ENEMY', 'NUMBER')


def window_kinds(opts):
    """The entry kinds drawn in the proportional face, with their line px and lines a page."""
    out = {}
    if opts.get('vwf_dialogue') == 1:
        out['dialogue'] = out['message'] = (F.LINE_PX, 2)
    if opts.get('vwf_cutscene') == 1:
        out['cutscene'] = (120, 4)
    return out


def insert_px(script):
    """An insert at its widest value: the widest party, item or enemy name; {NUMBER} as 99999."""
    segs = script['segments']
    return {'NAME': max(F.width(r['en']) for r in segs['party']['runs']),
            'ITEM': max(F.width(r['en']) for r in segs['items']['runs']),
            'ENEMY': max(F.width(r['en']) for r in segs['enemies']['runs']),
            'NUMBER': F.width('99999')}


def line_px(line, ins):
    return sum(ins[m.group(1)] if m.group(1) in INSERTS else 0 if m.group(1) else F.width(m.group(0))
               for m in re.finditer(r'\{([^}]*)\}|[^{]', line.replace(MARK, '')))


def fits(pages, px, per_page, ins):
    return all(len(lines) <= per_page and all(line_px(l, ins) <= px for l in lines) for lines in pages)


def rewrap(seg, px, per_page, ins):
    """A run of text up to a hard wait -> greedy lines of px, per_page to a page (the stock's
    own {PAGE}s, two-line pagination, are dropped), a space added after a mark the stock ran
    on into a word (HOVERCRAFT.HAPSBY) so the line can break there."""
    seg = re.sub(r'(?<=[.,!?;])(?=%s?[A-Z]{2})' % MARK, ' ', seg)
    words, pending = [], ''            # a boundary rides on the word after it
    for tok in re.split(r' +|\{BR\}|\{PAGE\}|(?=%s)' % MARK, seg):
        if tok == MARK:
            pending += MARK
        elif tok:
            words.append(pending + tok)
            pending = ''
    if pending:
        words.append(pending)
    lines = []
    for w in words:
        text = w.lstrip(MARK)
        if lines and lines[-1].replace(MARK, '') and text:
            lead = w[:len(w) - len(text)]
            trial = lines[-1] + lead + ' ' + text      # the space after the boundary: mid-line
            if line_px(trial, ins) <= px:
                lines[-1] = trial
                continue
        if lines and not lines[-1].replace(MARK, ''):
            lines[-1] += w
        else:
            lines.append(w)
    pages = ['{BR}'.join(lines[i:i + per_page]) for i in range(0, len(lines), per_page)]
    return '{PAGE}'.join(pages)


def wrap_chain(text, px, per_page, ins):
    """A chain's text (MARK between its entries) with each run that overflows re-wrapped: a run
    is the text up to a hard wait ({CLR}, {END}, {NOWAIT}, {TIMED}, {PAUSE})."""
    out = []
    hard = '|'.join(sorted(WAITS - {'PAGE'}))
    for n, run in enumerate(re.split(r'(\{(?:%s)\})' % hard, text)):
        if n % 2:                      # a hard wait: kept
            out.append(run)
            continue
        pages = [p.split('{BR}') for p in run.split('{PAGE}')]
        trimmed = re.sub(r' +(?=%s?(?:\{BR\}|\{PAGE\}|$))' % MARK, '', run)
        if fits(pages, px, per_page, ins):
            out.append(run)
        elif fits([p.split('{BR}') for p in trimmed.split('{PAGE}')], px, per_page, ins):
            out.append(trimmed)
        else:
            out.append(rewrap(run, px, per_page, ins))
    return ''.join(out)


def texts(entries, script, opts):
    kinds = window_kinds(opts)
    ins = insert_px(script) if kinds else None
    out = {e['id']: e['en'] for e in entries}
    i = 0
    while i < len(entries):
        j = i
        while entries[j].get('falls_through') and j + 1 < len(entries):
            j += 1
        chain = entries[i:j + 1]
        kind = chain[0]['kind']
        if kind in kinds and all(e['en'] == e['us'] for e in chain):
            px, per_page = kinds[kind]
            wrapped = wrap_chain(MARK.join(e['us'] for e in chain), px, per_page, ins).split(MARK)
            assert len(wrapped) == len(chain), chain[0]['id']
            for e, t in zip(chain, wrapped):
                out[e['id']] = t
        i = j + 1
    return out


def stock_bytes(e, text, opts):
    """True when the build can keep an entry's stock bytes: its stock text, unchanged, in a
    printer that still wraps (the window without vwf_dialogue) or never wraps (a cut-scene)."""
    return text == e['us'] and (e['kind'] not in window_kinds(opts) or e['kind'] == 'cutscene')


def entry_bytes(e, text, words, opts):
    """An entry's bytes in the build: the stock bytes where they still serve, else `text` encoded
    (in the face's codes where the face draws it)."""
    if stock_bytes(e, text, opts):
        return bytes.fromhex(e['hex'])
    face = e['kind'] in window_kinds(opts)
    return T.encode_us(text, words, charset=T.vwf_charset() if face else None)
