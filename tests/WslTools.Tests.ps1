BeforeAll {
    Import-Module "$PSScriptRoot/../scripts/WslTools.psm1" -Force
    $config = Import-PowerShellDataFile "$PSScriptRoot/../config.psd1"
}

Describe 'Public configuration' {
    It 'uses generic AMD64 environment defaults' {
        $config.DistributionName | Should -Be 'UbuntuDev-26.04'
        $config.DefaultUser | Should -Be 'developer'
        $config.Hostname | Should -Be 'ubuntu-dev'
        $config.VhdSize | Should -Be '50GB'
        $config.Images.AMD64.FileName | Should -Be 'ubuntu-26.04-wsl-amd64.wsl'
    }

    It 'accepts the repository configuration' {
        Test-WslConfiguration $config | Should -BeTrue
    }

    It 'rejects an invalid pinned hash' {
        $invalid = @{} + $config
        $invalid.Images = @{ AMD64 = @{} + $config.Images.AMD64 }
        $invalid.Images.AMD64.Sha256 = 'not-a-hash'
        Test-WslConfiguration $invalid | Should -BeFalse
    }
}

Describe 'Core setting validation' {
    It 'accepts a safe distribution name' {
        Test-WslDistributionName 'Work-Ubuntu_26.04' | Should -BeTrue
    }

    It 'rejects unsafe distribution names' -ForEach @('', '-ubuntu', 'name with spaces', 'name;rm') {
        Test-WslDistributionName $_ | Should -BeFalse
    }

    It 'accepts a Linux username' {
        Test-LinuxUserName 'dev_user-1' | Should -BeTrue
    }

    It 'rejects unsafe Linux usernames' -ForEach @('', 'Developer', '1developer', 'dev user') {
        Test-LinuxUserName $_ | Should -BeFalse
    }

    It 'accepts a hostname' {
        Test-WslHostName 'work-ubuntu.example' | Should -BeTrue
    }

    It 'rejects unsafe hostnames' -ForEach @('', '-ubuntu', 'ubuntu_dev', 'ubuntu;dev') {
        Test-WslHostName $_ | Should -BeFalse
    }

    It 'accepts supported VHD sizes' -ForEach @('50GB', '1024MB', '1TB') {
        Test-WslVhdSize $_ | Should -BeTrue
    }

    It 'rejects unsupported VHD sizes' -ForEach @('', '50', '50GiB', '-1GB') {
        Test-WslVhdSize $_ | Should -BeFalse
    }
}

Describe 'WSL version parsing' {
    It 'parses localized Store WSL output' -ForEach @(
        'WSL version: 2.7.12.0',
        'WSL-Version: 2.7.12.0',
        'Version WSL : 2.7.12.0',
        'WSL のバージョン: 2.7.12.0',
        'Versión de WSL: 2.7.12.0'
    ) {
        ConvertFrom-WslVersionText "$_`nKernel version: 6.6.87.2" |
            Should -Be ([version] '2.7.12')
    }

    It 'rejects output without a WSL version' {
        ConvertFrom-WslVersionText 'Windows Subsystem for Linux' | Should -BeNullOrEmpty
    }

    It 'does not mistake a later component version for the WSL version' {
        $output = "WSL is running in a degraded state`nKernel version: 6.6.87.2"
        ConvertFrom-WslVersionText $output | Should -BeNullOrEmpty
    }
}

Describe 'WSL installation command construction' {
    It 'passes all user values as separate argv entries' {
        $arguments = Get-WslInstallArguments -ImagePath 'C:\images\ubuntu.wsl' -DistributionName 'Work-Ubuntu' -VhdSize '50GB'
        $arguments | Should -Be @(
            '--install', '--from-file', 'C:\images\ubuntu.wsl',
            '--name', 'Work-Ubuntu',
            '--vhd-size', '50GB',
            '--no-launch'
        )
    }

    It 'recognizes the complete custom-image installation capability set' {
        $help = '--install --from-file PATH --name NAME --no-launch --vhd-size SIZE'
        Test-WslInstallHelp $help | Should -BeTrue
    }

    It 'rejects help missing <Missing>' -ForEach @(
        @{ Missing = '--from-file' }
        @{ Missing = '--name' }
        @{ Missing = '--no-launch' }
        @{ Missing = '--vhd-size' }
    ) {
        $options = @('--from-file', '--name', '--no-launch', '--vhd-size') | Where-Object { $_ -ne $Missing }
        Test-WslInstallHelp ($options -join ' ') | Should -BeFalse
    }

    It 'does not automate destructive distribution removal' {
        $scripts = Get-ChildItem "$PSScriptRoot/../scripts" -File -Recurse |
            Get-Content -Raw
        ($scripts -join "`n") | Should -Not -Match 'wsl(?:\.exe)?\s+--unregister'
    }
}
