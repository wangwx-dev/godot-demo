extends Node
## 全局设置（发布准备）：音量偏好持久化到 user://settings.cfg，启动即应用到音频总线。
## 三条总线 Master/BGM/SFX（default_bus_layout.tres）。线性音量 0~1 存盘，
## 播放走 linear_to_db 换算——0 为静音、1 为 0dB。

const CONFIG_PATH: String = "user://settings.cfg"
const BUSES: Array[String] = ["Master", "BGM", "SFX"]

var _volumes: Dictionary = {"Master": 0.9, "BGM": 0.7, "SFX": 0.9}
var _fullscreen: bool = false


func _ready() -> void:
	_load()
	for bus_name in BUSES:
		_apply(bus_name)
	_apply_fullscreen()


func fullscreen() -> bool:
	return _fullscreen


func set_fullscreen(on: bool) -> void:
	_fullscreen = on
	_apply_fullscreen()
	_save()


func _apply_fullscreen() -> void:
	DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen
			else DisplayServer.WINDOW_MODE_WINDOWED)


func volume(bus_name: String) -> float:
	return _volumes.get(bus_name, 1.0)


func set_volume(bus_name: String, linear: float) -> void:
	_volumes[bus_name] = clampf(linear, 0.0, 1.0)
	_apply(bus_name)
	_save()


func _apply(bus_name: String) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var linear: float = _volumes.get(bus_name, 1.0)
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func _load() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	for bus_name in BUSES:
		if cfg.has_section_key("audio", bus_name):
			_volumes[bus_name] = float(cfg.get_value("audio", bus_name))
	if cfg.has_section_key("video", "fullscreen"):
		_fullscreen = bool(cfg.get_value("video", "fullscreen"))


func _save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for bus_name in BUSES:
		cfg.set_value("audio", bus_name, _volumes[bus_name])
	cfg.set_value("video", "fullscreen", _fullscreen)
	cfg.save(CONFIG_PATH)
