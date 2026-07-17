class_name MapModuleTiled
extends MapModule
## 正式素材版模块基类：.tscn 手工场景（TileMapLayer 地面/装饰/障碍 + props）。
## 障碍碰撞由 TileSet 物理层与 props 内置 StaticBody2D 自带（不走声明式矩形）；
## 插槽从场景内 Slots 节点下的 Marker2D 分组读取（slot_spawn/slot_vehicle/slot_resource/slot_bandage）。
## 场景由 tools/build_map_assets.gd 生成，可在编辑器直接手调。


func _setup() -> void:
	# 建筑立面朝下的像素画不支持 90° 旋转变体（旋转后立面横躺穿帮）
	rotatable = false
	for marker in get_node("Slots").get_children():
		if not marker is Marker2D:
			continue
		if marker.is_in_group("slot_spawn"):
			spawn_slots.append(marker.position)
		elif marker.is_in_group("slot_vehicle"):
			vehicle_slots.append(marker.position)
		elif marker.is_in_group("slot_resource"):
			supply_slots.append(marker.position)
		elif marker.is_in_group("slot_bandage"):
			bandage_slots.append(marker.position)


func _draw() -> void:
	pass  # 正式美术无需占位矩形与主题水印
