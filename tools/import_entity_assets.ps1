# 素材导入：实体/特效/拾取物精灵，从 game-assets 素材库产出到项目 assets/sprites/。
# 与 import_environment_assets.ps1 同管线：全部像素来自素材库原图，仅做 2x 最近邻放大（16px 密度 -> 32px 基准），不修改内容。
# 帧号映射依据 tools/contact_sheets/sheet_player|zombies|player_attack|effects|pickups.png 人工认图（2026-07-17）。
Add-Type -AssemblyName System.Drawing

$zatRoot = "D:\personal\game-assets\sprites\zombie_apocalypse_tileset\Zombie Apocalypse Tileset\Organized separated sprites"
$fireSrc = "D:\personal\game-assets\sprites\stealthix_animated_fires\Small_Fireball_10x26.png"
$medSrc = "D:\personal\game-assets\sprites\oga_medicine_pack\medicine_pack.png"
$outRoot = "D:\personal\godot-demo\assets\sprites"

$all = @{}
Get-ChildItem $zatRoot -Recurse -File -Filter *.png | ForEach-Object {
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

function Export-Ids($ids, $prefix, $subDir) {
    $dir = "$outRoot\$subDir"
    New-Item -ItemType Directory -Force $dir | Out-Null
    for ($i = 0; $i -lt $ids.Count; $i++) {
        $id = $ids[$i]
        if (-not $all.ContainsKey($id)) { Write-Output "MISS $prefix id=$id"; continue }
        $img = [System.Drawing.Image]::FromFile($all[$id])
        $up = Scale2x $img; $img.Dispose()
        $name = if ($ids.Count -gt 1) { '{0}_{1:d2}.png' -f $prefix, $i } else { "$prefix.png" }
        $up.Save("$dir\$name"); $up.Dispose()
    }
    Write-Output "$subDir/$prefix : $($ids.Count) frames"
}

# ---------- 1. 角色（三朝向：0..3 正面走 / 4..5 侧面走 / 6..8 背面走）----------
Export-Ids @('0476','0477','0478','0479','0480','0481','0482','0483','0484') 'player_walk' 'characters'
# 三色变体（红=重伤肤/黑=剪影/粉=闪白），每 3 张一组对应 正/侧/背
Export-Ids @('0485','0486','0487','0488','0489','0490','0491','0492','0493') 'player_variant' 'characters'

# ---------- 2. 敌人（同三朝向布局）----------
Export-Ids @('0394','0395','0396','0397','0398','0399','0400','0401','0402') 'skinny_walk' 'enemies'
Export-Ids @('0430','0431','0432','0433','0434','0435','0436','0437','0438') 'kid_walk' 'enemies'
Export-Ids @('0412','0413','0414','0415','0416','0417','0418','0419','0420') 'big_walk' 'enemies'
Export-Ids @('0392','0393') 'sitting_zombie' 'enemies'
Export-Ids @('0379','0380','0381','0382','0383') 'blood_splat' 'enemies'

# ---------- 3. 武器与特效 ----------
Export-Ids @('0370') 'muzzle_flash' 'weapons'
Export-Ids @('0371','0372') 'bullet_tracer' 'weapons'
Export-Ids @('0373','0374') 'bullet_spark' 'weapons'
Export-Ids @('0375','0376','0377','0378') 'slash' 'weapons'
Export-Ids @('0364','0365','0366','0367','0368','0369') 'shotgun_blast' 'weapons'
Export-Ids @('0358','0359','0360','0361','0362','0363') 'explosion' 'weapons'
Export-Ids @('0321','0322','0323','0324','0325','0326') 'smoke' 'weapons'

# ---------- 4. 拾取物 ----------
Export-Ids @('0284','0285','0286','0287') 'money_spawn' 'pickups'
Export-Ids @('0288') 'itembox' 'pickups'
Export-Ids @('0289') 'itembox_broken' 'pickups'
Export-Ids @('0340') 'medkit' 'pickups'
Export-Ids @('0341') 'bottle' 'pickups'
Export-Ids @('0342') 'bandage_roll' 'pickups'
Export-Ids @('0337') 'icon_knife' 'pickups'
Export-Ids @('0334') 'icon_pistol' 'pickups'
Export-Ids @('0331') 'icon_shotgun' 'pickups'
Export-Ids @('0327') 'gas_can' 'pickups'
Export-Ids @('0343','0344') 'ammo' 'pickups'
Export-Ids @('0355','0356') 'radio' 'pickups'

# ---------- 5. Stealthix 小火苗切帧（帧 10x26，切格后丢弃全透明帧）----------
$fireDir = "$outRoot\weapons"
$sheet = [System.Drawing.Bitmap]::new($fireSrc)
$fw = 10; $fh = 26
$cols = [Math]::Floor($sheet.Width / $fw); $rows = [Math]::Floor($sheet.Height / $fh)
$fi = 0
for ($r = 0; $r -lt $rows; $r++) {
    for ($c = 0; $c -lt $cols; $c++) {
        $crop = $sheet.Clone([System.Drawing.Rectangle]::new($c * $fw, $r * $fh, $fw, $fh), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $empty = $true
        for ($py = 0; $py -lt $fh -and $empty; $py++) { for ($px = 0; $px -lt $fw; $px++) { if ($crop.GetPixel($px, $py).A -gt 8) { $empty = $false; break } } }
        if (-not $empty) {
            $up = Scale2x $crop
            $up.Save(('{0}\fire_small_r{1}_{2:d2}.png' -f $fireDir, $r, $c)); $up.Dispose()
            $fi++
        }
        $crop.Dispose()
    }
}
$sheet.Dispose()
Write-Output "weapons/fire_small : $fi frames (rows kept separate, 认图后留一行删其余)"

# ---------- 6. OGA medicine pack 切格（16px 网格，丢弃空格）----------
$medDir = "$outRoot\pickups"
$sheet = [System.Drawing.Bitmap]::new($medSrc)
$cols = [Math]::Floor($sheet.Width / 16); $rows = [Math]::Floor($sheet.Height / 16)
$mi = 0
for ($r = 0; $r -lt $rows; $r++) {
    for ($c = 0; $c -lt $cols; $c++) {
        $crop = $sheet.Clone([System.Drawing.Rectangle]::new($c * 16, $r * 16, 16, 16), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $empty = $true
        for ($py = 0; $py -lt 16 -and $empty; $py++) { for ($px = 0; $px -lt 16; $px++) { if ($crop.GetPixel($px, $py).A -gt 8) { $empty = $false; break } } }
        if (-not $empty) {
            $up = Scale2x $crop
            $up.Save(('{0}\medicine_{1:d2}.png' -f $medDir, $mi)); $up.Dispose()
            $mi++
        }
        $crop.Dispose()
    }
}
$sheet.Dispose()
Write-Output "pickups/medicine : $mi cells"
Write-Output "DONE"
