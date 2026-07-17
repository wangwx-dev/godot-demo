class_name WeaponData
extends Resource
## 武器定义（weapon-design，tech-design §3）。主副武器共用一类，slot 区分。

enum Slot { MAIN, SUB }
enum Geometry { ARC, LINE, AREA }  ## 弧形挥砍 / 直线弹道 / 区域效果；后续武器再扩

@export var display_name: String = ""
@export var slot: Slot = Slot.MAIN
@export var damage: int = 0
@export var interval: float = 1.0  ## 主武器攻击间隔；副武器 = 冷却
@export var attack_range: float = 0.0  ## 索敌半径
@export var geometry: Geometry = Geometry.ARC
@export var geometry_params: Dictionary = {}  ## 如 {"arc_degrees": 150} / {"pierce": 0}
@export var knockback: float = 0.0
@export var icon: Texture2D
