function Invoke-ErrorDISMTasks {

    <#

        .SYNOPSIS
        Function for common Error-Handling

    #>

    [CmdletBinding()]
    param(

        # The name and path of the Virtual Hard Disk to create.
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName
        )]
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

        $InputObject

    )

    begin {
        $Script:ErrorActionPreference = 'Stop'
    }

    process {

        'Error during build' | Write-Host -ForegroundColor Red
        $InputObject | Write-Host -ForegroundColor Red

        $VHDPath | Dismount-VHDDISMTasks

        Remove-Item $VHDPath -Force -Verbose

        throw $InputObject

    }


}
