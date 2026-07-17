class_name AffixData
extends Resource
## 精英词缀定义（enemy-design 词缀表，tech-design §3）。
## 效果参数用字典承载，词缀效果脚本在 M6 精英实装时定形。

@export var display_name: String = ""
@export var params: Dictionary = {}
@export var icon: Texture2D
@export var banned_pairs: Array[AffixData] = []  ## 禁配表（如 狂暴+磁力）
