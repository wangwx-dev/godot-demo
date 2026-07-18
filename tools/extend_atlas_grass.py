# 草地 tile 合成并追加进现有图集（2026-07-18 试玩反馈：地面全泥土太单调）。
# 从图集自身的植被 tile 采样绿色系调色板 → 合成 4 个 32px 草地变体 →
# 追加到 tileset_ground.png 新行 + 登记 manifest（solid=0）。风格与原素材同源。
# 运行：python tools/extend_atlas_grass.py（幂等：已有 grass_a 则跳过）
import json
import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ATLAS = ROOT / "assets" / "sprites" / "environment" / "tileset_ground.png"
MANIFEST = ROOT / "assets" / "sprites" / "environment" / "tileset_ground.json"
TILE = 32
random.seed(20260718)


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8-sig"))
    names = [t["name"] for t in manifest["tiles"]]
    if "grass_a" in names:
        print("[grass] 已存在，跳过")
        return
    atlas = Image.open(ATLAS).convert("RGBA")
    cols = int(manifest["columns"])

    # 调色板手调：素材包全是荒土色（#47352c/#77664e），没有绿色可采——
    # 用贴着现有色系的低饱和橄榄绿，绿得出来又不破坏末世基调
    lo = (0x4A, 0x52, 0x33)
    mid = (0x67, 0x6E, 0x42)
    hi = (0x84, 0x8A, 0x52)
    dry_base = (0x84, 0x78, 0x48)
    dry_hi = (0x9A, 0x8C, 0x58)
    print(f"[grass] 调色板 lo={lo} mid={mid} hi={hi} dry={dry_base}")

    def make_tile(base, dark, light, speckle: float) -> Image.Image:
        img = Image.new("RGBA", (TILE, TILE))
        for y in range(TILE):
            for x in range(TILE):
                r = random.random()
                if r < speckle * 0.5:
                    c = dark
                elif r < speckle:
                    c = light
                else:
                    # 2x2 像素块感：按半格坐标微抖动基色
                    k = 0.94 + 0.06 * (((x // 2) * 7 + (y // 2) * 13) % 3) / 2.0
                    c = (int(base[0] * k), int(base[1] * k), int(base[2] * k))
                img.putpixel((x, y), (*c, 255))
        return img

    variants = [
        ("grass_a", make_tile(mid, lo, hi, 0.10)),
        ("grass_b", make_tile(mid, lo, hi, 0.22)),
        ("grass_dry_a", make_tile(dry_base, lo, dry_hi, 0.12)),
        ("grass_dry_b", make_tile(dry_base, lo, mid, 0.24)),
    ]

    # 追加到图集末行（不改动任何现有 tile 坐标）
    rows = atlas.height // TILE
    used_last_row = sum(1 for t in manifest["tiles"] if t["y"] == rows - 1)
    free_in_last = cols - used_last_row
    need_new_row = len(variants) > free_in_last
    new_atlas = atlas
    if need_new_row:
        new_atlas = Image.new("RGBA", (atlas.width, atlas.height + TILE))
        new_atlas.paste(atlas, (0, 0))
        next_x, next_y = 0, rows
    else:
        next_x, next_y = used_last_row, rows - 1
    for name, img in variants:
        new_atlas.paste(img, (next_x * TILE, next_y * TILE))
        manifest["tiles"].append({"name": name, "x": next_x, "y": next_y, "solid": 0})
        print(f"[grass] {name} -> ({next_x},{next_y})")
        next_x += 1
        if next_x >= cols:
            next_x = 0
            next_y += 1
    new_atlas.save(ATLAS)
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
    print("[grass] 图集与清单已更新")


if __name__ == "__main__":
    main()
