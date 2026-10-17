"""The stock-reproduction check: with every option in ps1.options.asm at 0 and every `en`
set to its `us`, the source assembles to the US/EU release v3 (CRC32 00BEF1D7) byte for byte.

    python tools/checkstock.py

Writes the JSON with en = us to temporary files, sets the options to 0, regenerates the text
from them (gentext.py), assembles, compares with PSI_Disasm/ps1original.sms, and puts the
sources back (and assembles them again, so ps1built.sym matches the source).
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DISASM = os.path.join(ROOT, 'PSI_Disasm')
STOCK = os.path.join(DISASM, 'ps1original.sms')
# every file gentext writes, and the options; put back afterwards
SOURCES = ['ps1.asm', os.path.join('sound', 'sound_driver.asm'), os.path.join('banks', 'bank03.asm'),
           'ps1.options.asm']


def main():
    tmp = tempfile.mkdtemp()
    saved = {f: open(os.path.join(DISASM, f), 'rb').read() for f in SOURCES}
    try:
        opts = os.path.join(DISASM, 'ps1.options.asm')
        open(opts, 'wb').write(re.sub(rb'(?m)^(\.define\s+\w+)\s+1\b', rb'\1 0', saved['ps1.options.asm']))
        paths = {}
        for name in ('dialogue', 'script'):
            doc = json.load(open(os.path.join(ROOT, 'work', name + '.json'), encoding='utf-8'))
            runs = doc['entries'] if name == 'dialogue' else [r for s in doc['segments'].values() for r in s['runs']]
            for r in runs:
                r['en'] = r['us']
            paths[name] = os.path.join(tmp, name + '.json')
            json.dump(doc, open(paths[name], 'w', encoding='utf-8'), ensure_ascii=False)
        if subprocess.call([sys.executable, os.path.join(HERE, 'gentext.py'),
                            '--dialogue=' + paths['dialogue'], '--script=' + paths['script']]):
            raise SystemExit('gentext failed')
        out = os.path.join(tmp, 'stock.sms')
        if subprocess.call([sys.executable, os.path.join(HERE, 'sourcebuild.py'), out, '--no-gen']):
            raise SystemExit('assembly failed')
        built, stock = open(out, 'rb').read(), open(STOCK, 'rb').read()
    finally:
        for f, data in saved.items():
            open(os.path.join(DISASM, f), 'wb').write(data)
        subprocess.call([sys.executable, os.path.join(HERE, 'sourcebuild.py'),
                         os.path.join(tmp, 'restored.sms'), '--no-gen'], stdout=subprocess.DEVNULL)
        shutil.rmtree(tmp, ignore_errors=True)
    if built == stock:
        print('byte-identical to the US/EU release v3 (CRC32 %08X)' % zlib.crc32(stock))
        return
    diff = [i for i in range(min(len(built), len(stock))) if built[i] != stock[i]]
    print('%d bytes differ, first at $%05X' % (len(diff), diff[0] if diff else min(len(built), len(stock))))
    raise SystemExit(1)


if __name__ == '__main__':
    main()
