class_name WeaponData
extends Resource
## 武器定义（weapon-design，tech-design §3）。主副武器共用一类，slot 区分。

enum Slot { MAIN, SUB }
enum Geometry {
	ARC, LINE, AREA,  ## 弧形挥砍 / 直线弹道 / 区域持续（原三把，数值顺序不可变——.tres 里存的是整数）
	SCATTER,  ## 扇形多弹丸（霰弹枪）
	CONE,     ## 锥形持续跳伤（链锯）
	BURST,    ## 瞬时范围爆炸（土制手雷）
	TRAP,     ## 地面陷阱，触发定身（捕兽夹）
	STUN,     ## 范围瞬间定身，无伤害（闪光弹）
	DECOY,    ## 放置式引怪（诱饵收音机）
	BUFF,     ## 自身增益，无目标判定（肾上腺素）
}

@export var display_name: String = ""
@export var slot: Slot = Slot.MAIN
@export var damage: int = 0
@export var interval: float = 1.0  ## 主武器攻击间隔；副武器 = 冷却
@export var attack_range: float = 0.0  ## 索敌半径
@export var geometry: Geometry = Geometry.ARC
@export var geometry_params: Dictionary = {}  ## 如 {"arc_degrees": 150} / {"pierce": 0}
@export var knockback: float = 0.0
@export var icon: Texture2D
## 专属强化逐级效果（Lv2 起，顺序解锁）：[{"damage_add": 6.0}, {"arc_add": 60.0}, ...]
## 键：damage_add / interval_add / arc_add / knockback_add / pierce_add / radius_add / duration_add
@export var level_effects: Array = []
