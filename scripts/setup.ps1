[CmdletBinding()]
param(
    [string] $DistributionName,
    [string] $UserName,
    [string] $Hostname,
    [string] $VhdSize,
    [string] $ConfigPath,
    [string] $ImagePath,
    [string] $CacheDirectory = (Join-Path $env:LOCALAPPDATA 'wsl-images'),
    [switch] $NonInteractive,
    [switch] $Resume,
    [switch] $VerifyOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $PSScriptRoot 'WslTools.psm1') -Force
if (-not $ConfigPath) { $ConfigPath = Join-Path $repoRoot 'config.psd1' }
$resolvedConfigPath = (Resolve-Path -LiteralPath $ConfigPath).Path
$config = Import-PowerShellDataFile $resolvedConfigPath

function Invoke-Wsl {
    param([Parameter(Mandatory)][string[]] $Arguments)
    & wsl.exe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "wsl.exe failed with exit code ${LASTEXITCODE}: $($Arguments -join ' ')"
    }
}

function Get-InstalledDistribution {
    $lines = @(& wsl.exe --list --quiet 2>&1)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to enumerate WSL distributions.' }
    @($lines | ForEach-Object { ($_ -replace [char]0, '').Trim() } | Where-Object { $_ })
}

function Read-Setting {
    param(
        [Parameter(Mandatory)][string] $Label,
        [Parameter(Mandatory)][string] $DefaultValue
    )
    $answer = Read-Host "$Label [$DefaultValue]"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $DefaultValue }
    return $answer.Trim()
}

if ($Resume -and $VerifyOnly) { throw '-Resume and -VerifyOnly cannot be used together.' }

if (-not $DistributionName) { $DistributionName = $config.DistributionName }
if (-not $UserName) { $UserName = $config.DefaultUser }
if (-not $Hostname) { $Hostname = $config.Hostname }
if (-not $VhdSize) { $VhdSize = $config.VhdSize }

if (-not $NonInteractive -and -not $Resume -and -not $VerifyOnly) {
    if (-not $PSBoundParameters.ContainsKey('DistributionName')) {
        $DistributionName = Read-Setting -Label 'WSL distribution name' -DefaultValue $DistributionName
    }
    if (-not $PSBoundParameters.ContainsKey('UserName')) {
        $UserName = Read-Setting -Label 'Linux username' -DefaultValue $UserName
    }
    if (-not $PSBoundParameters.ContainsKey('Hostname')) {
        $Hostname = Read-Setting -Label 'Linux hostname' -DefaultValue $Hostname
    }
    if (-not $PSBoundParameters.ContainsKey('VhdSize')) {
        $VhdSize = Read-Setting -Label 'Maximum VHD size' -DefaultValue $VhdSize
    }
}

if (-not (Test-WslDistributionName $DistributionName)) { throw "Invalid WSL distribution name '$DistributionName'." }
if (-not (Test-LinuxUserName $UserName)) { throw "Invalid Linux username '$UserName'." }
if (-not (Test-WslHostName $Hostname)) { throw "Invalid hostname '$Hostname'." }
if (-not (Test-WslVhdSize $VhdSize)) { throw "Invalid VHD size '$VhdSize'." }

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { throw 'WSL is not installed.' }
$versionText = ((& wsl.exe --version 2>&1 | Out-String) -replace [char]0, '')
if ($LASTEXITCODE -ne 0 -or $versionText -notmatch 'WSL version:\s*(\d+)\.(\d+)\.(\d+)') {
    throw 'A recent Store version of WSL is required. Run: wsl --update'
}
$wslVersion = [version]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
if ($wslVersion -lt [version]$config.MinimumWsl) {
    throw "WSL $($config.MinimumWsl) or newer is required; found $wslVersion."
}
$wslHelp = ((& wsl.exe --help | Out-String) -replace [char]0, '')
if ($wslHelp -notmatch '--vhd-size') {
    throw 'This WSL version does not support installation-time VHD sizing. Run: wsl --update'
}

$installed = @(Get-InstalledDistribution)
$exists = $installed -contains $DistributionName
if ($exists -and -not $Resume) {
    if (-not $VerifyOnly) { throw "Distribution '$DistributionName' already exists; refusing to overwrite it." }
}
if ($Resume -and -not $exists) { throw "Distribution '$DistributionName' is not installed; there is nothing to resume." }
if ($VerifyOnly -and -not $exists) { throw "Distribution '$DistributionName' is not installed." }
if ($VerifyOnly) {
    & (Join-Path $PSScriptRoot 'verify.ps1') -DistributionName $DistributionName -ExpectedUser $UserName -ExpectedHostname $Hostname -ExpectedVhdSize $VhdSize
    exit 0
}

if (-not $NonInteractive) {
    Write-Host ''
    Write-Host 'Installation plan:' -ForegroundColor Cyan
    Write-Host "  Distribution : $DistributionName"
    Write-Host '  Image        : Ubuntu 26.04 LTS AMD64'
    Write-Host "  Linux user   : $UserName (locked password, passwordless sudo)"
    Write-Host "  Hostname     : $Hostname"
    Write-Host "  VHD maximum  : $VhdSize"
    $confirmation = Read-Host 'Continue? [y/N]'
    if ($confirmation -notmatch '^(y|yes)$') {
        Write-Host 'Cancelled. No changes were made.'
        exit 0
    }
}

if (-not $exists) {
    $architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    if ($architecture -ne 'X64') { throw "Ubuntu 26.04 AMD64 requires an X64 Windows host; found '$architecture'." }
    $image = $config.Images.AMD64
    if ($ImagePath) {
        $resolvedImage = (Resolve-Path -LiteralPath $ImagePath).Path
    } else {
        New-Item -ItemType Directory -Force -Path $CacheDirectory | Out-Null
        $resolvedImage = Join-Path $CacheDirectory $image.FileName
        if (Test-Path -LiteralPath $resolvedImage) {
            $cachedHash = (Get-FileHash -LiteralPath $resolvedImage -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($cachedHash -ne $image.Sha256) {
                Write-Warning 'Removing an incomplete or invalid cached image.'
                Remove-Item -LiteralPath $resolvedImage -Force
            }
        }
        if (-not (Test-Path -LiteralPath $resolvedImage)) {
            $partial = "$resolvedImage.part"
            Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
            Write-Host "Downloading the pinned Ubuntu $($config.UbuntuRelease) WSL image..."
            try {
                Invoke-WebRequest -UseBasicParsing -Uri $image.Url -OutFile $partial
                $partialHash = (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($partialHash -ne $image.Sha256) { throw 'Downloaded image checksum mismatch.' }
                Move-Item -LiteralPath $partial -Destination $resolvedImage
            } catch {
                Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
                throw
            }
        }
    }

    $actualHash = (Get-FileHash -LiteralPath $resolvedImage -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $image.Sha256) { throw 'Ubuntu image checksum mismatch.' }
    Write-Host "Installing '$DistributionName' with a $VhdSize maximum VHD..."
    $installArguments = Get-WslInstallArguments -ImagePath $resolvedImage -DistributionName $DistributionName -VhdSize $VhdSize
    Invoke-Wsl -Arguments $installArguments
}

$packages = Get-Content (Join-Path $repoRoot 'packages.txt') |
    ForEach-Object { ($_ -replace '#.*$', '').Trim() } | Where-Object { $_ }
foreach ($package in $packages) {
    if ($package -notmatch '^[A-Za-z0-9._+:-]+$') { throw "Invalid package name '$package'." }
}
$provision = ((Get-Content -Raw (Join-Path $PSScriptRoot 'provision.sh')) -replace "`r`n", "`n")
$base64 = [Convert]::ToBase64String([Text.UTF8Encoding]::new($false).GetBytes($provision))
$quotedPackages = @($packages | ForEach-Object { "'$_'" }) -join ' '
$command = "printf '%s' '$base64' | base64 --decode | bash -s -- '$UserName' '$Hostname' $quotedPackages"

Write-Host "Provisioning '$UserName' and $($packages.Count) baseline packages..."
Invoke-Wsl -Arguments @('--distribution', $DistributionName, '--user', 'root', '--', 'bash', '-lc', $command)
Invoke-Wsl -Arguments @('--terminate', $DistributionName)

& (Join-Path $PSScriptRoot 'verify.ps1') -DistributionName $DistributionName -ExpectedUser $UserName -ExpectedHostname $Hostname -ExpectedVhdSize $VhdSize
& (Join-Path $PSScriptRoot 'capture-state.ps1') -DistributionName $DistributionName
Write-Host "Ubuntu is ready. Start it with: wsl ~ -d $DistributionName"
