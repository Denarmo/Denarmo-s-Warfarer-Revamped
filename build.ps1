[CmdletBinding()]
param(
    [string]$Version = "",
    [switch]$NoBump,
    [switch]$SkipGameDeploy
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot

# 1. Read current version from modinfo.ini or WarfarerRevamped.lua
$luaFile = Join-Path $repoRoot "reframework\autorun\WarfarerRevamped.lua"
$modinfoFile = Join-Path $repoRoot "modinfo.ini"

$currentVersion = "1.0.0"
if (Test-Path $luaFile) {
    $luaContent = Get-Content $luaFile -Raw
    if ($luaContent -match 'local MOD,\s*VERSION,\s*CFG_VERSION\s*=\s*"[^"]+",\s*"([^"]+)"') {
        $currentVersion = $matches[1]
    }
}

# 2. Determine target version
if ($Version -ne "") {
    $targetVersion = $Version
} elseif ($NoBump) {
    $targetVersion = $currentVersion
} else {
    # Increment patch version (e.g. 1.0.0 -> 1.0.1)
    if ($currentVersion -match '^(\d+)\.(\d+)\.(\d+)$') {
        $major = [int]$matches[1]
        $minor = [int]$matches[2]
        $patch = [int]$matches[3] + 1
        $targetVersion = "$major.$minor.$patch"
    } else {
        $targetVersion = "1.0.1"
    }
}

Write-Host "Packaging Denarmo's Warfarer Revamped version $targetVersion (previous: $currentVersion)..." -ForegroundColor Cyan

# 3. Update modinfo.ini
$modinfoContent = @"
name=Denarmo's Warfarer Revamped
version=$targetVersion
author=Denarmo
description=Unified Warfarer mod combining radial weapon wheel, dynamic skillsets (6 slots), presets, and Dark Arisen DLC skills.
screenshot=screenshot.png
"@
[System.IO.File]::WriteAllText($modinfoFile, $modinfoContent.Trim() + "`r`n", [System.Text.Encoding]::UTF8)
Write-Host "Updated modinfo.ini with version $targetVersion" -ForegroundColor Green

# 4. Update WarfarerRevamped.lua
if (Test-Path $luaFile) {
    $luaContent = Get-Content $luaFile -Raw
    $newLua = [System.Text.RegularExpressions.Regex]::Replace(
        $luaContent,
        '(local MOD,\s*VERSION,\s*CFG_VERSION\s*=\s*"[^"]+",\s*")[^"]+(")',
        "`${1}$targetVersion`${2}"
    )
    [System.IO.File]::WriteAllText($luaFile, $newLua, [System.Text.Encoding]::UTF8)
    Write-Host "Updated WarfarerRevamped.lua with version $targetVersion" -ForegroundColor Green
}

# 5. Prepare build directory
$buildDir = Join-Path $repoRoot "build"
if (-not (Test-Path $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir -Force | Out-Null
}

$zipName = "Denarmo's Warfarer Revamped v$targetVersion.zip"
$zipPath = Join-Path $buildDir $zipName

if (Test-Path $zipPath) {
    Remove-Item -Path $zipPath -Force
}

# 6. Package into ZIP with clean relative paths
$stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

try {
    Copy-Item -Path $modinfoFile -Destination $stagingDir
    $screenshot = Join-Path $repoRoot "screenshot.png"
    if (Test-Path $screenshot) {
        Copy-Item -Path $screenshot -Destination $stagingDir
    }
    
    $stagingReframework = Join-Path $stagingDir "reframework"
    Copy-Item -Path (Join-Path $repoRoot "reframework") -Destination $stagingReframework -Recurse

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $zipStream = [System.IO.File]::Open($zipPath, [System.IO.FileMode]::Create)
    $archive = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $allFiles = Get-ChildItem -Path $stagingDir -Recurse -File
        foreach ($file in $allFiles) {
            $relative = $file.FullName.Substring($stagingDir.Length).TrimStart('\', '/')
            $entryName = $relative -replace '\\', '/'
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $entryName, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } finally {
        $archive.Dispose()
        $zipStream.Dispose()
    }
    Write-Host "Created archive: $zipPath" -ForegroundColor Green
} finally {
    if (Test-Path $stagingDir) {
        $resolvedStaging = [System.IO.Path]::GetFullPath($stagingDir)
        $resolvedTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/')
        if ([System.IO.Path]::GetDirectoryName($resolvedStaging) -ne $resolvedTemp) {
            throw "Refusing to remove staging directory outside the temporary directory: $resolvedStaging"
        }
        Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
    }
}

# 7. Also deploy to Fluffy Mod Manager if present
$fluffyDir = "C:\Users\david\Desktop\Fluffy Mod Manager\Games\DragonsDogma2\Mods"
if (Test-Path $fluffyDir) {
    Get-ChildItem -Path $fluffyDir -Filter "Denarmo's Warfarer Revamped*.zip" | Remove-Item -Force
    Copy-Item -Path $zipPath -Destination $fluffyDir -Force
    Write-Host "Deployed to Fluffy Mod Manager: $fluffyDir\$zipName" -ForegroundColor Green
}

# 8. Also deploy to game reframework directory if present
$gameLua = "D:\SteamLibrary\steamapps\common\Dragons Dogma 2\reframework\autorun\WarfarerRevamped.lua"
if (-not $SkipGameDeploy -and (Test-Path (Split-Path $gameLua))) {
    Copy-Item -Path $luaFile -Destination $gameLua -Force
    Write-Host "Deployed updated script to game: $gameLua" -ForegroundColor Green
}

Write-Host "Build complete! Version: $targetVersion" -ForegroundColor Cyan
