class_name Player
extends CharacterBody2D
## 俯视角八方向移动的玩家控制器。
## 基础数值为 upgrade-design 锚点（220 移速），角色微属性/强化在 M1+ 组装。

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


## 相机限制到图边界（关卡进场时调用，tech-design §1）。
func set_camera_limits(rect: Rect2) -> void:
	var camera: Camera2D = $Camera2D
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
