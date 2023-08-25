function Invoke-DISMRestoreHealth {

    <#

        .SYNOPSIS
        Wrapper for DISM

    #>

    param (

        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
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
        [System.IO.FileInfo[]]
        $Path

    )

    begin {
        $PSDefaultParameterValues['*:ErrorAction'] = 'Stop'
        '{0} ...' -f $MyInvocation.MyCommand | Write-Host -ForegroundColor Cyan
    }

    process {

        '... process ...' | Write-Host -ForegroundColor Yellow

        $Path | ForEach-Object {
            Dism /Image:"$_" /Cleanup-Image /RestoreHealth
        }

    }

    end {
        '... {0}: done' -f $MyInvocation.MyCommand | Write-Host -ForegroundColor Green
    }

}
