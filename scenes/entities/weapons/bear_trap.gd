class_name BearTrap
extends Node2D
## 捕兽夹地面道具（WeaponTrap 布设）：等第一个踩进触发半径的敌人，定住 duration 秒
## 并造成一次小额伤害，随即收起；lifetime 内没人踩中也会自行收回（economy-design
## "驻留保留进度"精神一致——陷阱不是无限期的地图污染）。

const TRIGGER_RADIUS: float = 26.0

var _root_duration: float = 3.0
var _trigger_damage: int = 8
var _lifetime: float = 12.0
var _age: float = 0.0
var _triggered: bool = false


func setup(root_duration: float, trigger_damage: int, lifetime: float) -> void:
	_root_duration = root_duration
	_trigger_damage = trigger_damage
	_lifetime = lifetime


func _physics_process(delta: float) -> void:
	if _triggered:
		return
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy.state == EnemyBase.State.DIE:
			continue
		if global_position.distance_to(enemy.global_position) <= TRIGGER_RADIUS:
			_trigger(enemy)
			return


func _trigger(enemy: EnemyBase) -> void:
	_triggered = true
	enemy.take_damage(_trigger_damage)
	enemy.apply_control(_root_duration, 0.0)
	queue_redraw()
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var color: Color = Color(0.85, 0.3, 0.25) if _triggered else Color(0.55, 0.55, 0.6)
	draw_circle(Vector2.ZERO, 14.0, Color(color.r, color.g, color.b, 0.35))
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 16, color, 2.5)
	for i in 6:
		var angle: float = TAU * i / 6.0
		draw_line(Vector2.from_angle(angle) * 8.0, Vector2.from_angle(angle) * 16.0, color, 2.0)
