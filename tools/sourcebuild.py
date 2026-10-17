"""Build the retranslation ROM from source.

    python tools/sourcebuild.py [out.sms] [--no-gen]

1. gentext.py writes work/dialogue.json and work/script.json into PSI_Disasm/
   (skipped with --no-gen, and until gentext.py exists);
2. WLA-DX assembles and links PSI_Disasm/ps1.asm (wla-z80 + wlalink, as
   PSI_Disasm/build.bat does, but with WLA-DX 10.7 rather than the 2006 binaries
   the disassembly ships);
3. the SMS header checksum is fixed in Python and the ROM is copied to `out.sms`
   (default: ps1en.sms in the repo root).

WLA-DX is found via $WLADX (the directory holding wla-z80.exe) or
./wla_dx_v10.7_Win64/. On an assembler or linker error its output is written to
PSI_Disasm/ps1.log and the build fails: never test a ROM while ps1.log exists.
The linker also writes PSI_Disasm/ps1built.sym (WLA symbols; Mesen 2 imports them).
"""
import hashlib
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
DISASM = os.path.join(ROOT, 'PSI_Disasm')
BUILT = os.path.join(DISASM, 'ps1built.sms')
LOG = os.path.join(DISASM, 'ps1.log')

# SMS header at $7FF0: the low nibble of $7FFF gives the range the BIOS checksums
# ($0000-$7FEF plus $8000 up to the end of the range). The stock ROM says $0, 256 KB.
SIZES = {0xC: 0x8000, 0xE: 0x10000, 0xF: 0x20000, 0x0: 0x40000, 0x1: 0x80000}


def wladx():
    for d in (os.environ.get('WLADX'), os.path.join(ROOT, 'wla_dx_v10.7_Win64')):
        if d and os.path.exists(os.path.join(d, 'wla-z80.exe')):
            return d
    raise SystemExit('WLA-DX not found: set WLADX or unpack wla_dx_v10.7_Win64/ in the repo root')


def checksum(rom):
    end = SIZES[rom[0x7FFF] & 15]
    return (sum(rom[:0x7FF0]) + sum(rom[0x8000:end])) & 0xFFFF


def fix_checksum(rom):
    rom = bytearray(rom)
    rom[0x7FFA:0x7FFC] = checksum(rom).to_bytes(2, 'little')
    return bytes(rom)


def run(cmd):
    p = subprocess.run(cmd, cwd=DISASM, stdin=subprocess.DEVNULL, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def assemble():
    for f in (LOG, os.path.join(DISASM, 'ps1.o')):
        try:
            os.remove(f)
        except FileNotFoundError:
            pass
    if os.path.exists(BUILT):
        shutil.move(BUILT, BUILT.replace('.sms', '.prev.sms'))
    wla = wladx()
    for step, cmd in (('assembler', [os.path.join(wla, 'wla-z80.exe'), '-o', 'ps1.o', 'ps1.asm']),
                      ('linker', [os.path.join(wla, 'wlalink.exe'), '-r', '-s', 'link.txt', 'ps1built.sms'])):
        rc, out = run(cmd)
        if rc != 0 or 'ERROR' in out:
            open(LOG, 'w', encoding='utf-8', newline='').write(out)
            print(out)
            raise SystemExit('%s failed (see PSI_Disasm/ps1.log)' % step)
    if not os.path.exists(BUILT):
        raise SystemExit('linker wrote no ROM')


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    out = args[0] if args else os.path.join(ROOT, 'ps1en.sms')
    gentext = os.path.join(HERE, 'gentext.py')
    if '--no-gen' not in sys.argv and os.path.exists(gentext):
        if subprocess.call([sys.executable, gentext]) != 0:
            raise SystemExit('gentext.py failed')
    assemble()
    rom = open(BUILT, 'rb').read()
    if len(rom) not in (0x80000, 0x100000):     # 1 MB with expand_rom
        raise SystemExit('ROM is %d bytes, not 512 KB or 1 MB' % len(rom))
    fixed = fix_checksum(rom)
    if fixed != rom:
        open(BUILT, 'wb').write(fixed)
        print('checksum fixed: %04X' % checksum(fixed))
    shutil.copyfile(BUILT, out)
    print('%s  %d bytes  sha256 %s' % (out, len(fixed), hashlib.sha256(fixed).hexdigest()))


if __name__ == '__main__':
    main()
