function Invoke-CleanUpImageRestoreHealthDISMTasks {

    <#

        .SYNOPSIS
        Wrapper for DISM

    #>

    param (

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript(
            {
                if (-Not ($_ | Test-Path) ) {
                    throw 'File does not exist.'
                }
                if (-Not ($_ | Test-Path -PathType Container) ) {
                    throw 'Argument must be a container.'
                }
                return $true
            }
        )]
        [System.IO.FileInfo]
        $Path

    )

    begin {
        $Script:ErrorActionPreference = 'Stop'
    }

    process {

        try {
            Dism.exe /Image:"$Path" /Cleanup-Image /RestoreHealth
            if (-not $?) { throw 'dism.exe did not complete properly' }
        }
        catch {
            throw $_
        }

    }

}
