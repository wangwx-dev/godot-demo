# 地面过渡/混合 tile 生成（2026-07-24 地图美术翻修）：
# 图集原只有 grass/dirt 两极基础 tile，直接相邻=硬边界棋盘感。
# 本脚本读现有 grass_a/dirt_a 真实像素，合成：
#   - 中间过渡地表 grass_worn（草到土的中间色，草稀土显）
#   - 4 方向边缘过渡 grass_edge_{n,e,s,w}（一半草一半土，噪声 dither 边界，用于草地块边缘）
#   - 4 内角/外角可后续补；MVP 先做 4 直边 + 1 中间态，够消棋盘
# 追加进 tileset_ground.png / .json（幂等：已有则跳过）。
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ATLAS = ROOT / "assets" / "sprites" / "environment" / "tileset_ground.png"
MANIFEST = ROOT / "assets" / "sprites" / "environment" / "tileset_ground.json"


def main():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8-sig"))
    T = int(manifest["tile_size"])
    cols = int(manifest["columns"])
    by = {t["name"]: t for t in manifest["tiles"]}
    atlas = Image.open(ATLAS).convert("RGBA")

    NEW = ["grass_worn", "grass_edge_n", "grass_edge_e", "grass_edge_s", "grass_edge_w",
           "grass_corner_ne", "grass_corner_nw", "grass_corner_se", "grass_corner_sw"]
    if all(n in by for n in NEW):
        print("[ground-transitions] 已存在，跳过")
        return

    def tile(name):
        t = by[name]
        return atlas.crop((t["x"]*T, t["y"]*T, (t["x"]+1)*T, (t["y"]+1)*T)).convert("RGBA")

    grass = tile("grass_a")
    grass2 = tile("grass_b")
    dirt = tile("dirt_a")
    gp = grass.load(); g2p = grass2.load(); dp = dirt.load()

    # 确定性伪随机（不引入 random 保证可复现构建）
    def h(x, y, s=0):
        v = (x * 374761393 + y * 668265263 + s * 2246822519) & 0xffffffff
        v = (v ^ (v >> 13)) * 1274126177 & 0xffffffff
        return ((v ^ (v >> 16)) & 0xffff) / 65535.0

    def blend(pa, pb, t):
        return tuple(int(pa[i]*(1-t)+pb[i]*t) for i in range(4))

    # grass_worn：草到土的中间态——大部分草、约 40% 像素被土色替换（成片斑块非椒盐）
    worn = Image.new("RGBA", (T, T))
    wp = worn.load()
    for y in range(T):
        for x in range(T):
            base = gp[x, y] if h(x, y, 1) > 0.35 else g2p[x, y]
            # 斑块噪声：低频块决定是否掺土
            block = h(x//3, y//3, 7)
            if block < 0.42:
                wp[x, y] = blend(base, dp[x, y], 0.55 + 0.3*h(x, y, 9))
            else:
                wp[x, y] = base

    # 边缘过渡：某一侧是土、渐变到草，dither 交界（供草地块四条边用）
    def edge(dir_):
        im = Image.new("RGBA", (T, T)); p = im.load()
        for y in range(T):
            for x in range(T):
                # d = 归一化到"土侧"的距离，0=纯土 1=纯草
                if dir_ == "n": d = y / (T-1)
                elif dir_ == "s": d = 1 - y/(T-1)
                elif dir_ == "w": d = x/(T-1)
                else: d = 1 - x/(T-1)  # e
                base = gp[x, y] if h(x, y, 1) > 0.4 else g2p[x, y]
                # dither 阈值：越靠土侧越可能是土
                thresh = d
                if h(x, y, 3) > thresh:
                    p[x, y] = blend(dp[x, y], base, min(1.0, d*0.6))
                else:
                    p[x, y] = base
        return im

    def corner(cx, cy):
        # cx,cy in {0,1}：土角在哪个角。0=土侧
        im = Image.new("RGBA", (T, T)); p = im.load()
        for y in range(T):
            for x in range(T):
                dx = x/(T-1) if cx else 1-x/(T-1)
                dy = y/(T-1) if cy else 1-y/(T-1)
                d = min(dx, dy)  # 到土角的径向
                base = gp[x, y] if h(x, y, 1) > 0.4 else g2p[x, y]
                if h(x, y, 3) > d:
                    p[x, y] = blend(dp[x, y], base, min(1.0, d*0.6))
                else:
                    p[x, y] = base
        return im

    built = {
        "grass_worn": worn,
        "grass_edge_n": edge("n"), "grass_edge_e": edge("e"),
        "grass_edge_s": edge("s"), "grass_edge_w": edge("w"),
        "grass_corner_nw": corner(0, 0), "grass_corner_ne": corner(1, 0),
        "grass_corner_sw": corner(0, 1), "grass_corner_se": corner(1, 1),
    }

    # 找真正空闲的格子（现有 tile 占用之外），不够则扩图集高度
    occupied = set((t["x"], t["y"]) for t in manifest["tiles"])
    cur_rows = atlas.height // T
    # 候选空格：先扫现有行的空洞，再往下扩行
    def free_cells(rows_total):
        for yy in range(rows_total):
            for xx in range(cols):
                if (xx, yy) not in occupied:
                    yield xx, yy
    slots = []
    scan_rows = cur_rows
    while len(slots) < len(NEW):
        slots = list(free_cells(scan_rows))
        if len(slots) < len(NEW):
            scan_rows += 1
    slots = slots[:len(NEW)]
    max_row = max(y for _, y in slots)
    new_atlas = atlas
    if (max_row + 1) * T > atlas.height:
        new_atlas = Image.new("RGBA", (atlas.width, (max_row + 1) * T))
        new_atlas.paste(atlas, (0, 0))
    for name, (nx, ny) in zip(NEW, slots):
        new_atlas.paste(built[name], (nx*T, ny*T))
        manifest["tiles"].append({"name": name, "x": nx, "y": ny, "solid": 0})
        occupied.add((nx, ny))
        print("[ground-transitions]", name, f"@({nx},{ny})")
    new_atlas.save(ATLAS)
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
    print("[ground-transitions] 完成，图集", new_atlas.size)


if __name__ == "__main__":
    main()
