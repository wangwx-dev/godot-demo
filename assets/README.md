# assets/

正式素材来自素材库 `D:\personal\game-assets\`（许可证登记见其 README.md），经 `tools/` 导入脚本产出：

- `tools/import_environment_assets.ps1` → `sprites/environment/`（地块图集 + props）
- `tools/import_entity_assets.ps1` → `sprites/{characters,enemies,weapons,pickups}/`（角色/敌人/特效/拾取物帧）

约定：

- **全部像素图为 16px 密度 ×2 最近邻放大**（32px 基准，tech-design §1）；项目默认纹理过滤 Nearest
- 帧号映射依据 `tools/contact_sheets/`（认图索引）；改选素材时改脚本重跑，不手工修改产出文件
- 角色/敌人 9 帧布局 = 正面 4 帧（00–03）/ 侧面 2 帧（04–05，flip_h 补左）/ 背面 3 帧（06–08）
- 署名义务与再分发限制见 `assets/CREDITS.md`（**仓库公开前必读**）
