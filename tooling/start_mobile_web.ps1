param(
    [int]$WebPort = 7357
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$frontendPath = Join-Path $repoRoot 'frontend'

Push-Location $frontendPath
try {
    flutter run `
        -d web-server `
        --web-hostname 127.0.0.1 `
        --web-port $WebPort
}
finally {
    Pop-Location
}
