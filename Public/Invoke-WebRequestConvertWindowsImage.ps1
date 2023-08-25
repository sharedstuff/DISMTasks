function Invoke-WebRequestConvertWindowsImage {

    <#

        .SYNOPSIS
        Wrapper for Invoke-WebRequest

    #>

    [CmdletBinding()]
    param (

        [Parameter()]
        [string]
        $Uri = 'https://raw.githubusercontent.com/microsoft/MSLab/master/Tools/Convert-WindowsImage.ps1',

        [Parameter()]
        [ValidateScript(
            {

                # create Split-Path
                if (-Not (Split-Path $_ | Test-Path) ) {
                    New-Item (Split-Path $_) -ItemType Directory
                }

                return $true
            }
        )]
        [System.IO.FileInfo]
        $OutFile = (Join-Path $PSScriptRoot 'Convert-WindowsImage.ps1')

    )

    if (-not (Test-Path -Path $OutFile)) {
        $WebRequestParams = @{
            Uri             = $Uri
            OutFile         = $OutFile
            UseBasicParsing = $true
            ErrorAction     = 'Stop'
        }
        Invoke-WebRequest @WebRequestParams
    }

    . $OutFile

}
