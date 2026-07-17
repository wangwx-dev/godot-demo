class_name EnemyBloater
extends EnemyBase
## 臃肿者：被击杀后原地膨胀 1s（预警）再爆炸——"别贴脸，别站它尸体上"（enemy-design #2）。

const EXPLODE_DELAY: float = 1.0
const EXPLODE_RADIUS: float = 120.0
const EXPLODE_DAMAGE: int = 25


func _on_death() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(body_polygon, "scale", body_polygon.scale * 1.35, EXPLODE_DELAY)
	tween.parallel().tween_property(body_polygon, "color", Color(1.0, 0.45, 0.15), EXPLODE_DELAY)
	tween.tween_callback(_explode)


func _explode() -> void:
	var flash: FlashCircle = FlashCircle.new()
	flash.radius = EXPLODE_RADIUS
	get_parent().add_child(flash)
	flash.global_position = global_position
	var player: Player = get_tree().get_first_node_in_group("player") as Player
	if player != null and global_position.distance_to(player.global_position) <= EXPLODE_RADIUS:
		player.take_damage(EXPLODE_DAMAGE)
	_spawn_drops()
	queue_free()
