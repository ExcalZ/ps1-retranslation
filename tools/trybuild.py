"""Build a test ROM from a few `en` edits, leaving the JSON and the source as they were.

    python tools/trybuild.py EDITS.json OUT.sms

EDITS.json: {"dialogue": {ID: en, ...}, "script": {SEGMENT: {RUN_ID: en, ...}, ...}}. The edits
are applied to temporary copies of work/dialogue.json and work/script.json (written beside
OUT as OUT.dialogue.json / OUT.script.json, for ps1emu.py --dialogue=), gentext.py writes them
into the source, the ROM is assembled to OUT, and the source is put back and rebuilt.
The edits must pass linecheck's rules; the build fails otherwise (the assembler on overflow,
gentext on an unencodable line).

Use it to see a line in the game before committing it to the JSON:
    python tools/trybuild.py edits.json work/analysis/try.sms
    python tools/ps1emu.py opening --rom=work/analysis/try.sms --dialogue=work/analysis/try.sms.dialogue.json --expect=B49B
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import checkstock

ROOT = checkstock.ROOT
DISASM = checkstock.DISASM


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    edits = json.load(open(sys.argv[1], encoding='utf-8'))
    out = os.path.abspath(sys.argv[2])
    dialogue = json.load(open(os.path.join(ROOT, 'work', 'dialogue.json'), encoding='utf-8'))
    script = json.load(open(os.path.join(ROOT, 'work', 'script.json'), encoding='utf-8'))
    by_id = {e['id']: e for e in dialogue['entries']}
    for i, en in edits.get('dialogue', {}).items():
        e = by_id.get(i) or by_id.get('LABEL_' + i)
        if e is None:
            raise SystemExit('no dialogue entry %s' % i)
        e['en'] = en
    for seg, runs in edits.get('script', {}).items():
        rs = {str(r['id']): r for r in script['segments'][seg]['runs']}
        for i, en in runs.items():
            rs[str(i)]['en'] = en
    paths = {'dialogue': out + '.dialogue.json', 'script': out + '.script.json'}
    json.dump(dialogue, open(paths['dialogue'], 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    json.dump(script, open(paths['script'], 'w', encoding='utf-8'), ensure_ascii=False, indent=1)

    saved = {f: open(os.path.join(DISASM, f), 'rb').read() for f in checkstock.SOURCES}
    try:
        if subprocess.call([sys.executable, os.path.join(HERE, 'gentext.py'),
                            '--dialogue=' + paths['dialogue'], '--script=' + paths['script']]):
            raise SystemExit('gentext failed')
        if subprocess.call([sys.executable, os.path.join(HERE, 'sourcebuild.py'), out, '--no-gen']):
            raise SystemExit('assembly failed')
        if subprocess.call([sys.executable, os.path.join(HERE, 'checkbuild.py')]):
            raise SystemExit('something moved')
    finally:
        for f, data in saved.items():
            open(os.path.join(DISASM, f), 'wb').write(data)
        subprocess.call([sys.executable, os.path.join(HERE, 'sourcebuild.py'),
                         os.path.join(os.path.dirname(out), 'restored.sms'), '--no-gen'],
                        stdout=subprocess.DEVNULL)
        try:
            os.remove(os.path.join(os.path.dirname(out), 'restored.sms'))
        except FileNotFoundError:
            pass


if __name__ == '__main__':
    main()
