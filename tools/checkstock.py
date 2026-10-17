"""The stock-reproduction check: with every option in ps1.options.asm at 0 the source
assembles to the US/EU release v3 (CRC32 00BEF1D7) byte for byte.

    python tools/checkstock.py

Sets the options to 0, assembles (sourcebuild --no-gen), compares with
PSI_Disasm/ps1original.sms and puts the options file back. Once the JSON and
gentext.py exist, this must also write every en as its us first (as PS II's does).
"""
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
OPTIONS = os.path.join(DISASM, 'ps1.options.asm')


def main():
    tmp = tempfile.mkdtemp()
    saved = open(OPTIONS, 'rb').read()
    try:
        open(OPTIONS, 'wb').write(re.sub(rb'(?m)^(\.define\s+\w+)\s+1\b', rb'\1 0', saved))
        out = os.path.join(tmp, 'stock.sms')
        if subprocess.call([sys.executable, os.path.join(HERE, 'sourcebuild.py'), out, '--no-gen']):
            raise SystemExit('assembly failed')
        built, stock = open(out, 'rb').read(), open(STOCK, 'rb').read()
    finally:
        open(OPTIONS, 'wb').write(saved)
        shutil.rmtree(tmp, ignore_errors=True)
    if built == stock:
        print('byte-identical to the US/EU release v3 (CRC32 %08X)' % zlib.crc32(stock))
        return
    diff = [i for i in range(min(len(built), len(stock))) if built[i] != stock[i]]
    print('%d bytes differ, first at $%05X' % (len(diff), diff[0] if diff else min(len(built), len(stock))))
    raise SystemExit(1)


if __name__ == '__main__':
    main()
