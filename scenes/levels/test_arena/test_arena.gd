extends Node2D
## M0 相机体感实测图：2560×2560（= 2×2 模块），画出模块网格与边界。
## 验收（mvp-plan M0）：色块玩家在空图里跑，一屏体感 OK、横穿 ≈11.6s。

const MAP_SIZE: float = 2560.0
const MODULE_SIZE: float = 1280.0

@onready var player: Player = $Player


func _ready() -> void:
	player.set_camera_limits(Rect2(0, 0, MAP_SIZE, MAP_SIZE))
	queue_redraw()


func _draw() -> void:
	# 地面底色
	draw_rect(Rect2(0, 0, MAP_SIZE, MAP_SIZE), Color(0.13, 0.14, 0.12))
	# 模块网格（1280 间隔）——判断"一屏 1.5 个模块"体感的参照线
	for i in range(1, int(MAP_SIZE / MODULE_SIZE)):
		var offset: float = i * MODULE_SIZE
		draw_line(Vector2(offset, 0), Vector2(offset, MAP_SIZE), Color(0.3, 0.3, 0.28), 4.0)
		draw_line(Vector2(0, offset), Vector2(MAP_SIZE, offset), Color(0.3, 0.3, 0.28), 4.0)
	# 图边界
	draw_rect(Rect2(0, 0, MAP_SIZE, MAP_SIZE), Color(0.6, 0.3, 0.25), false, 8.0)
	# 100px 刻度点（距离体感参照：奔跑者钻出距离/翻滚 160px 等都以它读）
	for x in range(0, int(MAP_SIZE) + 1, 100):
		for y in range(0, int(MAP_SIZE) + 1, 100):
			draw_circle(Vector2(x, y), 2.0, Color(0.22, 0.23, 0.21))
