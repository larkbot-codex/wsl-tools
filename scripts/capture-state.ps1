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
if (-not (Test-WslDistributionName $DistributionName)) { throw 'Invalid distribution name.' }
# Run the checked-in Bash implementation directly. Passing a script path keeps
# Windows PowerShell 5.1 from flattening a multiline `bash -lc` argument, and
# WSL's --cd option handles Windows checkout paths (including spaces) before
# the remaining command is handed to Linux.
& wsl.exe --distribution $DistributionName --cd $PSScriptRoot -- bash ./capture-state.sh
if ($LASTEXITCODE -ne 0) { throw "Unable to capture state from '$DistributionName'." }
