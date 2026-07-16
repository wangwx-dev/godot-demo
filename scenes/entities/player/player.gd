class_name Player
extends CharacterBody2D
## 俯视角八方向移动的玩家控制器。

@export var max_speed: float = 220.0
## 加速度和减速度（像素/秒²），值越大手感越"跟手"
@export var acceleration: float = 1600.0
@export var friction: float = 2000.0


func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
