[CmdletBinding()]
param(
    [string] $DistributionName,
    [string] $ExpectedUser,
    [string] $ExpectedHostname,
    [string] $ExpectedVhdSize
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$config = Import-PowerShellDataFile (Join-Path $repoRoot 'config.psd1')
if (-not $DistributionName) { $DistributionName = $config.DistributionName }
if (-not $ExpectedUser) { $ExpectedUser = $config.DefaultUser }
if (-not $ExpectedHostname) { $ExpectedHostname = $config.Hostname }
if (-not $ExpectedVhdSize) { $ExpectedVhdSize = $config.VhdSize }
$packages = Get-Content (Join-Path $repoRoot 'packages.txt') |
    ForEach-Object { ($_ -replace '#.*$', '').Trim() } | Where-Object { $_ }
foreach ($package in $packages) {
    if ($package -notmatch '^[A-Za-z0-9._+:-]+$') { throw "Invalid package name '$package'." }
}
& wsl.exe --distribution $DistributionName --user root -- apt-get update
if ($LASTEXITCODE -ne 0) { throw 'apt-get update failed.' }
& wsl.exe --distribution $DistributionName --user root -- env DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends @packages
if ($LASTEXITCODE -ne 0) { throw 'Package installation failed.' }
& (Join-Path $PSScriptRoot 'verify.ps1') -DistributionName $DistributionName -ExpectedUser $ExpectedUser -ExpectedHostname $ExpectedHostname -ExpectedVhdSize $ExpectedVhdSize
& (Join-Path $PSScriptRoot 'capture-state.ps1') -DistributionName $DistributionName
