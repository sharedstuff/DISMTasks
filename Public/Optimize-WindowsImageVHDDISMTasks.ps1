function Optimize-WindowsImageDISMTasks {

    [CmdletBinding()]
    param (

        <#
        Mandatory
        #>

        # The complete path to the WIM or ISO file that will be converted to a Virtual Hard Disk.
        # The ISO file must be valid Windows installation media to be recognized successfully.
        [Parameter(Mandatory)]
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
        [Parameter(Mandatory)]
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

        # WindowsOptionalFeature(s) FeatureName(s) to keep during the process
        [Parameter()]
        [string[]]
        $WindowsOptionalFeature = @(
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
        ),

        # WindowsCapability(s) Name(s) to keep during the process
        [Parameter()]
        [string[]]
        $WindowsCapability = @(),

        # Regex of WindowsCapability(s) Name(s) to keep during the process
        [Parameter()]
        [string]
        $WindowsCapabilityRegex = '^DirectX|^Language|^MicrosoftWindows\.Client\.WebExperience|^Microsoft\.Windows\.Ethernet|^Microsoft\.Windows\.Wifi|^OneCoreUAP\.OneSync|^OpenSSH\.Client|^Print\.Management\.Console|^Windows\.Kernel\.LA57|^WMIC',

        # AppProvisionedPackage(s) DisplayName(s) to keep during the process
        [Parameter()]
        [string[]]
        $AppProvisionedPackage = @(
            'Microsoft.DesktopAppInstaller'
            'Microsoft.SecHealthUI'
            'Microsoft.VCLibs.140.00'
            'Microsoft.WindowsStore'
            'Microsoft.WindowsTerminal'
            'MicrosoftWindows.Client.WebExperience'
        )

    )

    begin {

        'Optimize-WindowsImageDISMTasks ...' | Write-Host -ForegroundColor Yellow

        # WorkVHD
        'Copy CacheVHD to MinimizedVHD (at CachePath) ...' | Write-Host -ForegroundColor Yellow
        $CopyItemParams = @{
            Path        = $SourcePath
            Destination = $VHDPath
            Force       = $true
        }
        '... process ...' | Write-Host -ForegroundColor Yellow
        Copy-Item @CopyItemParams
        '... done' | Write-Host -ForegroundColor Green


        # Check if allready mounted
        if ((Get-DiskImage $VHDPath).Attached) {
            throw 'VHD is attached!'
        }

    }

    process {

        try {

            # Mount
            'Mount-DiskImage ...' | Write-Host -ForegroundColor Yellow
            '... process ...' | Write-Host -ForegroundColor Yellow
            $DiskImage = Mount-DiskImage $VHDPath
            $Volume = $DiskImage | Get-Disk | Get-Partition | Get-Volume
            $DriveLetter = $Volume.DriveLetter | Sort-Object -Unique
            if ($DriveLetter.Count -gt 1) { throw 'Multiple DriveLetters found!' }
            if ($DriveLetter.Count -lt 1) { throw 'No DriveLetters found!' }
            $VHDRoot = '{0}:\' -f $DriveLetter
            '... done' | Write-Host -ForegroundColor Green


            'Tasks on the VHD ...' | Write-Host -ForegroundColor Yellow
            '... process ...' | Write-Host -ForegroundColor Yellow


            # Purge StartMenu
            'Removing *layout*.xml + *start*.bin ...' | Write-Host -ForegroundColor Yellow
            '... process ...' | Write-Host -ForegroundColor Yellow
            Get-ChildItem (Join-Path $VHDRoot 'Users') -Directory | ForEach-Object {

                Get-ChildItem (Join-Path $_.FullName 'Appdata\Local\Microsoft\Windows\Shell') -Filter '*layout*.xml' -ErrorAction SilentlyContinue | ForEach-Object {
                    Remove-Item $_.FullName -Force
                }

                Get-ChildItem (Join-Path $_.FullName 'AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState') -Filter '*start*.bin' -ErrorAction SilentlyContinue | ForEach-Object {
                    Remove-Item $_.FullName -Force
                }

            }
            '... done' | Write-Host -ForegroundColor Green


            # WindowsOptionalFeature
            'Disable-WindowsOptionalFeature(s) ...' | Write-Host -ForegroundColor Yellow
            'Exceptions:' | Write-Host -ForegroundColor Yellow
            $WindowsOptionalFeature | Write-Host -ForegroundColor Yellow
            '... process ...' | Write-Host -ForegroundColor Yellow
            Get-WindowsOptionalFeature -Path $VHDRoot `
            | Where-Object { $_.State -eq 'Enabled' -and $_.FeatureName -notin $WindowsOptionalFeature } `
            | ForEach-Object {
                $_.FeatureName | Write-Host
                $null = $_ | Disable-WindowsOptionalFeature
            }
            '... done' | Write-Host -ForegroundColor Green


            # WindowsCapability
            'Remove-WindowsCapability(s) ...' | Write-Host -ForegroundColor Yellow
            'Exceptions:' | Write-Host -ForegroundColor Yellow
            $WindowsCapability | Write-Host -ForegroundColor Yellow
            $WindowsCapabilityRegex | Write-Host -ForegroundColor Yellow
            '... process ...' | Write-Host -ForegroundColor Yellow
            Get-WindowsCapability -Path $VHDRoot `
            | Where-Object { $_.State -eq 'Installed' -and $_.Name -NotIn $WindowsCapability -and $_.Name -NotMatch $WindowsCapabilityRegex } `
            | ForEach-Object {
                $_.Name | Write-Host
                $null = $_ | Remove-WindowsCapability
            }
            '... done' | Write-Host -ForegroundColor Green


            # AppProvisionedPackage
            'Remove-AppProvisionedPackage(s) ...' | Write-Host -ForegroundColor Yellow
            'Exceptions:' | Write-Host -ForegroundColor Yellow
            $AppProvisionedPackage | Write-Host -ForegroundColor Yellow
            '... process ...' | Write-Host -ForegroundColor Yellow
            Get-AppProvisionedPackage -Path $VHDRoot `
            | Where-Object DisplayName -NotIn $AppProvisionedPackage `
            | ForEach-Object {
                $_.DisplayName | Write-Host
                $null = $_ | Remove-AppProvisionedPackage
            }
            '... done' | Write-Host -ForegroundColor Green


            # Specification.json file
            'Generate .Specification.json file ...' | Write-Host -ForegroundColor Yellow
            '... process ...' | Write-Host -ForegroundColor Yellow
            $Specification = @{
                Edition                = (Get-WindowsEdition -Path $VHDRoot).Edition
                WindowsOptionalFeature = Get-WindowsOptionalFeature -Path $VHDRoot | Where-Object State -EQ 'Enabled' | Select-Object -ExpandProperty FeatureName
                WindowsCapability      = Get-WindowsCapability -Path $VHDRoot | Where-Object State -EQ 'Installed' | Select-Object -ExpandProperty Name
                AppProvisionedPackage  = Get-AppProvisionedPackage -Path $VHDRoot | Select-Object DisplayName, PackageName, Version, PublisherId, InstallLocation
                WindowsDriver          = Get-WindowsDriver -Path $VHDRoot
            }
            $Specification | ConvertTo-Json -Depth 5 | Set-Content -Path ('{0}.Specification.json' -f $VHDPath)
            '... done' | Write-Host -ForegroundColor Green

        }

        catch {

            'Error during build' | Write-Host -ForegroundColor Red

            'Unmount-DiskImage ...' | Write-Host -ForegroundColor Red
            $null = $DiskImage | Dismount-DiskImage

            'Remove VHD ...' | Write-Host -ForegroundColor Red
            Remove-Item $VHDPath -Force

            throw $_

        }

        finally {

            # Unmount
            'Unmount-DiskImage ...' | Write-Host -ForegroundColor Yellow
            '... process ...' | Write-Host -ForegroundColor Yellow
            $null = $DiskImage | Dismount-DiskImage
            '... done' | Write-Host -ForegroundColor Green

        }

    }

    end {
        '... Optimize-WindowsImageDISMTasks done' -f $MyInvocation.MyCommand | Write-Host -ForegroundColor Green
    }

}
