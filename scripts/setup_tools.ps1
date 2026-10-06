$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot

# All installed tools and downloads stay inside this checkout.
if (-not (Test-Path -LiteralPath '.venv\Scripts\python.exe')) {
    py -3 -m venv .venv
    if ($LASTEXITCODE -ne 0) { throw 'Python 3 is required to create .venv.' }
}
& '.\.venv\Scripts\python.exe' -m pip install --disable-pip-version-check --no-cache-dir -r requirements-dev.txt
if ($LASTEXITCODE -ne 0) { throw 'Development tooling installation failed.' }

$engineDirectory = Join-Path $projectRoot '.tools\godot'
$engineVersion = '4.7.2'
$archiveName = "Godot_v$engineVersion-stable_win64.exe.zip"
$downloadBase = "https://github.com/godotengine/godot-builds/releases/download/$engineVersion-stable"
New-Item -ItemType Directory -Force -Path $engineDirectory | Out-Null
$archivePath = Join-Path $engineDirectory $archiveName
$hashPath = Join-Path $engineDirectory 'SHA512-SUMS.txt'
Invoke-WebRequest -Uri "$downloadBase/SHA512-SUMS.txt" -OutFile $hashPath
if (-not (Test-Path -LiteralPath $archivePath)) {
    Invoke-WebRequest -Uri "$downloadBase/$archiveName" -OutFile $archivePath
}
$hashLine = Get-Content -LiteralPath $hashPath | Where-Object { $_.EndsWith($archiveName) }
if (@($hashLine).Count -ne 1) { throw 'Official archive checksum was not found.' }
$expectedHash = ($hashLine -split '\s+')[0]
$actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA512).Hash
if ($actualHash -ne $expectedHash) { throw 'Godot checksum mismatch; archive was not extracted.' }
Expand-Archive -LiteralPath $archivePath -DestinationPath $engineDirectory -Force
Write-Output "Installed verified Godot $engineVersion in $engineDirectory"
