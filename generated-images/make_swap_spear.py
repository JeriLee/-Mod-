# -*- coding: utf-8 -*-
"""
生成「月淬奔雷矛」的手持(swap)动画资源。

策略：以原版奔雷矛 lunar 皮肤的手持图 atlas(swap 布局)为底，
      用本模组自定义的三尖两刃刀造型覆盖 swap symbol，
      pivot 与底图保持一致（即握持点跟随原版），保证握在手上的位置正确。

输出：
  c:\\ds_mod\\generated-images\\swap_build\\swap_moonforged_spear.scml (+ 图)
  c:\\ds_mod\\3068206095\\anim\\swap_moonforged_spear.zip
"""
import os, shutil, subprocess, zipfile
from PIL import Image, ImageFilter
from collections import deque

SRC = r'c:\ds_mod\generated-images\spear_src_glass_tail.png'      # 已处理好的模型源图（横置，刃朝右）
BASE_SWAP_TEX = r'c:\ds_mod\generated-images\base_swap_lunar.tex'  # 原版 lunar 手持图集（由 texconv 解出）
WORK = r'c:\ds_mod\generated-images\swap_build'
MOD_ANIM = r'c:\ds_mod\3068206095\anim'
BUILD = 'swap_moonforged_spear'      # bank 名 = build 名 = symbol 名（与 OnEquip 的 OverrideSymbol 一致）
SYMBOL = BUILD
ANIM = 'idle'
FOLDER = 'moonforged_spear'
SCML_EXE = r"C:\Program Files (x86)\Steam\steamapps\common\Don't Starve Mod Tools\mod_tools\scml.exe"

# 手持图集里的握持点（相对整张图，归一化）。先置 None，稍后从底图 alpha 重心估算。
PIVOT = None

# ---------------------------------------------------------------- 1. 抠图
def cutout(src):
    im = Image.open(src).convert('RGB')
    w, h = im.size
    px = im.load()

    def is_bg(p):
        r, g, b = p
        mx = max(r, g, b)
        mn = min(r, g, b)
        if (mx - mn) > 20:
            return False
        return 170 <= mx <= 228

    fg = [[not is_bg(px[x, y]) for x in range(w)] for y in range(h)]
    label = [[0] * w for _ in range(h)]
    comps = []
    cur = 0
    for y in range(h):
        for x in range(w):
            if fg[y][x] and label[y][x] == 0:
                cur += 1
                q = deque([(x, y)])
                label[y][x] = cur
                cnt = 0
                minx = maxx = x
                miny = maxy = y
                while q:
                    cx, cy = q.popleft()
                    cnt += 1
                    if cx < minx: minx = cx
                    if cx > maxx: maxx = cx
                    if cy < miny: miny = cy
                    if cy > maxy: maxy = cy
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h and fg[ny][nx] and label[ny][nx] == 0:
                            label[ny][nx] = cur
                            q.append((nx, ny))
                comps.append((cnt, cur, (minx, miny, maxx, maxy)))

    comps.sort(reverse=True)
    total = sum(c[0] for c in comps)
    keep = set(c[1] for c in comps if c[0] >= max(400, total * 0.01))

    minx, miny, maxx, maxy = w, h, -1, -1
    for cnt, cid, bb in comps:
        if cid in keep:
            if bb[0] < minx: minx = bb[0]
            if bb[1] < miny: miny = bb[1]
            if bb[2] > maxx: maxx = bb[2]
            if bb[3] > maxy: maxy = bb[3]

    alpha = Image.new('L', (w, h), 0)
    apx = alpha.load()
    for y in range(miny, maxy + 1):
        row = label[y]
        for x in range(minx, maxx + 1):
            if row[x] in keep:
                apx[x, y] = 255

    rgba = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    rgba.paste(im, (0, 0), alpha)
    return rgba.crop((minx, miny, maxx + 1, maxy + 1))


def to_bright_blue(img, strength=0.72):
    im2 = img.convert('RGBA')
    ww, hh = im2.size
    src = im2.load()
    out = Image.new('RGBA', (ww, hh), (0, 0, 0, 0))
    dst = out.load()
    for y in range(hh):
        for x in range(ww):
            r, g, b, a = src[x, y]
            if a == 0:
                continue
            lum = (r * 299 + g * 587 + b * 114) / 1000.0 / 255.0
            if lum < 0.16:
                dst[x, y] = (r, g, b, a)
                continue
            tr = 48 + (150 - 48) * lum
            tg = 96 + (215 - 96) * lum
            tb = 190 + (255 - 190) * lum
            k = strength * min(1.0, (lum - 0.16) / 0.25)
            dst[x, y] = (int(max(0, min(255, r * (1 - k) + tr * k))),
                         int(max(0, min(255, g * (1 - k) + tg * k))),
                         int(max(0, min(255, b * (1 - k) + tb * k))), a)
    return out


def add_outline(img, width=3):
    ww, hh = img.size
    a = img.split()[3]
    pad = width
    big = Image.new('L', (ww + pad * 2, hh + pad * 2), 0)
    big.paste(a, (pad, pad))
    grown = big
    for _ in range(width):
        grown = grown.filter(ImageFilter.MaxFilter(3))
    grown_c = grown.crop((pad, pad, pad + ww, pad + hh))
    oa = a.load()
    ga = grown_c.load()
    outline_alpha = Image.new('L', (ww, hh), 0)
    outa = outline_alpha.load()
    for y in range(hh):
        for x in range(ww):
            if oa[x, y] < 128 and ga[x, y] >= 128:
                outa[x, y] = 255
    res = Image.new('RGBA', (ww, hh), (0, 0, 0, 0))
    res.paste(Image.new('RGBA', (ww, hh), (0, 0, 0, 255)), (0, 0), outline_alpha)
    res.paste(img, (0, 0), img)
    return res


def content_bbox(img):
    a = img.split()[3].load()
    w, h = img.size
    minx, miny, maxx, maxy = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            if a[x, y] > 20:
                if x < minx: minx = x
                if x > maxx: maxx = x
                if y < miny: miny = y
                if y > maxy: maxy = y
    return (minx, miny, maxx, maxy)


# ---------------------------------------------------------------- 2. 处理武器
body = cutout(SRC)
body = to_bright_blue(body)
print('body crop', body.size)
outlined = add_outline(body, 3)
print('body outlined', outlined.size)

# ---------------------------------------------------------------- 3. 画布 + pivot
# 手持时武器在手上是斜向的，但原版 swap 图集本身就是"武器横置 + 握持点在柄上"，
# 手部骨骼负责旋转。因此这里保持横置即可。
W, H = outlined.size
canvas = Image.new('RGBA', (W + 8, H + 8), (0, 0, 0, 0))
canvas.paste(outlined, (4, 4), outlined)
W, H = canvas.size

bbox = content_bbox(canvas)
print('canvas', (W, H), 'content bbox', bbox)

# 握持点：杆身（去掉枪头那一段）的水平中点在整条武器偏左 62% 的位置，
# 竖向取杆身中心。这样手会握在杆上，枪头自然朝外。
spans = []  # 每列的内容竖直跨度，用于找"最细"的连续区域 = 杆身
a = canvas.split()[3].load()
for x in range(W):
    ys = [y for y in range(H) if a[x, y] > 20]
    spans.append((min(ys), max(ys), len(ys)) if ys else None)

thin = [(i, s) for i, s in enumerate(spans) if s is not None]
# 杆身 = 竖直厚度最小的那批列
thicks = sorted([s[2] for _, s in thin])
min_thick = thicks[max(0, int(len(thicks) * 0.05))]
bar_cols = [(i, s) for i, s in thin if s[2] <= min_thick * 1.6]
bar_cols.sort()
grip_col = bar_cols[int(len(bar_cols) * 0.35)][0]      # 杆身靠左 35% 处（靠近手）
gs = spans[grip_col]
grip_y = (gs[0] + gs[1]) / 2.0

pivot_x = grip_col / float(W)
pivot_y = grip_y / float(H)
print('grip col/px', grip_col, 'grip y', grip_y, 'pivot', round(pivot_x, 6), round(pivot_y, 6))

# ---------------------------------------------------------------- 4. 输出图 + scml
if os.path.exists(WORK):
    shutil.rmtree(WORK)
imgdir = os.path.join(WORK, FOLDER)
os.makedirs(imgdir)
png_name = 'swap_moonforged_spear-0.png'
canvas.save(os.path.join(imgdir, png_name))

PX = '%.6f' % pivot_x
PY = '%.6f' % pivot_y

L = []
L.append('<?xml version="1.0" ?>')
L.append('<spriter_data generator="BrashMonkey Spriter" generator_version="b5" scml_version="1.0">')
L.append('\t<folder id="0" name="%s">' % FOLDER)
L.append('\t\t<file height="%d" id="0" name="%s/%s" pivot_x="%s" pivot_y="%s" width="%d"/>'
         % (H, FOLDER, png_name, PX, PY, W))
L.append('\t</folder>')
L.append('\t<entity id="0" name="%s">' % BUILD)
L.append('\t\t<animation id="0" name="%s" length="100" looping="true">' % ANIM)
L.append('\t\t\t<mainline>')
L.append('\t\t\t\t<key id="0" time="0">')
L.append('\t\t\t\t\t<object_ref abs_a="1" abs_angle="360" abs_pivot_x="%s" abs_pivot_y="%s" abs_scale_x="1" abs_scale_y="1" abs_x="0" abs_y="0" file="0" folder="0" id="0" key="0" name="%s" timeline="0" z_index="0"/>'
         % (PX, PY, SYMBOL))
L.append('\t\t\t\t</key>')
L.append('\t\t\t</mainline>')
L.append('\t\t\t<timeline id="0" name="%s">' % SYMBOL)
L.append('\t\t\t\t<key id="0" time="0" spin="1">')
L.append('\t\t\t\t\t<object abs_a="1" abs_angle="360" abs_pivot_x="%s" abs_pivot_y="%s" abs_scale_x="1" abs_scale_y="1" abs_x="0" abs_y="0" file="0" folder="0" pivot_x="%s" pivot_y="%s" scale_x="1" scale_y="1" x="0" y="0"/>'
         % (PX, PY, PX, PY))
L.append('\t\t\t\t</key>')
L.append('\t\t\t</timeline>')
L.append('\t\t</animation>')
L.append('\t</entity>')
L.append('</spriter_data>')

scml_path = os.path.join(WORK, BUILD + '.scml')
f = open(scml_path, 'w')
f.write('\n'.join(L))
f.close()
print('scml ok', scml_path)

# ---------------------------------------------------------------- 5. 编译
out = os.path.join(WORK, 'out')
if os.path.exists(out):
    shutil.rmtree(out)
subprocess.call([SCML_EXE, scml_path, out])

built = os.path.join(out, 'anim', BUILD + '.zip')
if not os.path.exists(built):
    raise SystemExit('compile failed: ' + built)

target = os.path.join(MOD_ANIM, BUILD + '.zip')
shutil.copy(built, target)
z = zipfile.ZipFile(target)
print('DONE ->', target)
print('entries', z.namelist())
