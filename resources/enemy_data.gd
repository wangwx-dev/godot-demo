class_name EnemyData
extends Resource
## 敌人数值定义（enemy-design 数值表落地，tech-design §3）。

@export var display_name: String = ""
@export var max_hp: int = 30
@export var speed: float = 120.0
@export var contact_damage: int = 10
@export var damage_interval: float = 0.5
@export var xp_drop: int = 1
@export var gold_chance: float = 0.1
@export var sprite_scale: float = 1.0
@export var sprite_set: String = "lpc_zombie_walk"  ## assets/sprites/enemies/ 下的 LPC 走路表名
@export var outline_color: Color = Color(0.2, 0.45, 0.2)  ## 轮廓即身份
@export var behavior_scene: PackedScene  ## 特殊尸重载行为的场景，空 = 直线追踪
