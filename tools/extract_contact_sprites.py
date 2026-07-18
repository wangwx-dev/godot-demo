# 从素材识别表（contact sheet，6x 放大+网格+标签）反向提取完好车辆 sprite（2026-07-18 F1）。
# 原始素材库未迁移到本机，识别表是仓库内唯一像素来源；6x→除 3 归一回 2x 管线。
# 运行：python tools/extract_contact_sprites.py → assets/sprites/environment/props/vehicle_*.png
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "tools" / "contact_sheets" / "sheet_vehicles.png"
OUT = ROOT / "assets" / "sprites" / "environment" / "props"
COLS = 8
SCALE = 6  # make_contact_sheets.ps1 $scale
PAD = 4

# 完好车辆的 (行, 列, 标签)——按识别表实际排布（行 2 后半 + 行 3 前三格）
TARGETS = [
    (2, 3, "0164"), (2, 4, "0165"), (2, 5, "0166"), (2, 6, "0167"), (2, 7, "0168"),
    (3, 0, "0169"), (3, 1, "0170"), (3, 2, "0171"),
]


def main() -> None:
    sheet = Image.open(SHEET).convert("RGBA")
    cell_w = sheet.width // COLS
    rows = 4
    cell_h = sheet.height // rows
    sprite_w = cell_w - 2 * PAD
    sprite_h = None  # 高度里含 label 区，取到 label 前：cellH = maxH*6 + labelH + 8
    # labelH 反推：假设 maxH*6 = cellH - labelH - 8，label 区约 18px（字体 9pt）
    label_h = 18
    sprite_h = cell_h - label_h - 2 * PAD

    for row, col, label in TARGETS:
        x0 = col * cell_w + PAD
        y0 = row * cell_h + PAD
        region = sheet.crop((x0, y0, x0 + sprite_w, y0 + sprite_h))
        bg = region.getpixel((1, 1))
        px = region.load()
        for y in range(region.height):
            for x in range(region.width):
                p = px[x, y]
                if abs(p[0] - bg[0]) <= 6 and abs(p[1] - bg[1]) <= 6 and abs(p[2] - bg[2]) <= 6:
                    px[x, y] = (0, 0, 0, 0)
        bbox = region.getbbox()
        if bbox is None:
            print("[extract] 空:", label)
            continue
        region = region.crop(bbox)
        # 6x → 2x（除 3），对齐现有 props 管线
        small = region.resize((max(region.width // 3, 1), max(region.height // 3, 1)), Image.NEAREST)
        out = OUT / f"vehicle_{label}.png"
        small.save(out)
        print(f"[extract] {out.name}  {small.size}")


if __name__ == "__main__":
    main()
