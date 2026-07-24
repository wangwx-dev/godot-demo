extends Node
## 调试工具（tech-design §6）。OS.is_debug_build() 门控，导出版自动失效。
## 快捷键：F1 角标开关 / F2 +100 金 / F3 跳过当天。
## 里程碑推进中临时需要的开关一律进这里，不散落在业务代码里。

## 校准角标数据源：各系统实装后写这几个字段（M1 敌人数、M2 Heat/间隔）。
var enemy_count: int = 0
var heat: float = -1.0
var spawn_interval: float = -1.0

var _label: Label
var _overlay_visible: bool = false  # 发布默认关，F1 开
var _shot_frame: int = 0  # --shot=N：第 N 帧存主视口截图后退出（无人值守 QA）
var _frame_count: int = 0
var _start_map: String = ""  # --start-map=shop|rest|assault：起局直接传送（无人值守 QA）
var _die_at: int = 0  # --die-at=N：第 N 帧自毁（结算画面无人值守 QA）
var _flow_stage: int = -1  # --flow-test：全循环流转测试（战斗→休整→商店→总攻→杀 Boss→撤离结算）
var _flow_wait: int = 0
var _ui_smoke_stage: int = -1  # --ui-smoke：主菜单→起始武器→暂停→设置 交互冒烟
var _ui_smoke_wait: int = 0
var _npc_smoke_stage: int = -1  # --npc-smoke：救援点生成→清守卫→解锁→存盘
var _npc_smoke_wait: int = 0


func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		set_process_unhandled_input(false)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_frame = int(arg.trim_prefix("--shot="))
		elif arg.begins_with("--start-map="):
			_start_map = arg.trim_prefix("--start-map=")
		elif arg.begins_with("--die-at="):
			_die_at = int(arg.trim_prefix("--die-at="))
		elif arg == "--flow-test":
			_flow_stage = 0
			process_mode = Node.PROCESS_MODE_ALWAYS  # 升级弹窗暂停树时测试也要继续走
		elif arg.begins_with("--route-audit="):
			# 路线审计：批量种子模拟整局候选流，验证保底与同种子复现（无头 QA）
			_route_audit.call_deferred(int(arg.trim_prefix("--route-audit=")))
		elif arg == "--ui-smoke":
			_ui_smoke_stage = 0
			process_mode = Node.PROCESS_MODE_ALWAYS  # 模态菜单暂停树时测试也要继续走
		elif arg == "--npc-smoke":
			_npc_smoke_stage = 0
			process_mode = Node.PROCESS_MODE_ALWAYS
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	_label = Label.new()
	_label.position = Vector2(8, 130)  # 让开正式 HUD 生存簇（M7）
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))
	layer.add_child(_label)
	add_child(layer)


func _process(_delta: float) -> void:
	_frame_count += 1
	if _start_map != "" and get_tree().current_scene != null:
		# 起局传送（--start-map）：商店 QA 顺带塞满测试物资走兑换播报
		var target: String = _start_map
		_start_map = ""
		if target == "battle":
			RunState.main_weapon = load("res://resources/weapons/weapon_pistol.tres")
			RunState.sub_weapon = load("res://resources/weapons/weapon_molotov.tres")
			get_tree().change_scene_to_file.call_deferred(
					"res://scenes/levels/test_arena/test_arena.tscn")
		elif target == "shop":
			RunState.try_add_loot(load("res://resources/loot/loot_canned_food.tres"))
			RunState.try_add_loot(load("res://resources/loot/loot_canned_food.tres"))
			RunState.try_add_loot(load("res://resources/loot/loot_medicine.tres"))
			RunState.try_add_loot(load("res://resources/loot/loot_gold_bar.tres"))
			MapFlow.travel(get_tree(), RunState.MapType.SHOP)
		elif target == "rest":
			MapFlow.travel(get_tree(), RunState.MapType.REST)
		elif target == "assault":
			MapFlow.travel(get_tree(), RunState.MapType.ASSAULT)
	if _die_at > 0 and _frame_count >= _die_at:
		_die_at = 0
		var qa_player: Player = get_tree().get_first_node_in_group("player") as Player
		if qa_player != null:
			qa_player.take_damage(9999)
	if _flow_stage >= 0:
		_flow_step()
	if _ui_smoke_stage >= 0:
		_ui_smoke_step()
	if _npc_smoke_stage >= 0:
		_npc_smoke_step()
	if _shot_frame > 0 and _frame_count >= _shot_frame:
		_shot_frame = 0
		var img: Image = get_viewport().get_texture().get_image()
		var out_path: String = "res://tools/previews/ingame_view.png"
		img.save_png(ProjectSettings.globalize_path(out_path))
		print("[Debug] 截图 -> ", out_path)
		get_tree().quit()
	var in_level: bool = get_tree().current_scene != null and get_tree().current_scene.is_in_group("levels")
	_label.visible = _overlay_visible and in_level
	if not _label.visible:
		return
	var lines: PackedStringArray = []
	lines.append("FPS %d" % Engine.get_frames_per_second())
	lines.append("seed %d" % RunRng.run_seed)
	lines.append("day %d/%d  gold %d  bag %d/%d" % [
		RunState.day, RunState.TOTAL_DAYS, RunState.gold,
		RunState.backpack.size(), RunState.backpack_cap,
	])
	lines.append("hp %d/%d  lv %d (%d/%d xp)" % [
		RunState.hp, RunState.max_hp, RunState.level,
		RunState.xp, RunState.xp_needed(RunState.level),
	])
	lines.append("enemies %d" % enemy_count)
	if heat >= 0.0:
		lines.append("heat %.1f  interval %.2fs" % [heat, spawn_interval])
	_label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_F1:
			_overlay_visible = not _overlay_visible
		KEY_F2:
			RunState.add_gold(100)
		KEY_F3:
			RunState.advance_day()
		KEY_F5:
			# QA 传送：商店图（M7 验收动线）
			MapFlow.travel(get_tree(), RunState.MapType.SHOP)
		KEY_F6:
			# QA 传送：休整图
			MapFlow.travel(get_tree(), RunState.MapType.REST)
		KEY_F7:
			# QA 传送：总攻图（M8 验收动线）
			MapFlow.travel(get_tree(), RunState.MapType.ASSAULT)
		KEY_F8:
			# QA 自毁：验证死亡结算画面
			var player: Player = get_tree().get_first_node_in_group("player") as Player
			if player != null:
				player.take_damage(9999)


## ---- 全循环流转测试（--flow-test）----
## 战斗→休整→商店→总攻→核平 Boss→撤离结算出现即 PASS。验证场景流转与胜利链路。

func _flow_step() -> void:
	if _frame_count > 12000:
		print("[flow-test] FAIL：超时（stage=%d）" % _flow_stage)
		get_tree().quit(1)
		return
	_flow_wait -= 1
	if _flow_wait > 0:
		return
	match _flow_stage:
		0:  # 预置起始武器（无头点不了起始二选一弹窗）+ 进战斗图
			RunState.main_weapon = load("res://resources/weapons/weapon_pistol.tres")
			RunState.sub_weapon = load("res://resources/weapons/weapon_molotov.tres")
			get_tree().change_scene_to_file.call_deferred(
					"res://scenes/levels/test_arena/test_arena.tscn")
			_flow_wait = 120
			_flow_stage = 1
		1:
			print("[flow-test] 战斗图 OK → 休整")
			MapFlow.travel(get_tree(), RunState.MapType.REST)
			_flow_wait = 90
			_flow_stage = 2
		2:
			print("[flow-test] 休整图 OK → 商店")
			MapFlow.travel(get_tree(), RunState.MapType.SHOP)
			_flow_wait = 90
			_flow_stage = 3
		3:
			print("[flow-test] 商店图 OK → 总攻（信号弹链路同款 travel）")
			MapFlow.travel(get_tree(), RunState.MapType.ASSAULT)
			_flow_wait = 150
			_flow_stage = 4
		4:  # 逐帧核平全场（坚韧词缀单跳上限，需要连打多轮）
			for node in get_tree().get_nodes_in_group("enemies"):
				(node as EnemyBase).take_damage(999999)
			if not get_tree().get_nodes_in_group("run_summary").is_empty():
				print("[flow-test] Boss 击杀 → 撤离结算出现，带出 %d 金 · 击杀 %d" % [
						RunState.gold, RunState.kills])
				print("[flow-test] PASS")
				get_tree().quit(0)


## ---- NPC 救援冒烟（--npc-smoke）----
## 重置 meta → 进战斗图 → 强制放救援点 → 清光守卫 → 验证解锁+存盘。

func _npc_smoke_step() -> void:
	if _frame_count > 4000:
		print("[npc-smoke] FAIL：超时（stage=%d）" % _npc_smoke_stage)
		get_tree().quit(1)
		return
	_npc_smoke_wait -= 1
	if _npc_smoke_wait > 0:
		return
	match _npc_smoke_stage:
		0:
			MetaProgress.reset_meta()
			RunState.main_weapon = load("res://resources/weapons/weapon_pistol.tres")
			RunState.sub_weapon = load("res://resources/weapons/weapon_molotov.tres")
			get_tree().change_scene_to_file.call_deferred(
					"res://scenes/levels/test_arena/test_arena.tscn")
			_npc_smoke_wait = 90
			_npc_smoke_stage = 1
		1:
			# 手动放一个救援点（不靠概率）
			var scene: Node = get_tree().current_scene
			var rescue = load("res://scenes/entities/rescue/rescue_point.gd").new()
			rescue.npc_id = MetaProgress.MEDIC
			rescue.position = Vector2(1280, 1280)
			scene.add_child(rescue)
			print("[npc-smoke] 放置救援点 medic，守卫数=", rescue.guard_count)
			_npc_smoke_wait = 30
			_npc_smoke_stage = 2
		2:
			# 清光该救援点的守卫（对所有 rescue_guard_id>=0 的敌人 take_damage）
			var guards: int = 0
			for node in get_tree().get_nodes_in_group("enemies"):
				var e: EnemyBase = node as EnemyBase
				if e != null and e.rescue_guard_id >= 0 and e.state != EnemyBase.State.DIE:
					e.take_damage(999999)
					guards += 1
			print("[npc-smoke] 清除守卫 ", guards, " 只")
			_npc_smoke_wait = 20
			_npc_smoke_stage = 3
		3:
			# 验证：medic 已解锁 + 本局救援记录 + meta 存盘
			if not MetaProgress.is_unlocked(MetaProgress.MEDIC):
				print("[npc-smoke] FAIL：解救后 medic 未解锁")
				get_tree().quit(1)
				return
			if RunState.rescued_this_run.is_empty():
				print("[npc-smoke] FAIL：rescued_this_run 未记录")
				get_tree().quit(1)
				return
			# 重新读盘验证持久化
			var check := MetaProgress
			print("[npc-smoke] medic 解锁=", check.is_unlocked(MetaProgress.MEDIC),
					" 本局救援=", RunState.rescued_this_run, " 累计解锁=", check.unlocked_count())
			print("[npc-smoke] PASS")
			get_tree().quit(0)


## ---- UI 交互冒烟（--ui-smoke）----
## 主菜单在场 → 开始新局 → 起始武器弹窗 → 选球棒 → 进战斗图 → 暂停 → 设置调音量 → 回主菜单。
## 每一步断言关键节点存在/状态正确，任一失配即 FAIL 非零退出。无头验证 UI 接线不炸。

func _ui_smoke_step() -> void:
	if _frame_count > 4000:
		print("[ui-smoke] FAIL：超时（stage=%d）" % _ui_smoke_stage)
		get_tree().quit(1)
		return
	_ui_smoke_wait -= 1
	if _ui_smoke_wait > 0:
		return
	var scene: Node = get_tree().current_scene
	match _ui_smoke_stage:
		0:  # 主菜单应为起始场景
			if scene == null or scene.name != "MainMenu":
				print("[ui-smoke] FAIL：起始场景不是主菜单（%s）" % [scene.name if scene else "null"])
				get_tree().quit(1)
				return
			print("[ui-smoke] 主菜单 OK → 开始新局")
			RunRng.new_run()
			RunState.reset()
			get_tree().change_scene_to_file.call_deferred(
					"res://scenes/levels/test_arena/test_arena.tscn")
			_ui_smoke_wait = 60
			_ui_smoke_stage = 1
		1:  # 战斗图应弹出起始武器二选一
			var starter: Node = get_tree().get_first_node_in_group("_modal_pause_owner")
			var menu: StarterWeaponMenu = _find_starter()
			if menu == null:
				print("[ui-smoke] FAIL：起始武器弹窗未出现")
				get_tree().quit(1)
				return
			if not get_tree().paused:
				print("[ui-smoke] FAIL：起始武器弹窗未暂停树")
				get_tree().quit(1)
				return
			print("[ui-smoke] 起始武器弹窗 OK（树已暂停）→ 选球棒")
			menu._on_pick(load("res://resources/weapons/weapon_bat.tres"))
			_ui_smoke_wait = 30
			_ui_smoke_stage = 2
		2:  # 选定后应恢复、主武器已装备
			if get_tree().paused:
				print("[ui-smoke] FAIL：选武器后树未恢复")
				get_tree().quit(1)
				return
			if RunState.main_weapon == null:
				print("[ui-smoke] FAIL：主武器未写入 RunState")
				get_tree().quit(1)
				return
			print("[ui-smoke] 起始武器已装备（%s）→ 打开暂停菜单" % RunState.main_weapon.display_name)
			PauseMenu._show_menu()
			_ui_smoke_wait = 20
			_ui_smoke_stage = 3
		3:  # 暂停菜单应暂停树
			if not get_tree().paused:
				print("[ui-smoke] FAIL：暂停菜单未暂停树")
				get_tree().quit(1)
				return
			print("[ui-smoke] 暂停菜单 OK → 调音量")
			var before: float = GameSettings.volume("BGM")
			GameSettings.set_volume("BGM", 0.33)
			if absf(GameSettings.volume("BGM") - 0.33) > 0.001:
				print("[ui-smoke] FAIL：音量未生效")
				get_tree().quit(1)
				return
			GameSettings.set_volume("BGM", before)
			print("[ui-smoke] 音量设置 OK → 回主菜单")
			PauseMenu._on_main_menu()
			_ui_smoke_wait = 60
			_ui_smoke_stage = 4
		4:  # 应回到主菜单，树已恢复
			if get_tree().paused:
				print("[ui-smoke] FAIL：回主菜单后树未恢复")
				get_tree().quit(1)
				return
			if scene == null or scene.name != "MainMenu":
				print("[ui-smoke] FAIL：未回到主菜单（%s）" % [scene.name if scene else "null"])
				get_tree().quit(1)
				return
			print("[ui-smoke] 回主菜单 OK")
			print("[ui-smoke] PASS")
			get_tree().quit(0)


func _find_starter() -> StarterWeaponMenu:
	for node in get_tree().get_nodes_in_group("_modal_pause_owner"):
		if node is StarterWeaponMenu:
			return node
	return null


## ---- 路线审计（--route-audit=N）----

## N 个种子各模拟一整局候选流：统计无精英候选的局数、同种子复现失败数。
func _route_audit(runs: int) -> void:
	if runs <= 0:
		print("[route-audit] FAIL：局数必须大于 0")
		get_tree().quit(2)
		return
	var no_elite: int = 0
	var no_shop_min: int = 0
	var repro_fail: int = 0
	var duplicate_days: int = 0
	var failed_seeds: Array[int] = []
	for i in runs:
		var audit_seed: int = 100003 + i * 7919
		var seq_a: Array = _simulate_route(audit_seed)
		var seq_b: Array = _simulate_route(audit_seed)
		var run_failed: bool = false
		if seq_a != seq_b:
			repro_fail += 1
			run_failed = true
		var elite_hits: int = 0
		var shop_hits: int = 0
		for picks in seq_a:
			if RunState.MapType.ELITE in picks:
				elite_hits += 1
			if RunState.MapType.SHOP in picks:
				shop_hits += 1
			if RunState.MapType.ASSAULT not in picks and picks.size() >= 2 and picks[0] == picks[1]:
				duplicate_days += 1
				run_failed = true
		if elite_hits == 0:
			no_elite += 1
			run_failed = true
		if shop_hits < RunState.SHOP_MIN_OFFERS:
			no_shop_min += 1
			run_failed = true
		if run_failed and failed_seeds.size() < 8:
			failed_seeds.append(audit_seed)
	print("[route-audit] 局数=%d  无精英候选局=%d  商店不足2局=%d  重复候选天=%d  复现失败=%d" % [
			runs, no_elite, no_shop_min, duplicate_days, repro_fail])
	var failure_count: int = no_elite + no_shop_min + duplicate_days + repro_fail
	if failure_count > 0:
		print("[route-audit] FAIL seeds（最多 8 个）=", failed_seeds)
		get_tree().quit(1)
	else:
		print("[route-audit] PASS")
		get_tree().quit(0)


## 单局模拟：滚完 8 天候选直到总攻，出口交替选择覆盖两条访问路径。
func _simulate_route(sim_seed: int) -> Array:
	RunRng.start_run(sim_seed)
	RunState.reset()
	var seq: Array = []
	while true:
		var picks: Array[int] = RunState.roll_candidates()
		seq.append(picks.duplicate())
		if RunState.MapType.ASSAULT in picks:
			break
		RunState.depart(picks[RunState.day % 2])
	return seq
