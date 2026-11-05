$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    node CI/validate.cjs
    if ($LASTEXITCODE -ne 0) { throw 'Static validation failed' }
} finally { Pop-Location }
