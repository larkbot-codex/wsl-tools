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

if ($ExpectedVhdSize -notmatch '^(\d+)(B|M|MB|G|GB|T|TB)$') { throw 'Invalid expected VHD size.' }
$sizeValue = [uint64]$Matches[1]
$multiplier = switch ($Matches[2]) {
    'B' { 1 }
    { $_ -in 'M','MB' } { 1MB }
    { $_ -in 'G','GB' } { 1GB }
    { $_ -in 'T','TB' } { 1TB }
}
$maximumBytes = $sizeValue * $multiplier

$failures = [Collections.Generic.List[string]]::new()
function Test-InDistro([string] $Label, [string] $Command) {
    & wsl.exe --distribution $DistributionName -- bash -lc $Command | Out-Host
    if ($LASTEXITCODE -eq 0) { Write-Host "[PASS] $Label" -ForegroundColor Green }
    else { Write-Host "[FAIL] $Label" -ForegroundColor Red; $failures.Add($Label) }
}

$installed = @(& wsl.exe --list --quiet 2>&1 | ForEach-Object { ($_ -replace [char]0, '').Trim() })
if ($installed -notcontains $DistributionName) { throw "Distribution '$DistributionName' is not installed." }

Test-InDistro 'Ubuntu distribution' 'grep -qx ID=ubuntu /etc/os-release'
Test-InDistro 'Ubuntu 26.04 release' 'grep -F VERSION_ID= /etc/os-release | grep -Fq 26.04'
Test-InDistro 'AMD64 architecture' 'test $(uname -m) = x86_64'
Test-InDistro 'WSL 2 kernel' 'grep -qi microsoft /proc/sys/kernel/osrelease'
Test-InDistro 'systemd is PID 1' 'test $(cat /proc/1/comm) = systemd'
Test-InDistro 'systemd user manager works' 'systemctl --user is-active default.target'
Test-InDistro 'Default user' "test `$(id -un) = '$ExpectedUser'"
Test-InDistro 'Passwordless sudo' 'sudo -n true'
foreach ($tool in 'git','gh','git-lfs','gcc','fzf','python3','podman') {
    Test-InDistro "$tool is installed" "command -v $tool >/dev/null"
}
Test-InDistro 'Rootless Podman works' 'podman info >/dev/null'
Test-InDistro 'Projects directory exists' 'test -d "$HOME/projects"'
Test-InDistro 'Configured hostname' "test `$(cat /proc/sys/kernel/hostname) = '$ExpectedHostname'"
Test-InDistro 'Filesystem maximum honors VHD limit' "test `$(df --output=size -B1 / | tail -1) -le $maximumBytes"

if ($failures.Count) { throw "Verification failed: $($failures -join ', ')" }
Write-Host "All checks passed for $DistributionName."
