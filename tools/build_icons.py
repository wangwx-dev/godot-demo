# 像素图标批量生成（2026-07-18 F1）：词缀 x3（16px）+ 球棒武器图标（24px）+ 价值物 x3（16px）。
# 程序化绘制，配色贴项目暗调色板；正式手绘图标可后续原位替换。
# 运行：python tools/build_icons.py → assets/sprites/ui/
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites" / "ui"
OUT.mkdir(parents=True, exist_ok=True)


def canvas(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def save(img, name):
    img.save(OUT / name)
    print("[icons]", name)


# ---- 词缀图标 16x16 ----
# 狂暴：红色爪痕（三道斜杠）
img, d = canvas(16)
for i, x in enumerate((3, 7, 11)):
    d.line([(x, 2), (x - 2, 13)], fill=(210, 50, 40, 255), width=2)
d.line([(2, 3), (13, 6)], fill=(120, 20, 15, 255), width=1)
save(img, "affix_frenzy.png")

# 召唤：紫色召唤环（圆环+三点）
img, d = canvas(16)
d.ellipse([2, 2, 13, 13], outline=(150, 80, 200, 255), width=2)
for x, y in ((7, 1), (2, 11), (12, 11)):
    d.rectangle([x, y, x + 2, y + 2], fill=(200, 140, 240, 255))
save(img, "affix_summon.png")

# 坚韧：灰盾
img, d = canvas(16)
d.polygon([(8, 1), (14, 4), (13, 10), (8, 15), (3, 10), (2, 4)], fill=(130, 135, 145, 255),
          outline=(70, 75, 85, 255))
d.line([(8, 3), (8, 12)], fill=(90, 95, 105, 255), width=1)
save(img, "affix_tough.png")

# ---- 球棒图标 24x24（钉板球棒：斜置棒身+钉子） ----
img, d = canvas(24)
d.line([(4, 20), (17, 7)], fill=(122, 82, 46, 255), width=4)
d.line([(15, 5), (20, 10)], fill=(150, 105, 60, 255), width=6)
for x, y in ((15, 6), (18, 9), (16, 10)):
    d.point((x, y), fill=(200, 200, 205, 255))
d.line([(3, 21), (6, 18)], fill=(80, 55, 30, 255), width=2)
save(img, "icon_bat.png")

# ---- 价值物图标 16x16 ----
# 罐头（白档）：银罐红标
img, d = canvas(16)
d.rectangle([4, 3, 11, 13], fill=(180, 185, 190, 255), outline=(90, 95, 100, 255))
d.rectangle([4, 7, 11, 9], fill=(190, 60, 50, 255))
d.ellipse([4, 1, 11, 4], fill=(210, 214, 218, 255), outline=(110, 115, 120, 255))
save(img, "loot_canned_food.png")

# 药品（蓝档）：白盒蓝十字
img, d = canvas(16)
d.rectangle([2, 4, 13, 13], fill=(235, 235, 230, 255), outline=(130, 130, 125, 255))
d.rectangle([6, 6, 9, 11], fill=(60, 110, 200, 255))
d.rectangle([4, 8, 11, 9], fill=(60, 110, 200, 255))
save(img, "loot_medicine.png")

# 金条（紫档→按经济文档是紫档价值，但图标用金色）
img, d = canvas(16)
d.polygon([(2, 10), (4, 6), (13, 6), (15, 10), (2, 10)], fill=(212, 175, 55, 255),
          outline=(140, 110, 30, 255))
d.rectangle([2, 10, 15, 13], fill=(190, 150, 40, 255), outline=(140, 110, 30, 255))
d.line([(5, 8), (8, 8)], fill=(240, 215, 120, 255), width=1)
save(img, "loot_gold_bar.png")

# ---- 新武器图标 24x24（F2 武器扩容：4 主武器+5 副武器；霰弹枪复用既有
# pickups/icon_shotgun.png，诱饵收音机复用既有 pickups/radio_00.png，两者不重绘） ----

# 自制钉枪：灰色枪管 + 露出的钉子束
img, d = canvas(24)
d.rectangle([2, 11, 16, 15], fill=(90, 92, 96, 255), outline=(50, 52, 56, 255))
d.rectangle([16, 12, 21, 14], fill=(70, 72, 76, 255))
for x in (17, 19, 21):
    d.line([(x, 9), (x, 13)], fill=(200, 190, 150, 255), width=1)
d.rectangle([3, 15, 9, 20], fill=(70, 48, 30, 255))
save(img, "icon_nailgun.png")

# 链锯：橙色机身 + 银色齿刃条
img, d = canvas(24)
d.rectangle([2, 9, 10, 16], fill=(200, 120, 30, 255), outline=(120, 65, 15, 255))
d.rectangle([9, 10, 21, 13], fill=(150, 152, 156, 255), outline=(90, 92, 96, 255))
for x in range(10, 21, 2):
    d.line([(x, 10), (x + 1, 13)], fill=(60, 62, 66, 255), width=1)
d.ellipse([3, 17, 8, 22], fill=(60, 62, 66, 255))
save(img, "icon_chainsaw.png")

# 复合弓：弧形弓身 + 弦 + 搭箭
img, d = canvas(24)
d.arc([3, 1, 19, 22], 250, 470, fill=(110, 75, 40, 255), width=2)
d.line([(6, 3), (6, 20)], fill=(210, 205, 190, 255), width=1)
d.line([(2, 11), (20, 11)], fill=(160, 110, 60, 255), width=1)
d.polygon([(20, 11), (16, 9), (16, 13)], fill=(170, 170, 165, 255))
save(img, "icon_bow.png")

# 土制手雷：军绿椭圆 + 保险栓
img, d = canvas(24)
d.ellipse([5, 8, 18, 21], fill=(80, 95, 55, 255), outline=(45, 55, 30, 255))
for y in (11, 14, 17):
    d.line([(6, y), (17, y)], fill=(45, 55, 30, 255), width=1)
d.rectangle([10, 3, 13, 8], fill=(90, 92, 96, 255), outline=(50, 52, 56, 255))
d.ellipse([14, 2, 20, 8], outline=(140, 30, 25, 255), width=2)
save(img, "icon_grenade.png")

# 捕兽夹：灰色圆环 + 放射齿（呼应场景内 bear_trap.gd 的 _draw 视觉语言）
img, d = canvas(24)
d.ellipse([5, 5, 19, 19], outline=(120, 122, 126, 255), width=2)
for i in range(8):
    import math
    a = math.tau * i / 8
    x0, y0 = 12 + 7 * math.cos(a), 12 + 7 * math.sin(a)
    x1, y1 = 12 + 11 * math.cos(a), 12 + 11 * math.sin(a)
    d.line([(x0, y0), (x1, y1)], fill=(160, 162, 166, 255), width=2)
save(img, "icon_bear_trap.png")

# 闪光弹：橄榄色圆柱罐体 + 顶部白色爆闪星
img, d = canvas(24)
d.rectangle([8, 9, 16, 21], fill=(105, 110, 90, 255), outline=(60, 64, 50, 255))
d.ellipse([8, 7, 16, 11], fill=(120, 125, 105, 255), outline=(60, 64, 50, 255))
for dx, dy in ((0, -6), (5, -3), (-5, -3), (3, -5), (-3, -5)):
    d.line([(12, 6), (12 + dx, 6 + dy)], fill=(250, 245, 200, 255), width=1)
save(img, "icon_flashbang.png")

# 肾上腺素：注射器（针管+活塞+针头）
img, d = canvas(24)
d.rectangle([8, 6, 15, 17], fill=(220, 225, 225, 200), outline=(120, 122, 126, 255))
d.rectangle([9, 12, 14, 17], fill=(200, 50, 55, 220))
d.rectangle([10, 2, 13, 6], fill=(150, 152, 156, 255))
d.line([(11, 17), (11, 22)], fill=(180, 182, 186, 255), width=1)
d.rectangle([6, 6, 17, 8], fill=(150, 152, 156, 255))
save(img, "icon_adrenaline.png")

print("[icons] 完成")
