# godot-demo

基于 Godot 4.7（标准版，GDScript）的 2D 小游戏项目。

## 技术约定

- **引擎**: Godot 4.7 stable（编辑器位于 `D:\personal\Godot_v4.7-stable_win64.exe\`）
- **语言**: GDScript（标准版引擎，不支持 C#）
- **渲染**: GL Compatibility（2D 游戏足够，且兼容性最好）
- **缩进**: GDScript 用 Tab（官方规范）；.tscn/.tres/.cfg 用 2 空格

## 目录结构

```
godot-demo/
├── autoloads/        # 全局单例脚本（游戏状态、事件总线、音频管理等）
├── scenes/
│   ├── levels/       # 关卡场景
│   ├── entities/     # 游戏实体（玩家、敌人、道具等，场景+同名脚本放一起）
│   └── ui/           # UI 场景（主菜单、HUD、暂停菜单等）
├── scripts/          # 不绑定场景的纯逻辑脚本（工具类、基类等）
├── resources/        # 自定义 Resource（.tres 数据文件、Resource 类定义）
├── assets/
│   ├── sprites/      # 图片素材
│   ├── audio/
│   │   ├── music/    # 背景音乐
│   │   └── sfx/      # 音效
│   └── fonts/        # 字体
└── addons/           # 第三方插件
```

组织原则：**场景和它的专属脚本放在同一目录**（如 `scenes/entities/player/player.tscn` + `player.gd`），素材按类型放 `assets/`。

## 命名规范（遵循 Godot 官方风格）

| 对象 | 风格 | 示例 |
|---|---|---|
| 文件/目录 | snake_case | `player_controller.gd`, `main_menu.tscn` |
| 类名 (class_name) | PascalCase | `PlayerController` |
| 节点名 | PascalCase | `Player`, `HealthBar` |
| 变量/函数 | snake_case | `move_speed`, `take_damage()` |
| 常量 | CONSTANT_CASE | `MAX_SPEED` |
| 信号 | snake_case 过去式 | `health_changed`, `died` |
| 私有成员 | 下划线前缀 | `_internal_state` |

## GDScript 约定

- 尽量使用静态类型：`var speed: float = 200.0`、`func heal(amount: int) -> void:`
- 节点引用用 `@onready var sprite: Sprite2D = $Sprite2D`
- 场景间通信优先用信号（signal up, call down），避免硬编码节点路径穿透场景边界
- 可复用的全局逻辑放 autoload，在 Project Settings → Globals 注册

## 常用命令

```powershell
# 打开编辑器
& "D:\personal\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" -e --path D:\personal\godot-demo

# 直接运行游戏（命令行版，能看到日志输出）
& "D:\personal\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --path D:\personal\godot-demo

# 无头模式检查脚本错误
& "D:\personal\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path D:\personal\godot-demo --check-only --script <脚本路径>
```

## 可用工具

- **godot MCP**（`.mcp.json`，@coding-solo/godot-mcp）：可启动编辑器、运行项目、抓取调试输出，GODOT_PATH 已指向 4.7 命令行版
- **context7 MCP**：Godot 4.7 官方文档查询，库 ID `/websites/godotengine_en_4_7`，写 GDScript 前先查 API 避免 3.x/4.x 混淆

## 参考

- **核心玩法设计见 `docs/game-design.md`**——做功能前先对照设计支柱和 MVP 范围；子系统设计（武器等）在 docs/ 下各自成文

- 官方示例项目在 `D:\personal\godot-demo-projects\`（2d/ 目录下有平台跳跃、俯视角等完整示例）
