# -*- coding: utf-8 -*-
"""
只把【枪尾月亮】改成玻璃蓝色（青蓝 + 高光 + 内发光 + 外发光），
枪头后月牙保持原样。
"""
from PIL import Image, ImageFilter

SRC = r'c:\ds_mod\generated-images\A_single_stylized_polearm_weap_2026-10-25T05-15-43.png'
DST = r'c:\ds_mod\generated-images\spear_src_tailmoon.png'

im = Image.open(SRC).convert('RGBA')
w, h = im.size
px = im.load()

def is_bg(p):
    r, g, b = p[:3]
    mx = max(r, g, b); mn = min(r, g, b)
    return (mx - mn) <= 20 and 170 <= mx <= 228

# ---------- 枪尾月亮椭圆区域 ----------
TCX, TCY, TRX, TRY = 192, 541, 102, 55

def in_ellipse(x, y, cx, cy, rx, ry):
    dx = (x - cx) / float(rx)
    dy = (y - cy) / float(ry)
    return dx * dx + dy * dy <= 1.0

out = im.copy()
op = out.load()

# ---------- 1) 玻璃蓝染色 ----------
for y in range(max(0, TCY - TRY), min(h, TCY + TRY + 1)):
    for x in range(max(0, TCX - TRX), min(w, TCX + TRX + 1)):
        if not in_ellipse(x, y, TCX, TCY, TRX, TRY):
            continue
        r, g, b, a = op[x, y]
        if a == 0 or is_bg((r, g, b)):
            continue
        lum = (r * 299 + g * 587 + b * 114) / 1000.0
        # 保留黑色描边
        if lum < 50:
            continue
        t = max(0.0, min(1.0, (lum - 50.0) / 165.0))
        # 玻璃蓝：暗部 (18,85,140) -> 亮部 (130,225,240) —— 青蓝、通透
        tr = 18 + (130 - 18) * t
        tg = 85 + (225 - 85) * t
        tb = 140 + (240 - 140) * t
        k = 0.88
        op[x, y] = (
            int(max(0, min(255, r * (1 - k) + tr * k))),
            int(max(0, min(255, g * (1 - k) + tg * k))),
            int(max(0, min(255, b * (1 - k) + tb * k))),
            a,
        )

# ---------- 2) 玻璃高光（顶部亮带，模拟玻璃反光） ----------
for y in range(max(0, TCY - TRY), min(h, TCY + TRY + 1)):
    for x in range(max(0, TCX - TRX), min(w, TCX + TRX + 1)):
        if not in_ellipse(x, y, TCX, TCY, TRX, TRY):
            continue
        r, g, b, a = op[x, y]
        if a == 0 or is_bg((r, g, b)):
            continue
        # 上半部分（y 偏上）加强高光
        rel_y = (y - (TCY - TRY)) / float(TRY * 2)
        if rel_y < 0.42:
            boost = (0.42 - rel_y) / 0.42   # 0~1，越靠上越强
            hk = 0.55 * boost
            op[x, y] = (
                int(min(255, r + (235 - r) * hk)),
                int(min(255, g + (252 - g) * hk)),
                int(min(255, b + (255 - b) * hk)),
                a,
            )

# ---------- 3) 外发光（玻璃通透光晕） ----------
mask = Image.new('L', (w, h), 0)
mk = mask.load()
for y in range(max(0, TCY - TRY), min(h, TCY + TRY + 1)):
    for x in range(max(0, TCX - TRX), min(w, TCX + TRX + 1)):
        if not in_ellipse(x, y, TCX, TCY, TRX, TRY):
            continue
        r, g, b, a = op[x, y]
        if a == 0 or is_bg((r, g, b)):
            continue
        lum = (r * 299 + g * 587 + b * 114) / 1000.0
        if lum > 80:
            mk[x, y] = int(min(255, (lum - 80) * 2.0))

halo1 = mask.filter(ImageFilter.GaussianBlur(6))
halo2 = mask.filter(ImageFilter.GaussianBlur(14))
h1 = halo1.load()
h2 = halo2.load()

halo_layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
hl = halo_layer.load()
for y in range(max(0, TCY - TRY - 30), min(h, TCY + TRY + 30)):
    for x in range(max(0, TCX - TRX - 30), min(w, TCX + TRX + 30)):
        v1 = h1[x, y]
        v2 = h2[x, y]
        if v1 == 0 and v2 == 0:
            continue
        alpha = int(min(150, v1 * 0.50 + v2 * 0.38))
        if alpha > 0:
            hl[x, y] = (110, 205, 245, alpha)   # 玻璃青蓝光

final = Image.new('RGBA', (w, h), (0, 0, 0, 0))
final.paste(halo_layer, (0, 0), halo_layer)
final.paste(out, (0, 0), out)

final.convert('RGB').save(DST)
print('saved', DST)
