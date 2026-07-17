class_name Bandage
extends Node2D
## 绷带（economy-design）：散布图内非箱点位置，即拾回 15 血，不占格不驻留。

const HEAL_AMOUNT: int = 15
const COLLECT_DISTANCE: float = 20.0

var discovered: bool = false

var _player: Player


func _ready() -> void:
	add_to_group("bandages")
	_player = get_tree().get_first_node_in_group("player") as Player


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if global_position.distance_to(_player.global_position) <= COLLECT_DISTANCE:
		# 满血不浪费：留在原地（economy-design HP=胆量资源，绷带是路上的决策点）
		if RunState.hp >= RunState.max_hp:
			return
		RunState.heal(HEAL_AMOUNT)
		queue_free()


func _draw() -> void:
	# 白底红十字占位
	draw_rect(Rect2(-8, -8, 16, 16), Color(0.9, 0.9, 0.88))
	draw_rect(Rect2(-6, -2, 12, 4), Color(0.85, 0.2, 0.2))
	draw_rect(Rect2(-2, -6, 4, 12), Color(0.85, 0.2, 0.2))
