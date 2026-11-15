param(
    [string]$Godot = 'godot',
    [switch]$Offline
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$godotPath = (Get-Command $Godot -ErrorAction Stop).Source
$cache = (New-Item -ItemType Directory -Force (Join-Path $project '.tinttube-tools')).FullName
$stage = (New-Item -ItemType Directory (Join-Path $cache ('android-qa-' + [Guid]::NewGuid()))).FullName
$build = (New-Item -ItemType Directory -Force (Join-Path $project 'build')).FullName

function Get-VerifiedArchive($Name, $Hash) {
    $archive = Join-Path $cache $Name
    if (-not (Test-Path -LiteralPath $archive)) {
        Invoke-WebRequest "https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/$Name" -OutFile $archive
    }
    if ((Get-FileHash -LiteralPath $archive).Hash -ne $Hash) {
        throw "Checksum mismatch for $archive. Delete the cached file and retry."
    }
    return $archive
}

try {
    foreach ($path in @('assets', 'data', 'scenes', 'scripts', 'project.godot', 'export_presets.cfg')) {
        Copy-Item -LiteralPath (Join-Path $project $path) -Destination $stage -Recurse
    }

    if ($Offline) {
        $presets = Join-Path $stage 'export_presets.cfg'
        (Get-Content -LiteralPath $presets) | Where-Object { $_ -notmatch '^gradle_build/(min_sdk|target_sdk)=' } |
            ForEach-Object { $_.Replace('gradle_build/use_gradle_build=true', 'gradle_build/use_gradle_build=false') } |
            Set-Content -LiteralPath $presets -Encoding utf8
    } else {
        $addonZip = Get-VerifiedArchive 'poing-godot-admob-v5.1.0.zip' '8c53ff52719edf6a81cc7d32a9cdaad2d9e11693c85faca25008a1c19355726f'
        $nativeZip = Get-VerifiedArchive 'android-template-v4.7.2.zip' 'f7fdf644d50c0e231d8f02ae044057e489d0bcafcf50e908a4858477e7ee05ee'
        $unpacked = Join-Path $stage '.sdk'
        Expand-Archive -LiteralPath $addonZip -DestinationPath $unpacked
        Copy-Item -LiteralPath (Join-Path $unpacked 'poing-godot-admob/addons') -Destination $stage -Recurse
        Expand-Archive -LiteralPath $nativeZip -DestinationPath (Join-Path $unpacked 'android')
        $bin = (New-Item -ItemType Directory -Force (Join-Path $stage 'addons/admob/android/bin')).FullName
        Copy-Item -LiteralPath (Join-Path $unpacked 'android/ads') -Destination $bin -Recurse
        Add-Content -LiteralPath (Join-Path $stage 'project.godot') -Encoding utf8 -Value @'

[editor_plugins]

enabled=PackedStringArray("res://addons/admob/plugin.cfg")
'@
    }

    & $godotPath --headless --path $stage --editor --import
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
    $apk = Join-Path $build $(if ($Offline) { 'tinttube-offline-qa.apk' } else { 'tinttube-admob-qa.apk' })
    $exportArgs = @('--headless', '--path', $stage, '--export-debug', 'Android QA', $apk)
    if (-not $Offline) { $exportArgs += '--install-android-build-template' }
    & $godotPath @exportArgs
    if ($LASTEXITCODE -ne 0) { throw 'Godot Android export failed.' }
    Write-Output $apk
} catch {
    Write-Warning "Build files are available for inspection at $stage"
    throw
}

$resolvedStage = (Resolve-Path -LiteralPath $stage).Path
if ($resolvedStage.StartsWith($cache + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $resolvedStage -Recurse -Force
}
