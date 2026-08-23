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

    It 'accepts supported regular Linux user IDs' -ForEach @(1000, 1001, 60000) {
        Test-WslUserId $_ | Should -BeTrue
    }

    It 'rejects unsafe Linux user IDs' -ForEach @($null, '', 999, 60001, 'user') {
        Test-WslUserId $_ | Should -BeFalse
    }

    It 'selects the first UID not used by another WSL distribution' {
        Get-NextAvailableWslUserId -UsedUserIds @(1000, 1002) | Should -Be 1001
    }

    It 'honors an available explicit UID' {
        Get-NextAvailableWslUserId -UsedUserIds @(1000) -RequestedUserId 2000 | Should -Be 2000
    }

    It 'rejects an explicit UID used by another WSL distribution' {
        { Get-NextAvailableWslUserId -UsedUserIds @(1000, 1001) -RequestedUserId 1001 } |
            Should -Throw '*already used*'
    }

    It 'preserves an existing UID even when a legacy distribution uses the same UID' {
        Resolve-WslUserId -CurrentUserId 1000 -UsedUserIds @(1000, 1001) | Should -Be 1000
    }

    It 'rejects an explicit migration of an existing user UID' {
        { Resolve-WslUserId -CurrentUserId 1000 -RequestedUserId 1001 } | Should -Throw '*refusing to migrate*'
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

    It 'rejects trailing line endings instead of passing values Bash will reject' -ForEach @(
        @{ Validator = 'Test-WslDistributionName'; Value = "Work-Ubuntu`n" }
        @{ Validator = 'Test-LinuxUserName'; Value = "developer`n" }
        @{ Validator = 'Test-WslHostName'; Value = "work-ubuntu`n" }
        @{ Validator = 'Test-WslVhdSize'; Value = "50GB`n" }
    ) {
        & $Validator $Value | Should -BeFalse
    }
}

Describe 'WSL version parsing' {
    It 'parses localized Store WSL output' -ForEach @(
        'WSL version: 2.7.12.0',
        'WSL-Version: 2.7.12.0',
        'Version WSL : 2.7.12.0',
        ('WSL ' + [char]0x306e + [char]0x30d0 + [char]0x30fc + [char]0x30b8 + [char]0x30e7 + [char]0x30f3 + ': 2.7.12.0'),
        ('Versi' + [char]0x00f3 + 'n de WSL: 2.7.12.0'),
        'Versione WSL: 2.7.12.0',
        'Versao do WSL: 2.7.12.0'
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
        $scripts = Get-ChildItem "$PSScriptRoot/.." -File -Recurse |
            Where-Object { $_.Extension -in @('.cmd', '.ps1', '.psm1') } |
            Get-Content -Raw
        ($scripts -join "`n") | Should -Not -Match 'wsl(?:\.exe)?\s+--unregister'
    }

    It 'does not change the default WSL distribution' {
        $scripts = Get-ChildItem "$PSScriptRoot/.." -File -Recurse |
            Where-Object { $_.Extension -in @('.cmd', '.ps1', '.psm1') } |
            Get-Content -Raw
        ($scripts -join "`n") | Should -Not -Match 'wsl(?:\.exe)?\s+--set-default(?:\s|$)'
    }

    It 'captures state through the checked-in Bash script' {
        $captureScript = Get-Content "$PSScriptRoot/../scripts/capture-state.ps1" -Raw
        $captureScript | Should -Match '--cd\s+\$PSScriptRoot\s+--\s+bash\s+\./capture-state\.sh'
        $captureScript | Should -Not -Match 'bash\s+-lc\s+\$command'
    }

    It 'passes the selected UID to useradd and refuses automatic UID migration' {
        $provisionScript = Get-Content "$PSScriptRoot/../scripts/provision.sh" -Raw
        $provisionScript | Should -Match 'useradd --uid "\$\{user_id\}"'
        $provisionScript | Should -Match 'refusing automatic UID migration'
    }
}

Describe 'Fresh Windows host bootstrap' {
    BeforeAll {
        $completeHelp = '--install --from-file PATH --name NAME --no-launch --vhd-size SIZE'
        $minimumVersion = [version] '2.4.10'
    }

    It 'classifies a supported host as ready' {
        Get-WslHostState `
            -CommandAvailable $true `
            -VersionExitCode 0 `
            -VersionText 'WSL version: 2.7.12.0' `
            -StatusExitCode 0 `
            -InstallHelp $completeHelp `
            -MinimumVersion $minimumVersion `
            -VirtualMachinePlatformEnabled $true `
            -RestartPending $false |
            Should -Be 'Ready'
    }

    It 'classifies a missing command or disabled host as absent' -ForEach @(
        @{ Available = $false; VersionExitCode = 1; StatusExitCode = 1 }
        @{ Available = $true; VersionExitCode = 0; StatusExitCode = 1 }
    ) {
        Get-WslHostState `
            -CommandAvailable $Available `
            -VersionExitCode $VersionExitCode `
            -VersionText 'WSL version: 2.7.12.0' `
            -StatusExitCode $StatusExitCode `
            -InstallHelp $completeHelp `
            -MinimumVersion $minimumVersion `
            -VirtualMachinePlatformEnabled $true `
            -RestartPending $false |
            Should -Be 'Absent'
    }

    It 'requires an update for an old or incomplete WSL command surface' -ForEach @(
        @{ Version = 'WSL version: 2.3.0.0'; Help = '--install' }
        @{ Version = 'WSL version: 2.7.12.0'; Help = '--install --from-file --name --no-launch' }
        @{ Version = 'Windows Subsystem for Linux'; Help = '--install' }
    ) {
        Get-WslHostState `
            -CommandAvailable $true `
            -VersionExitCode 0 `
            -VersionText $Version `
            -StatusExitCode 0 `
            -InstallHelp $Help `
            -MinimumVersion $minimumVersion `
            -VirtualMachinePlatformEnabled $true `
            -RestartPending $false |
            Should -Be 'UpdateRequired'
    }

    It 'requires host installation when Virtual Machine Platform is disabled' {
        Get-WslHostState `
            -CommandAvailable $true `
            -VersionExitCode 0 `
            -VersionText 'WSL version: 2.7.12.0' `
            -StatusExitCode 0 `
            -InstallHelp $completeHelp `
            -MinimumVersion $minimumVersion `
            -VirtualMachinePlatformEnabled $false `
            -RestartPending $false |
            Should -Be 'Absent'
    }

    It 'stops for a pending Windows restart before provisioning' {
        Get-WslHostState `
            -CommandAvailable $true `
            -VersionExitCode 0 `
            -VersionText 'WSL version: 2.7.12.0' `
            -StatusExitCode 0 `
            -InstallHelp $completeHelp `
            -MinimumVersion $minimumVersion `
            -VirtualMachinePlatformEnabled $true `
            -RestartPending $true |
            Should -Be 'RestartRequired'
    }

    It 'installs WSL without creating an unwanted distribution' {
        Get-WslHostActionArguments -Action Install |
            Should -Be @('--install', '--no-distribution')
    }

    It 'uses the supported WSL update command' {
        Get-WslHostActionArguments -Action Update | Should -Be @('--update')
    }

    It 'keeps VerifyOnly read-only when host preparation is needed' -ForEach @(
        'Absent',
        'UpdateRequired',
        'RestartRequired'
    ) {
        Get-WslBootstrapAction -HostState $_ -VerifyOnly | Should -Be 'ReadOnlyFailure'
    }

    It 'selects the required host action before provisioning' -ForEach @(
        @{ State = 'Ready'; Action = 'Provision' }
        @{ State = 'Absent'; Action = 'Install' }
        @{ State = 'UpdateRequired'; Action = 'Update' }
        @{ State = 'RestartRequired'; Action = 'Restart' }
    ) {
        Get-WslBootstrapAction -HostState $State | Should -Be $Action
    }

    It 'encodes an elevation command safely when the script path contains spaces' {
        $path = "C:\Users\Test User\Downloads\wsl-tools\bootstrap.ps1"
        $arguments = Get-ElevatedBootstrapArguments -ScriptPath $path -HostAction Install
        $arguments[0..2] | Should -Be @('-NoProfile', '-ExecutionPolicy', 'Bypass')
        $arguments[3] | Should -Be '-EncodedCommand'
        [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($arguments[4])) |
            Should -Be "& '$path' -HostAction 'Install'"
    }

    It 'ships a Windows PowerShell launcher for the root bootstrap' {
        $launcher = Get-Content -Raw "$PSScriptRoot/../Start-WslTools.cmd"
        $launcher | Should -Match 'Isolate bootstrap from user-installed PowerShell modules'
        $launcher | Should -Match 'set "PSModulePath=.*WindowsPowerShell'
        $launcher | Should -Match 'powershell\.exe -NoProfile -ExecutionPolicy Bypass'
        $launcher | Should -Match 'bootstrap\.ps1'
    }

    It 'fails closed when the VirtualMachinePlatform feature state cannot be read' {
        $bootstrap = Get-Content -Raw "$PSScriptRoot/../bootstrap.ps1"
        $bootstrap | Should -Not -Match 'virtualMachinePlatformEnabled\s*=\s*\$statusExitCode'
        $bootstrap | Should -Match '(?s)catch\s*\{.*Unable to read Windows optional-feature state.*\}'
    }
}

Describe 'Development package manifest' {
    It 'contains the expected baseline tools' {
        $packages = @(Read-WslPackageList "$PSScriptRoot/../packages.txt")
        $packages | Should -Contain 'build-essential'
        $packages | Should -Contain 'git'
        $packages | Should -Contain 'gh'
        $packages | Should -Contain 'python3'
        $packages | Should -Contain 'podman'
        $packages | Should -Contain 'ripgrep'
        $packages | Should -Contain 'shellcheck'
    }

    It 'rejects an option-shaped package name' {
        $path = Join-Path $TestDrive 'packages.txt'
        Set-Content -LiteralPath $path -Value '--allow-unauthenticated'
        { Read-WslPackageList $path } | Should -Throw '*Invalid package name*'
    }

    It 'rejects shell metacharacters in package names' {
        $path = Join-Path $TestDrive 'packages.txt'
        Set-Content -LiteralPath $path -Value 'git;id'
        { Read-WslPackageList $path } | Should -Throw '*Invalid package name*'
    }

    It 'validates package names again in the privileged provisioner' {
        $provisioner = Get-Content -Raw "$PSScriptRoot/../scripts/provision.sh"
        $provisioner | Should -Match 'for package in "\$\{packages\[@\]\}"'
        $provisioner | Should -Match '\[\[ ! \$\{package\} =~ \^\[A-Za-z0-9\]'
        $provisioner | Should -Match 'invalid package name:'
    }
}

Describe 'Verification helpers' {
    It 'converts supported VHD units to bytes' -ForEach @(
        @{ Value = '50GB'; Bytes = 53687091200 }
        @{ Value = '1024MB'; Bytes = 1073741824 }
        @{ Value = '1TB'; Bytes = 1099511627776 }
    ) {
        ConvertTo-WslByteSize $Value | Should -Be $Bytes
    }

    It 'rejects an unsupported VHD unit' {
        { ConvertTo-WslByteSize '50GiB' } | Should -Throw '*Invalid WSL size*'
    }

    It 'normalizes Windows and lone carriage-return line endings for Bash' {
        $normalized = ConvertTo-BashLineEndings "first`r`nsecond`rthird`nfourth"

        $normalized | Should -Be "first`nsecond`nthird`nfourth"
        $normalized.Contains("`r") | Should -BeFalse
    }

    It 'keeps generated state inventories out of source control' {
        Get-Content "$PSScriptRoot/../.gitignore" | Should -Contain 'state/*.txt'
    }

    It 'treats an unavailable systemd user manager as a warning' {
        $verification = Get-Content "$PSScriptRoot/../scripts/verify.ps1" -Raw
        $verification | Should -Match "systemd user manager works'.*-WarningOnly"
        $verification | Should -Match 'Rootless Podman will fall back to cgroupfs'
        $linuxVerification = Get-Content "$PSScriptRoot/../scripts/verify.sh" -Raw
        $linuxVerification | Should -Match "warn_check 'systemd user manager works'"
        $linuxVerification | Should -Match 'Rootless Podman will fall back to cgroupfs'
    }

    It 'captures setup state even when verification throws' {
        $setup = Get-Content "$PSScriptRoot/../scripts/setup.ps1" -Raw
        $setup | Should -Match '(?s)try\s*\{\s*& \(Join-Path \$PSScriptRoot ''verify\.ps1''\).*?\}\s*finally\s*\{\s*& \(Join-Path \$PSScriptRoot ''capture-state\.ps1''\)'
    }

    It 'captures synchronization state even when verification throws' {
        $sync = Get-Content "$PSScriptRoot/../scripts/sync-packages.ps1" -Raw
        $sync | Should -Match '(?s)try\s*\{\s*& \(Join-Path \$PSScriptRoot ''verify\.ps1''\).*?\}\s*finally\s*\{\s*& \(Join-Path \$PSScriptRoot ''capture-state\.ps1''\)'
    }
}
