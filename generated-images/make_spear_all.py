# -*- coding: utf-8 -*-
"""
「月淬奔雷矛」全套资源生成（统一使用宽版造型源图）。

源图：A_single_stylized_polearm_weap_2026-10-25T05-15-43.png（宽版三尖两刃刀）

产出：
  1) 物品栏图标  images/inventoryimages/moonforged_spear.png/.tex/.xml
  2) 地面 idle   anim/moonforged_spear.zip（斜插 + 描边 + 枪尖擦除 + 草地效果）
  3) 手持 swap   anim/swap_moonforged_spear.zip（由 make_swap_final.py 生成）

注意：scml.exe 生成的 build.bin 中 **symbol 名 = scml 的 folder 名**。
"""
import os, math, shutil, subprocess, zipfile, re
from collections import deque
from PIL import Image, ImageDraw, ImageFilter

SRC = r'c:\ds_mod\generated-images\A_single_stylized_polearm_weap_2026-10-25T05-15-43.png'
WORK = r'c:\ds_mod\generated-images\spear_build'
MOD = r'c:\ds_mod\3068206095'
BUILD_NAME = 'moonforged_spear'
SYMBOL = 'moonforged_spear'
SCML_EXE = r"C:\Program Files (x86)\Steam\steamapps\common\Don't Starve Mod Tools\mod_tools\scml.exe"
TOOLS = r"C:\Program Files (x86)\Steam\steamapps\common\Don't Starve Mod Tools\mod_tools"


# ============================================================ 抠图
def cutout(src, lo=190, hi=235):
    im = Image.open(src).convert('RGB')
    w, h = im.size
    px = im.load()

    def is_bg(p):
        r, g, b = p
        mx = max(r, g, b)
        mn = min(r, g, b)
        if (mx - mn) > 18:
            return False
        return lo <= mx <= hi

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


# ============================================================ 调色 / 描边
def to_bright_blue(img, strength=0.72):
    """把偏青灰的武器调成亮蓝色，保留明暗层次；黑描边/深阴影保持暗色"""
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
            nr = r * (1 - k) + tr * k
            ng = g * (1 - k) + tg * k
            nb = b * (1 - k) + tb * k
            dst[x, y] = (int(max(0, min(255, nr))), int(max(0, min(255, ng))),
                         int(max(0, min(255, nb))), a)
    return out


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


# ============================================================ 主流程
crop = cutout(SRC)
print('crop', crop.size)

# ---------------------------------------------- 1) 物品栏图标
# 图标用横版原图，长边占 128 画布的 84%（宽版武器长宽比大，需要更满）
icon = to_bright_blue(crop)
icw, ich = icon.size
target_long = int(round(128 * 0.84))
sc = target_long / float(max(icw, ich))
ns_w = max(1, int(round(icw * sc)))
ns_h = max(1, int(round(ich * sc)))
resized = icon.resize((ns_w, ns_h), Image.ANTIALIAS)
final = Image.new('RGBA', (128, 128), (0, 0, 0, 0))
final.paste(resized, ((128 - ns_w) // 2, (128 - ns_h) // 2), resized)

IMG_DIR = os.path.join(MOD, 'images', 'inventoryimages')
if not os.path.exists(IMG_DIR):
    os.makedirs(IMG_DIR)
icon_png = os.path.join(IMG_DIR, 'moonforged_spear.png')
final.save(icon_png)
print('icon saved ->', icon_png, 'size', (ns_w, ns_h))

# PNG -> TEX + XML（调用 Klei 的 image_build.py）
env = dict(os.environ)
env['PYTHONPATH'] = os.path.join(TOOLS, 'buildtools', 'windows')
rc = subprocess.call(
    [os.path.join(TOOLS, 'buildtools', 'windows', 'Python27', 'python.exe'),
     os.path.join(TOOLS, 'compiler_scripts', 'image_build.py'),
     '--force', icon_png],
    env=env, cwd=TOOLS)
print('image_build rc =', rc)

# ---------------------------------------------- 2) 地面 idle 动画
# 原图刃朝右，顺时针旋转 90 度 -> 刃朝下、杆朝上
crop_rot = crop.rotate(-90, expand=True)
cw, ch = crop_rot.size
print('rotated crop', cw, ch)

TARGET_LONG = 320
sc2 = TARGET_LONG / float(max(cw, ch))
nw = max(1, int(round(cw * sc2)))
nh = max(1, int(round(ch * sc2)))
base = crop_rot.resize((nw, nh), Image.ANTIALIAS)
base = to_bright_blue(base)
print('ground base', nw, nh)

OUTLINE_W = 3
base = add_outline(base, OUTLINE_W)
nw, nh = base.size
print('ground outlined', nw, nh)

# ---- 倾斜 15 度斜插（先倾斜，再按倾斜后的底边做入土效果）
TILT = 15.0
rot_all = base.rotate(-TILT, resample=Image.BICUBIC, expand=True)
ang = math.radians(-TILT)
tip_before = (nw / 2.0, float(nh))
cxp = nw / 2.0
cyp = nh / 2.0
rw, rh = rot_all.size
dx0 = tip_before[0] - cxp
dy0 = tip_before[1] - cyp
nx_tip = rw / 2.0 + (dx0 * math.cos(ang) - dy0 * math.sin(ang))
ny_tip = rh / 2.0 + (dx0 * math.sin(ang) + dy0 * math.cos(ang))

# ---- 整体上移：直接抬高 pivot_y
# pivot_y 是归一化坐标（0=画布顶，1=画布底），表示"武器上哪个点对齐到实体原点"。
# pivot_y 指向越靠下的位置，武器在游戏里就被顶得越高。
# 上移量 = 武器高度的 LIFT_RATIO 倍 => pivot_y 直接加 LIFT_RATIO（允许 > 1）。
# 高度方向：负值=向上，正值=向下（单位：武器高度）
LIFT_RATIO = 1.10
# 微调（单位：武器自身尺寸的比例）
# 方向规律：pivot_x 越大越靠左；pivot_y 越大越靠下
OFFSET_DOWN = 0.30   # 0.20 + 0.10（向下 10%）
OFFSET_RIGHT = -0.40  # -0.20 - 0.20（向右 20%）

pivot_x = nx_tip / float(rw) + OFFSET_RIGHT
pivot_y = ny_tip / float(rh) - LIFT_RATIO + OFFSET_DOWN
print('pivot raw=(%.4f, %.4f)  lift=%.2f  down=%.2f  right=%.2f  => (%.4f, %.4f)'
      % (nx_tip / float(rw), ny_tip / float(rh), LIFT_RATIO,
         OFFSET_DOWN, OFFSET_RIGHT, pivot_x, pivot_y))

nw, nh = rw, rh

# ---- 倾斜后：找出最底部内容所在行，作为地面线
ra = rot_all.split()[3].load()
last_y = -1
for y in range(nh - 1, -1, -1):
    for x in range(nw):
        if ra[x, y] > 20:
            last_y = y
            break
    if last_y >= 0:
        break

# 地面线处内容水平范围的中心
tip_cx = nw // 2
if last_y >= 0:
    xs = [x for x in range(nw) if ra[x, last_y] > 20]
    if xs:
        tip_cx = (min(xs) + max(xs)) // 2
print('after tilt: ground line y=%d cx=%d of %dx%d' % (last_y, tip_cx, nw, nh))

# ---- 擦掉枪尖入土的那一小段（只擦尖端附近，保留两侧刃）
TIP_ERASE = 14
r1, g1, b1, a1 = rot_all.split()
a1p = a1.load()
for i in range(TIP_ERASE):
    y = last_y - i
    if y < 0:
        break
    frac = float(i) / float(max(1, TIP_ERASE))
    # 越靠上擦得越窄，形成自然的尖锥入土
    half_w = int(round(4 + 12 * frac))
    for x in range(max(0, tip_cx - half_w), min(nw, tip_cx + half_w + 1)):
        a1p[x, y] = 0
rot_all = Image.merge('RGBA', (r1, g1, b1, a1))

# ---- 草地黑线（画在擦除处，向上发散，模拟草丛遮住枪尖）
GRASS_SCALE = 1.25   # 草丛整体放大倍数

grass = Image.new('RGBA', (nw, nh), (0, 0, 0, 0))
gd = ImageDraw.Draw(grass)
gy = last_y - TIP_ERASE // 2
gcx = tip_cx

# 先铺地面阴影（会被草叶压住，形成"从草里长出来"的层次）
sw = int(round(16 * GRASS_SCALE))
gd.ellipse([gcx - sw, gy - 2, gcx + sw, gy + int(round(7 * GRASS_SCALE))],
           fill=(26, 24, 20, 175))

# 再画草叶：从枪尖两侧向外长，避免被枪尖本体挡住
# dx_root=根部相对枪尖的水平偏移, dx_top=叶尖偏移, dy_top=叶尖高度（负=向上）
line_specs = [
    (-11, -20, -21, 3),
    (-6, -13, -26, 3),
    (5, 12, -26, 3),
    (10, 19, -21, 3),
    (-14, -24, -14, 3),
    (13, 24, -14, 3),
]
for (dx_root, dx_top, dy_top, width) in line_specs:
    x1 = int(round(gcx + dx_root * GRASS_SCALE))
    y1 = gy + 3
    x2 = int(round(gcx + dx_top * GRASS_SCALE))
    y2 = int(round(gy + dy_top * GRASS_SCALE))
    gd.line([(x1, y1), (x2, y2)], fill=(18, 16, 14, 240), width=width)

grass = grass.filter(ImageFilter.GaussianBlur(1.2))
rot_all = rot_all.convert('RGBA')
rot_all.paste(grass, (0, 0), grass)
if os.path.exists(WORK):
    shutil.rmtree(WORK)
imgdir = os.path.join(WORK, BUILD_NAME)
os.makedirs(imgdir)

NUM_FRAMES = 4
frames = []
for i in range(NUM_FRAMES):
    phase = (2.0 * math.pi * i) / NUM_FRAMES
    dx = int(round(1.2 * math.sin(phase)))
    dy = int(round(1.0 * math.sin(phase)))
    cv = Image.new('RGBA', (nw + 16, nh + 16), (0, 0, 0, 0))
    cv.paste(rot_all, (8 + dx, 8 + dy), rot_all)
    frames.append(cv)

frame_names = []
for i, fr in enumerate(frames):
    fn = '%s-%d' % (SYMBOL, i)
    fr.save(os.path.join(imgdir, fn + '.png'))
    frame_names.append(fn)

fw, fh = frames[0].size
print('frame', fw, fh)

PX = '%.6f' % pivot_x
PY = '%.6f' % pivot_y

L = []
L.append('<?xml version="1.0" ?>')
L.append('<spriter_data generator="BrashMonkey Spriter" generator_version="b5" scml_version="1.0">')
L.append('\t<folder id="0" name="%s">' % BUILD_NAME)
for i, fn in enumerate(frame_names):
    L.append('\t\t<file height="%d" id="%d" name="%s/%s.png" pivot_x="%s" pivot_y="%s" width="%d"/>'
             % (fh, i, BUILD_NAME, fn, PX, PY, fw))
L.append('\t</folder>')
L.append('\t<entity id="0" name="%s">' % BUILD_NAME)
L.append('\t\t<animation id="0" name="idle" length="%d" looping="true">' % (NUM_FRAMES * 100))
L.append('\t\t\t<mainline>')
for i in range(NUM_FRAMES):
    L.append('\t\t\t\t<key id="%d" time="%d">' % (i, i * 100))
    L.append('\t\t\t\t\t<object_ref abs_a="1" abs_angle="360" abs_pivot_x="%s" abs_pivot_y="%s" abs_scale_x="1" abs_scale_y="1" abs_x="0" abs_y="0" file="%d" folder="0" id="0" key="%d" name="%s" timeline="0" z_index="0"/>'
             % (PX, PY, i, i, SYMBOL))
    L.append('\t\t\t\t</key>')
L.append('\t\t\t</mainline>')
L.append('\t\t\t<timeline id="0" name="%s">' % SYMBOL)
for i in range(NUM_FRAMES):
    L.append('\t\t\t\t<key id="%d" time="%d" spin="1">' % (i, i * 100))
    L.append('\t\t\t\t\t<object abs_a="1" abs_angle="360" abs_pivot_x="%s" abs_pivot_y="%s" abs_scale_x="1" abs_scale_y="1" abs_x="0" abs_y="0" file="%d" folder="0" pivot_x="%s" pivot_y="%s" scale_x="1" scale_y="1" x="0" y="0"/>'
             % (PX, PY, i, PX, PY))
    L.append('\t\t\t\t</key>')
L.append('\t\t\t</timeline>')
L.append('\t\t</animation>')
L.append('\t</entity>')
L.append('</spriter_data>')

scml = os.path.join(WORK, BUILD_NAME + '.scml')
f = open(scml, 'w')
f.write('\n'.join(L))
f.close()

outdir = os.path.join(WORK, 'out')
if os.path.exists(outdir):
    shutil.rmtree(outdir)
subprocess.call([SCML_EXE, scml, outdir])

built = os.path.join(outdir, 'anim', BUILD_NAME + '.zip')
if not os.path.exists(built):
    raise SystemExit('ground compile failed')

strs = re.findall(r'[ -~]{4,}', zipfile.ZipFile(built).read('build.bin'))
print('ground build.bin strings:', strs[:6])

target = os.path.join(MOD, 'anim', BUILD_NAME + '.zip')
shutil.copy(built, target)
print('DONE ground ->', target, os.path.getsize(target))
