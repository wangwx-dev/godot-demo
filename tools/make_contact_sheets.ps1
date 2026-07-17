# 临时工具：给 zombie tileset 分类生成带编号 contact sheet，供人工/AI 识别每个 sprite 内容。
# 输出到 D:\personal\godot-demo\tools\contact_sheets\
Add-Type -AssemblyName System.Drawing

$srcRoot = "D:\personal\game-assets\sprites\zombie_apocalypse_tileset\Zombie Apocalypse Tileset\Organized separated sprites"
$outDir = "D:\personal\godot-demo\tools\contact_sheets"
New-Item -ItemType Directory -Force $outDir | Out-Null

$scale = 6
$cols = 8
$labelH = 16

function Make-Sheet($categories, $outName) {
    # 收集所有 (label, file)
    $items = @()
    foreach ($cat in $categories) {
        $files = Get-ChildItem "$srcRoot\$cat" -File -Filter *.png | Sort-Object Name
        foreach ($f in $files) {
            # 从文件名提取 NNNN 编号
            $idx = if ($f.Name -match '_(\d{4})_') { $Matches[1] } else { $f.BaseName }
            $items += [PSCustomObject]@{ Label = $idx; File = $f.FullName; Cat = $cat }
        }
    }
    if ($items.Count -eq 0) { return }

    # 求最大 cell 尺寸
    $maxW = 16; $maxH = 16
    foreach ($it in $items) {
        $img = [System.Drawing.Image]::FromFile($it.File)
        if ($img.Width -gt $maxW) { $maxW = $img.Width }
        if ($img.Height -gt $maxH) { $maxH = $img.Height }
        $img.Dispose()
    }
    $cellW = $maxW * $scale + 8
    $cellH = $maxH * $scale + $labelH + 8
    $rows = [Math]::Ceiling($items.Count / $cols)
    $sheetW = $cellW * $cols
    $sheetH = $cellH * $rows

    $sheet = New-Object System.Drawing.Bitmap($sheetW, $sheetH)
    $g = [System.Drawing.Graphics]::FromImage($sheet)
    $g.Clear([System.Drawing.Color]::FromArgb(255, 40, 44, 52))
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $font = New-Object System.Drawing.Font("Consolas", 9)
    $brush = [System.Drawing.Brushes]::Yellow
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 70, 74, 82))

    for ($i = 0; $i -lt $items.Count; $i++) {
        $col = $i % $cols
        $row = [Math]::Floor($i / $cols)
        $x = $col * $cellW
        $y = $row * $cellH
        $g.DrawRectangle($pen, $x, $y, $cellW - 1, $cellH - 1)
        $img = [System.Drawing.Image]::FromFile($items[$i].File)
        $g.DrawImage($img, $x + 4, $y + 4, $img.Width * $scale, $img.Height * $scale)
        $img.Dispose()
        $g.DrawString($items[$i].Label, $font, $brush, $x + 2, $y + $cellH - $labelH - 2)
    }
    $g.Dispose()
    $sheet.Save("$outDir\$outName.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $sheet.Dispose()
    Write-Output "$outName : $($items.Count) sprites"
}

Make-Sheet @('Terrain Variations', 'Grass with Flowers', 'Terrain wall', 'Modular Terrain Path') 'sheet_terrain'
Make-Sheet @('Modular Road') 'sheet_road'
Make-Sheet @('Modular Fences') 'sheet_fences'
Make-Sheet @('Trees', 'Modular Bushes', 'Different Crops Lengths', 'Modular Stacked Straw') 'sheet_vegetation'
Make-Sheet @('Urban Assets', 'Gas Station', 'Zombie Poster', 'Tombstone', 'Scarecrow') 'sheet_props'
Make-Sheet @('Broken Cars and Tires', 'Tractor', 'Drivable Car with 8 Directions') 'sheet_vehicles'
Make-Sheet @('Modular Small Building') 'sheet_building_small'
Make-Sheet @('Modular Big Building') 'sheet_building_big'
Make-Sheet @('Modular Barns') 'sheet_barns'
Make-Sheet @('Random Blood Stains', 'Dead Corpses With Flies Animation Frames', 'Windmill with Fan Animation Frames', '90潞 Rotatable Bridge Sprites', 'Water animation frames') 'sheet_misc'
Make-Sheet @('Player Character Walking Animation Frames', 'Damaged Player Animation Frames') 'sheet_player'
Make-Sheet @('Skinny Walking Zombie Animation', 'Kid Zombie Animation Frames', 'Big Zombie Walking Animation Frames', 'Sitting Zombie') 'sheet_zombies'
Make-Sheet @('Damaged Skinny Zombie Animation Frames', 'Damaged Kid Zombie Animation Frames', 'Damaged Big Zombie Animation Frames') 'sheet_zombies_damaged'
Make-Sheet @('Pistol Shooting Animation Frames', 'Knife Attack Animation Frames', 'Shotgun Shooting Animation Frames') 'sheet_player_attack'
Make-Sheet @('Explosion Animation Frames', 'Smoke Animation Frames', 'Blood Animation Frames', 'Exploding Barrel Animation Frames') 'sheet_effects'
Make-Sheet @('Pickable Items and Weapons', 'Spawning Money Animation Frames', 'Spawning Item Box Animation Frames + Broken Box Pieces') 'sheet_pickups'
Make-Sheet @('Inventory interface', 'UI Elements') 'sheet_ui'
