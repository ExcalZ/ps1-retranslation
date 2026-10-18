"""Write an edits file into work/dialogue.json and work/script.json (only the en fields).

    python tools/applyedits.py EDITS.json

EDITS.json as tools/trybuild.py takes it: {"dialogue": {ID: en}, "script": {SEGMENT: {RUN_ID: en}}}.
Try the edits first (trybuild.py, a scenario); then this makes them the script's. The JSON keeps
its layout (one-space indent, its own line endings); an unknown id stops it before anything is
written."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
WORK = os.path.join(os.path.dirname(HERE), 'work')


def load(name):
    path = os.path.join(WORK, name)
    text = open(path, encoding='utf-8', newline='').read()
    return path, text, json.loads(text)


def save(path, text, doc):
    nl = '\r\n' if '\r\n' in text else '\n'
    out = json.dumps(doc, ensure_ascii=False, indent=1).replace('\n', nl) + (nl if text.endswith(('\n', '\r\n')) else '')
    open(path, 'w', encoding='utf-8', newline='').write(out)


def main():
    edits = json.load(open(sys.argv[1], encoding='utf-8'))
    dpath, dtext, dialogue = load('dialogue.json')
    spath, stext, script = load('script.json')
    by_id = {e['id']: e for e in dialogue['entries']}
    for i, en in edits.get('dialogue', {}).items():
        e = by_id.get(i) or by_id.get('LABEL_' + i)
        if e is None:
            raise SystemExit('no entry %s in dialogue.json' % i)
        e['en'] = en
    for seg, runs in edits.get('script', {}).items():
        rs = {str(r['id']): r for r in script['segments'][seg]['runs']}
        for rid, en in runs.items():
            if str(rid) not in rs:
                raise SystemExit('no run %s %s in script.json' % (seg, rid))
            rs[str(rid)]['en'] = en
    save(dpath, dtext, dialogue)
    save(spath, stext, script)
    print('%d entries, %d runs' % (len(edits.get('dialogue', {})), sum(len(v) for v in edits.get('script', {}).values())))


if __name__ == '__main__':
    main()
