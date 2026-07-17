extends Node
## 全局信号中枢：只声明信号，不含逻辑（tech-design §2）。
## 跨场景通信全走这里，禁止节点路径穿透。

signal run_started(run_seed: int)
signal run_ended(victory: bool)
signal day_advanced(day: int)
signal heat_changed(heat: float)
signal deadline_collapsed
signal gold_changed(total: int)
signal backpack_changed
signal player_health_changed(current: int, max_value: int)
signal player_died
signal player_leveled_up(level: int)
signal player_xp_changed(xp: int, needed: int)
