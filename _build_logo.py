import os
from PIL import Image, ImageEnhance, ImageFilter

SRC = (r"C:\Users\Administrator\AppData\Local\CodeBuddyExtension\Data"
       r"\3401ada5-a0d3-49c0-8a5e-a68ee9efd2bc\CodeBuddyIDE"
       r"\3401ada5-a0d3-49c0-8a5e-a68ee9efd2bc\history"
       r"\821a6b3a8bf3d59f3b4f8b64b80fe5b4"
       r"\047a55d39fd74e1889ffadeaba9d4796\assets\preview.88c0bb7e24.jpg")
OUT = r"c:\ds_mod\MiniMap"

im = Image.open(SRC).convert("RGB")
w, h = im.size
px = im.load()

# 1) 用亮度找出主体（机器比背景亮很多），背景是暗橄榄色
THR = 128
min_x, min_y, max_x, max_y = w, h, -1, -1
for y in range(h):
    for x in range(w):
        r, g, b = px[x, y]
        if 0.299 * r + 0.587 * g + 0.114 * b > THR:
            if x < min_x:
                min_x = x
            if x > max_x:
                max_x = x
            if y < min_y:
                min_y = y
            if y > max_y:
                max_y = y
print("subject bbox:", min_x, min_y, max_x, max_y)

# 2) 外扩 18%，再补成正方形
cw, ch = max_x - min_x, max_y - min_y
pad = int(max(cw, ch) * 0.12)
min_x, max_x = min_x - pad, max_x + pad
min_y, max_y = min_y - pad, max_y + pad

side = max(max_x - min_x, max_y - min_y)
cx, cy = (min_x + max_x) // 2, (min_y + max_y) // 2
left, top = cx - side // 2, cy - side // 2

# 越界部分用边缘颜色填（取背景一角）
bg = im.getpixel((3, 3))
canvas = Image.new("RGB", (side, side), bg)
canvas.paste(im.crop((max(left, 0), max(top, 0),
                      min(left + side, w), min(top + side, h))),
             (max(0, -left), max(0, -top)))

# 3) 放大、提亮、锐化
SIZE = 256
logo = canvas.resize((SIZE * 3, SIZE * 3), Image.LANCZOS)
logo = ImageEnhance.Brightness(logo).enhance(1.18)
logo = ImageEnhance.Contrast(logo).enhance(1.18)
logo = ImageEnhance.Color(logo).enhance(1.15)
logo = logo.filter(ImageFilter.UnsharpMask(radius=3, percent=110, threshold=2))
logo = logo.resize((SIZE, SIZE), Image.LANCZOS)

# 4) 四周轻微压暗，图标缩到 70px 时主体更跳
mask = Image.new("L", (SIZE, SIZE), 0)
d = ImageDraw_draw = None
from PIL import ImageDraw
draw = ImageDraw.Draw(mask)
draw.ellipse((-SIZE * 0.25, -SIZE * 0.25, SIZE * 1.25, SIZE * 1.25), fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(SIZE * 0.18))
dark = ImageEnhance.Brightness(logo).enhance(0.55)
logo = Image.composite(logo, dark, mask)

png = os.path.join(OUT, "modicon.png")
logo.save(png)
print("saved:", png, logo.size)
