extends Node
## 跨局元进度（npc-design）：只存"救过哪些 NPC" + 统计，不存货币/物资
## （局内死亡全丢的紧张感不受影响）。与局内 RunState 职责分离（tech-design §2）。
## 存盘 user://meta.cfg。解锁是横向内容（服务可用性），非纵向数值膨胀。

const CONFIG_PATH: String = "user://meta.cfg"

## NPC id 常量（MVP 三个）
const VETERAN: String = "veteran"    ## 老兵——商店老板
const MEDIC: String = "medic"        ## 医师——治疗
const ARMORER: String = "armorer"    ## 军械师——武器货架
const ALL_NPCS: Array[String] = [VETERAN, MEDIC, ARMORER]

var _rescued: Dictionary = {}  ## npc_id -> true
var total_runs: int = 0
var total_extractions: int = 0


func _ready() -> void:
	_load()


func is_unlocked(npc_id: String) -> bool:
	return _rescued.get(npc_id, false)


func unlocked_count() -> int:
	return _rescued.size()


## 解救即解锁（npc-design MVP：救到即存，死亡也保留）。返回是否首次解锁。
func unlock(npc_id: String) -> bool:
	if _rescued.get(npc_id, false):
		return false
	_rescued[npc_id] = true
	_save()
	return true


func record_run() -> void:
	total_runs += 1
	_save()


func record_extraction() -> void:
	total_extractions += 1
	_save()


## 调试/重置元进度
func reset_meta() -> void:
	_rescued.clear()
	total_runs = 0
	total_extractions = 0
	_save()


func _load() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	total_runs = int(cfg.get_value("stats", "runs", 0))
	total_extractions = int(cfg.get_value("stats", "extractions", 0))
	for npc_id in ALL_NPCS:
		if bool(cfg.get_value("rescued", npc_id, false)):
			_rescued[npc_id] = true


func _save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("stats", "runs", total_runs)
	cfg.set_value("stats", "extractions", total_extractions)
	for npc_id in _rescued:
		cfg.set_value("rescued", npc_id, true)
	cfg.save(CONFIG_PATH)
