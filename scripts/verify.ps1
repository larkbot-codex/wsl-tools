[CmdletBinding()]
param(
    [string] $DistributionName,
    [string] $ExpectedUser,
    [Nullable[int]] $ExpectedUserId,
    [string] $ExpectedHostname,
    [string] $ExpectedVhdSize,
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
if (-not $ExpectedUser) { $ExpectedUser = $config.DefaultUser }
if (-not $ExpectedHostname) { $ExpectedHostname = $config.Hostname }
if (-not $ExpectedVhdSize) { $ExpectedVhdSize = $config.VhdSize }
if (-not (Test-WslDistributionName $DistributionName)) { throw 'Invalid distribution name.' }
if (-not (Test-LinuxUserName $ExpectedUser)) { throw 'Invalid expected user.' }
if ($PSBoundParameters.ContainsKey('ExpectedUserId') -and -not (Test-WslUserId $ExpectedUserId)) { throw 'Invalid expected user ID.' }
if (-not (Test-WslHostName $ExpectedHostname)) { throw 'Invalid expected hostname.' }
if (-not (Test-WslVhdSize $ExpectedVhdSize)) { throw 'Invalid expected VHD size.' }

$maximumBytes = ConvertTo-WslByteSize $ExpectedVhdSize
$packages = @(Read-WslPackageList (Join-Path $repoRoot 'packages.txt'))
$quotedPackages = @($packages | ForEach-Object { "'$_'" }) -join ' '

$failures = [Collections.Generic.List[string]]::new()
function Test-InDistro([string] $Label, [string] $Command) {
    & wsl.exe --distribution $DistributionName -- bash -lc $Command | Out-Host
    if ($LASTEXITCODE -eq 0) { Write-Host "[PASS] $Label" -ForegroundColor Green }
    else { Write-Host "[FAIL] $Label" -ForegroundColor Red; $failures.Add($Label) }
}

$installed = @(& wsl.exe --list --quiet 2>&1 | ForEach-Object { ($_ -replace [char] 0, '').Trim() })
if ($LASTEXITCODE -ne 0) { throw 'Unable to enumerate WSL distributions.' }
if ($installed -notcontains $DistributionName) { throw "Distribution '$DistributionName' is not installed." }

Test-InDistro 'Ubuntu distribution' 'grep -qx ID=ubuntu /etc/os-release'
Test-InDistro 'Ubuntu 26.04 release' 'grep -F VERSION_ID= /etc/os-release | grep -Fq 26.04'
Test-InDistro 'AMD64 architecture' 'test $(uname -m) = x86_64'
Test-InDistro 'WSL 2 kernel' 'grep -qi microsoft /proc/sys/kernel/osrelease'
Test-InDistro 'systemd is PID 1' 'test $(cat /proc/1/comm) = systemd'
Test-InDistro 'systemd user manager works' 'systemctl --user is-active --quiet default.target'
Test-InDistro 'Default user' "test `$(id -un) = '$ExpectedUser'"
if ($PSBoundParameters.ContainsKey('ExpectedUserId')) {
    Test-InDistro 'Unique Linux user ID' "test `$(id -u) = '$ExpectedUserId'"
}
Test-InDistro 'Passwordless sudo' 'sudo -n true'
Test-InDistro 'Baseline packages installed' "dpkg-query -W $quotedPackages >/dev/null"
Test-InDistro 'Rootless Podman works' 'podman info >/dev/null'
Test-InDistro 'Projects directory exists' 'test -d "$HOME/projects"'
Test-InDistro 'Configured hostname' "test `$(cat /proc/sys/kernel/hostname) = '$ExpectedHostname'"
Test-InDistro 'Filesystem maximum honors VHD limit' "test `$(df --output=size -B1 / | tail -1) -le $maximumBytes"

if ($failures.Count) { throw "Verification failed: $($failures -join ', ')" }
Write-Host "All checks passed for $DistributionName."
