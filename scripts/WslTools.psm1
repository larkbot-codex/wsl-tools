Set-StrictMode -Version Latest

function Test-WslDistributionName {
    param([AllowEmptyString()][string] $Value)
    return $Value -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}\z'
}

function Test-LinuxUserName {
    param([AllowEmptyString()][string] $Value)
    return $Value -cmatch '^[a-z_][a-z0-9_-]{0,31}\z'
}

function Test-WslUserId {
    param([AllowNull()] $Value)

    $parsed = 0
    return [int]::TryParse([string] $Value, [ref] $parsed) -and
        $parsed -ge 1000 -and $parsed -le 60000
}

function Get-NextAvailableWslUserId {
    param(
        [int[]] $UsedUserIds = @(),
        [AllowNull()] $RequestedUserId
    )

    $used = @{}
    foreach ($userId in $UsedUserIds) {
        if (Test-WslUserId $userId) { $used[[int] $userId] = $true }
    }

    if ($null -ne $RequestedUserId) {
        if (-not (Test-WslUserId $RequestedUserId)) { throw 'The Linux user ID must be between 1000 and 60000.' }
        $requested = [int] $RequestedUserId
        if ($used.ContainsKey($requested)) { throw "Linux user ID $requested is already used by another WSL distribution." }
        return $requested
    }

    for ($candidate = 1000; $candidate -le 60000; $candidate++) {
        if (-not $used.ContainsKey($candidate)) { return $candidate }
    }
    throw 'No unused Linux user ID is available between 1000 and 60000.'
}

function Resolve-WslUserId {
    param([AllowNull()] $CurrentUserId, [int[]] $UsedUserIds = @(), [AllowNull()] $RequestedUserId)

    if ($null -ne $CurrentUserId) {
        if (-not (Test-WslUserId $CurrentUserId)) { throw 'The existing Linux user ID must be between 1000 and 60000.' }
        $current = [int] $CurrentUserId
        if ($null -ne $RequestedUserId) {
            if (-not (Test-WslUserId $RequestedUserId)) { throw 'The Linux user ID must be between 1000 and 60000.' }
            if ([int] $RequestedUserId -ne $current) {
                throw "The Linux user already has UID $current; refusing to migrate it automatically to UID $RequestedUserId."
            }
        }
        return $current
    }
    return Get-NextAvailableWslUserId -UsedUserIds $UsedUserIds -RequestedUserId $RequestedUserId
}

function Test-WslHostName {
    param([AllowEmptyString()][string] $Value)
    return $Value -match '^[A-Za-z0-9][A-Za-z0-9.-]{0,62}\z'
}

function Test-WslVhdSize {
    param([AllowEmptyString()][string] $Value)
    return $Value -match '^\d+(B|M|MB|G|GB|T|TB)\z'
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
    if ($image.FileName -notmatch '^ubuntu-[0-9.]+-wsl-amd64\.wsl\z') { return $false }
    if ($image.Sha256 -notmatch '^[a-f0-9]{64}\z') { return $false }

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
        if ($package -notmatch '^[A-Za-z0-9][A-Za-z0-9._+:-]*\z') {
            throw "Invalid package name '$package'."
        }
    }
    return $packages
}

function ConvertTo-WslByteSize {
    param([Parameter(Mandatory)][string] $Value)

    if (-not (Test-WslVhdSize $Value)) { throw "Invalid WSL size '$Value'." }
    $Value -match '^(\d+)(B|M|MB|G|GB|T|TB)\z' | Out-Null
    $sizeValue = [uint64] $Matches[1]
    $multiplier = switch ($Matches[2]) {
        'B' { [uint64] 1 }
        { $_ -in 'M', 'MB' } { [uint64] 1MB }
        { $_ -in 'G', 'GB' } { [uint64] 1GB }
        { $_ -in 'T', 'TB' } { [uint64] 1TB }
    }
    return $sizeValue * $multiplier
}

function ConvertTo-BashLineEndings {
    param([AllowEmptyString()][string] $Value)

    return $Value -replace "`r`n", "`n" -replace "`r", "`n"
}

Export-ModuleMember -Function @(
    'Test-WslDistributionName',
    'Test-LinuxUserName',
    'Test-WslUserId',
    'Get-NextAvailableWslUserId',
    'Resolve-WslUserId',
    'Test-WslHostName',
    'Test-WslVhdSize',
    'ConvertFrom-WslVersionText',
    'Test-WslConfiguration',
    'Get-WslInstallArguments',
    'Test-WslInstallHelp',
    'Read-WslPackageList',
    'ConvertTo-WslByteSize',
    'ConvertTo-BashLineEndings'
)
