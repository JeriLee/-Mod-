# -*- coding: utf-8 -*-
import os
from PIL import Image, ImageDraw

d = r"c:\ds_mod\generated-images\scmltest\test"
if not os.path.exists(d):
    os.makedirs(d)

im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
dr = ImageDraw.Draw(im)
dr.rectangle([8, 28, 56, 36], fill=(60, 90, 160, 255))
dr.polygon([(56, 24), (64, 32), (56, 40)], fill=(180, 200, 255, 255))
im.save(os.path.join(d, "test-0.png"))
print("ok")
