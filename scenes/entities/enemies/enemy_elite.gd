class_name EnemyElite
extends EnemyBase
## 词缀精英（enemy-design）：任意底板 × 放大（血×6/体×1.5/伤×1.5/速×0.9）× 1~2 词缀。
## MVP 词缀 3 个：狂暴（半血提速+攻速）/召唤（6s 召 3 普通尸）/坚韧（单次伤害上限 10% 最大血）。
## 有仇恨半径——游荡精英可绕开（自由取舍），受击立即入战。
## 掉落：30 金 + 必掉蓝档强化拾取物；击杀后 10s 刷入安全窗（EventBus.elite_killed）。

enum Affix { FRENZY, SUMMON, TOUGH }

const AFFIX_NAMES: Array[String] = ["狂暴", "召唤", "坚韧"]
const AGGRO_RADIUS: float = 480.0
const SUMMON_INTERVAL: float = 6.0
const SUMMON_COUNT: int = 3
const GOLD_BOUNTY: int = 30

const BASE_SCENE: PackedScene = preload("res://scenes/entities/enemies/enemy_base.tscn")
const WALKER_DATA: EnemyData = preload("res://resources/enemies/enemy_walker.tres")

var affixes: Array[int] = []

var _home: Vector2 = Vector2.INF
var _aggroed: bool = false
var _frenzied: bool = false
var _max_hp: int = 0
var _summon_timer: float = SUMMON_INTERVAL


func _ready() -> void:
	# 底板放大：复制资源改数，不污染共享 .tres
	data = data.duplicate()
	data.max_hp = roundi(data.max_hp * 6.0)
	data.contact_damage = roundi(data.contact_damage * 1.5)
	data.speed *= 0.9
	data.sprite_scale *= 1.5
	super()
	_max_hp = hp


func _physics_process(delta: float) -> void:
	if _home == Vector2.INF:
		_home = global_position
	if state == State.CHASE and not _aggroed:
		if _player != null and is_instance_valid(_player) 				and global_position.distance_to(_player.global_position) <= AGGRO_RADIUS:
			_aggroed = true
		else:
			# 未入战：守在原地缓慢归位（守卫点/游荡锚点）
			velocity = (_home - global_position).limit_length(60.0)
			move_and_slide()
			queue_redraw()
			return
	if _aggroed and Affix.FRENZY in affixes and not _frenzied and hp <= _max_hp / 2:
		# 狂暴：斩杀阶段别松懈（enemy-design 考题）
		_frenzied = true
		data.speed *= 1.6
		data.damage_interval *= 0.5
	if _aggroed and Affix.SUMMON in affixes and state == State.CHASE:
		_summon_timer -= delta
		if _summon_timer <= 0.0:
			_summon_timer = SUMMON_INTERVAL
			_summon()
	super(delta)
	queue_redraw()


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	_aggroed = true
	if Affix.TOUGH in affixes:
		# 坚韧：克制低频高伤，逼攻速流打法
		amount = mini(amount, ceili(_max_hp * 0.1))
	super(amount, knockback)


func _summon() -> void:
	var rng: RandomNumberGenerator = RunRng.stream("enemy")
	for i in SUMMON_COUNT:
		var minion: EnemyBase = BASE_SCENE.instantiate()
		minion.data = WALKER_DATA
		get_parent().add_child(minion)
		var angle: float = rng.randf_range(0.0, TAU)
		minion.global_position = global_position + Vector2.from_angle(angle) * rng.randf_range(40.0, 80.0)


func _on_death() -> void:
	EventBus.elite_killed.emit()
	var pool: ObjectPool = get_tree().get_first_node_in_group("pickup_pool") as ObjectPool
	if pool != null:
		var coin: Pickup = pool.acquire() as Pickup
		coin.activate(Pickup.Kind.GOLD, GOLD_BOUNTY, global_position + Vector2(0, 10))
		var token: Pickup = pool.acquire() as Pickup
		token.activate(Pickup.Kind.UPGRADE, 1, global_position + Vector2(0, -14))
	super()


func _draw() -> void:
	if state == State.DIE:
		return
	var half_w: float = 30.0
	var y: float = -BODY_RADIUS * data.sprite_scale - 18.0
	# 血条（普通尸不显示，精英显示——地位可读）
	draw_rect(Rect2(-half_w, y, half_w * 2.0, 6.0), Color(0.1, 0.1, 0.1, 0.85))
	draw_rect(Rect2(-half_w, y, half_w * 2.0 * (float(hp) / _max_hp), 6.0), Color(0.85, 0.25, 0.2))
	# 词缀读题：头顶文字（正式版图标化，asset-list）
	var names: Array[String] = []
	for affix in affixes:
		names.append(AFFIX_NAMES[affix])
	draw_string(ThemeDB.fallback_font, Vector2(-half_w, y - 6.0),
			" ".join(names), HORIZONTAL_ALIGNMENT_CENTER, half_w * 2.0, 13, Color(0.95, 0.75, 0.3))
