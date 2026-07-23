class_name WeaponDecoy
extends WeaponBase
## 诱饵收音机（功能类，固定放置/大半径/长冷却）：驻留搜刮且有尸群逼近时才放
## （weapon-design v2.1：与猎人"诱饵"技能——投掷/短时/灵活点控——差异化定位，
## 这是放置/持久的面控，"搜刮神器"）。

func _try_attack() -> bool:
	if _enemies_in_range().is_empty():
		return false
	if not _player_is_looting():
		return false
	var radio: DecoyRadio = DecoyRadio.new()
	get_tree().current_scene.add_child(radio)
	radio.global_position = global_position
	radio.setup(
			data.geometry_params.get("pull_radius", 260.0) + _level_sum("radius_add"),
			data.geometry_params.get("duration", 10.0) + _level_sum("duration_add"))
	Sfx.play("chest_open", -4.0, 300)
	return true


## 触发条件之一："驻留搜刮"——玩家正在某个资源点读条中（economy-design 驻留态）。
func _player_is_looting() -> bool:
	for node in get_tree().get_nodes_in_group("resource_points"):
		if (node as ResourcePoint).is_dwelling():
			return true
	return false
