[CmdletBinding()]
param(
    [string] $DistributionName,
    [string] $ConfigPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $PSScriptRoot 'WslTools.psm1') -Force
if (-not $ConfigPath) { $ConfigPath = Join-Path $repoRoot 'config.psd1' }
$resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$config = Import-PowerShellDataFile $resolvedConfigPath
if (-not (Test-WslConfiguration $config)) { throw "Invalid WSL configuration: $resolvedConfigPath" }
if (-not $DistributionName) { $DistributionName = $config.DistributionName }
if (-not (Test-WslDistributionName $DistributionName)) {
    throw "Invalid WSL distribution name '$DistributionName'."
}

$packages = @(Read-WslPackageList (Join-Path $repoRoot 'packages.txt'))
& wsl.exe --distribution $DistributionName --user root -- apt-get update
if ($LASTEXITCODE -ne 0) { throw 'apt-get update failed.' }
& wsl.exe --distribution $DistributionName --user root -- env DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends @packages
if ($LASTEXITCODE -ne 0) { throw 'Package installation failed.' }
& wsl.exe --distribution $DistributionName --user root -- apt-get clean
if ($LASTEXITCODE -ne 0) { throw 'apt-get clean failed.' }
Write-Host "Package synchronization complete for '$DistributionName'."
