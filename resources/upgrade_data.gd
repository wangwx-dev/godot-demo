class_name UpgradeData
extends Resource
## 强化卡定义（upgrade-design 卡表，tech-design §3）。
## effect 先用"枚举+值"覆盖 MVP，紫卡"规则改写"实装时演进为脚本引用（tech-design 待定 3）。

enum Rarity { WHITE, BLUE, PURPLE }
enum Effect {
	DAMAGE_MULT, ATTACK_SPEED_MULT, RANGE_MULT, MOVE_SPEED_MULT,
	MAX_HP_ADD, PICKUP_RADIUS_MULT, SKILL_COOLDOWN_ADD, LOOT_TIME_MULT,
}

@export var display_name: String = ""
@export var description: String = ""
@export var rarity: Rarity = Rarity.WHITE
@export var max_stacks: int = 3
@export var effect: Effect = Effect.DAMAGE_MULT
@export var effect_value: float = 0.0  ## 每层数值（乘数增量或加法量，随 effect 语义）
@export var weapon_ref: WeaponData  ## 空 = 通用强化；非空 = 该武器专属（换武器清零）
@export var icon: Texture2D
