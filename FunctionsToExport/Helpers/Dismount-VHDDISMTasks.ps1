function Dismount-VHDDISMTasks {

    <#

        .SYNOPSIS
        Wrapper for Dismount-VHD (DiskImage)

    #>

    param (

        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [ValidateScript(
            {
                if (-Not ($_ | Test-Path) ) {
                    throw 'File does not exist.'
                }
                if (-Not ($_ | Test-Path -PathType Leaf) ) {
                    throw 'Argument must be a file.'
                }
                if ($_ -notmatch '(\.vhdx)') {
                    throw 'File specified must be of type vhdx.'
                }
                return $true
            }
        )]
        [System.IO.FileInfo[]]
        [Alias('SourcePath')]
        $VHDPath

    )

    begin {
        $Script:ErrorActionPreference = 'Stop'
    }

    process {
        $VHDPath | ForEach-Object {
            Get-DiskImage $VHDPath | Dismount-DiskImage
        }
    }

}
