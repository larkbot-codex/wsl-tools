Set-StrictMode -Version Latest

function Test-WslDistributionName {
    param([AllowEmptyString()][string] $Value)
    return $Value -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'
}

function Test-LinuxUserName {
    param([AllowEmptyString()][string] $Value)
    return $Value -cmatch '^[a-z_][a-z0-9_-]{0,31}$'
}

function Test-WslHostName {
    param([AllowEmptyString()][string] $Value)
    return $Value -match '^[A-Za-z0-9][A-Za-z0-9.-]{0,62}$'
}

function Test-WslVhdSize {
    param([AllowEmptyString()][string] $Value)
    return $Value -match '^\d+(B|M|MB|G|GB|T|TB)$'
}

function ConvertFrom-WslVersionText {
    param([AllowEmptyString()][string] $Value)

    if ($Value -notmatch '^[^\r\n]*?(\d+)\.(\d+)\.(\d+)') {
        return $null
    }

    return [version]::new([int] $Matches[1], [int] $Matches[2], [int] $Matches[3])
}

function Test-WslConfiguration {
    param([Parameter(Mandatory)][hashtable] $Configuration)

    $requiredKeys = @('DistributionName', 'DefaultUser', 'Hostname', 'VhdSize', 'MinimumWsl', 'Images')
    foreach ($key in $requiredKeys) {
        if (-not $Configuration.ContainsKey($key)) { return $false }
    }

    if (-not (Test-WslDistributionName $Configuration.DistributionName)) { return $false }
    if (-not (Test-LinuxUserName $Configuration.DefaultUser)) { return $false }
    if (-not (Test-WslHostName $Configuration.Hostname)) { return $false }
    if (-not (Test-WslVhdSize $Configuration.VhdSize)) { return $false }

    $minimumVersion = $null
    if (-not [version]::TryParse([string] $Configuration.MinimumWsl, [ref] $minimumVersion)) { return $false }

    if (-not $Configuration.Images.ContainsKey('AMD64')) { return $false }
    $image = $Configuration.Images.AMD64
    if (-not $image) { return $false }
    foreach ($key in @('FileName', 'Url', 'Sha256')) {
        if (-not $image.ContainsKey($key)) { return $false }
    }
    if ($image.FileName -notmatch '^ubuntu-[0-9.]+-wsl-amd64\.wsl$') { return $false }
    if ($image.Sha256 -notmatch '^[a-f0-9]{64}$') { return $false }

    $imageUri = $null
    if (-not [uri]::TryCreate([string] $image.Url, [UriKind]::Absolute, [ref] $imageUri)) { return $false }
    if ($imageUri.Scheme -ne 'https') { return $false }

    return $true
}

function Get-WslInstallArguments {
    param(
        [Parameter(Mandatory)][string] $ImagePath,
        [Parameter(Mandatory)][string] $DistributionName,
        [Parameter(Mandatory)][string] $VhdSize
    )

    return @(
        '--install', '--from-file', $ImagePath,
        '--name', $DistributionName,
        '--vhd-size', $VhdSize,
        '--no-launch'
    )
}

function Test-WslInstallHelp {
    param([AllowEmptyString()][string] $Value)

    foreach ($option in @('--from-file', '--name', '--no-launch', '--vhd-size')) {
        if (-not $Value.Contains($option)) { return $false }
    }
    return $true
}

function Read-WslPackageList {
    param([Parameter(Mandatory)][string] $Path)

    $packages = @(Get-Content -LiteralPath $Path |
        ForEach-Object { ($_ -replace '#.*$', '').Trim() } |
        Where-Object { $_ })
    if (-not $packages.Count) { throw "$Path contains no packages." }
    foreach ($package in $packages) {
        if ($package -notmatch '^[A-Za-z0-9][A-Za-z0-9._+:-]*$') {
            throw "Invalid package name '$package'."
        }
    }
    return $packages
}

function ConvertTo-WslByteSize {
    param([Parameter(Mandatory)][string] $Value)

    if (-not (Test-WslVhdSize $Value)) { throw "Invalid WSL size '$Value'." }
    $Value -match '^(\d+)(B|M|MB|G|GB|T|TB)$' | Out-Null
    $sizeValue = [uint64] $Matches[1]
    $multiplier = switch ($Matches[2]) {
        'B' { [uint64] 1 }
        { $_ -in 'M', 'MB' } { [uint64] 1MB }
        { $_ -in 'G', 'GB' } { [uint64] 1GB }
        { $_ -in 'T', 'TB' } { [uint64] 1TB }
    }
    return $sizeValue * $multiplier
}

Export-ModuleMember -Function @(
    'Test-WslDistributionName',
    'Test-LinuxUserName',
    'Test-WslHostName',
    'Test-WslVhdSize',
    'ConvertFrom-WslVersionText',
    'Test-WslConfiguration',
    'Get-WslInstallArguments',
    'Test-WslInstallHelp',
    'Read-WslPackageList',
    'ConvertTo-WslByteSize'
)
