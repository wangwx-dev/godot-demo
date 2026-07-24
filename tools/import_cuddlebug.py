# cuddlebug Apocalypse 角色包导入（2026-07-24 美术翻修）：
# 玩家/丧尸/子弹/箭矢 4 方向 32px 帧 → assets/sprites/ 下按 Fx 约定的行序精灵表。
# 授权：cuddle bug（itch.io/apocalyse），可商用可改，禁再分发——故只导入加工产物，
# 原始包留在 game-assets 库（不入 git）。行序统一为项目 Fx.DIR_NAMES = [up,left,down,right]。
# 源行序（预览确认）：0=front(down) 1=back(up) 2=right 3=left。
import os
from PIL import Image

SRC = r"D:\personal\game-assets\sprites\cuddlebug_apocalypse_characters\Apocalypse Character Pack"
DST_CHAR = r"D:\personal\godot-demo\assets\sprites\characters"
DST_ENEMY = r"D:\personal\godot-demo\assets\sprites\enemies"
DST_WEAP = r"D:\personal\godot-demo\assets\sprites\weapons"
CELL = 32
SCALE = 2  # 2x 最近邻，贴近项目其它 32→64 实体密度

# 源行 → 项目 Fx 行序 [up,left,down,right]
# 源：0=down 1=up 2=right 3=left  →  目标顺序需要的源行索引：
ROW_REMAP = [1, 3, 0, 2]  # up<-src1, left<-src3, down<-src0, right<-src2


def reorder_and_scale(src_path, dst_path, cols):
    im = Image.open(src_path).convert("RGBA")
    w, h = im.size
    assert h == CELL * 4, f"{src_path} 行数非4: {h}"
    out = Image.new("RGBA", (cols * CELL * SCALE, 4 * CELL * SCALE), (0, 0, 0, 0))
    for dst_row, src_row in enumerate(ROW_REMAP):
        for c in range(cols):
            cell = im.crop((c * CELL, src_row * CELL, (c + 1) * CELL, (src_row + 1) * CELL))
            if SCALE != 1:
                cell = cell.resize((CELL * SCALE, CELL * SCALE), Image.NEAREST)
            out.paste(cell, (c * CELL * SCALE, dst_row * CELL * SCALE))
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    out.save(dst_path)
    print("[cuddlebug]", os.path.relpath(dst_path, r"D:\personal\godot-demo"), f"{cols}x4 @{SCALE}x")


# 玩家动画（cols 按 readme）
PLAYER = {
    "Idle.png": ("cb_player_idle.png", 3),
    "Walk.png": ("cb_player_walk.png", 5),
    "Shoot.png": ("cb_player_shoot.png", 5),
    "Stab.png": ("cb_player_stab.png", 5),
    "Crossbow.png": ("cb_player_crossbow.png", 7),
    "Death.png": ("cb_player_death.png", 5),
}
for src, (dst, cols) in PLAYER.items():
    reorder_and_scale(os.path.join(SRC, "Player", src), os.path.join(DST_CHAR, dst), cols)

# 子弹/箭矢（同样 4 方向行序）
reorder_and_scale(os.path.join(SRC, "Player", "Bullet.png"), os.path.join(DST_WEAP, "cb_bullet.png"), 5)
reorder_and_scale(os.path.join(SRC, "Player", "Arrow.png"), os.path.join(DST_WEAP, "cb_arrow.png"), 9)

# 丧尸动画
ZOMBIE = {
    "Idle.png": ("cb_zombie_idle.png", 6),
    "Walk.png": ("cb_zombie_walk.png", 11),
    "Attack.png": ("cb_zombie_attack.png", 9),
    "Death.png": ("cb_zombie_death.png", 8),
}
for src, (dst, cols) in ZOMBIE.items():
    reorder_and_scale(os.path.join(SRC, "Zombie", src), os.path.join(DST_ENEMY, dst), cols)

print("[cuddlebug] 完成")
