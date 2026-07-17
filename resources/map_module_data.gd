class_name MapModuleData
extends Resource
## 地图模块定义（mapgen-design 模块库，tech-design §3）。
## 插槽（资源点/载具/绷带/投放）由模块场景内的 Marker2D 分组承载。

@export var display_name: String = ""
@export var theme_name: String = ""
@export var scene: PackedScene
