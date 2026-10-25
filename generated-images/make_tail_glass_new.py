# -*- coding: utf-8 -*-
"""
基于用户指定插图 A_single_stylized_polearm_weap_2026-10-25T05-10-43.png，
只把【枪尾月亮】改成玻璃蓝色，其余不变。
枪尾月亮实测位置：x 50~235, y 435~580，中心约 (140, 508)
"""
from PIL import Image, ImageFilter

SRC = r'c:\ds_mod\generated-images\A_single_stylized_polearm_weap_2026-10-25T05-10-43.png'
DST = r'c:\ds_mod\generated-images\spear_src_glass_tail.png'

im = Image.open(SRC).convert('RGBA')
w, h = im.size
px = im.load()

BG = (177, 177, 177)
def is_bg(p):
    r, g, b = p[:3]
    return abs(r-BG[0]) < 16 and abs(g-BG[1]) < 16 and abs(b-BG[2]) < 16

# 枪尾月亮椭圆区域
TCX, TCY, TRX, TRY = 140, 508, 95, 78

def in_ellipse(x, y):
    dx = (x - TCX) / float(TRX)
    dy = (y - TCY) / float(TRY)
    return dx*dx + dy*dy <= 1.0

out = im.copy()
op = out.load()

# ---- 1) 玻璃蓝染色 ----
for y in range(max(0, TCY-TRY), min(h, TCY+TRY+1)):
    for x in range(max(0, TCX-TRX), min(w, TCX+TRX+1)):
        if not in_ellipse(x, y):
            continue
        r, g, b, a = op[x, y]
        if a == 0 or is_bg((r, g, b)):
            continue
        lum = (r*299 + g*587 + b*114) / 1000.0
        if lum < 50:      # 保留黑描边
            continue
        t = max(0.0, min(1.0, (lum - 50.0) / 160.0))
        # 玻璃蓝：暗 (16,80,135) -> 亮 (125,225,242)
        tr = 16 + (125 - 16) * t
        tg = 80 + (225 - 80) * t
        tb = 135 + (242 - 135) * t
        k = 0.88
        op[x, y] = (
            int(max(0, min(255, r*(1-k) + tr*k))),
            int(max(0, min(255, g*(1-k) + tg*k))),
            int(max(0, min(255, b*(1-k) + tb*k))),
            a,
        )

# ---- 2) 玻璃高光（上部亮带） ----
for y in range(max(0, TCY-TRY), min(h, TCY+TRY+1)):
    for x in range(max(0, TCX-TRX), min(w, TCX+TRX+1)):
        if not in_ellipse(x, y):
            continue
        r, g, b, a = op[x, y]
        if a == 0 or is_bg((r, g, b)):
            continue
        rel_y = (y - (TCY - TRY)) / float(TRY * 2)
        if rel_y < 0.40:
            boost = (0.40 - rel_y) / 0.40
            hk = 0.55 * boost
            op[x, y] = (
                int(min(255, r + (235 - r) * hk)),
                int(min(255, g + (252 - g) * hk)),
                int(min(255, b + (255 - b) * hk)),
                a,
            )

# ---- 3) 外发光 ----
mask = Image.new('L', (w, h), 0)
mk = mask.load()
for y in range(max(0, TCY-TRY), min(h, TCY+TRY+1)):
    for x in range(max(0, TCX-TRX), min(w, TCX+TRX+1)):
        if not in_ellipse(x, y):
            continue
        r, g, b, a = op[x, y]
        if a == 0 or is_bg((r, g, b)):
            continue
        lum = (r*299 + g*587 + b*114) / 1000.0
        if lum > 80:
            mk[x, y] = int(min(255, (lum - 80) * 2.0))

h1 = mask.filter(ImageFilter.GaussianBlur(6)).load()
h2 = mask.filter(ImageFilter.GaussianBlur(14)).load()

halo = Image.new('RGBA', (w, h), (0, 0, 0, 0))
hp = halo.load()
for y in range(max(0, TCY-TRY-32), min(h, TCY+TRY+32)):
    for x in range(max(0, TCX-TRX-32), min(w, TCX+TRX+32)):
        v1 = h1[x, y]; v2 = h2[x, y]
        if v1 == 0 and v2 == 0:
            continue
        alpha = int(min(150, v1*0.50 + v2*0.38))
        if alpha > 0:
            hp[x, y] = (110, 205, 245, alpha)

final = Image.new('RGBA', (w, h), (0, 0, 0, 0))
final.paste(halo, (0, 0), halo)
final.paste(out, (0, 0), out)

final.convert('RGB').save(DST)
print('saved', DST)
