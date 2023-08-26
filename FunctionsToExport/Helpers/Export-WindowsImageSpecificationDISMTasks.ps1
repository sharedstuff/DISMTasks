function Export-WindowsImageSpecificationDISMTasks {

    <#

        .SYNOPSIS
        Get a hashtable representing the WindowsImage specification

    #>

    [CmdletBinding()]
    param (

    [Parameter(Mandatory)]
    [ValidateScript(
        {
            if (-Not ($_ | Test-Path) ) {
                throw 'Directory does not exist.'
            }
            if (-Not ($_ | Test-Path -PathType Container) ) {
                throw 'Argument must be a directory.'
            }
            return $true
        }
    )]
    [System.IO.FileInfo]
    $VHDRoot,

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
        $Path

    )

    begin {
        $Script:ErrorActionPreference = 'Stop'
    }

    process {
        @{
            Edition                = (Get-WindowsEdition -Path $VHDRoot).Edition
            WindowsOptionalFeature = Get-WindowsOptionalFeature -Path $VHDRoot | Where-Object State -EQ 'Enabled' | Select-Object -ExpandProperty FeatureName
            WindowsCapability      = Get-WindowsCapability -Path $VHDRoot | Where-Object State -EQ 'Installed' | Select-Object -ExpandProperty Name
            AppProvisionedPackage  = Get-AppProvisionedPackage -Path $VHDRoot | Select-Object DisplayName, PackageName, Version, PublisherId, InstallLocation
            WindowsDriver          = Get-WindowsDriver -Path $VHDRoot
        } | ConvertTo-Json | Set-Content -Path $Path -Force
    }

}
