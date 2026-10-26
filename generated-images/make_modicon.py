# -*- coding: utf-8 -*-
"""
把 preview.jpg（女武神举奔雷矛的封面图）做成 DST 模组图标：
  1. 缩放到 256x256，输出 modicon.png
  2. 调 Klei Mod Tools 的 image_build.py 把 PNG 转成 modicon.tex
  3. 生成 modicon.xml（atlas 定义）

DST 要求：modicon 必须是正方形，建议 256x256（workshop 页面与模组列表都会用它）。
"""
import os
import shutil
import subprocess

from PIL import Image

MOD = r'c:\ds_mod\3068206095'
SRC = os.path.join(MOD, 'preview.jpg')
ICON_PNG = os.path.join(MOD, 'modicon.png')
SIZE = 256

TOOLS = r"C:\Program Files (x86)\Steam\steamapps\common\Don't Starve Mod Tools\mod_tools"

# ---------- 1) 缩放为 256x256 ----------
im = Image.open(SRC).convert('RGB')
w, h = im.size
side = min(w, h)
# 居中裁成正方形（源图本身就是 1:1，此步是保险）
left = (w - side) // 2
top = (h - side) // 2
sq = im.crop((left, top, left + side, top + side))
sq = sq.resize((SIZE, SIZE), Image.LANCZOS)
sq.save(ICON_PNG)
print('png saved ->', ICON_PNG)

# ---------- 2) PNG -> TEX ----------
env = dict(os.environ)
env['PYTHONPATH'] = os.path.join(TOOLS, 'buildtools', 'windows')
rc = subprocess.call(
    [os.path.join(TOOLS, 'buildtools', 'windows', 'Python27', 'python.exe'),
     os.path.join(TOOLS, 'compiler_scripts', 'image_build.py'),
     '--force', ICON_PNG],
    env=env, cwd=TOOLS)
print('image_build rc =', rc)
if rc != 0:
    raise SystemExit('image_build failed')

# image_build 会在 PNG 同目录生成同名 .tex
tex = os.path.join(MOD, 'modicon.tex')
if not os.path.exists(tex):
    raise SystemExit('modicon.tex not generated')
print('tex ok ->', tex, os.path.getsize(tex), 'bytes')

# ---------- 3) 生成 modicon.xml ----------
xml = os.path.join(MOD, 'modicon.xml')
with open(xml, 'w') as f:
    f.write('<Atlas>\n'
            '\t<Texture filename="modicon.tex"/>\n'
            '\t<Elements>\n'
            '\t\t<Element name="modicon.tex" width="%d" height="%d" u1="0" u2="1" v1="0" v2="1"/>\n'
            '\t</Elements>\n'
            '</Atlas>\n' % (SIZE, SIZE))
print('xml ok ->', xml)
print('DONE')
