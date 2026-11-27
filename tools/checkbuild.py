"""Nothing in the stock image moved.

    python tools/checkbuild.py [--snapshot]

Compares every label of PSI_Disasm/ps1built.sym (the last build) with work/stock_labels.json,
except the labels that live in the text regions and may move with the translation: bank 2
from DialogueBlock (02:8000) to the end of the bank (the table, the blocks, the cut-scene
strings and the dictionary after them; relocate_script takes the text to banks 32-34), and
bank 12 from the first message (0C:B108); and except the labels an option replaces with its
own code (REPLACED). Every other label must keep its stock address; labels in the new banks
(32-63) are new. --snapshot writes stock_labels.json from the
current symbol file (do it only on a stock build).
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ps1text as T

SNAPSHOT = os.path.join(T.ROOT, 'work', 'stock_labels.json')
MOVABLE = [(2, 0x8000, 0xC000), (12, 0xB108, 0xC000)]
# labels an option removes on purpose (its code takes their place)
REPLACED = {'far_calls': ['_RST_10H', '_RST_18H', '_RST_20H', '_RST_28H', '_RST_30H'],
            # the number printer's insides (only it refers to them); LABEL_3292 and LABEL_3332,
            # its entry and the code after it, stay put
            'vwf_dialogue': ['LABEL_32A2', 'LABEL_32B2', 'LABEL_32C2', 'LABEL_32D0', 'LABEL_32E1',
                             'LABEL_32F5', 'LABEL_32FB', 'LABEL_3302'],
            # the equipment box's own loop
            'long_item_names': ['LABEL_3735'],
            # the battle menu's redraw (MacroAsk draws the round's windows; its bytes hold the
            # field menu's table)
            'battle_macros': ['LABEL_30D5'],
            # the hospital's insides (ext/hospital.asm has the routine; LABEL_298D stays put)
            'hospital_everyone': ['LABEL_2999', 'LABEL_2A48', 'LABEL_2A52', 'LABEL_2A55', 'LABEL_2A5E']}


def options():
    text = open(os.path.join(T.DISASM, 'ps1.options.asm'), encoding='latin-1').read()
    return {m.group(1): int(m.group(2)) for m in re.finditer(r'(?m)^\.define\s+(\w+)\s+(\d+)', text)}


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
    gone = {l for opt, labels in REPLACED.items() if options().get(opt) for l in labels}
    moved, missing = [], []
    for name, (bank, addr) in stock.items():
        if name in gone:
            continue
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
