# 素材署名与许可证（游戏 credits 页依据）

> 素材库原始包与完整许可证说明在 `D:\personal\game-assets\`（README.md 登记表）。
> 本文件是"游戏内 credits 需要写什么"的收口清单。

## 必须署名（许可证要求）

| 作者 | 素材 | 许可证 | 署名格式 |
|---|---|---|---|
| Little Robot Sound Factory | 恐怖氛围音效 | CC-BY 3.0 | "Horror Sound Effects Library by Little Robot Sound Factory"（⚠️ 只署名，**不放链接**——作者原网址已被恶意方接管） |
| Kyrise | RPG 图标 | CC-BY 4.0 | "Icons by Kyrise (kyrise.itch.io)" |
| LuQui | 热气球（占位） | CC-BY 4.0 | "Hot air balloon art by LuQui"（若最终未使用可移除） |

## 建议署名（作者请求，非强制）

| 作者 | 素材 |
|---|---|
| Ittai Manero | Zombie Apocalypse Tileset（主美术：角色/丧尸/场景/道具） |
| cuddle bug | Apocalypse Character Pack（玩家/丧尸主美术 + NPC） |

## 无需署名（CC0/OFL，列出以致谢）

Kenney（UI/音效）、Stealthix（火焰）、Nikoichu（图标）、unbreaded（血条）、
artisticdude/rubberduck/qubodup/josepharaoh99/MintoDog/Juhani Junkala/Ville Nousiainen/Daniel Simion（音频）、
TakWolf 等（缝合像素字体，SIL OFL 1.1——随游戏分发时保留 assets/fonts/fusion_pixel_OFL.txt）

## 再分发限制（仓库公开前必读）

以下素材**不可再分发**，当前仓库为本地私有可以入库；若将仓库开源/公开，需先移除或改用替代品：

- `assets/sprites/{characters,enemies,weapons,pickups,environment}/` 中源自 Zombie Apocalypse Tileset（Ittai Manero）的全部派生文件
- cuddle bug 角色包派生文件（玩家/丧尸动画帧、子弹/箭矢，2026-07-24 起为主角色美术）

恢复方式：素材库 `D:\personal\game-assets\` + `tools\import_environment_assets.ps1` / `tools\import_entity_assets.ps1` 重新产出。

## cuddlebug 角色（2026-07-24 美术翻修，玩家/丧尸转正）

- **来源**：[Apocalypse Character Pack](https://cuddle-bug.itch.io/apocalypse) by **cuddle bug**（免费角色包）
- **授权**：可商用可修改；**禁止再分发/转售素材包本身（修改后亦然）**；署名非必需但受欢迎
- **派生产物**（`tools/import_cuddlebug.py` 切帧+行序重排+2× 最近邻放大）：
  - `characters/cb_player_*.png`：幸存者 idle/walk/shoot（持枪）/stab（近战）/crossbow/death，四方向
  - `enemies/cb_zombie_*.png`：丧尸 idle/walk/attack/death，四方向（三型靠缩放+色相染色区分）
  - `weapons/cb_bullet.png` `weapons/cb_arrow.png`：配套弹丸/箭矢
- **合规**：仓库只含上述**加工后的衍生文件**，原始素材包留在项目外的素材库（game-assets），不入 git
- 取代 2026-07-18 的 LPC 幸存者/丧尸（旧帧图保留备用，未删）

## LPC 角色（2026-07-18 角色素材升级）

- **幸存者角色**（`characters/lpc_survivor_walk.png`，tools/build_lpc_characters.py 合成）：
  图层来自 [Universal LPC Spritesheet Character Generator](https://github.com/liberatedpixelcup/Universal-LPC-Spritesheet-Character-Generator)
  （body/head: Stephen Challener (Redshrike)、bluecarrot16、Benjamin K. Smith (BenCreating)、Evert、Eliza Wyatt (ElizaWy)、MadMarcel、TheraHedwig、Matthew Krohn (makrohn)、Johannes Sjölund (wulax)、Stafford McIntyre、Nila122 等；
  longsleeve/pants/shoes: bluecarrot16、David Conway Jr. (JaidynReiman)、ElizaWy、Pierre Vigier (pvigier)、Michael Whitlock (bigbeargames)、Mark Weyer、Thane Brimhall (pennomi)、laetissima 等；
  hair (messy1): JaidynReiman 等）。许可证：CC-BY-SA 3.0 / GPL 3.0。
  完整逐部件署名以仓库 CREDITS.csv 为准。
- **丧尸**（`enemies/lpc_zombie_walk.png`，取自完整表 walk 行）：
  ["[LPC] Zombie"](https://opengameart.org/content/lpc-zombie) by Benjamin K. Smith (BenCreating), commissioned by castelonia，
  基于 Stephen Challener (Redshrike) 的 LPC 男性基础。许可证：CC-BY-SA 3.0 / GPL 3.0。

> 注意：CC-BY-SA 素材要求署名与相同方式共享（对美术资产层面）。发布时本 CREDITS 须随游戏附带。

## 音乐（2026-07-18 F1 正式 BGM）

- "Darkest Child"（战斗图）、"Ossuary 5 - Rest"（休整/商店图）、"Five Armies"（总攻图）
  Kevin MacLeod (incompetech.com)
  Licensed under Creative Commons: By Attribution 4.0
  https://creativecommons.org/licenses/by/4.0/
