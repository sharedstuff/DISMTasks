function Mount-VHDDISMTasks {

    <#

        .SYNOPSIS
        Wrapper for Mount-VHD (DiskImage)

    #>

    param (

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
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

            try {

                $DiskImage = Mount-DiskImage $_
                $DriveLetter = $DiskImage | Get-Disk | Get-Partition | Get-Volume | Select-Object -ExpandProperty DriveLetter | Sort-Object -Unique

                if ($DriveLetter.Count -gt 1) { throw 'Multiple DriveLetters found!' }
                elseif ($DriveLetter.Count -lt 1) { throw 'No DriveLetters found!' }

                '{0}:\' -f $DriveLetter

            }
            catch {
                $_
                $DiskImage | Dismount-DiskImage
            }

        }
    }

}
