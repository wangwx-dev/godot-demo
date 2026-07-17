class_name LootData
extends Resource
## 价值物定义（economy-design 价值物表：白10/蓝25/紫60，tech-design §3）。

enum Tier { WHITE, BLUE, PURPLE }

@export var display_name: String = ""
@export var tier: Tier = Tier.WHITE
@export var value: int = 10
@export var icon: Texture2D
