"""Run a bounded emulator scenario in Mesen 2 (headless test runner).

    python tools/ps1emu.py SCENARIO [--rom=PATH] [--timeout=SECONDS] [--frames=N]
                                    [--expect=ID,ID,...] [--dialogue=PATH]
                                    [--words=SEGMENT[:a-b],...] [--script=PATH] [--keep-sram]
                                    [key=value ...]

SCENARIO is work/scripts/SCENARIO.lua (or a path). The runner writes one Lua file to
work/analysis/run/: a PS1 table (the run's name, the output folder, the frame cap, the bank 0/1
labels of PSI_Disasm/ps1built.sym as CPU addresses, every label as a ROM offset in PS1.rom,
the key=value params), then work/scripts/lib.lua, then the
scenario. Mesen runs it with --testRunner at full speed, no window. The log and the screenshots
land in work/analysis/ (git-ignored) as SCENARIO.log and SCENARIO_NNN_name.png.

Each run starts with a blank battery: Mesen keeps the cartridge RAM in Mesen_2.1.1/Saves/,
and the runner deletes the ROM's .sav first unless --keep-sram (a saved game would otherwise
change what the next run sees, e.g. no naming screen for a slot already named).

Bounded three ways: every wait in lib.lua has a frame limit, the run stops at --frames
(default 30000, about 8 minutes of game time), and Mesen's own --timeout (default 120 s)
plus a process kill 30 s after that.

--expect compares the pages the scenario logged with the `en` of those dialogue.json entries
(ids, or labels without LABEL_, in the order the game plays them; each runs on through its
falls_through entries): cut-scene pages, and the dialogue window's two lines at each button
wait (window_pages models the scrolling). E.g. opening --expect=B49B,B4FC,B5D5;
--dialogue=PATH takes the expected text from another copy (trybuild.py writes one).
--words checks that the `en` of those script.json runs (a segment, or an id range of it) is on
the screen rows the scenario dumped (dump_screen): e.g. menus --words=field_menu,item_menu.

Mesen is found via $MESEN (the exe or its folder) or ./Mesen_2.1.1/. It runs portable: the
runner keeps a settings.json beside Mesen.exe with Lua I/O access on (the scenarios write their
log and screenshots), which also keeps Mesen's data out of the user's Documents.

The ROM defaults to ps1en.sms (the last build). The labels come from the last build's symbol
file; the code labels do not move (checkbuild.py), so they also hold for
PSI_Disasm/ps1original.sms - run any scenario with --rom=PSI_Disasm/ps1original.sms to compare.
"""
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ps1text as T
import stockwrap as W

ROOT = T.ROOT
SCRIPTS = os.path.join(ROOT, 'work', 'scripts')
OUT = os.path.join(ROOT, 'work', 'analysis')
EXIT = {0: 'done', 1: 'the scenario failed', 2: 'frame cap reached'}


def mesen():
    for p in (os.environ.get('MESEN'), os.path.join(ROOT, 'Mesen_2.1.1')):
        if not p:
            continue
        exe = p if p.lower().endswith('.exe') else os.path.join(p, 'Mesen.exe')
        if os.path.exists(exe):
            return exe
    raise SystemExit('Mesen not found: set MESEN or unpack Mesen 2.1.1 into Mesen_2.1.1/')


def ensure_settings(exe):
    """Portable mode: settings.json beside the exe, with Lua I/O access on and an SMS pad in
    port 1 (Mesen sets the pad up only in its first-run wizard, which the runner skips)."""
    path = os.path.join(os.path.dirname(exe), 'settings.json')
    cfg = {}
    if os.path.exists(path):
        try:
            cfg = json.load(open(path, encoding='utf-8-sig'))
        except ValueError:
            cfg = {}
    before = json.dumps(cfg, sort_keys=True)
    cfg.setdefault('Debug', {}).setdefault('ScriptWindow', {})['AllowIoOsAccess'] = True
    cfg.setdefault('Sms', {}).setdefault('Port1', {})['Type'] = 'SmsController'
    if json.dumps(cfg, sort_keys=True) != before:
        json.dump(cfg, open(path, 'w', encoding='utf-8'), indent=1)


def lua_str(s):
    return '"%s"' % s.replace('\\', '/').replace('"', '\\"')


def lua_value(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, float)):
        return str(v)
    return lua_str(str(v))


def compose(name, scenario, params, frames):
    syms = T.symbols()
    labels = {k: a for k, (b, a) in syms.items() if b < 2 and a < 0x8000 and re.match(r'^[A-Za-z_]\w*$', k)}
    head = ['PS1 = {',
            '  name = %s,' % lua_str(name),
            '  out = %s,' % lua_str(OUT),
            '  max_frames = %d,' % frames,
            '  params = {%s},' % ', '.join('[%s] = %s' % (lua_str(k), lua_value(v)) for k, v in params.items()),
            '  labels = {']
    head += ['    %s = 0x%04X,' % (k, a) for k, a in sorted(labels.items())]
    head += ['  },', '  rom = {']           # every label's ROM offset (for data in any bank)
    head += ['    %s = 0x%05X,' % (k, T.rom_offset(b, a)) for k, (b, a) in sorted(syms.items())
             if re.match(r'^[A-Za-z_]\w*$', k)]
    head += ['  },', '}', '']
    # the face (tools/diafont.py) for reading vwf_windows' cells: each glyph's advance and its
    # columns, bit r the pixel in row r
    import diafont
    head += ['FACE = {']
    for ch in diafont.CHAR_CODE:
        adv, rows = diafont.glyph(ch)
        cols = [sum(((rows[r] >> (7 - x)) & 1) << r for r in range(8)) for x in range(min(adv, 8))]
        head.append('  { %s, %d, { %s } },' % (lua_str(ch), adv, ', '.join(str(c) for c in cols)))
    head += ['}', '']
    # the menu words the build shows (script.json, or --script=: a trial build's copy), so a
    # scenario finds a translated menu: PS1_WORDS.attack (the battle menu's first), yes, no
    words = json.load(open(SCRIPT_PATH or os.path.join(ROOT, 'work', 'script.json'), encoding='utf-8'))
    segs = words['segments']
    head += ['PS1_WORDS = { attack = %s, yes = %s, no = %s }' % (
        lua_str(segs['battle_menu']['runs'][0]['en'].strip()),
        lua_str(segs['yes_no']['runs'][0]['en'].strip()), lua_str(segs['yes_no']['runs'][1]['en'].strip())), '']
    lib = open(os.path.join(SCRIPTS, 'lib.lua'), encoding='utf-8').read()
    body = open(scenario, encoding='utf-8').read()
    return '\n'.join(head) + lib + '\n-- ---- scenario: %s\n' % os.path.basename(scenario) + body


SCRIPT_PATH = None                     # main: --script=


def run(name, rom=None, params=None, timeout=120, frames=30000, keep_sram=False):
    """Run one scenario; returns (exit code, log lines)."""
    scenario = name if name.endswith('.lua') else os.path.join(SCRIPTS, name + '.lua')
    name = os.path.splitext(os.path.basename(scenario))[0]
    rom = os.path.abspath(rom or os.path.join(ROOT, 'ps1en.sms'))
    if not os.path.exists(rom):
        raise SystemExit('no ROM at %s (build one with tools/sourcebuild.py)' % rom)
    exe = mesen()
    ensure_settings(exe)
    if not keep_sram:                    # every run starts with a blank battery (no saved games)
        sav = os.path.join(os.path.dirname(exe), 'Saves', os.path.splitext(os.path.basename(rom))[0] + '.sav')
        if os.path.exists(sav):
            os.remove(sav)
    os.makedirs(os.path.join(OUT, 'run'), exist_ok=True)
    for f in os.listdir(OUT):
        if f.startswith(name + '_') and f.endswith('.png') or f == name + '.log':
            os.remove(os.path.join(OUT, f))
    script = os.path.join(OUT, 'run', name + '.lua')
    open(script, 'w', encoding='utf-8', newline='\n').write(compose(name, scenario, params or {}, frames))
    try:
        p = subprocess.run([exe, '--testRunner', '--timeout=%d' % timeout, script, rom],
                           cwd=os.path.dirname(exe), stdin=subprocess.DEVNULL,
                           capture_output=True, timeout=timeout + 30)
        code = p.returncode
    except subprocess.TimeoutExpired:
        code = -2
    logpath = os.path.join(OUT, name + '.log')
    lines = open(logpath, encoding='utf-8').read().splitlines() if os.path.exists(logpath) else []
    return code, lines


def vwf_text(line):
    """A line lib.lua read back from the proportional tiles ("vwf:" + the hex of the line's tiles,
    8 ink rows each: 10 in the window, 15 in a cut-scene) -> its text, decoded with the face;
    any other line as it is."""
    if not line.startswith('vwf:'):
        return line
    import diafont
    data = bytes.fromhex(line[4:])
    px = len(data)                       # 8 rows a tile: a byte a pixel column of 8
    rows = [[(data[(x // 8) * 8 + r] >> (7 - x % 8)) & 1 for x in range(px)] for r in range(8)]
    return diafont.decode(rows)


def seen_pages(lines):
    """The pages a scenario logged ("page N (window|cut-scene): a / b ..."): [(kind, lines)]."""
    out = []
    for l in lines:
        m = re.search(r'page \d+ \((window|cut-scene)\): (.*)$', l)
        if m:
            page = [vwf_text(x.strip()).rstrip() for x in m.group(2).split(' / ')]
            while page and not page[-1]:
                page.pop()
            out.append((m.group(1), page))
    return out


def chain(doc, start):
    """The entries the game plays from `start`: on through every falls_through."""
    entries = doc['entries']
    i = next((n for n, e in enumerate(entries) if e['id'] in (start, 'LABEL_' + start)), None)
    if i is None:
        raise SystemExit('no entry %s in dialogue.json' % start)
    out = [entries[i]]
    while out[-1].get('falls_through'):
        i += 1
        out.append(entries[i])
    return out


def window_pages(texts):
    """The dialogue window at each button wait while it plays `texts` (one open window).

    Two lines; a {BR} or a {PAGE} moves to the next line, scrolling once both are used; a
    {PAGE} and an {END} wait for a button first ({TIMED} and {PAUSE} for a time: a page too,
    as lib.lua's page_scene logs them); {CLR} empties the window; a string that
    starts in the open window starts on a new line. At a wait the window shows the last two
    lines since it opened or was cleared."""
    shown, cur, pages = [], '', []

    def snap():
        ls = (shown + [cur])[-2:]
        while ls and not ls[-1]:
            ls.pop()
        pages.append(('window', [x.rstrip() for x in ls]))

    for n, text in enumerate(texts):
        if n and (shown or cur):
            shown.append(cur)
            cur = ''
        pos = 0
        for m in T.TAG.finditer(text):
            cur += text[pos:m.start()]
            tag = m.group(1)
            if tag in ('BR', 'PAGE'):
                if tag == 'PAGE':
                    snap()
                shown.append(cur)
                cur = ''
            elif tag == 'CLR':
                shown, cur = [], ''
            elif tag in ('END', 'TIMED', 'PAUSE'):   # a button wait, or a timed one
                snap()
            elif tag not in T.TERMINATORS:
                cur += m.group(0)
            pos = m.end()
        cur += text[pos:]
    return pages


def build_texts(path=None):
    """dialogue.json (or `path`) and each entry's text as the build gives it (tools/stockwrap.py:
    with the face options of ps1.options.asm, the stock text re-wrapped). The script for the
    inserts' widths is the one beside `path` (trybuild's OUT.script.json) or work/script.json."""
    doc = json.load(open(path or os.path.join(ROOT, 'work', 'dialogue.json'), encoding='utf-8'))
    spath = path.replace('.dialogue.json', '.script.json') if path else ''
    if not os.path.exists(spath):
        spath = os.path.join(ROOT, 'work', 'script.json')
    script = json.load(open(spath, encoding='utf-8'))
    return doc, W.texts(doc['entries'], script, T.options())


def expected_pages(ids, path=None):
    """The pages entries `ids` should show, from their text in the build: [(kind, lines)]. Cut-scene ids
    give cut-scene pages; dialogue and message ids, given in the order the game plays them,
    give the window's pages (one window for a run of consecutive window ids)."""
    doc, texts = build_texts(path)
    out, run = [], []
    for i in ids + [None]:
        es = chain(doc, i) if i else []
        if run and (not es or es[0]['kind'] == 'cutscene'):
            out += window_pages(run)
            run = []
        if not es:
            break
        if es[0]['kind'] != 'cutscene':
            run.append(''.join(texts[e['id']] for e in es))
            continue
        text = T.TAG.sub(lambda m: {'BR': '\n', 'PAGE': '\f', 'CLR': '\f'}.get(m.group(1), ''),
                         ''.join(texts[e['id']] for e in es))
        for p in text.split('\f'):
            page = [x.rstrip() for x in p.split('\n')]
            while page and not page[-1]:
                page.pop()
            if page:
                out.append(('cut-scene', page))
    return out


def expected_words(spec, path=None):
    """The `en` of script.json runs: spec 'segment[:ids],...', ids 'n', 'a-b' or several joined
    with '+' (items:25+27+28) -> [(label, word)]."""
    doc = json.load(open(path or os.path.join(ROOT, 'work', 'script.json'), encoding='utf-8'))
    out = []
    for part in spec.split(','):
        seg, _, ids = part.partition(':')
        if seg not in doc['segments']:
            raise SystemExit('no segment %s in script.json' % seg)
        ranges = [(int(a), int(b or a)) for a, _, b in (x.partition('-') for x in ids.split('+'))] if ids else []
        for r in doc['segments'][seg]['runs']:
            if ranges and not any(a <= int(r['id']) <= b for a, b in ranges):
                continue
            if r['en'].strip():
                out.append(('%s %s' % (seg, r['id']), r['en'].strip()))
    return out


WILD = {'NAME': '.{1,6}', 'ENEMY': '.{1,14}', 'ITEM': '.{1,14}', 'NUMBER': '[0-9O]{1,5}'}


def same_page(want, seen):
    """A page as expected: the same kind and lines, an insert matching any value it can hold.
    '0' and 'O' count as the same (they look the same in the face, which decodes 'O')."""
    if want[0] != seen[0] or len(want[1]) != len(seen[1]):
        return False
    for w, s in zip(want[1], seen[1]):
        pattern = ''.join(WILD.get(m.group(1), re.escape(m.group(0))) if m.group(1) else
                          re.escape(m.group(0).replace('0', 'O'))
                          for m in re.finditer(r'\{(\w+)\}|[^{]+|\{', w))
        if not re.fullmatch(pattern, s.replace('0', 'O')):
            return False
    return True


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--') and '=' not in a]
    if not args:
        raise SystemExit(__doc__)
    opts = dict(a[2:].split('=', 1) for a in sys.argv[1:] if a.startswith('--') and '=' in a)
    params = dict(a.split('=', 1) for a in sys.argv[1:] if not a.startswith('--') and '=' in a)
    global SCRIPT_PATH
    SCRIPT_PATH = opts.get('script')
    code, lines = run(args[0], opts.get('rom'), params, int(opts.get('timeout', 120)),
                      int(opts.get('frames', 30000)), '--keep-sram' in sys.argv)
    for l in lines:
        print(l)
    print('%s: %s (exit %d)' % (args[0], EXIT.get(code, 'Mesen did not finish (timeout or crash)'), code))
    if not lines:
        print('no log at all: the script did not load - a Lua syntax error (e.g. a goto past a local)?')
    if code != 0:
        raise SystemExit(1)
    if 'expect' in opts:
        want, seen = expected_pages(opts['expect'].split(','), opts.get('dialogue')), seen_pages(lines)
        bad = [n for n in range(max(len(want), len(seen)))
               if n >= len(want) or n >= len(seen) or not same_page(want[n], seen[n])]
        for n in bad[:10]:
            print('page %d: expected %s' % (n + 1, str(want[n]) if n < len(want) else '-'))
            print('         on screen %s' % (str(seen[n]) if n < len(seen) else '-'))
        print('%d of %d pages as dialogue.json has them' % (len(want) - len(bad), len(want)))
        if bad:
            raise SystemExit(1)
    if '--known' in sys.argv:
        doc, texts = build_texts(opts.get('dialogue'))
        known, chain_text = set(), ''
        for e in doc['entries']:          # a chain (falls_through) as one text: a line may span it
            chain_text += texts[e['id']]
            if e.get('falls_through'):
                continue
            text = T.TAG.sub(lambda m: '\n' if m.group(1) in ('BR', 'PAGE', 'CLR') else
                             ('' if m.group(1) in T.TERMINATORS else m.group(0)), chain_text)
            chain_text = ''
            known.update(x.rstrip() for x in text.split('\n') if x.strip())
        seen = [l for kind, page in seen_pages(lines) if kind == 'window' for l in page if l.strip()]
        unknown = [l for l in seen if not any(same_page(('window', [k]), ('window', [l])) for k in known)]
        for l in unknown:
            print('not a line of dialogue.json: %r' % l)
        print('%d of %d window lines are lines of dialogue.json' % (len(seen) - len(unknown), len(seen)))
        if unknown:
            raise SystemExit(1)
    if 'words' in opts:
        screen = '\n'.join(l.split('|', 1)[1] for l in lines if '|' in l)
        want = expected_words(opts['words'], opts.get('script'))
        # the menus' fixed font is capitals only: compare in capitals
        missing = [(k, w) for k, w in want
                   if not re.search(r'(?<![A-Z0-9])%s(?![A-Z0-9])' % re.escape(w.upper()), screen.upper())]
        for k, w in missing:
            print('not on screen: %s %r' % (k, w))
        print('%d of %d script.json words on screen' % (len(want) - len(missing), len(want)))
        if missing:
            raise SystemExit(1)


if __name__ == '__main__':
    main()
