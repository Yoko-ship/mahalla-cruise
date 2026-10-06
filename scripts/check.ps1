$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path -LiteralPath '.venv\Scripts\python.exe')) {
    throw 'Run .\scripts\setup_tools.ps1 before running checks.'
}
& '.\.venv\Scripts\python.exe' scripts/check.py
exit $LASTEXITCODE
