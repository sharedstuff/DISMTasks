function Invoke-DISMTasksBuild {

    <#

        .SYNOPSIS
        Invoke-DISMTasks "Build" task

    #>

    [CmdletBinding()]
    param (

        # The complete path to the WIM or ISO file that will be converted to a Virtual Hard Disk.
        # The ISO file must be valid Windows installation media to be recognized successfully.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript(
            {
                if (-Not ($_ | Test-Path) ) {
                    throw 'File does not exist.'
                }
                if (-Not ($_ | Test-Path -PathType Leaf) ) {
                    throw 'Argument must be a file.'
                }
                if ($_ -notmatch '(\.vhdx)') {
                    throw 'File must be of type vhdx.'
                }
                return $true
            }
        )]
        [System.IO.FileInfo]
        $SourcePath,

        # The name and path of the Virtual Hard Disk to create.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
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


        # Directory(s) to add AppProvisionedPackage(s) from
        [Parameter(ValueFromPipelineByPropertyName)]
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
        [System.IO.FileInfo[]]
        $AppProvisionedPackagePath,

        # Directory(s) to add Driver(s) from
        [Parameter(ValueFromPipelineByPropertyName)]
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
        [System.IO.FileInfo[]]
        $DriverPath,

        # Directory(s) to copy/merge Content from
        [Parameter(ValueFromPipelineByPropertyName)]
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
        [System.IO.FileInfo[]]
        $MergePath,

        # Directory(s) to add Package(s) from
        [Parameter(ValueFromPipelineByPropertyName)]
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
        [System.IO.FileInfo[]]
        $PackagePath,

        # WindowsCapability(s) Name(s) to add during the process
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]
        $WindowsCapability,

        # WindowsOptionalFeature(s) FeatureName(s) to add during the process
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]
        $WindowsOptionalFeature

    )

    begin {
        $Script:ErrorActionPreference = 'Stop'
        Start-TranscriptDISMTasks ('{0}.log' -f $VHDPath)
        '{0} begin ...' -f $MyInvocation.MyCommand | Write-Host -ForegroundColor Cyan
    }

    process {

        try {

            # Check if allready mounted
            if ((Get-DiskImage $VHDPath -ErrorAction SilentlyContinue).Attached) {
                throw 'VHD is attached!'
            }

            # WorkVHD
            $CopyItemParams = @{
                Path        = $SourcePath
                Destination = $VHDPath
                Force       = $true
                Verbose     = $true
            }
            Copy-Item @CopyItemParams

            # Mount
            $VHDRoot = $VHDPath | Mount-VHDDISMTasks

            # AppProvisonedPackagePath
            'Add-AppProvisionedPackage ...' | Write-Host -ForegroundColor Yellow
            if ($AppProvisionedPackagePath) {
                $AppProvisionedPackagePath | ForEach-Object {
                    $_ | Write-Host -ForegroundColor Yellow
                    $ChildItem = @(
                        Get-ChildItem $_ -Filter '*.appx'
                        Get-ChildItem $_ -Filter '*.*bundle'
                    )
                    $ChildItem | ForEach-Object {
                        $_ | Write-Host -ForegroundColor Yellow
                        try {
                            Add-AppProvisionedPackage -Path $VHDRoot -PackagePath $_.FullName -SkipLicense
                        }
                        catch {
                            throw $_
                        }
                    }
                }
            }

            # DriverPath
            'Add-WindowsDriver ...' | Write-Host -ForegroundColor Yellow
            if ($DriverPath) {
                $DriverPath | ForEach-Object {
                    $_ | Write-Host -ForegroundColor Yellow
                    Add-WindowsDriver -Path $VHDRoot -Driver $_ -Recurse
                }
            }

            # MergePath
            'Robocopy.exe ...' | Write-Host -ForegroundColor Yellow
            if ($MergePath) {
                $MergePath | ForEach-Object {
                    $_ | Write-Host -ForegroundColor Yellow
                    Robocopy.exe $_ $VHDRoot /S
                }
            }

            # PackagePath
            'Add-WindowsPackage ...' | Write-Host -ForegroundColor Yellow
            if ($PackagePath) {
                $PackagePath | ForEach-Object {
                    $_ | Write-Host -ForegroundColor Yellow
                    Add-WindowsPackage -Path $VHDRoot -PackagePath $_
                }
            }

            # WindowsCapability
            'Add-WindowsCapability ...' | Write-Host -ForegroundColor Yellow
            if ($WindowsCapability) {
                $WindowsCapability | ForEach-Object {
                    $_ | Write-Host -ForegroundColor Yellow
                    Add-WindowsCapability -Path $VHDRoot -Name $_
                }
            }

            # WindowsOptionalFeature
            'Add-WindowsOptionalFeature ...' | Write-Host -ForegroundColor Yellow
            if ($WindowsOptionalFeature) {
                $WindowsOptionalFeature | ForEach-Object {
                    $_ | Write-Host -ForegroundColor Yellow
                    Add-WindowsOptionalFeature -Path $VHDRoot -Name $_
                }
            }

            $VHDRoot | Invoke-CleanUpImageRestoreHealthDISMTasks
            Export-WindowsImageSpecificationDISMTasks -Path ('{0}.Specification.json' -f $VHDPath) -VHDRoot $VHDRoot

            $VHDPath | Dismount-VHDDISMTasks
            Optimize-VHD -Path $VHDPath -Mode Full

        }

        catch {
            Invoke-ErrorDISMTasks -InputObject $_ -VHDPath $VHDPath
        }

    }

    end {
        Stop-TranscriptDISMTasks
        '... {0} end' -f $MyInvocation.MyCommand | Write-Host -ForegroundColor Green
    }

}
