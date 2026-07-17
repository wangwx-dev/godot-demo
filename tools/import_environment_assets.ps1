# 素材导入：从 game-assets 的 Zombie Apocalypse Tileset（Ittai Manero）拷贝原始 sprite 进项目。
# 全部像素来自素材库原图，仅做 2x 最近邻放大（16px -> 32px，匹配 tech-design 32px 基准），不做任何内容修改。
# 产出：
#   assets/sprites/environment/tileset_ground.png   —— 16x16 地块拼成的图集（32px/格）
#   assets/sprites/environment/tileset_ground.json  —— 图集清单（名称/坐标/是否碰撞）
#   assets/sprites/environment/props/*.png          —— 非规则尺寸的成品件（建筑/车/标志等）
Add-Type -AssemblyName System.Drawing

$srcRoot = "D:\personal\game-assets\sprites\zombie_apocalypse_tileset\Zombie Apocalypse Tileset\Organized separated sprites"
$refPng = "D:\personal\game-assets\sprites\zombie_apocalypse_tileset\Zombie Apocalypse Tileset\Zombie Apocalypse Tileset Reference.png"
$envDir = "D:\personal\godot-demo\assets\sprites\environment"
$propDir = "$envDir\props"
New-Item -ItemType Directory -Force $envDir | Out-Null
New-Item -ItemType Directory -Force $propDir | Out-Null

$all = @{}
Get-ChildItem $srcRoot -Recurse -File -Filter *.png | ForEach-Object {
    if ($_.Name -match '_(\d{4})_') { $all[$Matches[1]] = $_.FullName }
}

function Scale2x($img) {
    $bmp = New-Object System.Drawing.Bitmap(($img.Width * 2), ($img.Height * 2))
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
    $g.CompositingMode = 'SourceCopy'
    $g.DrawImage($img, 0, 0, $img.Width * 2, $img.Height * 2)
    $g.Dispose()
    return $bmp
}

# ---------- 1. 图集 tile 清单（必须 16x16）----------
# solid=1 的 tile 会在 TileSet 里挂满格碰撞（层 1）
$tiles = @()
# 地面基底
$tiles += @(@('dirt_a', '0077', 0), @('dirt_b', '0078', 0), @('dirt_twigs_a', '0079', 0), @('dirt_twigs_b', '0080', 0))
# 暗色灌木带白花（点缀）+ 玉米秆墙（视觉密林，可走）
$tiles += @(@('flowers_a', '0117', 0), @('flowers_b', '0217', 0), @('corn_wall', '0064', 0))
# 泥土小径
$tiles += @(@('path_patch', '0065', 0), @('path_cross', '0066', 0), @('path_h', '0067', 0), @('path_v', '0068', 0))
$tiles += @(@('path_bend_a', '0069', 0), @('path_bend_b', '0070', 0), @('path_bend_c', '0071', 0), @('path_bend_d', '0072', 0))
$tiles += @(@('path_bend_e', '0073', 0), @('path_bend_f', '0074', 0), @('path_t_a', '0075', 0), @('path_t_b', '0076', 0))
# 沥青路
$tiles += @(@('road_plain', '0053', 0), @('road_manhole', '0054', 0))
$tiles += @(@('road_edge_v_left', '0029', 0), @('road_edge_v_right', '0039', 0), @('road_dash_v', '0034', 0))
$tiles += @(@('road_edge_h_top', '0044', 0), @('road_line_h_mid', '0045', 0), @('road_edge_h_bottom', '0046', 0))
$tiles += @(@('road_cross_v_a', '0047', 0), @('road_cross_v_b', '0048', 0), @('road_cross_v_c', '0049', 0))
$tiles += @(@('road_cross_h_a', '0050', 0), @('road_cross_h_b', '0051', 0), @('road_cross_h_c', '0052', 0))
# 农田（不同生长期）
$tiles += @(@('crops_tilled', '0109', 0), @('crops_sprout', '0110', 0), @('crops_mid', '0111', 0), @('crops_tall_a', '0112', 0))
# 血迹/尸体（战损点缀）
$tiles += @(@('blood_a', '0384', 0), @('blood_b', '0385', 0), @('blood_c', '0386', 0))
$tiles += @(@('corpse_a', '0290', 0), @('corpse_b', '0293', 0))
# 灌木丛（可走的软遮挡）
$tiles += @(@('bush_a', '0082', 0), @('bush_b', '0084', 0), @('bush_c', '0085', 0), @('bush_d', '0086', 0), @('bush_e', '0088', 0), @('bush_f', '0090', 0))
# 树（占整格的障碍）
$tiles += @(@('tree_bare', '0134', 1), @('tree_stump', '0138', 1), @('tree_blossom', '0142', 1))
$tiles += @(@('tree_shrub_a', '0135', 0), @('tree_shrub_b', '0136', 0))
# 白桩栅栏（花园）
$tiles += @(@('picket_a', '0126', 1), @('picket_b', '0127', 1), @('picket_c', '0128', 1), @('picket_d', '0129', 1))
$tiles += @(@('picket_e', '0130', 1), @('picket_f', '0131', 1), @('picket_g', '0132', 1), @('picket_h', '0133', 1))
# 木板栅栏（谷仓院墙）
$tiles += @(@('board_a', '0194', 1), @('board_b', '0195', 1), @('board_c', '0196', 1), @('board_d', '0197', 1))
$tiles += @(@('board_e', '0198', 1), @('board_f', '0199', 1), @('board_g', '0200', 1), @('board_h', '0201', 1))
# 围栏（农场矮栏）
$tiles += @(@('rail_h_left', '0206', 1), @('rail_h', '0207', 1), @('rail_h_right', '0208', 1))
$tiles += @(@('rail_v_a', '0209', 1), @('rail_v_b', '0210', 1), @('rail_mid_a', '0211', 1), @('rail_mid_b', '0212', 1))
$tiles += @(@('rail_h_plain', '0213', 1), @('rail_mid_c', '0214', 1), @('rail_post_a', '0215', 1), @('rail_post_b', '0216', 1))
# 干草堆（障碍）
$tiles += @(@('straw_big', '0118', 1), @('straw_mid', '0119', 1))

$validTiles = @()
foreach ($t in $tiles) {
    if (-not $all.ContainsKey($t[1])) { Write-Output "MISS tile $($t[0]) id=$($t[1])"; continue }
    $img = [System.Drawing.Image]::FromFile($all[$t[1]])
    # 16x16 以内的居中放进 32px 格（窄条栅栏件天然比格子细）；超出的转 props
    if ($img.Width -gt 16 -or $img.Height -gt 16) {
        Write-Output "SKIP tile $($t[0]) id=$($t[1]) size=$($img.Width)x$($img.Height) -> props"
        $img.Dispose()
        $img2 = [System.Drawing.Image]::FromFile($all[$t[1]])
        $up = Scale2x $img2; $img2.Dispose()
        $up.Save("$propDir\$($t[0]).png"); $up.Dispose()
        continue
    }
    $img.Dispose()
    $validTiles += , $t
}

$cols = 12
$rows = [Math]::Ceiling($validTiles.Count / $cols)
$atlas = New-Object System.Drawing.Bitmap(($cols * 32), ($rows * 32))
$g = [System.Drawing.Graphics]::FromImage($atlas)
$g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
$g.CompositingMode = 'SourceCopy'
$manifest = @()
for ($i = 0; $i -lt $validTiles.Count; $i++) {
    $t = $validTiles[$i]
    $cx = $i % $cols; $cy = [Math]::Floor($i / $cols)
    $img = [System.Drawing.Image]::FromFile($all[$t[1]])
    # 居中放置（16x16 铺满；窄件居中）
    $dx = $cx * 32 + (32 - $img.Width * 2) / 2
    $dy = $cy * 32 + (32 - $img.Height * 2) / 2
    $g.DrawImage($img, [int]$dx, [int]$dy, $img.Width * 2, $img.Height * 2)
    $img.Dispose()
    $manifest += [ordered]@{ name = $t[0]; src_id = $t[1]; x = $cx; y = $cy; solid = [int]$t[2] }
}
$g.Dispose()
$atlas.Save("$envDir\tileset_ground.png"); $atlas.Dispose()
[ordered]@{ tile_size = 32; columns = $cols; source = "Zombie Apocalypse Tileset (Ittai Manero, itch.io)"; tiles = $manifest } |
    ConvertTo-Json -Depth 4 | Out-File "$envDir\tileset_ground.json" -Encoding utf8
Write-Output "atlas: $($validTiles.Count) tiles, $($cols)x$rows"

# ---------- 2. Props（原尺寸成品件，2x 放大直拷）----------
$props = @(
    @('gas_station', '0225'), @('gas_pump', '0143'), @('gas_sign', '0144'),
    @('wreck_red_h', '0179'), @('wreck_red_h2', '0180'), @('wreck_red_top', '0181'), @('wreck_red_v', '0182'),
    @('wreck_white_h', '0183'), @('wreck_white_h2', '0184'), @('wreck_white_top', '0185'), @('wreck_white_v', '0186'),
    @('wreck_brown_h', '0187'), @('wreck_brown_h2', '0188'), @('wreck_brown_top', '0189'), @('wreck_brown_v', '0190'),
    @('tires_a', '0191'), @('tires_b', '0192'), @('tires_c', '0193'),
    @('mailbox', '0145'), @('traffic_cone', '0150'), @('barrier_striped', '0151'),
    @('sign_warning', '0154'), @('sign_noentry', '0155'), @('sign_50', '0157'), @('sign_nopark', '0158'), @('sign_stop', '0159'),
    @('scarecrow', '0124'), @('tombstone', '0357'), @('windmill', '0218'),
    @('fence_gate', '0202'),
    @('straw_small', '0120'), @('straw_tall', '0121')
)
foreach ($p in $props) {
    if (-not $all.ContainsKey($p[1])) { Write-Output "MISS prop $($p[0]) id=$($p[1])"; continue }
    $img = [System.Drawing.Image]::FromFile($all[$p[1]])
    $up = Scale2x $img
    Write-Output "prop $($p[0]) $($img.Width)x$($img.Height)"
    $img.Dispose()
    $up.Save("$propDir\$($p[0]).png"); $up.Dispose()
}

# ---------- 3. 从官方 Reference 图裁成品建筑（透明底，原像素）----------
# Reference 里的成品按 16px 格 + 1px 透明缝摆放：裁完删掉全透明的行/列即可还原无缝成品。
$ref = [System.Drawing.Bitmap]::new($refPng)
function Crop-Trim-Save($x, $y, $w, $h, $name, $eraseRects) {
    $crop = $ref.Clone([System.Drawing.Rectangle]::new($x, $y, $w, $h), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    # 清掉裁切区内混入的相邻杂物（参考图打包时塞进空角的独立件），坐标为参考图绝对坐标
    if ($null -ne $eraseRects) {
        foreach ($er in $eraseRects) {
            for ($py = $er[1]; $py -lt $er[1] + $er[3]; $py++) {
                for ($px = $er[0]; $px -lt $er[0] + $er[2]; $px++) {
                    $lx = $px - $x; $ly = $py - $y
                    if ($lx -ge 0 -and $ly -ge 0 -and $lx -lt $crop.Width -and $ly -lt $crop.Height) {
                        $crop.SetPixel($lx, $ly, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
                    }
                }
            }
        }
    }
    # 标记非空行/列
    $colHas = New-Object bool[] $crop.Width
    $rowHas = New-Object bool[] $crop.Height
    for ($py = 0; $py -lt $crop.Height; $py++) {
        for ($px = 0; $px -lt $crop.Width; $px++) {
            if ($crop.GetPixel($px, $py).A -gt 8) { $colHas[$px] = $true; $rowHas[$py] = $true }
        }
    }
    $cols = @(); for ($px = 0; $px -lt $crop.Width; $px++) { if ($colHas[$px]) { $cols += $px } }
    $rows = @(); for ($py = 0; $py -lt $crop.Height; $py++) { if ($rowHas[$py]) { $rows += $py } }
    if ($cols.Count -eq 0) { Write-Output "EMPTY crop $name"; $crop.Dispose(); return }
    $packed = New-Object System.Drawing.Bitmap($cols.Count, $rows.Count)
    for ($j = 0; $j -lt $rows.Count; $j++) {
        for ($i = 0; $i -lt $cols.Count; $i++) {
            $packed.SetPixel($i, $j, $crop.GetPixel($cols[$i], $rows[$j]))
        }
    }
    $crop.Dispose()
    $up = Scale2x $packed
    Write-Output "refcrop $name $($packed.Width)x$($packed.Height)"
    $packed.Dispose()
    $up.Save("$propDir\$name.png"); $up.Dispose()
}
Crop-Trim-Save 14 24 106 88 'building_store' $null
Crop-Trim-Save 408 18 84 110 'barn_red' @(@(408, 18, 16, 19), @(476, 18, 16, 17))
Crop-Trim-Save 408 132 84 100 'barn_tan' @(@(408, 132, 16, 18), @(476, 132, 16, 17))
$ref.Dispose()
Write-Output "DONE"
