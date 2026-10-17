"""Nothing in the stock image moved.

    python tools/checkbuild.py [--snapshot]

Compares every label of PSI_Disasm/ps1built.sym (the last build) with work/stock_labels.json,
except the labels that live in the text regions and may move with the translation: bank 2
from the first dialogue block (02:82AA) to the end of the bank (the blocks, the cut-scene
strings and the dictionary after them), and bank 12 from the first message (0C:B108).
Every other label must keep its stock address. --snapshot writes stock_labels.json from the
current symbol file (do it only on a stock build).
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ps1text as T

SNAPSHOT = os.path.join(T.ROOT, 'work', 'stock_labels.json')
MOVABLE = [(2, 0x82AA, 0xC000), (12, 0xB108, 0xC000)]


def movable(bank, addr):
    return any(bank == b and lo <= addr < hi for b, lo, hi in MOVABLE)


def main():
    syms = T.symbols()
    if '--snapshot' in sys.argv:
        json.dump({k: '%02X:%04X' % v for k, v in sorted(syms.items())},
                  open(SNAPSHOT, 'w', encoding='utf-8', newline='\n'), indent=0)
        print('wrote %d labels' % len(syms))
        return
    stock = {k: tuple(int(x, 16) for x in v.split(':'))
             for k, v in json.load(open(SNAPSHOT, encoding='utf-8')).items()}
    moved, missing = [], []
    for name, (bank, addr) in stock.items():
        if movable(bank, addr):
            continue
        if name not in syms:
            missing.append(name)
        elif syms[name] != (bank, addr):
            moved.append('%s %02X:%04X -> %02X:%04X' % ((name, bank, addr) + syms[name]))
    for m in moved[:30]:
        print('moved', m)
    for m in missing[:30]:
        print('missing', m)
    if moved or missing:
        raise SystemExit('%d labels moved, %d missing' % (len(moved), len(missing)))
    print('nothing moved (%d fixed labels)' % sum(1 for b, a in stock.values() if not movable(b, a)))


if __name__ == '__main__':
    main()
