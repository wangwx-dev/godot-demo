class_name PressureHud
extends CanvasLayer
## M2 临时压力 UI（mvp-plan：简单数字/色条即可，正式警戒条归 M7）。
## Heat 色条 + 死线倒计时（最后 60s 变红+心跳、最后 10s 报数）+ 涌潮方向性红光+低吼。

const GROWL := preload("res://assets/audio/sfx/surge_growl.wav")
const HEARTBEAT := preload("res://assets/audio/sfx/heartbeat.wav")
const TICK := preload("res://assets/audio/sfx/countdown_tick.wav")

var director: HeatDirector

var _surge_glow_timer: float = 0.0
var _surge_direction: Vector2 = Vector2.RIGHT
var _heartbeat_timer: float = 0.0
var _last_countdown_second: int = -1

var _heat_label: Label
var _time_label: Label
var _glow: Control
var _audio: AudioStreamPlayer


func setup(heat_director: HeatDirector) -> void:
	director = heat_director
	director.surge_incoming.connect(_on_surge_incoming)


func _ready() -> void:
	layer = 90
	_glow = Control.new()
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	var box: VBoxContainer = VBoxContainer.new()
	box.position = Vector2(760, 8)
	add_child(box)
	_heat_label = Label.new()
	_heat_label.add_theme_font_size_override("font_size", 22)
	box.add_child(_heat_label)
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 30)
	box.add_child(_time_label)
	_audio = AudioStreamPlayer.new()
	add_child(_audio)


func _process(delta: float) -> void:
	if director == null or not is_instance_valid(director):
		return
	# Heat：数字 + 阶段色（绿→黄→红→深红崩溃，对齐 ui-design 四态）
	var heat: float = director.heat
	var color: Color
	if director.collapse:
		color = Color(0.75, 0.1, 0.1)
		_heat_label.text = "!! 崩溃 !!"
	else:
		if heat < 4.0:
			color = Color(0.4, 0.8, 0.4)
		elif heat < 8.0:
			color = Color(0.9, 0.8, 0.3)
		else:
			color = Color(0.95, 0.4, 0.25)
		_heat_label.text = "警戒 %d" % floori(heat)
	_heat_label.add_theme_color_override("font_color", color)
	# 死线倒计时
	var left: float = director.time_left()
	_time_label.text = "%d:%02d" % [floori(left / 60.0), floori(left) % 60]
	var final_minute: bool = left <= 60.0 and not director.collapse
	_time_label.add_theme_color_override("font_color",
			Color(0.95, 0.25, 0.2) if final_minute or director.collapse else Color(0.85, 0.85, 0.8))
	if final_minute:
		# 心跳渐强：60s 每 1.2s 一次 → 最后 10s 每 0.5s
		_heartbeat_timer -= delta
		if _heartbeat_timer <= 0.0:
			_heartbeat_timer = lerpf(0.5, 1.2, left / 60.0)
			_play(HEARTBEAT, linear_to_db(lerpf(1.0, 0.5, left / 60.0)))
		if left <= 10.0 and floori(left) != _last_countdown_second:
			_last_countdown_second = floori(left)
			_play(TICK, 0.0)
	# 涌潮红光淡出
	if _surge_glow_timer > 0.0:
		_surge_glow_timer -= delta
		_glow.queue_redraw()


func _on_surge_incoming(direction: Vector2) -> void:
	_surge_direction = direction
	_surge_glow_timer = HeatDirector.SURGE_WARNING_DURATION
	_play(GROWL, 0.0)


## 涌潮来向的屏幕边缘红色渐变条（正式 shader 版归 M7）。
func _draw_glow() -> void:
	if _surge_glow_timer <= 0.0:
		return
	var size: Vector2 = _glow.size
	var alpha: float = 0.55 * (0.6 + 0.4 * sin(_surge_glow_timer * 12.0))  # 脉动
	var thickness: float = 90.0
	var color: Color = Color(0.9, 0.15, 0.1, alpha)
	var fade: Color = Color(0.9, 0.15, 0.1, 0.0)
	# 主导轴决定哪条边亮
	if absf(_surge_direction.x) >= absf(_surge_direction.y):
		if _surge_direction.x > 0.0:
			_draw_gradient_rect(Rect2(size.x - thickness, 0, thickness, size.y), fade, color, true)
		else:
			_draw_gradient_rect(Rect2(0, 0, thickness, size.y), color, fade, true)
	else:
		if _surge_direction.y > 0.0:
			_draw_gradient_rect(Rect2(0, size.y - thickness, size.x, thickness), fade, color, false)
		else:
			_draw_gradient_rect(Rect2(0, 0, size.x, thickness), color, fade, false)


func _draw_gradient_rect(rect: Rect2, from: Color, to: Color, horizontal: bool) -> void:
	var steps: int = 12
	for i in steps:
		var t0: float = float(i) / steps
		var slice: Rect2
		if horizontal:
			slice = Rect2(rect.position.x + rect.size.x * t0, rect.position.y, rect.size.x / steps, rect.size.y)
		else:
			slice = Rect2(rect.position.x, rect.position.y + rect.size.y * t0, rect.size.x, rect.size.y / steps)
		_glow.draw_rect(slice, from.lerp(to, t0))


func _play(stream: AudioStream, volume_db: float) -> void:
	_audio.stream = stream
	_audio.volume_db = volume_db
	_audio.play()
