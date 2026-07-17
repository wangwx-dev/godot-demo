class_name Pickup
extends Node2D
## 掉落拾取物（经验球/金币），对象池复用（enemy-design）。
## 无物理体：每帧距离判定 + 进拾取半径后磁吸加速飞向玩家。

enum Kind { XP, GOLD }

const COLLECT_DISTANCE: float = 14.0
const MAGNET_ACCEL: float = 1400.0

var kind: Kind = Kind.XP
var amount: int = 1

var _active: bool = false
var _magnet_speed: float = 0.0
var _player: Player


func activate(new_kind: Kind, new_amount: int, pos: Vector2) -> void:
	kind = new_kind
	amount = new_amount
	global_position = pos
	_active = true
	_magnet_speed = 0.0
	_player = get_tree().get_first_node_in_group("player") as Player
	show()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _active:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		return
	var distance: float = global_position.distance_to(_player.global_position)
	if distance <= COLLECT_DISTANCE:
		_collect()
		return
	if distance <= _player.effective_pickup_radius():
		_magnet_speed += MAGNET_ACCEL * delta
		global_position = global_position.move_toward(_player.global_position, _magnet_speed * delta)
	else:
		_magnet_speed = 0.0


func _collect() -> void:
	match kind:
		Kind.XP:
			RunState.add_xp(amount)
		Kind.GOLD:
			RunState.add_gold(amount)
	_active = false
	hide()
	var pool: ObjectPool = get_parent() as ObjectPool
	if pool != null:
		pool.release(self)
	else:
		queue_free()


func _draw() -> void:
	if kind == Kind.XP:
		draw_circle(Vector2.ZERO, 5.0, Color(0.35, 0.85, 0.95))
	else:
		draw_circle(Vector2.ZERO, 6.0, Color(0.95, 0.8, 0.2))
