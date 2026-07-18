# LPC 幸存者合成 + LPC 丧尸走路帧提取（2026-07-18 角色素材升级）。
# 图层来源：Universal LPC Spritesheet Character Generator 仓库（各部件 CC-BY-SA 3.0 / GPL 3.0 为主，
# 逐部件署名见 assets/CREDITS.md）；丧尸：OpenGameArt "[LPC] Zombie" by Benjamin K. Smith。
# 用法：python tools/build_lpc_characters.py [素材库目录]
#   素材库目录默认 ../asset-lib（工作区级，不入库）；缺文件时自动从网络下载。
# 产物：
#   assets/sprites/characters/lpc_survivor_walk.png  576x256（4 方向 x 9 帧，col0=站立）
#   assets/sprites/enemies/lpc_zombie_walk.png       同布局
import sys
import urllib.request
from pathlib import Path

from PIL import Image

REPO_ROOT = Path(__file__).resolve().parent.parent
LIB = Path(sys.argv[1]) if len(sys.argv) > 1 else REPO_ROOT.parent / "asset-lib"
LAYER_DIR = LIB / "lpc_layers"
RAW = "https://raw.githubusercontent.com/liberatedpixelcup/Universal-LPC-Spritesheet-Character-Generator/master/spritesheets"
ZOMBIE_URL = "https://opengameart.org/sites/default/files/Zombie_0.png"

# 部件 -> (仓库路径, 染色乘数 None=不染)
LAYERS = [
    ("body", "body/bodies/male/walk.png", None),
    ("feet", "feet/shoes/basic/male/walk.png", (0.32, 0.26, 0.20)),   # 棕靴
    ("legs", "legs/pants/male/walk.png", (0.38, 0.42, 0.52)),         # 牛仔蓝灰
    ("torso", "torso/clothes/longsleeve/longsleeve/male/walk.png", (0.62, 0.24, 0.20)),  # 暗红外套
    ("head", "head/heads/human/male/walk.png", None),
    ("hair", "hair/messy1/adult/walk.png", "hair"),                   # 特殊：去橙转深棕
]


def fetch(url: str, dest: Path) -> None:
    if dest.exists():
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    print(f"[lpc] 下载 {url}")
    urllib.request.urlretrieve(url, dest)


def tint(img: Image.Image, mult) -> Image.Image:
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if mult == "hair":
                # 去色后压深棕（原橙发太跳）
                lum = (r * 3 + g * 5 + b * 2) // 10
                px[x, y] = (int(lum * 0.42), int(lum * 0.33), int(lum * 0.26), a)
            else:
                px[x, y] = (min(int(r * mult[0] + 12), 255), min(int(g * mult[1] + 12), 255),
                            min(int(b * mult[2] + 12), 255), a)
    return out


def build_survivor() -> None:
    base = Image.new("RGBA", (576, 256), (0, 0, 0, 0))
    for name, path, mult in LAYERS:
        f = LAYER_DIR / f"{name}.png"
        fetch(f"{RAW}/{path}", f)
        layer = Image.open(f).convert("RGBA")
        if mult is not None:
            layer = tint(layer, mult)
        base.alpha_composite(layer)
    out = REPO_ROOT / "assets" / "sprites" / "characters" / "lpc_survivor_walk.png"
    base.save(out)
    print(f"[lpc] {out.relative_to(REPO_ROOT)}")


def build_zombie() -> None:
    src = LIB / "lpc_zombie_full.png"
    fetch(ZOMBIE_URL, src)
    full = Image.open(src).convert("RGBA")
    # 通用 21 行布局：walk = 第 8~11 行（up/left/down/right），每行 9 帧
    walk = full.crop((0, 8 * 64, 9 * 64, 12 * 64))
    out = REPO_ROOT / "assets" / "sprites" / "enemies" / "lpc_zombie_walk.png"
    walk.save(out)
    print(f"[lpc] {out.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    build_survivor()
    build_zombie()
    print("[lpc] 完成")
