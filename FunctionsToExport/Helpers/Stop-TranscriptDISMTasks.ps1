function Stop-TranscriptDISMTasks {

    <#

        .SYNOPSIS
        Wrapper for Stop-Transcript

    #>

    [CmdletBinding()]
    param ()

    begin {
        $Script:ErrorActionPreference = 'Stop'
    }

    process {
        Stop-Transcript -ErrorAction SilentlyContinue
    }

}
