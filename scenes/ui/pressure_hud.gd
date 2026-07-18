class_name PressureHud
extends CanvasLayer
## 威胁反馈层（M2 起，M7 起数字/条移交 GameHud 警戒条，本层只管"表现"）：
## 涌潮方向性红光+低吼、末 60s 心跳渐强、末 10s 报数音、崩溃常驻红晕、
## 受击红晕闪现、低血（<30%）常驻淡红晕（ui-design 战斗反馈）。

const GROWL := preload("res://assets/audio/sfx/surge_growl.wav")
const HEARTBEAT := preload("res://assets/audio/sfx/heartbeat.wav")
const TICK := preload("res://assets/audio/sfx/countdown_tick.wav")

const LOW_HP_RATIO: float = 0.3

var director: HeatDirector

var _surge_glow_timer: float = 0.0
var _surge_direction: Vector2 = Vector2.RIGHT
var _heartbeat_timer: float = 0.0
var _last_countdown_second: int = -1
var _hit_flash: float = 0.0
var _last_hp: int = -1

var _surge_label: Label
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
	_surge_label = Label.new()
	_surge_label.add_theme_font_size_override("font_size", 42)
	_surge_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.15))
	_surge_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_surge_label.add_theme_constant_override("outline_size", 6)
	_surge_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_surge_label.position = Vector2(-130, 120)
	_surge_label.visible = false
	add_child(_surge_label)
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	_last_hp = RunState.hp
	EventBus.player_health_changed.connect(_on_health_changed)


func _on_health_changed(current: int, _max_value: int) -> void:
	if current < _last_hp:
		_hit_flash = 0.35
	_last_hp = current


func _process(delta: float) -> void:
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	if director == null or not is_instance_valid(director):
		return
	var left: float = director.time_left()
	var final_minute: bool = left <= 60.0 and not director.collapse
	if final_minute:
		# 心跳渐强：60s 每 1.2s 一次 → 最后 10s 每 0.5s
		_heartbeat_timer -= delta
		if _heartbeat_timer <= 0.0:
			_heartbeat_timer = lerpf(0.5, 1.2, left / 60.0)
			_play(HEARTBEAT, linear_to_db(lerpf(1.0, 0.5, left / 60.0)))
		if left <= 10.0 and floori(left) != _last_countdown_second:
			_last_countdown_second = floori(left)
			_play(TICK, 0.0)
	# 红光淡出 / 崩溃常驻 / 受击与低血红晕都要重绘
	if _surge_glow_timer > 0.0:
		_surge_glow_timer -= delta
		if _surge_glow_timer <= 0.0:
			_surge_label.visible = false
	_glow.queue_redraw()


func _on_surge_incoming(direction: Vector2) -> void:
	_surge_direction = direction
	_surge_glow_timer = HeatDirector.SURGE_WARNING_DURATION
	_surge_label.text = "尸潮来袭 %s" % _direction_name(direction)
	_surge_label.visible = true
	_play(GROWL, 3.0)


func _direction_name(direction: Vector2) -> String:
	if absf(direction.x) >= absf(direction.y):
		return "→ 右侧" if direction.x > 0.0 else "← 左侧"
	return "↓ 下方" if direction.y > 0.0 else "↑ 上方"


## 屏幕边缘反馈合成：崩溃常驻深红呼吸 > 受击闪现红晕 > 低血常驻淡红晕 > 涌潮方向红光。
func _draw_glow() -> void:
	var size: Vector2 = _glow.size
	# 崩溃期：四边常驻深红呼吸晕——整个屏幕都在告诉你"该跑了"
	if director != null and is_instance_valid(director) and director.collapse:
		var pulse: float = 0.30 + 0.12 * sin(Time.get_ticks_msec() / 350.0)
		_draw_vignette(size, Color(0.7, 0.05, 0.05), pulse, 140.0)
	# 受击红晕：短促一闪（ui-design 战斗反馈）
	if _hit_flash > 0.0:
		_draw_vignette(size, Color(0.9, 0.08, 0.05), 0.55 * (_hit_flash / 0.35), 110.0)
	# 低血常驻淡红晕："该去休整了"不用文字说
	var hp_ratio: float = float(RunState.hp) / maxf(RunState.max_hp, 1)
	if hp_ratio <= LOW_HP_RATIO and RunState.hp > 0:
		var breathe: float = 0.16 + 0.08 * sin(Time.get_ticks_msec() / 300.0)
		_draw_vignette(size, Color(0.75, 0.1, 0.08), breathe, 90.0)
	if _surge_glow_timer <= 0.0:
		return
	# 涌潮预警：加宽加亮 + 快脉动
	var alpha: float = 0.85 * (0.55 + 0.45 * sin(_surge_glow_timer * 14.0))
	var thickness: float = 260.0
	var color: Color = Color(1.0, 0.1, 0.05, alpha)
	var fade: Color = Color(1.0, 0.1, 0.05, 0.0)
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


## 四边红晕（受击/低血/崩溃共用）。
func _draw_vignette(size: Vector2, base: Color, alpha: float, edge: float) -> void:
	var edge_color: Color = Color(base.r, base.g, base.b, alpha)
	var edge_fade: Color = Color(base.r, base.g, base.b, 0.0)
	_draw_gradient_rect(Rect2(0, 0, edge, size.y), edge_color, edge_fade, true)
	_draw_gradient_rect(Rect2(size.x - edge, 0, edge, size.y), edge_fade, edge_color, true)
	_draw_gradient_rect(Rect2(0, 0, size.x, edge), edge_color, edge_fade, false)
	_draw_gradient_rect(Rect2(0, size.y - edge, size.x, edge), edge_fade, edge_color, false)


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
