"""Extract the script into work/dialogue.json and the name tables into work/script.json.

    python tools/extract_text.py [--force]

Runs once, on a stock build (PSI_Disasm/ps1built.sym must be the stock one): it reads the US
text from the source (textsrc.py), the JP text from work/ps1jp_stock.sms, pairs them (by id
for the dialogue blocks, by work/pairing.json for the messages and cut-scenes) and writes
`jp`, `us`, `hex`, the addresses, and `en` = `us`. It refuses to overwrite existing JSON
without --force: a re-extraction would drop every translation.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ps1text as T
import textsrc as S

ROOT = T.ROOT
WORK = os.path.join(ROOT, 'work')
JP_ROM = os.path.join(WORK, 'ps1jp_stock.sms')
STOCK = os.path.join(T.DISASM, 'ps1original.sms')


def addr(bank, a):
    return '%02X:%04X' % (bank, a)


def field_text(data, lang, term):
    """A fixed name field: the bytes up to the terminator, trailing blanks dropped."""
    if term in data:
        data = data[:data.index(term)]
    s = ''.join((T.us_char if lang == 'us' else T.jp_char)(b) for b in data)
    return s.rstrip(' 　')


def pair(kind, us_list, jp_list, rules):
    """us index -> (jp index or None, cont)."""
    out = {}
    for r in rules[kind]:
        a, b = r['us']
        for n, i in enumerate(range(a, b + 1)):
            out[i] = (None, True) if r.get('cont') else (r['jp'] + n, False)
    assert sorted(out) == list(range(len(us_list))), 'pairing.json does not cover every %s' % kind
    return out


def main():
    for f in ('dialogue.json', 'script.json'):
        if os.path.exists(os.path.join(WORK, f)) and '--force' not in sys.argv:
            raise SystemExit('work/%s exists: extraction would drop the translation (--force)' % f)
    defs = T.defines()
    words = T.us_words(defs)
    syms = T.symbols()
    us_rom = open(STOCK, 'rb').read()
    jp = open(JP_ROM, 'rb').read()
    rules = json.load(open(os.path.join(WORK, 'pairing.json'), encoding='utf-8'))

    us = S.us_strings(defs)
    # addresses: a label's own, then each following string after the previous one
    where = {}
    for sid, label, kind, data in us:
        if sid == label:
            b, a = syms[label]
        else:
            a = where[prev][1] + len(prev_data)
        where[sid] = (b, a)
        prev, prev_data = sid, data
        off = T.rom_offset(b, a)
        assert us_rom[off:off + len(data)] == data, 'source and ROM differ at %s' % sid

    jp_dialogue = S.jp_blocks(jp)
    jp_msg = S.jp_run(jp, *S.JP_MESSAGES)
    jp_cut = S.jp_run(jp, *S.JP_CUTSCENES)
    by_kind = {k: [x for x in us if x[2] == k] for k in ('dialogue', 'message', 'cutscene')}
    pairs = {'message': pair('message', by_kind['message'], jp_msg, rules),
             'cutscene': pair('cutscene', by_kind['cutscene'], jp_cut, rules)}
    used = {'message': set(), 'cutscene': set()}

    entries = []
    index = {k: 0 for k in by_kind}
    for sid, label, kind, data in us:
        n = index[kind]
        index[kind] += 1
        wrap = kind != 'cutscene'
        e = {'id': sid[len('Dialogue_Index_'):] if kind == 'dialogue' else sid,
             'kind': kind,
             'label': label if sid == label else None,
             'addr': addr(*where[sid]),
             'hex': data.hex().upper(),
             'us': T.render(data, 'us', words, wrap)}
        if kind == 'dialogue':
            ja, jb = jp_dialogue[n]
        else:
            j, cont = pairs[kind][n]
            if cont:
                e['jp_cont'] = True
                ja = None
            else:
                ja, jb = (jp_msg if kind == 'message' else jp_cut)[j]
                used[kind].add(j)
        if ja is not None:
            e['jp_addr'] = addr(2, ja)
            e['jp'] = T.render(jb, 'jp', wrap=wrap)
        if T.us_kind(data[-1]) not in T.TERMINATORS:
            e['falls_through'] = True
        e['en'] = e['us']
        entries.append(e)

    jp_only = []
    for kind, lst in (('message', jp_msg), ('cutscene', jp_cut)):
        for j, (ja, jb) in enumerate(lst):
            if j not in used[kind]:
                jp_only.append({'kind': kind, 'jp_addr': addr(2, ja), 'jp': T.render(jb, 'jp')})

    dialogue = {
        'about': 'The script of Phantasy Star (SMS): JP (Japan ROM), US (the v3 source), EN (the '
                 'retranslation; edit only en). Text form and controls: tools/ps1text.py and '
                 'docs/pipeline.md section 4. kind: dialogue (DialogueBlock id), message (bank 12, '
                 'by label), cutscene (the cut-scene printer: no auto-wrap). falls_through: no end '
                 'code, the game runs on into the next entry. jp_cont: the JP of this entry is part '
                 'of the previous entry\'s jp.',
        'entries': entries,
        'jp_only': jp_only,
    }

    # ---- name tables
    segs = {}
    party = [us_rom[T.rom_offset(*syms['CharacterNames']) + 4 * i:][:4] for i in range(4)]
    segs['party'] = {'width': 4, 'label': 'CharacterNames', 'runs': [
        {'id': i, 'hex': party[i].hex().upper(), 'us': field_text(party[i], 'us', 0x65),
         'jp': field_text(jp[S.JP_PARTY + 4 * i:][:4], 'jp', 0x58)} for i in range(4)]}
    item0 = T.rom_offset(*syms['ItemNames'])
    jp_items = 2 * 0x4000 + S.JP_ITEMS - 0x8000
    segs['items'] = {'width': 8, 'label': 'ItemNames', 'runs': [
        {'id': i, 'hex': us_rom[item0 + 8 * i:][:8].hex().upper(),
         'us': field_text(us_rom[item0 + 8 * i:][:8], 'us', 0x65),
         'jp': field_text(jp[jp_items + 8 * i:][:8], 'jp', 0x58)} for i in range(65)]}
    enemy0 = 3 * 0x4000 + S.ENEMIES - 0x8000
    enemy_labels = sorted((T.rom_offset(*v), k) for k, v in syms.items()
                          if k.startswith('Enemy_') and v[0] == 3
                          and 0 <= T.rom_offset(*v) - enemy0 < 75 * 32
                          and (T.rom_offset(*v) - enemy0) % 32 == 0)
    segs['enemies'] = {'width': 8, 'label': 'B03_EnemyData', 'runs': []}
    for off, name in enemy_labels:
        i = (off - enemy0) // 32
        if i == 0:
            continue                        # Enemy_None: no name
        segs['enemies']['runs'].append({
            'id': i, 'label': name, 'hex': us_rom[off:off + 8].hex().upper(),
            'us': field_text(us_rom[off:off + 8], 'us', 0x65),
            'jp': field_text(jp[off:off + 8], 'jp', 0x58)})
    for s in segs.values():
        for r in s['runs']:
            r['en'] = r['us']
    script = {
        'about': 'The fixed-width name tables (docs/pipeline.md 3.6). Edit only en; width is in '
                 'cells, the field is padded with an end code and spaces.',
        'segments': segs,
    }

    for name, doc in (('dialogue.json', dialogue), ('script.json', script)):
        with open(os.path.join(WORK, name), 'w', encoding='utf-8', newline='\n') as f:
            json.dump(doc, f, indent=1, ensure_ascii=False)
            f.write('\n')
    print('dialogue.json: %d entries (%s), %d JP-only' % (
        len(entries), ', '.join('%d %s' % (len(v), k) for k, v in by_kind.items()), len(jp_only)))
    print('script.json: %s' % ', '.join('%d %s' % (len(s['runs']), k) for k, s in segs.items()))


if __name__ == '__main__':
    main()
