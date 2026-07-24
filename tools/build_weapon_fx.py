# 武器特效重绘（2026-07-24 美术翻修）：替换发粉发白的占位弹道/枪口焰/火花/挥砍。
# 程序化像素绘制，暖色（橙黄）系，读起来像"火药武器"。→ assets/sprites/weapons/
import math, os
from PIL import Image, ImageDraw

OUT = r"D:\personal\godot-demo\assets\sprites\weapons"


def cv(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def save(img, name):
    img.save(os.path.join(OUT, name))
    print("[weapon-fx]", name, img.size)


# ---- 子弹拖尾（朝右，飞行时 rotation 对齐方向）：亮橙弹芯 + 渐淡拖尾 ----
# 两帧交替做微闪
for f, core in enumerate([(255, 230, 120), (255, 200, 70)]):
    img, d = cv(24, 8)
    # 拖尾（左淡右浓）
    for x in range(24):
        a = int(180 * (x / 23.0) ** 2)
        d.line([(x, 4), (x, 4)], fill=(255, 150, 40, a))
    # 弹芯亮点
    d.ellipse([17, 2, 23, 6], fill=core + (255,))
    d.ellipse([18, 3, 22, 5], fill=(255, 255, 220, 255))
    save(img, f"bullet_tracer_{f:02d}.png")

# 钉枪/弓用细一点的钢青色弹（区分手枪橙）
for f in range(2):
    img, d = cv(24, 6)
    for x in range(24):
        a = int(160 * (x / 23.0) ** 2)
        d.line([(x, 3), (x, 3)], fill=(150, 200, 220, a))
    d.ellipse([18, 1, 23, 5], fill=(210, 240, 255, 255))
    save(img, f"bullet_tracer_1{f}.png".replace("1", "0", 0))
# 上面命名保持 bullet_tracer_01 兼容旧引用（钉枪/弓用）
img, d = cv(24, 6)
for x in range(24):
    a = int(160 * (x / 23.0) ** 2)
    d.line([(x, 3), (x, 3)], fill=(150, 200, 220, a))
d.ellipse([18, 1, 23, 5], fill=(210, 240, 255, 255))
save(img, "bullet_tracer_01.png")

# ---- 枪口焰（单图，出膛方向 rotation）：黄白星芒 ----
img, d = cv(28, 20)
cx, cy = 6, 10
for ang, ln in [(0, 20), (-18, 12), (18, 12), (-32, 7), (32, 7)]:
    r = math.radians(ang)
    x2 = cx + math.cos(r) * ln
    y2 = cy + math.sin(r) * ln
    d.line([(cx, cy), (x2, y2)], fill=(255, 210, 90, 230), width=3)
d.ellipse([cx-5, cy-5, cx+5, cy+5], fill=(255, 240, 160, 255))
d.ellipse([cx-3, cy-3, cx+3, cy+3], fill=(255, 255, 235, 255))
save(img, "muzzle_flash.png")

# ---- 命中火花 2 帧：橙色迸溅 ----
for f in range(2):
    img, d = cv(20, 20)
    cx = cy = 10
    n = 6
    for i in range(n):
        a = math.tau * i / n + f * 0.5
        ln = 8 if f == 0 else 5
        x2 = cx + math.cos(a) * ln
        y2 = cy + math.sin(a) * ln
        d.line([(cx, cy), (x2, y2)], fill=(255, 170, 60, 220), width=2)
    d.ellipse([cx-3, cy-3, cx+3, cy+3], fill=(255, 230, 150, 255))
    save(img, f"bullet_spark_{f:02d}.png")

# ---- 挥砍拖影 4 帧（弧形白刃，替换几乎透明的旧 slash）----
for f in range(4):
    img, d = cv(48, 48)
    cx, cy = 8, 24
    alpha = int(230 * (1 - f / 4.0))
    r0, r1 = 34, 40
    start = -50 + f * 8
    end = 50 + f * 8
    pts_out = []
    pts_in = []
    for a in range(int(start), int(end)+1, 6):
        rad = math.radians(a)
        pts_out.append((cx + math.cos(rad) * r1, cy + math.sin(rad) * r1))
        pts_in.append((cx + math.cos(rad) * r0, cy + math.sin(rad) * r0))
    poly = pts_out + pts_in[::-1]
    if len(poly) >= 3:
        d.polygon(poly, fill=(255, 255, 235, alpha))
    save(img, f"slash_{f:02d}.png")

print("[weapon-fx] 完成")
