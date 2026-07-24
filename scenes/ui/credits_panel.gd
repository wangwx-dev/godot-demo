class_name CreditsPanel
extends Control
## 鸣谢界面（发布合规）：展示 CC-BY/CC-BY-SA 素材的强制署名（许可证要求）。
## 主菜单"鸣谢"打开；内容与 assets/CREDITS.md 收口清单一致，随包分发的 CREDITS.md 为完整版。

const LINES: Array = [
	["末日搜打撤", 26, Color(0.85, 0.3, 0.25)],
	["", 10, Color.WHITE],
	["— 音乐 —", 18, Color(0.7, 0.8, 0.7)],
	["Kevin MacLeod (incompetech.com) — CC-BY 4.0", 14, Color(0.82, 0.82, 0.78)],
	["\"Darkest Child\" / \"Ossuary 5 - Rest\" / \"Five Armies\"", 13, Color(0.65, 0.65, 0.62)],
	["", 8, Color.WHITE],
	["— 音效 —", 18, Color(0.7, 0.8, 0.7)],
	["Horror Sound Effects Library by Little Robot Sound Factory — CC-BY 3.0", 13, Color(0.82, 0.82, 0.78)],
	["Kenney / Stealthix / 及众 CC0 作者（详见随包 CREDITS）", 13, Color(0.65, 0.65, 0.62)],
	["", 8, Color.WHITE],
	["— 美术 —", 18, Color(0.7, 0.8, 0.7)],
	["Apocalypse Character Pack by cuddle bug（玩家/丧尸）", 13, Color(0.82, 0.82, 0.78)],
	["Zombie Apocalypse Tileset by Ittai Manero（场景/道具）", 13, Color(0.82, 0.82, 0.78)],
	["Icons by Kyrise (kyrise.itch.io) — CC-BY 4.0", 13, Color(0.82, 0.82, 0.78)],
	["LPC 贡献者群 — CC-BY-SA 3.0（详见随包 CREDITS.md）", 13, Color(0.65, 0.65, 0.62)],
	["", 8, Color.WHITE],
	["— 字体 —", 18, Color(0.7, 0.8, 0.7)],
	["缝合像素字体 by TakWolf 等 — SIL OFL 1.1", 13, Color(0.82, 0.82, 0.78)],
	["", 10, Color.WHITE],
	["完整署名与许可证见随游戏分发的 CREDITS.md", 12, Color(0.55, 0.6, 0.55)],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	for line in LINES:
		var label: Label = Label.new()
		label.text = line[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", line[1])
		label.add_theme_color_override("font_color", line[2])
		box.add_child(label)
	var close_btn: Button = Button.new()
	close_btn.text = "返回"
	close_btn.custom_minimum_size = Vector2(200, 40)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(func() -> void:
			Sfx.play("ui_confirm", -6.0)
			queue_free())
	box.add_child(close_btn)
