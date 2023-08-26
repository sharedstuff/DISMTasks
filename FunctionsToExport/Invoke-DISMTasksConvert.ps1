function Invoke-DISMTasksConvert {

    <#

        .SYNOPSIS
        Invoke-DISMTasks "Convert" task

    #>

    [CmdletBinding()]
    param (

        # The complete path to the WIM or ISO file that will be converted to a Virtual Hard Disk.
        # The ISO file must be valid Windows installation media to be recognized successfully.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript(
            {
                if (-Not ($_ | Test-Path) ) {
                    throw 'File does not exist.'
                }
                if (-Not ($_ | Test-Path -PathType Leaf) ) {
                    throw 'Argument must be a file.'
                }
                if ($_ -notmatch '(\.iso|\.wim)') {
                    throw 'File must be either of type iso or wim.'
                }
                return $true
            }
        )]
        [System.IO.FileInfo]
        $SourcePath,

        # The name and path of the Virtual Hard Disk to create.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
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

        # The name or image index of the image to apply from the WIM.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]
        $Edition,

        # The size of the Virtual Hard Disk to create.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ulong]
        $SizeBytes

    )

    begin {
        $Script:ErrorActionPreference = 'Stop'
        Start-TranscriptDISMTasks ('{0}.log' -f $VHDPath)
        '{0} begin ...' -f $MyInvocation.MyCommand | Write-Host -ForegroundColor Cyan
    }

    process {

        $ConvertWindowsImageParams = @{
            SourcePath = $SourcePath
            VHDPath    = $VHDPath
            Edition    = $Edition
            SizeBytes  = $SizeBytes
            # Standard options here
            DiskLayout = 'UEFI'
        }

        try {

            # Check if allready mounted
            if ((Get-DiskImage $VHDPath -ErrorAction SilentlyContinue).Attached) {
                throw 'VHD is attached!'
            }

            Convert-WindowsImage @ConvertWindowsImageParams

            $VHDRoot = $VHDPath | Mount-VHDDISMTasks

            $VHDRoot | Invoke-CleanUpImageRestoreHealthDISMTasks
            Export-WindowsImageSpecificationDISMTasks -Path ('{0}.Specification.json' -f $VHDPath) -VHDRoot $VHDRoot

            $VHDPath | Dismount-VHDDISMTasks
            Optimize-VHD -Path $VHDPath -Mode Full

        }

        catch {
            Invoke-ErrorDISMTasks -InputObject $_ -VHDPath $VHDPath
        }

    }

    end {
        Stop-TranscriptDISMTasks
        '... {0} end' -f $MyInvocation.MyCommand | Write-Host -ForegroundColor Green
    }

}

