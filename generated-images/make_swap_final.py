# -*- coding: utf-8 -*-
"""
生成「月淬奔雷矛」手持(swap)资源。

源图：A_single_stylized_polearm_weap_2026-10-25T05-15-43.png（宽版三尖两刃刀）

关键点（此前踩过的坑）：
  scml.exe 生成的 build.bin 里，**symbol 名 = scml 的 folder 名**，
  而不是 entity 名 / timeline 名。所以必须把 folder 名设为
  "swap_moonforged_spear"，OverrideSymbol 才能生效。
"""
import os, shutil, subprocess, zipfile, re
from collections import deque
from PIL import Image, ImageFilter

SRC = r'c:\ds_mod\generated-images\A_single_stylized_polearm_weap_2026-10-25T05-15-43.png'
WORK = r'c:\ds_mod\generated-images\swap_final'
MOD = r'c:\ds_mod\3068206095'
BUILD = 'swap_moonforged_spear'
SYMBOL = BUILD
FOLDER = BUILD          # 必须等于 SYMBOL，scml.exe 用 folder 名作为 symbol 名
ANIM = 'idle'
SCML_EXE = r"C:\Program Files (x86)\Steam\steamapps\common\Don't Starve Mod Tools\mod_tools\scml.exe"

TARGET_LEN = 300        # 手持武器长边像素
GRIP_RATIO = 0.335      # 握持点在武器全长的位置（0=枪尾, 1=枪尖）
OUTLINE_W = 2           # 黑色描边宽度


# ---------------------------------------------------------------- 1. 去背景
def cutout(src):
    im = Image.open(src).convert('RGB')
    w, h = im.size
    px = im.load()

    def is_bg(p):
        r, g, b = p
        mx = max(r, g, b)
        mn = min(r, g, b)
        if (mx - mn) > 18:
            return False
        return 190 <= mx <= 235

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
    # 保留占前景 1% 以上的部件（水印等小碎块会被过滤）
    keep = set(c[1] for c in comps if c[0] >= max(400, total * 0.01))
    print('comps %d, keep %d' % (len(comps), len(keep)))

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


# ---------------------------------------------------------------- 2. 描边
def add_outline(img, width):
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


# ---------------------------------------------------------------- 3. 主流程
weapon = cutout(SRC)
print('weapon crop', weapon.size)

cw, ch = weapon.size
sc = TARGET_LEN / float(cw)
nw = max(4, int(round(cw * sc)))
nh = max(4, int(round(ch * sc)))
resized = weapon.resize((nw, nh), Image.ANTIALIAS)
resized = add_outline(resized, OUTLINE_W)
nw, nh = resized.size
print('resized+outline', nw, nh)

# 画布四周留白
PAD = 4
FW, FH = nw + PAD * 2, nh + PAD * 2
frame = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
frame.paste(resized, (PAD, PAD), resized)

# pivot：scml 的 pivot_x/y 是归一化坐标，(0,0)=左上，(0.5,0.5)=中心
piv_x = (PAD + nw * GRIP_RATIO) / float(FW)
piv_y = (PAD + nh * 0.5) / float(FH)
print('frame', (FW, FH), 'pivot', round(piv_x, 6), round(piv_y, 6))

# ---------------------------------------------------------------- 4. 输出 scml
if os.path.exists(WORK):
    shutil.rmtree(WORK)
imgdir = os.path.join(WORK, FOLDER)
os.makedirs(imgdir)
png_name = BUILD + '-0.png'
frame.save(os.path.join(imgdir, png_name))

PX = '%.6f' % piv_x
PY = '%.6f' % piv_y

L = []
L.append('<?xml version="1.0" ?>')
L.append('<spriter_data generator="BrashMonkey Spriter" generator_version="b5" scml_version="1.0">')
L.append('\t<folder id="0" name="%s">' % FOLDER)
L.append('\t\t<file height="%d" id="0" name="%s/%s" pivot_x="%s" pivot_y="%s" width="%d"/>'
         % (FH, FOLDER, png_name, PX, PY, FW))
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

scml = os.path.join(WORK, BUILD + '.scml')
f = open(scml, 'w')
f.write('\n'.join(L))
f.close()

# ---------------------------------------------------------------- 5. 编译
outdir = os.path.join(WORK, 'out')
if os.path.exists(outdir):
    shutil.rmtree(outdir)
subprocess.call([SCML_EXE, scml, outdir])

built = os.path.join(outdir, 'anim', BUILD + '.zip')
if not os.path.exists(built):
    raise SystemExit('compile failed')

z = zipfile.ZipFile(built)
strs = re.findall(r'[ -~]{4,}', z.read('build.bin'))
print('build.bin strings:', strs[:8])

target = os.path.join(MOD, 'anim', BUILD + '.zip')
shutil.copy(built, target)
print('DONE ->', target, os.path.getsize(target))
