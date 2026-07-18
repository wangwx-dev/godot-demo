extends Node
## 占位音效总线（M2 三件套之后的全表补齐）：
## 同名节流防群体命中炸耳、播放器池轮转、BGM 手动循环。
## 正式音频期只换 wav 不换接口（asset-list §7）。

const SFX_DIR: String = "res://assets/audio/sfx/"
const BGM_DIR: String = "res://assets/audio/music/"
const POOL_SIZE: int = 12

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last_play: Dictionary = {}  # 音效名 -> 上次播放 msec
var _streams: Dictionary = {}
var _bgm_player: AudioStreamPlayer
var _bgm_name: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 三选一暂停时确认音也要响
	for i in POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_bgm_player = AudioStreamPlayer.new()
	add_child(_bgm_player)
	_bgm_player.finished.connect(func() -> void: _bgm_player.play())
	# 全局信号自动接线（无归属节点的音效走这里）
	EventBus.player_leveled_up.connect(func(_level: int) -> void: play("level_up", -4.0))


## 播放音效：throttle_ms 内同名只响一次（群体挥砍命中 50 只也只有一层声音）。
func play(sfx_name: String, volume_db: float = 0.0, throttle_ms: int = 70) -> void:
	var now: int = Time.get_ticks_msec()
	if _last_play.has(sfx_name) and now - _last_play[sfx_name] < throttle_ms:
		return
	_last_play[sfx_name] = now
	if not _streams.has(sfx_name):
		var path: String = SFX_DIR + sfx_name + ".wav"
		_streams[sfx_name] = load(path) if ResourceLoader.exists(path) else null
		if _streams[sfx_name] == null:
			push_warning("Sfx 缺失：" + sfx_name)
	var stream: AudioStream = _streams[sfx_name]
	if stream == null:
		return
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.play()


## 切 BGM（battle/safe/assault；"" = 停）。同名不重启。
func bgm(bgm_name: String, volume_db: float = -10.0) -> void:
	if _bgm_name == bgm_name:
		return
	_bgm_name = bgm_name
	if bgm_name.is_empty():
		_bgm_player.stop()
		return
	_bgm_player.stream = load(BGM_DIR + "bgm_" + bgm_name + ".wav")
	_bgm_player.volume_db = volume_db
	_bgm_player.play()
