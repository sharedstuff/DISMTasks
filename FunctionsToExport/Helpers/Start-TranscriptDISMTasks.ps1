function Start-TranscriptDISMTasks {

    <#

        .SYNOPSIS
        Wrapper for Start-Transcript

    #>

    [CmdletBinding()]
    param (

        [Parameter(Mandatory)]
        [ValidateScript(
            {
                if (-Not (Split-Path $_ | Test-Path) ) {
                    New-Item (Split-Path $_) -ItemType Directory
                }
                return $true
            }
        )]
        [System.IO.FileInfo]
        $Path,

        [Parameter()]
        [switch]
        $Append

    )

    begin {
        $Script:ErrorActionPreference = 'Stop'
    }

    process {
        try { $null = Stop-Transcript } catch {}
        $PSBoundParameters.Force = $true
        $PSBoundParameters.UseMinimalHeader = $true
        Start-Transcript @PSBoundParameters
    }

}
