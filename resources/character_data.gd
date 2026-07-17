class_name CharacterData
extends Resource
## 角色三拉杆定义（character-design，tech-design §3）。微属性为乘数（1.0 = 锚点值）。

@export var display_name: String = ""
@export var skill_scene: PackedScene
@export var speed_mult: float = 1.0
@export var hp_mult: float = 1.0
@export var pickup_mult: float = 1.0
@export var starting_weapon: WeaponData
