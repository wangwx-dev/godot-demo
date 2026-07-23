class_name FlashPulse
extends Node2D
## 闪光弹爆闪视觉：白色扩散圈迅速放大淡出，纯程序绘制不需要专属贴图。

const LIFETIME: float = 0.35

var radius: float = 130.0
var _age: float = 0.0


func setup(pulse_radius: float) -> void:
	radius = pulse_radius


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = _age / LIFETIME
	draw_circle(Vector2.ZERO, radius * (0.3 + 0.7 * t), Color(1.0, 1.0, 0.9, 0.55 * (1.0 - t)))
