class_name ControlsHint
extends CanvasLayer
## 首图操作提示（发布：无引导玩家会懵）。第 1 天战斗图进场显示，8 秒后淡出。
## 只在每局第一张战斗图出现，不打断（不暂停），左下角低干扰。

const HINTS: Array[String] = [
	"WASD / 方向键 — 移动（武器自动攻击，站位即瞄准）",
	"空格 — 翻滚闪避（有冷却）",
	"E — 靠近载具/资源点交互",
	"ESC — 暂停",
	"找到载具即出口 · 搜刮物资 · 8 天后突围",
]


func _ready() -> void:
	layer = 84
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(16, -170)
	panel.modulate.a = 0.0
	add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title: Label = Label.new()
	title.text = "操作"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	box.add_child(title)
	for h in HINTS:
		var label: Label = Label.new()
		label.text = h
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		box.add_child(label)
	# 淡入 → 停留 → 淡出销毁
	var tw: Tween = create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.4)
	tw.tween_interval(8.0)
	tw.tween_property(panel, "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)
