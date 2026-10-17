"""Tests of the codecs and of the JSON against both ROMs.

    python tools/test_text.py

* the JP kana table matches the JP glyph table (02:8000);
* every entry's `hex` is the stock ROM at its `addr`, and renders to its `us`;
* every `jp` renders from the JP ROM at its `jp_addr`;
* the name tables' `hex` and `jp` match both ROMs;
* the tilemap runs: `hex` and `upper_hex` are the ROM at `addr` and the row above, at the
  label's symbol plus `offset`; `us` decodes from them and `jp` from the JP ROM; encoding `us`
  through the source's glyph table gives the stock bytes back; the read-only segments (naming
  screen, credits) decode from both ROMs;
* the US encoder: encoding each `us` and rendering it back gives the same displayed text, and
  the whole script encoded that way (no stock bytes) still fits both banks.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ps1text as T
import textsrc as S
import tilemaps as M

WORK = os.path.join(T.ROOT, 'work')
US = open(os.path.join(T.DISASM, 'ps1original.sms'), 'rb').read()
JP = open(os.path.join(WORK, 'ps1jp_stock.sms'), 'rb').read()
failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)


def at(rom, a):
    bank, addr = (int(x, 16) for x in a.split(':'))
    return T.rom_offset(bank, addr)


def test_glyphs():
    g = JP[2 * 0x4000:2 * 0x4000 + 0x59 * 2]
    for n in range(1, 0x33):
        check(g[2 * n + 1] == 0xCB + n - 1 and g[2 * n] == 0xC0, 'JP glyph %02X' % n)
    for n in range(0x33, 0x4C):
        check(g[2 * n] in (0xFD, 0xFE), 'JP glyph %02X has no (han)dakuten' % n)


def test_dialogue(doc, words):
    for e in doc['entries']:
        data = bytes.fromhex(e['hex'])
        off = at(US, e['addr'])
        check(US[off:off + len(data)] == data, '%s: hex is not the ROM at %s' % (e['id'], e['addr']))
        wrap = e['kind'] != 'cutscene'
        check(T.render(data, 'us', words, wrap) == e['us'], '%s: us does not render from hex' % e['id'])
        if 'jp_addr' in e:
            j = at(JP, e['jp_addr'])
            n = len(JP)
            part = None
            for p in (S.jp_blocks(JP) if e['kind'] == 'dialogue' else []):
                if 2 * 0x4000 - 0x8000 + p[0] == j:
                    part = p[1]
                    break
            if part is None:
                end = j
                while JP[end] not in S.TERM_JP:
                    end += 1
                part = JP[j:end + 1]
            check(T.render(part, 'jp', wrap=wrap) == e['jp'], '%s: jp does not render from the JP ROM' % e['id'])
        # the encoder: the same display from re-encoded text
        enc = T.encode_us(e['us'], words)
        check(T.render(enc, 'us', words, wrap) == e['us'],
              '%s: encode/render round trip differs:\n  %s\n  %s' % (e['id'], e['us'], T.render(enc, 'us', words, wrap)))


def test_fit(doc, words):
    used = {'02': 0, '0C': 0}
    stock = {'02': 0, '0C': 0}
    for e in doc['entries']:
        used[e['addr'][:2]] += len(T.encode_us(e['us'], words))
        stock[e['addr'][:2]] += len(e['hex']) // 2
    for bank, free in (('02', 183), ('0C', 40)):
        print('  re-encoded stock script, bank %s: %d bytes (stock %d, room %d)' % (
            bank, used[bank], stock[bank], stock[bank] + free))
        check(used[bank] <= stock[bank] + free, 'the re-encoded script overflows bank %s' % bank)


def test_tables(doc):
    for name, seg in doc['segments'].items():
        if 'width' not in seg:
            continue
        for r in seg['runs']:
            data = bytes.fromhex(r['hex'])
            check(len(data) == seg['width'], '%s %s: hex width' % (name, r['id']))
    syms = T.symbols()
    p = T.rom_offset(*syms['CharacterNames'])
    for r in doc['segments']['party']['runs']:
        check(US[p + 4 * r['id']:][:4].hex().upper() == r['hex'], 'party %d' % r['id'])
    p = T.rom_offset(*syms['ItemNames'])
    for r in doc['segments']['items']['runs']:
        check(US[p + 8 * r['id']:][:8].hex().upper() == r['hex'], 'item %d' % r['id'])
    for r in doc['segments']['enemies']['runs']:
        p = T.rom_offset(*syms[r['label']])
        check(US[p:p + 8].hex().upper() == r['hex'], 'enemy %s' % r['label'])
        check(p == 3 * 0x4000 + S.ENEMIES - 0x8000 + 32 * r['id'], 'enemy %s: record index' % r['label'])


def test_tilemaps(doc):
    syms = T.symbols()
    glyphs = M.us_glyph_table()
    check(glyphs == M.us_glyph_table_rom(US), 'the glyph table in the source is not the ROM\'s')
    uinv, jinv = M.us_inverse(glyphs), M.jp_inverse(JP)
    n = 0
    for name, seg in doc['segments'].items():
        if seg.get('kind') != 'tilemap':
            continue
        for r in seg['runs']:
            n += 1
            tag = '%s %s' % (name, r['id'])
            bank, base = syms[r['label']]
            check(M.addr(bank, base + r['offset']) == r['addr'], tag + ': addr is not label + offset')
            lo, up, text = M.us_text(US, r, uinv)
            check(lo.hex().upper() == r['hex'], tag + ': hex is not the ROM')
            check(r['upper'] == ('upper_hex' in r), tag + ': upper_hex')
            if r['upper']:
                check(up.hex().upper() == r['upper_hex'], tag + ': upper_hex is not the ROM')
            check(text == r['us'], tag + ': us does not decode from the ROM (%r)' % text)
            check(M.jp_text(JP, r, jinv) == r['jp'], tag + ': jp does not decode from the JP ROM')
            check(len(lo) == 2 * r['cells'] and M.cell_width(r['us']) <= r['cells'], tag + ': width')
            stock = (lo, up or b'')
            enc = M.patch(stock, M.encode(r['us'], glyphs, r['cells'], r['upper']), r['upper'])
            check(enc == (lo, up), tag + ': encoding us does not give the stock bytes')
    print('  tilemap runs: %d' % n)
    ro = doc['segments']
    check(ro['naming_screen']['runs'][0]['us'] == '{BR}'.join(M.naming_lines(US, 'us', uinv)),
          'naming screen: us')
    check(ro['naming_screen']['runs'][0]['jp'] == '{BR}'.join(M.naming_lines(JP, 'jp', jinv)),
          'naming screen: jp')
    for r, u, j in zip(ro['credits']['runs'], M.credit_screens(US), M.credit_screens(JP)):
        check(r['us'] == '{BR}'.join(t for _, _, t in u) and r['us_at'] == [[a, b] for a, b, _ in u],
              'credits %d: us' % r['id'])
        check(r['jp'] == '{BR}'.join(t for _, _, t in j) and r['jp_at'] == [[a, b] for a, b, _ in j],
              'credits %d: jp' % r['id'])


def main():
    words = T.us_words()
    test_glyphs()
    test_dialogue(json.load(open(os.path.join(WORK, 'dialogue.json'), encoding='utf-8')), words)
    test_fit(json.load(open(os.path.join(WORK, 'dialogue.json'), encoding='utf-8')), words)
    test_tables(json.load(open(os.path.join(WORK, 'script.json'), encoding='utf-8')))
    test_tilemaps(json.load(open(os.path.join(WORK, 'script.json'), encoding='utf-8')))
    for f in failures[:40]:
        print('FAIL', f)
    print('%d failures' % len(failures))
    if failures:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
