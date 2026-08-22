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

Export-ModuleMember -Function @(
    'Test-WslDistributionName',
    'Test-LinuxUserName',
    'Test-WslHostName',
    'Test-WslVhdSize',
    'Get-WslInstallArguments'
)
