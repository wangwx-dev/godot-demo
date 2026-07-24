class_name Fx
extends Object
## 实体素材特效工具库：SpriteFrames 缓存构建、一次性动画、血迹贴花。
## 帧图命名约定：assets/sprites/<prefix>_00.png ~ _NN.png（import_entity_assets.ps1 产物）。

const SPRITE_ROOT: String = "res://assets/sprites/"
const GORE_GROUP: String = "gore_decals"
const GORE_CAP: int = 80  # 血迹贴花上限，超出移除最旧的（防节点无限增长）

static var _frames_cache: Dictionary = {}
static var _flash_shader: Shader


## 构建/复用 SpriteFrames："default" 动画 = prefix_00..prefix_(count-1)
static func frames(prefix: String, count: int, fps: float = 8.0, loop: bool = true) -> SpriteFrames:
	var key: String = "%s|%d|%.1f|%s" % [prefix, count, fps, loop]
	if _frames_cache.has(key):
		return _frames_cache[key]
	var sf: SpriteFrames = SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	sf.set_animation_loop("default", loop)
	for i in count:
		var tex: Texture2D = load("%s%s_%02d.png" % [SPRITE_ROOT, prefix, i])
		assert(tex != null, "缺少帧图：" + prefix + "_%02d" % i)
		sf.add_frame("default", tex)
	_frames_cache[key] = sf
	return sf


const DIR_NAMES: Array[String] = ["up", "left", "down", "right"]  # LPC 通用行序


## LPC 走路表（576x256：4 方向行 x 9 列，col0=站立）→ walk_*/idle_* 八动画
static func dir_frames(sheet_path: String, fps: float = 10.0) -> SpriteFrames:
	var key: String = "dir|%s|%.1f" % [sheet_path, fps]
	if _frames_cache.has(key):
		return _frames_cache[key]
	var tex: Texture2D = load(SPRITE_ROOT + sheet_path)
	assert(tex != null, "缺少帧图：" + sheet_path)
	var sf: SpriteFrames = SpriteFrames.new()
	for row in 4:
		var walk_name: String = "walk_" + DIR_NAMES[row]
		sf.add_animation(walk_name)
		sf.set_animation_speed(walk_name, fps)
		sf.set_animation_loop(walk_name, true)
		for col in range(1, 9):
			var frame: AtlasTexture = AtlasTexture.new()
			frame.atlas = tex
			frame.region = Rect2(col * 64, row * 64, 64, 64)
			sf.add_frame(walk_name, frame)
		var idle_name: String = "idle_" + DIR_NAMES[row]
		sf.add_animation(idle_name)
		var idle: AtlasTexture = AtlasTexture.new()
		idle.atlas = tex
		idle.region = Rect2(0, row * 64, 64, 64)
		sf.add_frame(idle_name, idle)
	_frames_cache[key] = sf
	return sf


## 向已有 SpriteFrames 补挂动作表（如 slash 6 帧 x 4 向）→ <prefix>_<dir> 四动画（不循环）
static func add_action(sf: SpriteFrames, sheet_path: String, prefix: String, cols: int, fps: float = 16.0) -> void:
	if sf.has_animation(prefix + "_up"):
		return
	var tex: Texture2D = load(SPRITE_ROOT + sheet_path)
	assert(tex != null, "缺少帧图：" + sheet_path)
	for row in 4:
		var anim: String = prefix + "_" + DIR_NAMES[row]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, fps)
		sf.set_animation_loop(anim, false)
		for col in cols:
			var frame: AtlasTexture = AtlasTexture.new()
			frame.atlas = tex
			frame.region = Rect2(col * 64, row * 64, 64, 64)
			sf.add_frame(anim, frame)


## cuddlebug 多方向动画构建（美术翻修）：帧 64px（2×32），行序同 DIR_NAMES=[up,left,down,right]。
## 把多张精灵表（idle/walk/shoot/…）合进一个 SpriteFrames：每张表贡献 <prefix>_<dir> 四动画。
## specs: [[sheet_path, prefix, cols, fps, loop], ...]。frame 64px。
const CB_CELL: int = 64

static func cb_frames(specs: Array) -> SpriteFrames:
	var key: String = "cb|" + str(specs)
	if _frames_cache.has(key):
		return _frames_cache[key]
	var sf: SpriteFrames = SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for spec in specs:
		var sheet_path: String = spec[0]
		var prefix: String = spec[1]
		var cols: int = spec[2]
		var fps: float = spec[3]
		var loop: bool = spec[4]
		var tex: Texture2D = load(SPRITE_ROOT + sheet_path)
		assert(tex != null, "缺少帧图：" + sheet_path)
		for row in 4:
			var anim: String = prefix + "_" + DIR_NAMES[row]
			sf.add_animation(anim)
			sf.set_animation_speed(anim, fps)
			sf.set_animation_loop(anim, loop)
			for col in cols:
				var frame: AtlasTexture = AtlasTexture.new()
				frame.atlas = tex
				frame.region = Rect2(col * CB_CELL, row * CB_CELL, CB_CELL, CB_CELL)
				sf.add_frame(anim, frame)
	_frames_cache[key] = sf
	return sf


## 向量 → LPC 方向名（主导轴决定）
static func dir_name(v: Vector2) -> String:
	if absf(v.x) >= absf(v.y):
		return "right" if v.x >= 0.0 else "left"
	return "down" if v.y >= 0.0 else "up"


## 按指定帧序构建（一张帧图序列里交错存多套皮肤时用，如 player_variant 三套衣服）
static func frames_indexed(prefix: String, indices: Array, fps: float = 8.0, loop: bool = true) -> SpriteFrames:
	var key: String = "%s|%s|%.1f|%s" % [prefix, str(indices), fps, loop]
	if _frames_cache.has(key):
		return _frames_cache[key]
	var sf: SpriteFrames = SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	sf.set_animation_loop("default", loop)
	for i in indices:
		var tex: Texture2D = load("%s%s_%02d.png" % [SPRITE_ROOT, prefix, i])
		assert(tex != null, "缺少帧图：" + prefix + "_%02d" % i)
		sf.add_frame("default", tex)
	_frames_cache[key] = sf
	return sf


## 一次性动画（爆炸/挥砍/枪口焰等）：播完自动销毁
static func one_shot(parent: Node, prefix: String, count: int, pos: Vector2,
		fps: float = 12.0, sprite_scale: float = 1.0, rot: float = 0.0) -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = frames(prefix, count, fps, false)
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.rotation = rot
	parent.add_child(sprite)
	sprite.global_position = pos
	sprite.play("default")
	sprite.animation_finished.connect(sprite.queue_free)
	return sprite


## 单帧特效（枪口焰等无编号单图）：短暂显示后销毁
static func single(parent: Node, sprite_path: String, pos: Vector2, lifetime: float = 0.08,
		sprite_scale: float = 1.0, rot: float = 0.0) -> void:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(SPRITE_ROOT + sprite_path)
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.rotation = rot
	parent.add_child(sprite)
	sprite.global_position = pos
	parent.get_tree().create_timer(lifetime).timeout.connect(sprite.queue_free)


## 循环动画（火焰等）：调用方负责生命周期（挂在会销毁的父节点下）
static func looping(parent: Node, prefix: String, count: int, local_pos: Vector2,
		fps: float = 10.0, sprite_scale: float = 1.0) -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = frames(prefix, count, fps, true)
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.position = local_pos
	parent.add_child(sprite)
	sprite.play("default")
	# 错帧起播：多团火不同步，避免"复制粘贴感"
	sprite.frame = randi() % count
	return sprite


## 血迹贴花：死亡处随机血渍，压在实体层之下，超上限先进先出
static func blood_decal(scene_parent: Node, pos: Vector2, decal_scale: float = 1.0) -> void:
	var tree: SceneTree = scene_parent.get_tree()
	if tree == null:
		return
	var existing: Array[Node] = tree.get_nodes_in_group(GORE_GROUP)
	if existing.size() >= GORE_CAP:
		existing[0].queue_free()
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load("%senemies/blood_splat_%02d.png" % [SPRITE_ROOT, randi() % 5])
	sprite.rotation = randf() * TAU
	sprite.scale = Vector2.ONE * decal_scale
	sprite.z_index = -1
	sprite.modulate.a = 0.85
	sprite.add_to_group(GORE_GROUP)
	scene_parent.add_child(sprite)
	sprite.global_position = pos


## 受击闪白材质（每实体一份实例，shader 参数互不干扰）
static func flash_material() -> ShaderMaterial:
	if _flash_shader == null:
		_flash_shader = load("res://scripts/flash.gdshader")
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _flash_shader
	return mat
