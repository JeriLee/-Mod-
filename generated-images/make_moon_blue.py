# -*- coding: utf-8 -*-
"""
把武器上的两个月亮改成蓝色发光，输出新贴图。
  - 枪尾月亮环：x 95~290, y 490~592
  - 枪头后月牙：x 925~1090, y 485~615
"""
import math
from PIL import Image, ImageFilter

SRC = r'c:\ds_mod\generated-images\A_single_stylized_polearm_weap_2026-10-25T05-15-43.png'
DST = r'c:\ds_mod\generated-images\A_single_stylized_polearm_weap_2026-10-25T05-15-43_moonblue.png'

im = Image.open(SRC).convert('RGBA')
w, h = im.size
px = im.load()

def is_bg(p):
    r, g, b = p[:3]
    mx = max(r, g, b); mn = min(r, g, b)
    return (mx - mn) <= 20 and 170 <= mx <= 228

# ---------- 区域定义 ----------
MOONS = [
    # (名称, cx, cy, rx, ry)  —— 椭圆区域
    ('tail', 192, 541, 100, 52),
    ('head', 1005, 550, 88, 68),
]

# ---------- 1) 把月亮区域的金属/浅色染成蓝色发光 ----------
out = im.copy()
op = out.load()

for (name, cx, cy, rx, ry) in MOONS:
    for y in range(max(0, cy - ry), min(h, cy + ry + 1)):
        for x in range(max(0, cx - rx), min(w, cx + rx + 1)):
            # 椭圆内判断
            dx = (x - cx) / float(rx)
            dy = (y - cy) / float(ry)
            if dx*dx + dy*dy > 1.0:
                continue
            r, g, b, a = op[x, y]
            if a == 0 or is_bg((r, g, b)):
                continue
            lum = (r*299 + g*587 + b*114) / 1000.0
            # 保留很暗的描边
            if lum < 55:
                continue
            t = max(0.0, min(1.0, (lum - 55.0) / 150.0))
            # 目标蓝色：暗部 (30,80,170) -> 亮部 (170,225,255)
            tr = 30 + (170 - 30) * t
            tg = 80 + (225 - 80) * t
            tb = 170 + (255 - 170) * t
            k = 0.82
            op[x, y] = (
                int(max(0, min(255, r*(1-k) + tr*k))),
                int(max(0, min(255, g*(1-k) + tg*k))),
                int(max(0, min(255, b*(1-k) + tb*k))),
                a,
            )

# ---------- 2) 给月亮加蓝色外发光（光晕） ----------
# 从月亮区域的亮部生成 alpha 掩码
glow_mask = Image.new('L', (w, h), 0)
gm = glow_mask.load()
for (name, cx, cy, rx, ry) in MOONS:
    for y in range(max(0, cy - ry), min(h, cy + ry + 1)):
        for x in range(max(0, cx - rx), min(w, cx + rx + 1)):
            dx = (x - cx) / float(rx)
            dy = (y - cy) / float(ry)
            if dx*dx + dy*dy > 1.0:
                continue
            r, g, b, a = op[x, y]
            if a == 0 or is_bg((r, g, b)):
                continue
            lum = (r*299 + g*587 + b*114) / 1000.0
            if lum > 90:
                # 越亮发光越强
                gm[x, y] = int(min(255, (lum - 90) * 2.2))

# 模糊成光晕
halo = glow_mask.filter(ImageFilter.GaussianBlur(7))
halo_wide = glow_mask.filter(ImageFilter.GaussianBlur(16))

halo_layer = Image.new('RGBA', (w, h), (0, 0, 0, 0))
hd = halo_layer.load()
hw_ = halo_wide.load()
hp = halo.load()
for y in range(h):
    for x in range(w):
        v = hp[x, y]
        vw = hw_[x, y]
        if v == 0 and vw == 0:
            continue
        # 光晕颜色：亮蓝
        alpha = int(min(140, v * 0.45 + vw * 0.35))
        if alpha > 0:
            hd[x, y] = (90, 180, 255, alpha)

# 光晕在下，武器在上
final = Image.new('RGBA', (w, h), (0, 0, 0, 0))
final.paste(halo_layer, (0, 0), halo_layer)
final.paste(out, (0, 0), out)

final.convert('RGB').save(DST)
print('saved', DST)
