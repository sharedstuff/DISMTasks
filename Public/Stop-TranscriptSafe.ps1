function Stop-TranscriptSafe {

    <#

        .SYNOPSIS
        Wrapper for Stop-Transcript

    #>

    [CmdletBinding()]
    param ()

    begin {
        $PSDefaultParameterValues['*:ErrorAction'] = 'Stop'
    }

    process {
        Stop-Transcript -ErrorAction SilentlyContinue
    }

}
