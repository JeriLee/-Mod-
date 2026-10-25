# -*- coding: utf-8 -*-
"""
为 moonforged_spear 生成地面 idle 动画资源。
流程：PNG 去背景(保留主体连通域) -> 生成多帧 -> 生成 scml -> scml.exe 编译成 zip
"""
import os, sys, math, shutil, subprocess
from PIL import Image
from collections import deque

SRC = r'c:\ds_mod\generated-images\A_single_stylized_polearm_weap_2026-10-25T05-10-43.png'
WORK = r'c:\ds_mod\generated-images\spear_build'
BUILD_NAME = 'moonforged_spear'
SYMBOL = 'moonforged_spear'

# ---------- 1. 去背景（颜色阈值） ----------
im = Image.open(SRC).convert('RGB')
w, h = im.size
px = im.load()

def is_bg(p):
    r, g, b = p
    mx = max(r, g, b)
    mn = min(r, g, b)
    if (mx - mn) > 20:
        return False
    return 150 <= mx <= 205

fg = [[not is_bg(px[x, y]) for x in range(w)] for y in range(h)]

# ---------- 2. 连通域标记，保留最大的若干个 ----------
label = [[0]*w for _ in range(h)]
comps = []   # (size, id, (minx,miny,maxx,maxy))
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
                for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                    nx, ny = cx+dx, cy+dy
                    if 0 <= nx < w and 0 <= ny < h and fg[ny][nx] and label[ny][nx] == 0:
                        label[ny][nx] = cur
                        q.append((nx, ny))
            comps.append((cnt, cur, (minx, miny, maxx, maxy)))

comps.sort(reverse=True)
print('total comps', len(comps), 'top sizes', [c[0] for c in comps[:4]])

# 保留最大的 2 个（主体 + 可能分离的部件），且大小超过阈值
KEEP = set()
total_fg = sum(c[0] for c in comps)
kept = 0
for cnt, cid, _bb in comps:
    if cnt >= max(500, total_fg * 0.01):   # 至少占总前景 1%
        KEEP.add(cid)
        kept += cnt
print('keep comps', len(KEEP), 'pixels', kept, '/', total_fg)

# 计算保留区域 bbox
minx, miny, maxx, maxy = w, h, -1, -1
for cnt, cid, bb in comps:
    if cid in KEEP:
        if bb[0] < minx: minx = bb[0]
        if bb[1] < miny: miny = bb[1]
        if bb[2] > maxx: maxx = bb[2]
        if bb[3] > maxy: maxy = bb[3]
print('content bbox', (minx, miny, maxx, maxy))

# ---------- 3. 生成 alpha ----------
alpha = Image.new('L', (w, h), 0)
apx = alpha.load()
for y in range(miny, maxy+1):
    lab_row = label[y]
    for x in range(minx, maxx+1):
        if lab_row[x] in KEEP:
            apx[x, y] = 255

rgba = Image.new('RGBA', (w, h), (0, 0, 0, 0))
rgba.paste(im, (0, 0), alpha)

crop = rgba.crop((minx, miny, maxx+1, maxy+1))
cw, ch = crop.size
print('cropped', cw, ch)

# ---------- 4. 缩放 ----------
TARGET_LONG = 200
scale = TARGET_LONG / float(max(cw, ch))
nw = max(1, int(round(cw * scale)))
nh = max(1, int(round(ch * scale)))
base_img = crop.resize((nw, nh), Image.ANTIALIAS)
print('resized', nw, nh)

# ---------- 5. 多帧 ----------
if os.path.exists(WORK):
    shutil.rmtree(WORK)
imgdir = os.path.join(WORK, BUILD_NAME)
os.makedirs(imgdir)

NUM_FRAMES = 4
frames = []
for i in range(NUM_FRAMES):
    phase = (2.0 * math.pi * i) / NUM_FRAMES
    dy = int(round(1.5 * math.sin(phase)))
    angle = 1.0 * math.sin(phase)
    canvas = Image.new('RGBA', (nw + 12, nh + 12), (0, 0, 0, 0))
    rot = base_img.rotate(angle, resample=Image.BICUBIC, expand=False)
    canvas.paste(rot, (6, 6 + dy), rot)
    frames.append(canvas)

frame_names = []
for i, fr in enumerate(frames):
    fn = '%s-%d' % (SYMBOL, i)
    fr.save(os.path.join(imgdir, fn + '.png'))
    frame_names.append(fn)

fw, fh = frames[0].size
print('frame size', fw, fh)

# ---------- 6. 生成 scml ----------
pivot_x = 0.5
pivot_y = 0.5
L = []
L.append('<?xml version="1.0" ?>')
L.append('<spriter_data generator="BrashMonkey Spriter" generator_version="b5" scml_version="1.0">')
L.append('\t<folder id="0" name="%s">' % BUILD_NAME)
for i, fn in enumerate(frame_names):
    L.append('\t\t<file height="%d" id="%d" name="%s/%s.png" pivot_x="%s" pivot_y="%s" width="%d"/>'
             % (fh, i, BUILD_NAME, fn, pivot_x, pivot_y, fw))
L.append('\t</folder>')
L.append('\t<entity id="0" name="%s">' % BUILD_NAME)
L.append('\t\t<animation id="0" name="idle" length="%d" looping="true">' % (NUM_FRAMES * 100))
L.append('\t\t\t<mainline>')
for i in range(NUM_FRAMES):
    L.append('\t\t\t\t<key id="%d" time="%d">' % (i, i * 100))
    L.append('\t\t\t\t\t<object_ref abs_a="1" abs_angle="360" abs_pivot_x="%s" abs_pivot_y="%s" abs_scale_x="1" abs_scale_y="1" abs_x="0" abs_y="0" file="%d" folder="0" id="0" key="%d" name="%s" timeline="0" z_index="0"/>'
             % (pivot_x, pivot_y, i, i, SYMBOL))
    L.append('\t\t\t\t</key>')
L.append('\t\t\t</mainline>')
L.append('\t\t\t<timeline id="0" name="%s">' % SYMBOL)
for i in range(NUM_FRAMES):
    L.append('\t\t\t\t<key id="%d" time="%d" spin="1">' % (i, i * 100))
    L.append('\t\t\t\t\t<object abs_a="1" abs_angle="360" abs_pivot_x="%s" abs_pivot_y="%s" abs_scale_x="1" abs_scale_y="1" abs_x="0" abs_y="0" file="%d" folder="0" pivot_x="%s" pivot_y="%s" scale_x="1" scale_y="1" x="0" y="0"/>'
             % (pivot_x, pivot_y, i, pivot_x, pivot_y))
    L.append('\t\t\t\t</key>')
L.append('\t\t\t</timeline>')
L.append('\t\t</animation>')
L.append('\t</entity>')
L.append('</spriter_data>')

scml_path = os.path.join(WORK, BUILD_NAME + '.scml')
f = open(scml_path, 'w')
f.write('\n'.join(L))
f.close()
print('scml ok')
