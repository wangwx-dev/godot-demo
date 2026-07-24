[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$GodotPath = 'D:\personal\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe',

    [Parameter()]
    [ValidateRange(1, 1000000)]
    [int]$RouteRuns = 1000,

    [Parameter()]
    [ValidateRange(1, 1000000)]
    [int]$SmokeFrames = 600
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$totalStages = 6
$fixedSeed = 424242
$fixedFps = 60

function Format-CommandArgument {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    if ($Value -match '[\s"]') {
        return '"{0}"' -f $Value.Replace('"', '\"')
    }
    return $Value
}

function Invoke-GodotStage {
    param(
        [Parameter(Mandatory)]
        [int]$Number,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    Write-Host ''
    Write-Host ('[{0}/{1}] {2}' -f $Number, $totalStages, $Name) -ForegroundColor Cyan
    $displayArguments = ($Arguments | ForEach-Object { Format-CommandArgument -Value $_ }) -join ' '
    Write-Host ('> "{0}" {1}' -f $script:resolvedGodotPath, $displayArguments) -ForegroundColor DarkGray

    & $script:resolvedGodotPath @Arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw ('Stage {0}/{1} failed: {2} (exit code {3}).' -f $Number, $totalStages, $Name, $exitCode)
    }

    Write-Host ('PASS: {0}' -f $Name) -ForegroundColor Green
}

try {
    $projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
    $projectFile = Join-Path $projectRoot 'project.godot'
    if (-not (Test-Path -LiteralPath $projectFile -PathType Leaf)) {
        throw "Project file not found: $projectFile"
    }

    $script:resolvedGodotPath = (Resolve-Path -LiteralPath $GodotPath -ErrorAction Stop).Path
    if (-not (Test-Path -LiteralPath $script:resolvedGodotPath -PathType Leaf)) {
        throw "Godot executable not found: $GodotPath"
    }

    Write-Host 'godot-demo verification' -ForegroundColor White
    Write-Host ("Project: {0}" -f $projectRoot)
    Write-Host ("Godot:  {0}" -f $script:resolvedGodotPath)
    Write-Host ("Route runs: {0}; smoke: seed {1}, {2} FPS, {3} frames" -f $RouteRuns, $fixedSeed, $fixedFps, $SmokeFrames)

    Invoke-GodotStage -Number 1 -Name 'Godot version' -Arguments @(
        '--version'
    )

    Invoke-GodotStage -Number 2 -Name 'Headless editor import and parse' -Arguments @(
        '--headless'
        '--path', $projectRoot
        '--import'
    )

    Invoke-GodotStage -Number 3 -Name 'Route audit' -Arguments @(
        '--headless'
        '--path', $projectRoot
        '--'
        "--route-audit=$RouteRuns"
    )

    Invoke-GodotStage -Number 4 -Name 'Full flow test' -Arguments @(
        '--headless'
        '--path', $projectRoot
        '--'
        '--flow-test'
    )

    Invoke-GodotStage -Number 5 -Name 'UI interaction smoke' -Arguments @(
        '--headless'
        '--path', $projectRoot
        '--'
        '--ui-smoke'
    )

    Invoke-GodotStage -Number 6 -Name 'Fixed-seed fixed-FPS smoke test' -Arguments @(
        '--headless'
        '--path', $projectRoot
        '--fixed-fps', $fixedFps.ToString()
        '--quit-after', $SmokeFrames.ToString()
        '--'
        "--seed=$fixedSeed"
    )

    Write-Host ''
    Write-Host 'All verification stages passed.' -ForegroundColor Green
}
catch {
    [Console]::Error.WriteLine('Verification failed: {0}', $_.Exception.Message)
    exit 1
}

