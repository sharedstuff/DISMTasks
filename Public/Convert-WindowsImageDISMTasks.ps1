function Convert-WindowsImageDISMTasks {

    <#

        .SYNOPSIS
        Wrapper for Convert-WindowsImage
        Creates a bootable VHD(X) based on Windows 7,8, 10 or Windows Server 2012, 2012R2, 2016, 2019 installation media.

    #>

    [CmdletBinding()]
    param (

        # The complete path to the WIM or ISO file that will be converted to a Virtual Hard Disk.
        # The ISO file must be valid Windows installation media to be recognized successfully.
        [Parameter(Mandatory)]
        [ValidateScript({
                if (-Not ($_ | Test-Path) ) {
                    throw 'File does not exist.'
                }
                if (-Not ($_ | Test-Path -PathType Leaf) ) {
                    throw 'Argument must be a file.'
                }
                if ($_ -notmatch '(\.iso|\.wim)') {
                    throw 'File specified must be either of type iso or wim.'
                }
                return $true
            })]
        [System.IO.FileInfo]
        $SourcePath,

        # The name or image index of the image to apply from the WIM.
        [Parameter(Mandatory)]
        [string]
        $Edition,

        # The name and path of the Virtual Hard Disk to create.
        [Parameter(Mandatory)]
        [ValidateScript(
            {
                if (-Not (Split-Path $_ | Test-Path) ) {
                    New-Item (Split-Path $_) -ItemType Directory
                }
                if ($_ -notmatch '(\.vhdx)') {
                    throw 'File must be of type vhdx.'
                }
                return $true
            }
        )]
        [System.IO.FileInfo]
        $VHDPath,

        # The size of the Virtual Hard Disk to create.
        [Parameter(Mandatory)]
        [int64]
        $SizeBytes

    )

    begin {

        $mslabVersion = 'dev'

        #region download convert-windowsimage if needed and load it
        $convertWindowsImagePath = "$PSScriptRoot\Convert-WindowsImage.ps1"
        if (-not (Test-Path -Path $convertWindowsImagePath)) {
            'Downloading Convert-WindowsImage ...' | Write-Host -ForegroundColor Yellow
            try {
                Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/microsoft/MSLab/releases/download/$mslabVersion/Convert-WindowsImage.ps1" -OutFile $convertWindowsImagePath
            }
            catch {
                try {
                    "Download Convert-windowsimage.ps1 from releases ($mslabVersion) failed with $($_.Exception.Message), trying master branch now" | Write-Host -ForegroundColor Yellow
                    Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/microsoft/MSLab/master/Tools/Convert-WindowsImage.ps1' -OutFile $convertWindowsImagePath
                }
                catch {
                    throw 'Failed to download Convert-WindowsImage.ps1!'
                }
            }
        }

        #load convert-windowsimage
        . "$PSScriptRoot\Convert-WindowsImage.ps1"

    }

    process {

        $PSDefaultParameterValues['*:ErrorAction'] = 'Stop'

        $ConvertWindowsImageParams = $PSBoundParameters
        $ConvertWindowsImageParams.DiskLayout = 'UEFI'

        Convert-WindowsImage @ConvertWindowsImageParams
        Get-VHD $ConvertWindowsImageParams.VHDPath

    }

}
