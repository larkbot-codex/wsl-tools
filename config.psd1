@{
    UbuntuRelease     = '26.04'
    DistributionName = 'UbuntuDev-26.04'
    DefaultUser      = 'developer'
    Hostname         = 'ubuntu-dev'
    VhdSize          = '50GB'
    MinimumWsl       = '2.4.10'
    Images           = @{
        AMD64 = @{
            FileName = 'ubuntu-26.04-wsl-amd64.wsl'
            Url      = 'https://releases.ubuntu.com/resolute/ubuntu-26.04-wsl-amd64.wsl'
            Sha256   = '96c7f5fb28a7fe28245331f9bfbe4375f18dd29a4850116ad3c4f60f6700c55c'
        }
    }
}
