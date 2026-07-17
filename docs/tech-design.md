# 技术架构设计（实现方案）

> 状态：v1（2026-07-17）。开工前的三项阻塞决策落地：相机与像素密度、代码组织（Autoload/Resource/场景流转）、输入映射；附调试工具规划。
> 关联：玩法规格见 docs/game-design.md 及各子系统文档；工程约定（目录/命名/GDScript 风格）见 CLAUDE.md。

## 1. 相机与像素密度（全局参照，先于一切素材与地图制作）

设计文档的所有距离都是绝对像素（玩家 220px/s、模块 1280×1280、载具间距 ≥1000px），本节把它们钉到屏幕上：

| 项 | 决定 | 推导 |
|---|---|---|
| 基准视口 | **1920×1080**（canvas_items + expand 不变） | 一屏视野 = 1.5×0.84 个模块——能看清尸群包围圈的形成，又不至于一眼看穿整图 |
| 相机 zoom | **1.0**（不缩放，试玩校准 ±0.2❓） | 横穿 2×2 图 2560px ÷ 220px/s ≈ 11.6s，落在 mapgen"12~17 秒可横穿"目标内——设计数值本就按此密度写的 |
| 相机行为 | Camera2D 跟随玩家 + 图边界 limit + 轻微平滑 | 无前瞻偏移（自动索敌不需要预判视野） |
| 角色/普通尸 sprite | **32×32 逻辑尺寸** | 同屏 50 只怪时占屏 ~4%，尸群可读；奔跑者 24、臃肿者 48、精英 = 底板 ×1.5 |
| 持续流刷入环 | 以相机视口边缘为基准外扩 400~600px | pressure-design 的"屏幕外"定义在此闭环 |

- 素材按 32px 基准密度产出（asset-list 规格列以此为准）；占位期用 ColorRect/Polygon2D 同尺寸色块
- ❓ zoom 最终值 = M0 里程碑用色块实测一屏体感后拍板（asset-list 管理约定 5 的闭环点）

## 2. Autoload 清单（全局单例，按此注册顺序）

| Autoload | 职责 | 关键点 |
|---|---|---|
| **EventBus** | 全局信号中枢：`day_advanced`、`heat_changed`、`deadline_collapsed`、`player_died`、`run_ended`… | 只声明信号，无逻辑——跨场景通信全走这里，禁止节点路径穿透（CLAUDE.md 约定） |
| **RunRng** | 种子随机管理：一局一主种子，派生**具名流**（`route`/`mapgen`/`loot`/`enemy`/`upgrade` 各一个 RandomNumberGenerator） | 具名流隔离是"同种子可复现整局"的前提——战斗中多打一枪不能影响下一图的模块选择。开局即建流，所有随机调用必须走流，禁用裸 randi() |
| **RunState** | 局状态：天数、路线候选、货币、8 格背包、构筑（已拿强化）、当前角色/武器等级、提前总攻标记 | 跨图保留的状态只在这里；图内状态（Heat/死线/迷雾）归关卡场景，换图即弃。局结束整体 reset |
| **Debug** | 调试工具（见 §6） | `OS.is_debug_build()` 门控，导出版自动失效 |

- 有意不做 autoload 的：Heat/死线控制器、刷怪器、迷雾——都是**图内生命周期**，做成关卡场景的子节点（`HeatDirector`、`SpawnDirector`、`FogOverlay`），换图自然销毁重建
- 音频管理 MVP 暂缓（直接挂 AudioStreamPlayer），素材替换期再立 autoload

## 3. Resource 数据模式（resources/，全部数值的落地容器）

设计文档反复写"用 Resource 定义"，字段结构在此统一。每类一个 `class_name` 脚本 + 若干 .tres 实例：

| Resource 类 | 字段（初版） | 实例来源 |
|---|---|---|
| `EnemyData` | max_hp, speed, contact_damage, damage_interval, xp_drop, gold_chance, sprite_scale, outline_color, behavior_scene(PackedScene) | enemy-design 数值表（普通尸/奔跑者/臃肿者…） |
| `CharacterData` | display_name, skill_scene, speed_mult, hp_mult, pickup_mult, starting_weapon(WeaponData) | character-design 三人（MVP 只实装信使，三人数据先建档） |
| `WeaponData` | slot(main/sub), damage, interval, range, geometry(枚举+参数字典), knockback, pierce, cooldown(副武器), upgrade_track(Array[UpgradeData]) | weapon-design（球棒/手枪/燃烧瓶） |
| `UpgradeData` | rarity(白/蓝/紫), max_stacks, effect_type(枚举), effect_value, weapon_ref(可空=通用), icon | upgrade-design 卡表 |
| `LootData` | tier(白/蓝/紫), value(10/25/60), display_name, icon | economy-design 价值物表 |
| `AffixData` | affix_name, effect 参数, icon, banned_pairs(Array) | enemy-design 词缀表（狂暴/召唤/坚韧） |
| `MapModuleData` | scene(PackedScene), theme_name, slots 由场景内 Marker2D 分组承载 | mapgen-design 模块库 |

- 数值改动只碰 .tres，不碰代码——试玩校准期的改数成本要压到最低（30+ 处"试玩定"都落在这层）
- 词缀/强化的 effect 先用"枚举+值"覆盖 MVP 需求，效果复杂化再演进为脚本引用

## 4. 场景流转

```
main.tscn（常驻壳，唯一 main_scene）
 ├─ 局外：开始界面（MVP 极简：一个"出发"按钮）
 └─ 局内循环：
     RunSetup（RunRng 建流、RunState 重置、路线首日生成）
       → 图场景（战斗/精英：模块拼装＋Heat/死线/迷雾/刷怪 | 休整/商店：固定小图）
       → 乘载具离图 → 结算横幅 + 选路界面（RouteUI，游戏树暂停）
       → 下一图 …（循环，天数 -1）
       → 总攻图（天数耗尽或信号弹）→ 胜利结算 / 死亡结算
       → 回开始界面
```

- **main.tscn 作壳，图场景用 `change_scene_to_packed` 级联切换**；选路界面是 CanvasLayer 弹层不是独立场景（它需要读 RunState 且是"喘息点"，不值得一次场景切换）
- 跨图状态只经 RunState / 图内状态随场景销毁——这条边界就是设计文档"图内时间与天数解耦"在代码里的形状
- 玩家场景每图重新实例化，属性从 RunState（构筑）+ CharacterData 组装

## 5. 输入映射（project.godot，本次补齐）

| 动作 | 键盘 | 手柄 | 用途 |
|---|---|---|---|
| move_* | WASD/方向键 | 左摇杆 | 已有 |
| **dodge** | Space | A(0) | 角色技能（翻滚/护盾/诱饵共用一键，压柱 2） |
| **interact** | E | X(2) | 开箱驻留、上载具、休整服务点、信号弹 |
| **pause** | Esc | Start(6) | 暂停菜单 |

- UI 导航沿 Godot 内置 ui_* 动作；手柄 UI 适配归 ui-design 待定 #7

## 6. 调试工具规划（Debug autoload，M0 就位）

试玩校准是所有数值的定案方式，调试面板是校准期的主要生产工具：

- 启动参数 `--seed=N` 指定种子重放（走 RunRng）
- 快捷键（debug build）：给 100 金 / Heat +2 / 跳到死线前 10s / 跳过当天 / 无敌 / 直接进总攻
- 常驻角标（可开关）：FPS、同屏敌人数、当前 Heat、刷入间隔——pressure 校准的读数面板
- 里程碑推进中临时需要的开关一律进 Debug，不散落在业务代码里

## 7. 工程杂项

- `rendering_device/driver.windows="d3d12"` 对 gl_compatibility 无效，本次移除
- godot MCP 已配置未激活（需重启 Claude Code 会话）——激活后用于跑项目抓调试输出
- .tscn 手写时统一 2 空格缩进（.editorconfig 已约定），uid 让编辑器生成，手写场景开编辑器保存一次归一化

## 待定问题

1. 相机 zoom 最终值与 sprite 密度——M0 色块实测定
2. 音频 autoload 与 BGM 分层（Heat 联动❓pressure 遗留）——素材替换期
3. UpgradeData effect 枚举 → 脚本化的演进时机——紫卡"规则改写"实装时
4. 开始界面正式版（选角/元进度入口）——局外 UI 期
