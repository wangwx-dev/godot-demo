class_name FlashCircle
extends Node2D
## 一次性圆形闪光（臃肿者爆炸等），淡出后自毁。

var radius: float = 120.0
var color: Color = Color(1.0, 0.5, 0.2, 0.7)
var life: float = 0.4

var _age: float = 0.0


func _process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(color, color.a * (1.0 - _age / life)))
