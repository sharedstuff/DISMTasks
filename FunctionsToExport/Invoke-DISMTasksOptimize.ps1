function Invoke-DISMTasksOptimize {

    <#

        .SYNOPSIS
        Invoke-DISMTasks "Optimize" task

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

        # AppProvisionedPackage(s) DisplayName(s) to keep during the process
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]
        $AppProvisionedPackage,

        # WindowsCapability(s) Name(s) to keep during the process
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]
        $WindowsCapability,

        # WindowsOptionalFeature(s) FeatureName(s) to keep during the process
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]
        $WindowsOptionalFeature

    )

    begin {

        $Script:ErrorActionPreference = 'Stop'
        Start-TranscriptDISMTasks ('{0}.log' -f $VHDPath)
        '{0} begin ...' -f $MyInvocation.MyCommand | Write-Host -ForegroundColor Cyan

        # Blocked

        $WindowsOptionalFeatureBlock = @(
            'Printing-Foundation-Features'
            'Printing-Foundation-InternetPrinting-Client'
            'Printing-PrintToPDFServices-Features'
            'MSRDC-Infrastructure'
            'NetFx4-AdvSrvs'
            'SearchEngine-Client-Package'
            'SmbDirect'
            'WCF-Services45'
            'WCF-TCP-PortSharing45'
            'Windows-Defender-Default-Definitions'
        )

        $WindowsCapabilityBlockRegex = '^DirectX|^Language|^MicrosoftWindows\.Client\.WebExperience|^Microsoft\.Windows\.Ethernet|^Microsoft\.Windows\.Wifi|^OneCoreUAP\.OneSync|^OpenSSH\.Client|^Print\.Management\.Console|^Windows\.Kernel\.LA57|^WMIC'

        $AppProvisionedPackageBlock = @(
            'Microsoft.DesktopAppInstaller'
            'Microsoft.SecHealthUI'
            'Microsoft.VCLibs.140.00'
            'Microsoft.WindowsStore'
            'Microsoft.WindowsTerminal'
            'MicrosoftWindows.Client.WebExperience'
            'Microsoft.HEVCVideoExtension' # <-- 1€ !!!
        )

    }

    process {

        $WindowsOptionalFeatureBlock | ForEach-Object {
            if ($WindowsOptionalFeature -notcontains $_) { $WindowsOptionalFeature += $_ }
        }

        $AppProvisionedPackageBlock | ForEach-Object {
            if ($AppProvisionedPackage -notcontains $_) { $AppProvisionedPackage += $_ }
        }

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


            'Removing *layout*.xml + *start*.bin ...' | Write-Host -ForegroundColor Yellow
            Get-ChildItem (Join-Path $VHDRoot 'Users') -Directory | ForEach-Object {

                Get-ChildItem (Join-Path $_.FullName 'Appdata\Local\Microsoft\Windows\Shell') -Filter '*layout*.xml' -ErrorAction SilentlyContinue | ForEach-Object {
                    Remove-Item $_.FullName -Force -Verbose
                }

                Get-ChildItem (Join-Path $_.FullName 'AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState') -Filter '*start*.bin' -ErrorAction SilentlyContinue | ForEach-Object {
                    Remove-Item $_.FullName -Force -Verbose
                }

            }


            'Disable-WindowsOptionalFeature(s) ...' | Write-Host -ForegroundColor Yellow

            'Exceptions:' | Write-Host -ForegroundColor Yellow
            $WindowsOptionalFeature | Write-Host -ForegroundColor Yellow

            Get-WindowsOptionalFeature -Path $VHDRoot | Where-Object { $_.State -eq 'Enabled' -and $_.FeatureName -notin $WindowsOptionalFeature } | ForEach-Object {
                $_.FeatureName | Write-Host
                $_ | Disable-WindowsOptionalFeature
            }


            'Remove-WindowsCapability(s) ...' | Write-Host -ForegroundColor Yellow

            'Exceptions:' | Write-Host -ForegroundColor Yellow
            $WindowsCapability | Write-Host -ForegroundColor Yellow
            $WindowsCapabilityBlockRegex | Write-Host -ForegroundColor Yellow

            Get-WindowsCapability -Path $VHDRoot | Where-Object { $_.State -eq 'Installed' -and $_.Name -NotIn $WindowsCapability -and $_.Name -NotMatch $WindowsCapabilityBlockRegex } | ForEach-Object {
                $_.Name | Write-Host
                $_ | Remove-WindowsCapability
            }


            'Remove-AppProvisionedPackage(s) ...' | Write-Host -ForegroundColor Yellow

            'Exceptions:' | Write-Host -ForegroundColor Yellow
            $AppProvisionedPackage | Write-Host -ForegroundColor Yellow

            Get-AppProvisionedPackage -Path $VHDRoot | Where-Object DisplayName -NotIn $AppProvisionedPackage | ForEach-Object {
                $_.DisplayName | Write-Host
                $_ | Remove-AppProvisionedPackage
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
