extends Node
## 种子随机管理（tech-design §2）：一局一主种子，派生具名随机流。
## 具名流隔离是"同种子可复现整局"的前提——战斗中多打一枪不能影响
## 下一图的模块选择。所有随机调用必须走流，禁用裸 randi()。

const STREAM_NAMES: Array[String] = ["route", "mapgen", "loot", "enemy", "upgrade"]

var run_seed: int = 0

var _streams: Dictionary = {}


func _ready() -> void:
	var forced: int = _parse_seed_arg()
	start_run(forced if forced != 0 else _make_random_seed())


## 开新局：重建全部具名流。启动参数 --seed=N（"--" 之后）可指定复现。
func start_run(new_seed: int) -> void:
	run_seed = new_seed
	_streams.clear()
	for stream_name in STREAM_NAMES:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = hash("%s:%d" % [stream_name, new_seed])
		_streams[stream_name] = rng
	print("[RunRng] run seed = %d" % run_seed)


func stream(stream_name: String) -> RandomNumberGenerator:
	assert(_streams.has(stream_name), "未知随机流：" + stream_name)
	return _streams[stream_name]


func _make_random_seed() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi()


func _parse_seed_arg() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return int(arg.trim_prefix("--seed="))
	return 0
