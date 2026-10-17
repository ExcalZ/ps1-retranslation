"""Draw work/analysis/vramdump.json as a tile sheet, to find the tiles a battle leaves free.

    python tools/ps1emu.py vramdump enemy=39 [bg=N]
    python tools/vramsheet.py            writes work/analysis/vramsheet.png

Every VRAM tile, 4x, framed by how the screen used it during the dump (green the background,
blue a sprite, red never on screen), rows and columns labelled in hex; the free ranges are
printed. Tiles $1C0-$1FF are the nametable, the frame tiles and the sprite table (grey). The
font slots a screen happens not to show count as red but are not free. No image library: the
PNG is written by hand."""
import json
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import diafont as F

OUT = os.path.join(os.path.dirname(HERE), 'work', 'analysis')
d = json.load(open(os.path.join(OUT, 'vramdump.json')))
vram = bytes.fromhex(d['vram'])
pal = d.get('pal') or list(range(32))
bg = {t: m for t, m in d['shown']}
spr = {t for t, _ in d['spr']}


def rgb(c):
    return ((c & 3) * 85, ((c >> 2) & 3) * 85, ((c >> 4) & 3) * 85)


S, GAP, LEFT, TOP = 4, 4, 44, 40
W = LEFT + 16 * (8 * S + GAP) + 8
H = TOP + 32 * (8 * S + GAP) + 8
img = [[(40, 40, 40)] * W for _ in range(H)]


def put(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        img[y][x] = c


def text(x, y, s, c=(230, 230, 230), scale=2):
    rows = F.render(s, px=F.width(s))
    for r, row in enumerate(rows):
        for cx, on in enumerate(row):
            if on:
                for dy in range(scale):
                    for dx in range(scale):
                        put(x + cx * scale + dx, y + r * scale + dy, c)


GREEN, BLUE, RED, GREY = (60, 200, 80), (80, 140, 255), (230, 60, 60), (110, 110, 110)
text(4, 4, 'Enemy %d, backdrop %d. Green: background on screen; blue: sprite; red: not on screen' % (d['enemy'], d['bg']), scale=1)
text(4, 16, 'Grey: tiles 1C0-1FF, the nametable, frame tiles and sprite table', scale=1)
for col in range(16):
    text(LEFT + col * (8 * S + GAP) + 12, TOP - 14, '%X' % col)
for t in range(512):
    row, col = divmod(t, 16)
    x0, y0 = LEFT + col * (8 * S + GAP), TOP + row * (8 * S + GAP)
    if col == 0:
        text(2, y0 + 10, '%03X' % t)
    palbase = 16 if (t in spr or bg.get(t, 1) & 2) else 0
    for y in range(8):
        p = [vram[t * 32 + y * 4 + k] for k in range(4)]
        for x in range(8):
            ci = sum(((p[k] >> (7 - x)) & 1) << k for k in range(4))
            c = rgb(pal[palbase + ci])
            for dy in range(S):
                for dx in range(S):
                    put(x0 + x * S + dx, y0 + y * S + dy, c)
    frame = GREY if t >= 0x1C0 else GREEN if t in bg else BLUE if t in spr else RED
    if t in bg and t in spr:
        frame = (60, 200, 200)
    for i in range(-2, 8 * S + 2):
        for k in (1, 2):
            put(x0 + i, y0 - k, frame)
            put(x0 + i, y0 + 8 * S + k - 1, frame)
            put(x0 - k, y0 + i, frame)
            put(x0 + 8 * S + k - 1, y0 + i, frame)

free = [t for t in range(0x1C0) if t not in bg and t not in spr]
runs = []
for t in free:
    if runs and runs[-1][1] == t - 1:
        runs[-1][1] = t
    else:
        runs.append([t, t])
print('%d tiles below $1C0 not on screen: %s' % (len(free), ', '.join(
    '$%03X-$%03X' % (a, b) if a != b else '$%03X' % a for a, b in runs)))


def png(path, rows):
    raw = b''.join(b'\x00' + bytes(v for px in r for v in px) for r in rows)

    def chunk(tag, data):
        c = tag + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xFFFFFFFF)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0))
                           + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


png(os.path.join(OUT, 'vramsheet.png'), img)
print('wrote work/analysis/vramsheet.png')
