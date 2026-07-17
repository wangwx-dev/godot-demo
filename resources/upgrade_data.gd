class_name UpgradeData
extends Resource
## 强化条目定义（upgrade-design，tech-design §3）。
## 白卡=纯数值；蓝卡=技能/生存域或武器专属；紫卡（规则改写）MVP 暂缓。
## 武器专属用 WEAPON_LEVEL：weapon_ref 指向武器，逐层名称/描述在 level_* 数组，
## 实际效果数据在 WeaponData.level_effects（顺序解锁，Lv2→Lv4）。

enum Rarity { WHITE, BLUE, PURPLE }
enum Effect {
	DAMAGE_MULT,          ## 力量：伤害 +值（加算）
	ATTACK_INTERVAL_MULT, ## 敏捷：攻击间隔 -值（乘算递减）
	RANGE_MULT,           ## 扩展：攻击范围 +值
	MOVE_SPEED_MULT,      ## 疾跑：移速 +值
	MAX_HP_ADD,           ## 强壮：最大生命 +值（新增部分立即回满）
	PICKUP_RADIUS_MULT,   ## 磁性：拾取半径 +值
	SKILL_COOLDOWN_ADD,   ## 灵活筋骨：角色技能冷却 +值（负数）
	LOOT_TIME_MULT,       ## 快手：驻留时间 -值（M4 接线）
	WEAPON_LEVEL,         ## 武器专属：weapon_ref 武器升 1 级
}

@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rarity: Rarity = Rarity.WHITE
@export var effect: Effect = Effect.DAMAGE_MULT
@export var effect_value: float = 0.0
@export var max_stacks: int = 3
@export var weapon_ref: WeaponData  ## 仅 WEAPON_LEVEL：持有该武器才入池
@export var level_names: PackedStringArray = []  ## 仅 WEAPON_LEVEL：逐层卡名
@export var level_descs: PackedStringArray = []  ## 仅 WEAPON_LEVEL：逐层描述
