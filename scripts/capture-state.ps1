[CmdletBinding()]
param([string] $DistributionName)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$config = Import-PowerShellDataFile (Join-Path $repoRoot 'config.psd1')
if (-not $DistributionName) { $DistributionName = $config.DistributionName }
$stateDirectory = Join-Path $repoRoot 'state'
New-Item -ItemType Directory -Force -Path $stateDirectory | Out-Null
$statePath = Join-Path $stateDirectory "$DistributionName.txt"

$command = @'
set -Eeuo pipefail
echo '## OS'
cat /etc/os-release
echo
echo '## Kernel'
uname -a
echo
echo '## Filesystem'
df -hT /
echo
echo '## Installed DEB packages (name and version)'
dpkg-query -W | sort
echo
echo '## Selected tools'
git --version
gh --version | head -1
git-lfs --version
gcc --version | head -1
python3 --version
podman --version
systemctl --version | head -1
'@
$output = & wsl.exe --distribution $DistributionName -- bash -lc $command 2>&1
if ($LASTEXITCODE -ne 0) { throw "Unable to capture state from '$DistributionName'." }
@("# Distribution: $DistributionName", "# Captured: $([DateTime]::UtcNow.ToString('u'))", '') + $output |
    Set-Content -LiteralPath $statePath -Encoding utf8
Write-Host "Wrote exact installation state to $statePath"
