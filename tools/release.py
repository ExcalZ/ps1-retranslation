"""Package the retranslation for distribution: BPS patches + patcher + readme + zip.

    python tools/release.py 1.0 [--rom ps1en.sms] [--allow-stale]

Produces, under release/ (both ignored by git):

    PS1_Retranslation_v1.0/PS1_Retranslation_v1.0.bps      (from US/EU v3)
    PS1_Retranslation_v1.0/PS1_Retranslation_v1.0_V2.bps   (from US/EU v2)
    PS1_Retranslation_v1.0/Patcher.html
    PS1_Retranslation_v1.0/readme.txt
    PS1_Retranslation_v1.0.zip

The disassembly reproduces US/EU v3 (CRC32 00BEF1D7, PSI_Disasm/ps1original.sms) with every
option at 0, so the canonical patch is made against v3. US/EU v2 (CRC32 E4A65E79) is taken as
well (the owner, 2026-11-26): a small BPS from v2 to v3 is embedded in Patcher.html, which
applies it first when it recognises that dump, and a second full patch from v2 ships beside
the canonical one for conventional patchers. The v2 dump is expected at
work/ps1en_v2_stock.sms (game data: never committed).

Patches are made with Flips when it is found (flips/flips.exe here or in a sibling
../ps4-translate or ../ps2-translate, all untracked) - its encoder finds more matches - and
with tools/bps.py otherwise. Either way tools/bps.py re-applies every patch, and the ROM must
come back byte for byte.

The readme is rendered from release/readme_template.txt: every number a player can check
(sizes, CRC32/MD5/SHA-1 of the sources and of the result, the header checksum, the date) is a
@TOKEN@ filled in from the files, so the text cannot disagree with the patch beside it. Edit
the template, not the rendered readme.

Refuses to package if:
  - the ROM being shipped differs from PSI_Disasm/ps1built.sms (a stale copy), unless
    --allow-stale is given
  - a source ROM's CRC32 is wrong, or the v2 dump is missing
  - the ROM's header checksum does not match the one stored at $7FFA
  - re-applying a patch does not reproduce its target
"""
import datetime
import hashlib
import os
import re
import subprocess
import sys
import tempfile
import zipfile
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import bps  # noqa: E402
import sourcebuild  # noqa: E402
import webpatch  # noqa: E402

NAME = 'PS1_Retranslation'
V3 = os.path.join(ROOT, 'PSI_Disasm', 'ps1original.sms')
V3_CRC = 0x00BEF1D7
V2 = os.path.join(ROOT, 'work', 'ps1en_v2_stock.sms')
V2_CRC = 0xE4A65E79
BUILT = os.path.join(ROOT, 'PSI_Disasm', 'ps1built.sms')
TEMPLATE = os.path.join(ROOT, 'release', 'readme_template.txt')
PATCHER = os.path.join(ROOT, 'tools', 'patcher_template.html')
FLIPS = next((p for p in [os.path.join(ROOT, 'flips', 'flips.exe')] +
              [os.path.join(os.path.dirname(ROOT), s, 'flips', 'flips.exe')
               for s in ('ps4-translate', 'ps2-translate')]
              if os.path.exists(p)), None)
OUTDIR = os.path.join(ROOT, 'release')


def hashes(data):
    return {'SIZE': '{:,}'.format(len(data)), 'CRC32': '%08X' % zlib.crc32(data),
            'MD5': hashlib.md5(data).hexdigest(), 'SHA1': hashlib.sha1(data).hexdigest()}


def make_patch(source, target, label, flips=True):
    if FLIPS and flips:
        with tempfile.TemporaryDirectory() as tmp:
            s, t, p = (os.path.join(tmp, n) for n in ('s.sms', 't.sms', 'p.bps'))
            open(s, 'wb').write(source)
            open(t, 'wb').write(target)
            subprocess.run([FLIPS, '--create', '--bps', s, t, p], check=True,
                           stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL)
            patch = open(p, 'rb').read()
    else:
        patch = bps.create(source, target, label.encode())
    if bps.apply(patch, source) != target:
        sys.exit('%s: the patch does not reproduce its target' % label)
    return patch


def render(template, tokens):
    text = open(template, encoding='utf-8').read()
    for k, v in tokens.items():
        text = text.replace('@%s@' % k, v)
    left = re.findall(r'@[A-Z][A-Z0-9_]*@', text)
    if left:
        sys.exit('%s: unfilled token(s): %s' % (os.path.basename(template), ', '.join(sorted(set(left)))))
    return text


def load(path, crc, what):
    if not os.path.exists(path):
        sys.exit('%s: missing - %s (CRC32 %08X) is needed there' % (path, what, crc))
    data = open(path, 'rb').read()
    if zlib.crc32(data) != crc:
        sys.exit('%s: CRC32 %08X, expected %08X - not %s' % (path, zlib.crc32(data), crc, what))
    return data


def main(argv):
    if not argv or argv[0].startswith('-'):
        sys.exit(__doc__)
    version = argv[0]
    rom_path = argv[argv.index('--rom') + 1] if '--rom' in argv else os.path.join(ROOT, 'ps1en.sms')

    v3 = load(V3, V3_CRC, 'Phantasy Star (USA, Europe) v3')
    v2 = load(V2, V2_CRC, 'Phantasy Star (USA, Europe) v2')
    rom = open(rom_path, 'rb').read()
    if os.path.exists(BUILT) and open(BUILT, 'rb').read() != rom and '--allow-stale' not in argv:
        sys.exit('%s differs from %s - rebuild first, or pass --allow-stale' % (rom_path, BUILT))
    stored = int.from_bytes(rom[0x7FFA:0x7FFC], 'little')
    if sourcebuild.checksum(rom) != stored:
        sys.exit('header checksum %04X does not match stored %04X' % (sourcebuild.checksum(rom), stored))

    stem = '%s_v%s' % (NAME, version)
    folder = os.path.join(OUTDIR, stem)
    os.makedirs(folder, exist_ok=True)
    label = '%s v%s' % (NAME.replace('_', ' '), version)
    patch = make_patch(v3, rom, label)
    patch2 = make_patch(v2, rom, label + ' (v2)')
    to_v3 = make_patch(v2, v3, 'v2 to v3', flips=False)
    names = {'PATCH': stem + '.bps', 'PATCH2': stem + '_V2.bps'}
    open(os.path.join(folder, names['PATCH']), 'wb').write(patch)
    open(os.path.join(folder, names['PATCH2']), 'wb').write(patch2)

    diff = sum(1 for a, b in zip(v2, v3) if a != b)
    tokens = dict(names, VERSION=version, DATE=datetime.date.today().strftime('%d.%m.%Y'),
                  SMSCHK='%04X' % stored, V2DIFF='{:,}'.format(diff))
    for prefix, data in (('SRC_', v3), ('V2_', v2), ('OUT_', rom)):
        for k, v in hashes(data).items():
            tokens[prefix + k] = v
    text = render(TEMPLATE, tokens)
    readme = os.path.join(folder, 'readme.txt')
    # BOM + CRLF: Notepad-friendly, as the PS II and PS IV readmes.
    open(readme, 'wb').write(('﻿' + text.replace('\r\n', '\n').replace('\n', '\r\n')).encode('utf-8'))

    patcher = os.path.join(folder, 'Patcher.html')
    webpatch.render_patcher(patch, patcher, PATCHER, {
        'TITLE': 'Phantasy Star',
        'SUBTITLE': 'English Retranslation v%s' % version,
        'GAME': 'Phantasy Star (USA, Europe)',
        'PATCH': names['PATCH'],
        'OUT_NAME': 'Phantasy Star - English Retranslation v%s' % version,   # + .sms
        'README_NOTE': ' See readme.txt.',
        'HINT': ' See readme.txt, section 2.',
    }, alternates=[('US/EU v2', to_v3)])

    zip_path = os.path.join(OUTDIR, stem + '.zip')
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as z:
        for n in (names['PATCH'], names['PATCH2'], 'Patcher.html', 'readme.txt'):
            z.write(os.path.join(folder, n), n)

    print('source  v3 %s  CRC32 %s; v2 CRC32 %s (%s bytes differ)'
          % (tokens['SRC_SIZE'], tokens['SRC_CRC32'], tokens['V2_CRC32'], tokens['V2DIFF']))
    print('target  %s  CRC32 %s  header checksum %s' % (tokens['OUT_SIZE'], tokens['OUT_CRC32'], tokens['SMSCHK']))
    print('patches %d / %d bytes (%s), %d-byte v2 -> v3 in the patcher; all verified by re-applying'
          % (len(patch), len(patch2), 'Flips' if FLIPS else 'tools/bps.py', len(to_v3)))
    print('wrote   %s' % folder)
    print('wrote   %s' % zip_path)


if __name__ == '__main__':
    main(sys.argv[1:])
