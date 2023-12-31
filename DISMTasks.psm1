function Invoke-DISMTasks {

    <#

        .SYNOPSIS
        Invokes DISMTasks

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
                if ($_ -notmatch '(\.iso|\.wim)') {
                    throw 'File must be either of type iso or wim.'
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

        # The name or image index of the image to apply from the WIM.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]
        $Edition,


        # Optimize
        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]
        $Optimize,

        # The size of the Virtual Hard Disk to create.
        [Parameter(ValueFromPipelineByPropertyName)]
        [ulong]
        $SizeBytes = 128GB,

        # The path of a directory for use as build cache
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateScript(
            {
                if (-Not ($_ | Test-Path) ) {
                    $null = New-Item $_ -ItemType Directory
                }
                if (-Not ($_ | Test-Path -PathType Container) ) {
                    throw 'Argument must be a directory.'
                }
                return $true
            }
        )]
        [System.IO.FileInfo]
        $CachePath = '.\.cache',


        # AppProvisionedPackage(s) DisplayName(s) to keep during the process
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]
        $AppProvisionedPackage,

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

        # WindowsCapability(s)
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]
        $WindowsCapability = @(),

        # WindowsOptionalFeature(s)
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]
        $WindowsOptionalFeature = @(),


        # The name of the VM to use/create.
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $Name,

        # Start the VM at the end of the build process.
        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]
        $StartVM,

        # Connect to the VM at the end of the build process.
        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]
        $ConnectVM,

        # VM SwitchName
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $SwitchName = 'Default Switch',

        # VM ProcessorCount
        [Parameter(ValueFromPipelineByPropertyName)]
        [int]
        $ProcessorCount = 4,

        # VM DynamicMemory
        [Parameter(ValueFromPipelineByPropertyName)]
        [bool]
        $DynamicMemory = $true,

        # VM MemoryStartupBytes
        [Parameter(ValueFromPipelineByPropertyName)]
        [int64]
        $MemoryStartupBytes = 2GB,

        # VM MemoryMinimumBytes
        [Parameter(ValueFromPipelineByPropertyName)]
        [int64]
        $MemoryMinimumBytes = 2GB,

        # VM MemoryMaximumBytes
        [Parameter(ValueFromPipelineByPropertyName)]
        [int64]
        $MemoryMaximumBytes = 8GB,

        # VM AutomaticStartAction
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $AutomaticStartAction = 'Nothing',

        # VM AutomaticStopAction
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $AutomaticStopAction = 'ShutDown',

        # VM CheckpointType
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $CheckpointType = 'Disabled'

    )

    begin {
        $Script:ErrorActionPreference = 'Stop'
        '{0} begin ...' -f $MyInvocation.MyCommand | Write-Host -ForegroundColor Cyan
    }

    process {

        # Convert
        $InvokeDISMTasksConvertParams = @{
            SourcePath = $SourcePath
            VHDPath    = Join-Path $CachePath (('{0}.{1}.vhdx') -f (Get-Item $SourcePath).BaseName, $Edition)
            Edition    = $Edition
        }
        @(
            'SizeBytes'
        ) | ForEach-Object {
            $Value = Get-Variable -Name $_ -ValueOnly
            if ($Value) { $InvokeDISMTasksConvertParams.$_ = $Value }
        }

        if (Test-Path $InvokeDISMTasksConvertParams.VHDPath) {
            'Skipping Invoke-DISMTasksConvert - using cache' | Write-Host -ForegroundColor Green
        }
        else {
            Invoke-DISMTasksConvert @InvokeDISMTasksConvertParams
        }


        # Optimize
        $InvokeDISMTasksOptimizeParams = @{
            SourcePath = $InvokeDISMTasksConvertParams.VHDPath
            VHDPath    = '{0}.Optimize.vhdx' -f $VHDPath
        }
        @(
            'AppProvisionedPackage'
            'WindowsCapability'
            'WindowsOptionalFeature'
        ) | ForEach-Object {
            $Value = Get-Variable -Name $_ -ValueOnly
            if ($Value) { $InvokeDISMTasksOptimizeParams.$_ = $Value }
        }
        if ($Optimize) {
            if (Test-Path $InvokeDISMTasksOptimizeParams.VHDPath) {
                'Skipping Invoke-DISMTasksOptimize - using cache' | Write-Host -ForegroundColor Green
            }
            else {
                Invoke-DISMTasksOptimize @InvokeDISMTasksOptimizeParams
            }
        }


        # Build
        $InvokeDISMTasksBuildParams = @{
            SourcePath = & {
                if ($Optimize) { $InvokeDISMTasksOptimizeParams.VHDPath }
                else { $InvokeDISMTasksConvertParams.VHDPath }
            }
            VHDPath    = '{0}.Build.vhdx' -f $VHDPath
        }
        @(
            'AppProvisionedPackagePath'
            'DriverPath'
            'MergePath'
            'PackagePath'
            'WindowsCapability'
            'WindowsOptionalFeature'
        ) | ForEach-Object {
            $Value = Get-Variable -Name $_ -ValueOnly
            if ($Value) { $InvokeDISMTasksBuildParams.$_ = $Value }
        }
        if (Test-Path $InvokeDISMTasksBuildParams.VHDPath) {
            'Skipping Invoke-DISMTasksBuild - using cache' | Write-Host -ForegroundColor Green
        }
        else {
            Invoke-DISMTasksBuild @InvokeDISMTasksBuildParams
        }


        # VM
        $InvokeDISMTasksVMParams = @{
            SourcePath           = $InvokeDISMTasksBuildParams.VHDPath
            VHDPath              = '{0}.VM.vhdx' -f $VHDPath
            Name                 = $Name
            StartVM              = $StartVM
            ConnectVM            = $ConnectVM
            SwitchName           = $SwitchName
            ProcessorCount       = $ProcessorCount
            DynamicMemory        = $DynamicMemory
            MemoryStartupBytes   = $MemoryStartupBytes
            MemoryMinimumBytes   = $MemoryMinimumBytes
            MemoryMaximumBytes   = $MemoryMaximumBytes
            AutomaticStartAction = $AutomaticStartAction
            AutomaticStopAction  = $AutomaticStopAction
            CheckpointType       = $CheckpointType
        }
        Invoke-DISMTasksVM @InvokeDISMTasksVMParams

    }

    end {
        '... {0} end' -f $MyInvocation.MyCommand | Write-Host -ForegroundColor Green
    }

}
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
function Invoke-DISMTasksConvert {

    <#

        .SYNOPSIS
        Invoke-DISMTasks "Convert" task

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
                if ($_ -notmatch '(\.iso|\.wim)') {
                    throw 'File must be either of type iso or wim.'
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

        # The name or image index of the image to apply from the WIM.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]
        $Edition,

        # The size of the Virtual Hard Disk to create.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ulong]
        $SizeBytes

    )

    begin {
        $Script:ErrorActionPreference = 'Stop'
        Start-TranscriptDISMTasks ('{0}.log' -f $VHDPath)
        '{0} begin ...' -f $MyInvocation.MyCommand | Write-Host -ForegroundColor Cyan
    }

    process {

        $ConvertWindowsImageParams = @{
            SourcePath = $SourcePath
            VHDPath    = $VHDPath
            Edition    = $Edition
            SizeBytes  = $SizeBytes
            # Standard options here
            DiskLayout = 'UEFI'
        }

        try {

            # Check if allready mounted
            if ((Get-DiskImage $VHDPath -ErrorAction SilentlyContinue).Attached) {
                throw 'VHD is attached!'
            }

            Convert-WindowsImage @ConvertWindowsImageParams

            $VHDRoot = $VHDPath | Mount-VHDDISMTasks

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
function Invoke-DISMTasksVM {

    <#

        .SYNOPSIS
        Invoke-DISMTasks "VM" task

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

        # The name of the VM to use/create.
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $Name,

        # Start the VM at the end of the build process.
        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]
        $StartVM,

        # Connect to the VM at the end of the build process.
        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]
        $ConnectVM,

        # VM SwitchName
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $SwitchName = 'Default Switch',

        # VM ProcessorCount
        [Parameter(ValueFromPipelineByPropertyName)]
        [int]
        $ProcessorCount = 4,

        # VM DynamicMemory
        [Parameter(ValueFromPipelineByPropertyName)]
        [bool]
        $DynamicMemory = $true,

        # VM MemoryStartupBytes
        [Parameter(ValueFromPipelineByPropertyName)]
        [int64]
        $MemoryStartupBytes = 2GB,

        # VM MemoryMinimumBytes
        [Parameter(ValueFromPipelineByPropertyName)]
        [int64]
        $MemoryMinimumBytes = 2GB,

        # VM MemoryMaximumBytes
        [Parameter(ValueFromPipelineByPropertyName)]
        [int64]
        $MemoryMaximumBytes = 8GB,

        # VM AutomaticStartAction
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $AutomaticStartAction = 'Nothing',

        # VM AutomaticStopAction
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $AutomaticStopAction = 'ShutDown',

        # VM CheckpointType
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $CheckpointType = 'Disabled'

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

            'VM ...' | Write-Host -ForegroundColor Yellow

            'Get-/New-VM ...' | Write-Host -ForegroundColor Yellow
            $NewVMParams = @{
                VHDPath    = $VHDPath
                Generation = 2
                Name       = $Name
            }

            $SetVMParams = @{
                AutomaticStartAction = $AutomaticStartAction
                AutomaticStopAction  = $AutomaticStopAction
                CheckpointType       = $CheckpointType
                DynamicMemory        = $DynamicMemory
                ProcessorCount       = $ProcessorCount
                MemoryMinimumBytes   = $MemoryMinimumBytes
                MemoryMaximumBytes   = $MemoryMaximumBytes
                MemoryStartupBytes   = $MemoryStartupBytes
                Notes                = 'created by DISMTasks on {0}' -f (Get-Date -Format s)
            }


            $VM = Get-VM $NewVMParams.Name -ErrorAction SilentlyContinue
            if ($VM -and $VM.Generation -eq 2 -and $NewVMParams.VHDPath -in $VM.HardDrives.Path) {
                '... using cache ...' | Write-Host -ForegroundColor Green
            }
            else {
                $VM = New-VM @NewVMParams
                $VM | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName $SwitchName
                $VM | Get-VMIntegrationService | Where-Object Enabled -EQ $false | ForEach-Object { $VM | Enable-VMIntegrationService -Name $_.Name }
                $VM | Set-VM @SetVMParams
            }


            if ($VM -and $StartVM) {
                'Start-VM ...' | Write-Host -ForegroundColor Yellow
                $VM | Start-VM
            }


            if ($VM -and $StartVM -and $ConnectVM) {
                'Connect-VM (vmconnect.exe) ...' | Write-Host -ForegroundColor Yellow
                '... process ...' | Write-Host -ForegroundColor Yellow
                vmconnect.exe $Env:COMPUTERNAME $VM.Name
                '... done' | Write-Host -ForegroundColor Green
            }

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
function Convert-WindowsImage
{
    #Requires -Version 3.0
    [CmdletBinding(DefaultParameterSetName="SRC")]

    param(
        [Parameter(ParameterSetName="SRC", Mandatory=$true, ValueFromPipeline=$true)]
        [Alias("WIM")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        $SourcePath,

        [Parameter(ParameterSetName="SRC")]
        [switch]
        $CacheSource = $false,

        [Parameter(ParameterSetName="SRC")]
        [Alias("SKU")]
        [string[]]
        [ValidateNotNullOrEmpty()]
        $Edition,

        [Parameter(ParameterSetName="SRC")]
        [Alias("WorkDir")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $_ })]
        $WorkingDirectory = $pwd,

        [Parameter(ParameterSetName="SRC")]
        [Alias("TempDir")]
        [string]
        [ValidateNotNullOrEmpty()]
        $TempDirectory = $env:Temp,

        [Parameter(ParameterSetName="SRC")]
        [Alias("VHD")]
        [string]
        [ValidateNotNullOrEmpty()]
        $VHDPath,

        [Parameter(ParameterSetName="SRC")]
        [Alias("Size")]
        [UInt64]
        [ValidateNotNullOrEmpty()]
        [ValidateRange(512MB, 64TB)]
        $SizeBytes = 25GB,

        [Parameter(ParameterSetName="SRC")]
        [Alias("Format")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("VHD", "VHDX", "AUTO")]
        $VHDFormat = "AUTO",

        [Parameter(ParameterSetName="SRC")]
        [Alias("MergeFolder")]
        [string]
        [ValidateNotNullOrEmpty()]
        $MergeFolderPath = "",

        [Parameter(ParameterSetName="SRC", Mandatory=$true)]
        [Alias("Layout")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("BIOS", "UEFI")]
        $DiskLayout,

        [Parameter(ParameterSetName="SRC")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("NativeBoot", "VirtualMachine")]
        $BCDinVHD = "VirtualMachine",

        [Parameter(ParameterSetName="SRC")]
        [Parameter(ParameterSetName="UI")]
        [string]
        $BCDBoot = "bcdboot.exe",

        [Parameter(ParameterSetName="SRC")]
        [string[]]
        [ValidateNotNullOrEmpty()]
        $Feature,

        [Parameter(ParameterSetName="SRC")]
        [string[]]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        $Driver,

        [Parameter(ParameterSetName="SRC")]
        [string[]]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        $Package,

        [Parameter(ParameterSetName="SRC")]
        [switch]
        $ExpandOnNativeBoot = $true,

        [Parameter(ParameterSetName="SRC")]
        [switch]
        $RemoteDesktopEnable = $false,

        [Parameter(ParameterSetName="SRC")]
        [Alias("Unattend")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        $UnattendPath,

        [Parameter(ParameterSetName="SRC")]
        [Parameter(ParameterSetName="UI")]
        [switch]
        $Passthru,

        [Parameter(ParameterSetName="SRC")]
        [string]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $(Resolve-Path $_) })]
        $DismPath,

        [Parameter(ParameterSetName="SRC")]
        [switch]
        $ApplyEA = $false,

        [Parameter(ParameterSetName="UI")]
        [switch]
        $ShowUI
    )
    #region Code

    Begin
    {
        # Version information that can be populated by timebuild.
        $ScriptVersion = DATA
        {
    ConvertFrom-StringData -StringData @"
        Major     = 10
        Minor     = 0
        Build     = 14278
        Qfe       = 1000
        Branch    = rs1_es_media
        Timestamp = 160201-1707
        Flavor    = amd64fre
"@
}

        $myVersion              = "$($ScriptVersion.Major).$($ScriptVersion.Minor).$($ScriptVersion.Build).$($ScriptVersion.QFE).$($ScriptVersion.Flavor).$($ScriptVersion.Branch).$($ScriptVersion.Timestamp)"
        $scriptName             = "Convert-WindowsImage"                       # Name of the script, obviously.
        $sessionKey             = [Guid]::NewGuid().ToString()                 # Session key, used for keeping records unique between multiple runs.
        $logFolder              = "$($TempDirectory)\$($scriptName)\$($sessionKey)" # Log folder path.
        $vhdMaxSize             = 2040GB                                       # Maximum size for VHD is ~2040GB.
        $lowestSupportedBuild   = 9200                                         # The lowest supported *host* build.  Set to Win8 CP.
        $transcripting          = $false

        # Since we use the VHDFormat in output, make it uppercase.
        # We'll make it lowercase again when we use it as a file extension.
        $VHDFormat              = $VHDFormat.ToUpper()
        ##########################################################################################
        #                                      Here Strings
        ##########################################################################################

        # Banner text displayed during each run.
        $header    = @"

Windows(R) Image to Virtual Hard Disk Converter for Windows(R) 10
Copyright (C) Microsoft Corporation.  All rights reserved.
Version $myVersion

"@

        #region Helper Functions

        ##########################################################################################
        #                                   Helper Functions
        ##########################################################################################

        <#
            Functions to mount and dismount registry hives.
            These hives will automatically be accessible via the HKLM:\ registry PSDrive.

            It should be noted that I have more confidence in using the RegLoadKey and
            RegUnloadKey Win32 APIs than I do using REG.EXE - it just seems like we should
            do things ourselves if we can, instead of using yet another binary.

            Consider this a TODO for future versions.
        #>
        function Mount-RegistryHive
        {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
                [System.IO.FileInfo]
                [ValidateNotNullOrEmpty()]
                [ValidateScript({ $_.Exists })]
                $Hive
            )

            $mountKey = [System.Guid]::NewGuid().ToString()
            $regPath  = "REG.EXE"

            if (Test-Path HKLM:\$mountKey)
            {
                throw "The registry path already exists.  I should just regenerate it, but I'm lazy."
            }

            $regArgs = (
                "LOAD",
                "HKLM\$mountKey",
                $Hive.Fullname
            )
            try
            {

                Run-Executable -Executable $regPath -Arguments $regArgs

            }
            catch
            {
                throw
            }

            # Set a global variable containing the name of the mounted registry key
            # so we can unmount it if there's an error.
            $global:mountedHive = $mountKey

            return $mountKey
        }

        ##########################################################################################

        Function Dismount-RegistryHive
        {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
                [string]
                [ValidateNotNullOrEmpty()]
                $HiveMountPoint
            )

            $regPath = "REG.EXE"

            $regArgs = (
                "UNLOAD",
                "HKLM\$($HiveMountPoint)"
            )

            Run-Executable -Executable $regPath -Arguments $regArgs

            $global:mountedHive = $null
        }

        ##########################################################################################

        function
        Test-Admin
        {
            <#
                .SYNOPSIS
                    Short function to determine whether the logged-on user is an administrator.

                .EXAMPLE
                    Do you honestly need one?  There are no parameters!

                .OUTPUTS
                    $true if user is admin.
                    $false if user is not an admin.
            #>
            [CmdletBinding()]
            param()

            $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
            $isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
            Write-W2VTrace "isUserAdmin? $isAdmin"

            return $isAdmin
        }

        ##########################################################################################

        function
        Get-WindowsBuildNumber
        {
            $os = Get-CimInstance -ClassName "Win32_OperatingSystem"
            return [int]($os.BuildNumber)
        }

        ##########################################################################################

        function
        Test-WindowsVersion
        {
            $isWin8 = ((Get-WindowsBuildNumber) -ge [int]$lowestSupportedBuild)

            Write-W2VTrace "is Windows 8 or Higher? $isWin8"
            return $isWin8
        }

        ##########################################################################################

        function
        Write-W2VInfo
        {
        # Function to make the Write-Host output a bit prettier.
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [string]
                [ValidateNotNullOrEmpty()]
                $text
            )
            Write-Host "INFO   : $($text)"
        }

        ##########################################################################################

        function
        Write-W2VTrace
        {
        # Function to make the Write-Verbose output... well... exactly the same as it was before.
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [string]
                [ValidateNotNullOrEmpty()]
                $text
            )
            Write-Verbose $text
        }

        ##########################################################################################

        function
        Write-W2VError
        {
        # Function to make the Write-Host (NOT Write-Error) output prettier in the case of an error.
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [string]
                [ValidateNotNullOrEmpty()]
                $text
            )
            Write-Host "ERROR  : $($text)" -ForegroundColor Red
        }

        ##########################################################################################

        function
        Write-W2VWarn
        {
        # Function to make the Write-Host (NOT Write-Warning) output prettier.
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [string]
                [ValidateNotNullOrEmpty()]
                $text
            )
            Write-Host "WARN   : $($text)" -ForegroundColor Yellow
        }

        ##########################################################################################

        function
        Run-Executable
        {
            <#
                .SYNOPSIS
                    Runs an external executable file, and validates the error level.

                .PARAMETER Executable
                    The path to the executable to run and monitor.

                .PARAMETER Arguments
                    An array of arguments to pass to the executable when it's executed.

                .PARAMETER SuccessfulErrorCode
                    The error code that means the executable ran successfully.
                    The default value is 0.
            #>

            [CmdletBinding()]
            param(
                [Parameter(Mandatory=$true)]
                [string]
                [ValidateNotNullOrEmpty()]
                $Executable,

                [Parameter(Mandatory=$true)]
                [string[]]
                [ValidateNotNullOrEmpty()]
                $Arguments,

                [Parameter()]
                [int]
                [ValidateNotNullOrEmpty()]
                $SuccessfulErrorCode = 0

            )

            Write-W2VTrace "Running $Executable $Arguments"
            $ret = Start-Process           `
                -FilePath $Executable      `
                -ArgumentList $Arguments   `
                -NoNewWindow               `
                -Wait                      `
                -RedirectStandardOutput "$($TempDirectory)\$($scriptName)\$($sessionKey)\$($Executable)-StandardOutput.txt" `
                -RedirectStandardError  "$($TempDirectory)\$($scriptName)\$($sessionKey)\$($Executable)-StandardError.txt"  `
                -Passthru

            Write-W2VTrace "Return code was $($ret.ExitCode)."

            if ($ret.ExitCode -ne $SuccessfulErrorCode)
            {
                throw "$Executable failed with code $($ret.ExitCode)!"
            }
        }

        ##########################################################################################
        Function Test-IsNetworkLocation
        {
            <#
                .SYNOPSIS
                    Determines whether or not a given path is a network location or a local drive.

                .DESCRIPTION
                    Function to determine whether or not a specified path is a local path, a UNC path,
                    or a mapped network drive.

                .PARAMETER Path
                    The path that we need to figure stuff out about,
            #>

            [CmdletBinding()]
            param(
                [Parameter(ValueFromPipeLine = $true)]
                [string]
                [ValidateNotNullOrEmpty()]
                $Path
            )

            $result = $false

            if ([bool]([URI]$Path).IsUNC)
            {
                $result = $true
            }
            else
            {
                $driveInfo = [IO.DriveInfo]((Resolve-Path $Path).Path)

                if ($driveInfo.DriveType -eq "Network")
                {
                    $result = $true
                }
            }

            return $result
        }
        ##########################################################################################

        #endregion Helper Functions
    }

    Process
    {
        Write-Host $header
        
        $disk           = $null
        $openWim        = $null
        $openIso        = $null
        $vhdFinalName   = $null
        $vhdFinalPath   = $null
        $mountedHive    = $null
        $isoPath        = $null
        $tempSource     = $null
        $vhd            = @()

        try
        {
            # Create log folder
            if (Test-Path $logFolder)
            {
                $null = Remove-Item $logFolder -Force -Recurse
            }

            $null = mkdir $logFolder -Force

            # Try to start transcripting.  If it's already running, we'll get an exception and swallow it.
            try
            {
                $null = Start-Transcript -Path (Join-Path $logFolder "Convert-WindowsImageTranscript.txt") -Force -ErrorAction SilentlyContinue
                $transcripting = $true
            }
            catch
            {
                Write-W2VWarn "Transcription is already running.  No Convert-WindowsImage-specific transcript will be created."
                $transcripting = $false
            }

            #
            # Add types
            #
            #Add-WindowsImageTypes

            # Check to make sure we're running as Admin.
            if (!(Test-Admin))
            {
                throw "Images can only be applied by an administrator.  Please launch PowerShell elevated and run this script again."
            }

            # Check to make sure we're running on Win8.
            if (!(Test-WindowsVersion))
            {
                throw "$scriptName requires Windows 8 Consumer Preview or higher.  Please use WIM2VHD.WSF (http://code.msdn.microsoft.com/wim2vhd) if you need to create VHDs from Windows 7."
            }

            # Resolve the path for the unattend file.
            if (![string]::IsNullOrEmpty($UnattendPath))
            {
                $UnattendPath = (Resolve-Path $UnattendPath).Path
            }

            if ($VHDFormat -ilike "AUTO")
            {
                if ($DiskLayout -eq "BIOS")
                {
                    $VHDFormat = "VHD"
                }
                else
                {
                    $VHDFormat = "VHDX"
                }
            }

            #
            # Choose smallest supported block size for dynamic VHD(X)
            #
            $BlockSizeBytes = 1MB

            # There's a difference between the maximum sizes for VHDs and VHDXs.  Make sure we follow it.
            if ("VHD" -ilike $VHDFormat)
            {
                if ($SizeBytes -gt $vhdMaxSize)
                {
                    Write-W2VWarn "For the VHD file format, the maximum file size is ~2040GB.  We're automatically setting the size to 2040GB for you."
                    $SizeBytes = 2040GB
                }

                $BlockSizeBytes = 512KB
            }

            # Check if -VHDPath and -WorkingDirectory were both specified.
            if ((![String]::IsNullOrEmpty($VHDPath)) -and (![String]::IsNullOrEmpty($WorkingDirectory)))
            {
                if ($WorkingDirectory -ne $pwd)
                {
                    # If the WorkingDirectory is anything besides $pwd, tell people that the WorkingDirectory is being ignored.
                    Write-W2VWarn "Specifying -VHDPath and -WorkingDirectory at the same time is contradictory."
                    Write-W2VWarn "Ignoring the WorkingDirectory specification."
                    $WorkingDirectory = Split-Path $VHDPath -Parent
                }
            }

            if ($VHDPath)
            {
                # Check to see if there's a conflict between the specified file extension and the VHDFormat being used.
                $ext = ([IO.FileInfo]$VHDPath).Extension

                if (!($ext -ilike ".$($VHDFormat)"))
                {
                    throw "There is a mismatch between the VHDPath file extension ($($ext.ToUpper())), and the VHDFormat (.$($VHDFormat)).  Please ensure that these match and try again."
                }
            }

            # Create a temporary name for the VHD(x).  We'll name it properly at the end of the script.
            if ([String]::IsNullOrEmpty($VHDPath))
            {
                $VHDPath      = Join-Path $WorkingDirectory "$($sessionKey).$($VHDFormat.ToLower())"
            }
            else
            {
                # Since we can't do Resolve-Path against a file that doesn't exist, we need to get creative in determining
                # the full path that the user specified (or meant to specify if they gave us a relative path).
                # Check to see if the path has a root specified.  If it doesn't, use the working directory.
                if (![IO.Path]::IsPathRooted($VHDPath))
                {
                    $VHDPath  = Join-Path $WorkingDirectory $VHDPath
                }

                $vhdFinalName = Split-Path $VHDPath -Leaf
                $VHDPath      = Join-Path (Split-Path $VHDPath -Parent) "$($sessionKey).$($VHDFormat.ToLower())"
            }

            Write-W2VTrace "Temporary $VHDFormat path is : $VHDPath"

            # If we're using an ISO, mount it and get the path to the WIM file.
            if (([IO.FileInfo]$SourcePath).Extension -ilike ".ISO")
            {
                # If the ISO isn't local, copy it down so we don't have to worry about resource contention
                # or about network latency.
                if (Test-IsNetworkLocation $SourcePath)
                {
                    Write-W2VInfo "Copying ISO $(Split-Path $SourcePath -Leaf) to temp folder..."
                    robocopy $(Split-Path $SourcePath -Parent) $TempDirectory $(Split-Path $SourcePath -Leaf) | Out-Null
                    $SourcePath = "$($TempDirectory)\$(Split-Path $SourcePath -Leaf)"

                    $tempSource = $SourcePath
                }

                $isoPath = (Resolve-Path $SourcePath).Path

                Write-W2VInfo "Opening ISO $(Split-Path $isoPath -Leaf)..."
                $openIso     = Mount-DiskImage -ImagePath $isoPath -StorageType ISO -PassThru
                # Refresh the DiskImage object so we can get the real information about it.  I assume this is a bug.
                $openIso     = Get-DiskImage -ImagePath $isoPath
                $driveLetter = ($openIso | Get-Volume).DriveLetter

                $SourcePath  = "$($driveLetter):\sources\install.wim"

                # Check to see if there's a WIM file we can muck about with.
                Write-W2VInfo "Looking for $($SourcePath)..."
                if (!(Test-Path $SourcePath))
                {
                    throw "The specified ISO does not appear to be valid Windows installation media."
                }
            }

            # Check to see if the WIM is local, or on a network location.  If the latter, copy it locally.
            if (Test-IsNetworkLocation $SourcePath)
            {
                Write-W2VInfo "Copying WIM $(Split-Path $SourcePath -Leaf) to temp folder..."
                robocopy $(Split-Path $SourcePath -Parent) $TempDirectory $(Split-Path $SourcePath -Leaf) | Out-Null
                $SourcePath = "$($TempDirectory)\$(Split-Path $SourcePath -Leaf)"

                $tempSource = $SourcePath
            }

            $SourcePath  = (Resolve-Path $SourcePath).Path

            ####################################################################################################
            # QUERY WIM INFORMATION AND EXTRACT THE INDEX OF TARGETED IMAGE
            ####################################################################################################

            Write-W2VInfo "Looking for the requested Windows image in the WIM file"
            $WindowsImage = Get-WindowsImage -ImagePath $SourcePath

            if (-not $WindowsImage -or ($WindowsImage -is [System.Array]))
            {
                #
                # WIM may have multiple images.  Filter on Edition (can be index or name) and try to find a unique image
                #
                $EditionIndex = 0;
                if ([Int32]::TryParse($Edition, [ref]$EditionIndex))
                {
                    $WindowsImage = Get-WindowsImage -ImagePath $SourcePath -Index $EditionIndex
                }
                else
                {
                    $WindowsImage = Get-WindowsImage -ImagePath $SourcePath | Where-Object {$_.ImageName -ilike "*$($Edition)"}
                }

                if (-not $WindowsImage)
                {
                    throw "Requested windows Image was not found on the WIM file!"
                }
                if ($WindowsImage -is [System.Array])
                {
                    Write-W2VInfo "WIM file has the following $($WindowsImage.Count) images that match filter *$($Edition)"
                    Get-WindowsImage -ImagePath $SourcePath

                    Write-W2VError "You must specify an Edition or SKU index, since the WIM has more than one image."
                    throw "There are more than one images that match ImageName filter *$($Edition)"
                }
            }

            $ImageIndex = $WindowsImage[0].ImageIndex

            Write-W2VInfo "Creating sparse disk..."
            $newVhd = New-VHD -Path $VHDPath -SizeBytes $SizeBytes -BlockSizeBytes $BlockSizeBytes -Dynamic

            Write-W2VInfo "Mounting $VHDFormat..."
            $disk = $newVhd | Mount-VHD -PassThru | Get-Disk

            switch ($DiskLayout)
            {
                "BIOS"
                {
                    Write-W2VInfo "Initializing disk..."
                    Initialize-Disk -Number $disk.Number -PartitionStyle MBR

                    #
                    # Create the Windows/system partition
                    #
                    Write-W2VInfo "Creating single partition..."
                    $systemPartition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -MbrType IFS -IsActive
                    $windowsPartition = $systemPartition

                    Write-W2VInfo "Formatting windows volume..."
                    $systemVolume = Format-Volume -Partition $systemPartition -FileSystem NTFS -Force -Confirm:$false
                    $windowsVolume = $systemVolume
                }

                "UEFI"
                {
                    Write-W2VInfo "Initializing disk..."
                    Initialize-Disk -Number $disk.Number -PartitionStyle GPT

                    if ((Get-WindowsBuildNumber) -ge 10240)
                    {
                        #
                        # Create the system partition.  Create a data partition so we can format it, then change to ESP
                        #
                        Write-W2VInfo "Creating EFI system partition..."
                        $systemPartition = New-Partition -DiskNumber $disk.Number -Size 200MB -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'

                        Write-W2VInfo "Formatting system volume..."
                        $systemVolume = Format-Volume -Partition $systemPartition -FileSystem FAT32 -Force -Confirm:$false

                        Write-W2VInfo "Setting system partition as ESP..."
                        $systemPartition | Set-Partition -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'
                        $systemPartition | Add-PartitionAccessPath -AssignDriveLetter
                    }
                    else
                    {
                        #
                        # Create the system partition
                        #
                        Write-W2VInfo "Creating EFI system partition (ESP)..."
                        $systemPartition = New-Partition -DiskNumber $disk.Number -Size 200MB -GptType '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}' -AssignDriveLetter

                        Write-W2VInfo "Formatting ESP..."
                        $formatArgs = @(
                            "$($systemPartition.DriveLetter):", # Partition drive letter
                            "/FS:FAT32",                        # File system
                            "/Q",                               # Quick format
                            "/Y"                                # Suppress prompt
                            )

                        Run-Executable -Executable format -Arguments $formatArgs
                    }

                    #
                    # Create the reserved partition
                    #
                    Write-W2VInfo "Creating MSR partition..."
                    $reservedPartition = New-Partition -DiskNumber $disk.Number -Size 128MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'

                    #
                    # Create the Windows partition
                    #
                    Write-W2VInfo "Creating windows partition..."
                    $windowsPartition = New-Partition -DiskNumber $disk.Number -UseMaximumSize -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'

                    Write-W2VInfo "Formatting windows volume..."
                    $windowsVolume = Format-Volume -Partition $windowsPartition -FileSystem NTFS -Force -Confirm:$false
                }
            }

            #
            # Assign drive letter to Windows partition.  This is required for bcdboot
            #

            $attempts = 1
            $assigned = $false

            do
            {
                $windowsPartition | Add-PartitionAccessPath -AssignDriveLetter
                $windowsPartition = $windowsPartition | Get-Partition
                if($windowsPartition.DriveLetter -ne 0)
                {
                    $assigned = $true
                }
                else
                {
                    #sleep for up to 10 seconds and retry
                    Get-Random -Minimum 1 -Maximum 10 | Start-Sleep

                    $attempts++
                }
            }
            while ($attempts -le 100 -and -not($assigned))

            if (-not($assigned))
            {
                throw "Unable to get Partition after retry"
            }

            $windowsDrive = $(Get-Partition -Volume $windowsVolume).AccessPaths[0].substring(0,2)
            Write-W2VInfo "Windows path ($windowsDrive) has been assigned."
            Write-W2VInfo "Windows path ($windowsDrive) took $attempts attempts to be assigned."

            #
            # Refresh access paths (we have now formatted the volume)
            #
            $systemPartition = $systemPartition | Get-Partition
            $systemDrive = $systemPartition.AccessPaths[0].trimend("\").replace("\?", "??")
            Write-W2VInfo "System volume location: $systemDrive"

            ####################################################################################################
            # APPLY IMAGE FROM WIM TO THE NEW VHD
            ####################################################################################################

            Write-W2VInfo "Applying image to $VHDFormat. This could take a while..."
            if ((Get-Command Expand-WindowsImage -ErrorAction SilentlyContinue) -and ((-not $ApplyEA) -and ([string]::IsNullOrEmpty($DismPath))))
            {
                Expand-WindowsImage -ApplyPath $windowsDrive -ImagePath $SourcePath -Index $ImageIndex -LogPath "$($logFolder)\DismLogs.log" | Out-Null
            }
            else
            {
                if (![string]::IsNullOrEmpty($DismPath))
                {
                    $dismPath = $DismPath
                }
                else
                {
                    $dismPath = $(Join-Path (get-item env:\windir).value "system32\dism.exe")
                }

                $applyImage = "/Apply-Image"
                if ($ApplyEA)
                {
                    $applyImage = $applyImage + " /EA"
                }

                $dismArgs = @("$applyImage /ImageFile:`"$SourcePath`" /Index:$ImageIndex /ApplyDir:$windowsDrive /LogPath:`"$($logFolder)\DismLogs.log`"")
                Write-W2VInfo "Applying image: $dismPath $dismArgs"
                $process  = Start-Process -Passthru -Wait -NoNewWindow -FilePath $dismPath `
                            -ArgumentList $dismArgs `

                if ($process.ExitCode -ne 0)
                {
 	                throw "Image Apply failed! See DismImageApply logs for details"
                }
            }
            Write-W2VInfo "Image was applied successfully. "

            #
            # Here we copy in the unattend file (if specified by the command line)
            #
            if (![string]::IsNullOrEmpty($UnattendPath))
            {
                Write-W2VInfo "Applying unattend file ($(Split-Path $UnattendPath -Leaf))..."
                Copy-Item -Path $UnattendPath -Destination (Join-Path $windowsDrive "unattend.xml") -Force
            }

            if (![string]::IsNullOrEmpty($MergeFolderPath))
            {
                Write-W2VInfo "Applying merge folder ($MergeFolderPath)..."
                Copy-Item -Recurse -Path (Join-Path $MergeFolderPath "*") -Destination $windowsDrive -Force #added to handle merge folders
            }

            if ($BCDinVHD -ne "NativeBoot")                       # User asked for a non-bootable image
            {
                if (Test-Path "$($systemDrive)\boot\bcd")
                {
                    Write-W2VInfo "Image already has BIOS BCD store..."
                }
                elseif (Test-Path "$($systemDrive)\efi\microsoft\boot\bcd")
                {
                    Write-W2VInfo "Image already has EFI BCD store..."
                }
                else
                {
                    Write-W2VInfo "Making image bootable..."
                    $bcdBootArgs = @(
                        "$($windowsDrive)\Windows", # Path to the \Windows on the VHD
                        "/s $systemDrive",          # Specifies the volume letter of the drive to create the \BOOT folder on.
                        "/v"                        # Enabled verbose logging.
                        )

                    switch ($DiskLayout)
                    {
                        "BIOS"
                        {
                            $bcdBootArgs += "/f BIOS"   # Specifies the firmware type of the target system partition
                        }

                        "UEFI"
                        {
                            $bcdBootArgs += "/f UEFI"   # Specifies the firmware type of the target system partition
                        }
                    }

                    Run-Executable -Executable $BCDBoot -Arguments $bcdBootArgs

                    # The following is added to mitigate the VMM diff disk handling
                    # We're going to change from MBRBootOption to LocateBootOption.

                    if ($DiskLayout -eq "BIOS")
                    {
                        Write-W2VInfo "Fixing the Device ID in the BCD store on $($VHDFormat)..."
                        Run-Executable -Executable "BCDEDIT.EXE" -Arguments (
                            "/store $($systemDrive)\boot\bcd",
                            "/set `{bootmgr`} device locate"
                        )
                        Run-Executable -Executable "BCDEDIT.EXE" -Arguments (
                            "/store $($systemDrive)\boot\bcd",
                            "/set `{default`} device locate"
                        )
                        Run-Executable -Executable "BCDEDIT.EXE" -Arguments (
                            "/store $($systemDrive)\boot\bcd",
                            "/set `{default`} osdevice locate"
                        )
                    }
                }

                Write-W2VInfo "Drive is bootable.  Cleaning up..."
            }
            else
            {
                # Don't bother to check on debugging.  We can't boot WoA VHDs in VMs, and
                # if we're native booting, the changes need to be made to the BCD store on the
                # physical computer's boot volume.

                Write-W2VInfo "Image applied. It is not bootable."
            }

            if ($RemoteDesktopEnable -or (-not $ExpandOnNativeBoot))
            {
                $hive = Mount-RegistryHive -Hive (Join-Path $windowsDrive "Windows\System32\Config\System")

                if ($RemoteDesktopEnable)
                {
                    Write-W2VInfo -text "Enabling Remote Desktop"
                    Set-ItemProperty -Path "HKLM:\$($hive)\ControlSet001\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
                }

                if (-not $ExpandOnNativeBoot)
                {
                    Write-W2VInfo -text "Disabling automatic $VHDFormat expansion for Native Boot"
                    Set-ItemProperty -Path "HKLM:\$($hive)\ControlSet001\Services\FsDepends\Parameters" -Name "VirtualDiskExpandOnMount" -Value 4
                }

                Dismount-RegistryHive -HiveMountPoint $hive
            }

            if ($Driver)
            {
                Write-W2VInfo -text "Adding Windows Drivers to the Image"
                $Driver | ForEach-Object -Process {
                    Write-W2VInfo -text "Driver path: $PSItem"
                    Add-WindowsDriver -Path $windowsDrive -Recurse -Driver $PSItem -Verbose | Out-Null
                }
            }

            If ($Feature)
            {
                Write-W2VInfo -text "Installing Windows Feature(s) $Feature to the Image"
                $FeatureSourcePath = Join-Path -Path "$($driveLetter):" -ChildPath "sources\sxs"
                Write-W2VInfo -text "From $FeatureSourcePath"
                Enable-WindowsOptionalFeature -FeatureName $Feature -Source $FeatureSourcePath -Path $windowsDrive -All | Out-Null
            }

            if ($Package)
            {
                Write-W2VInfo -text "Adding Windows Packages to the Image"

                $Package | ForEach-Object -Process {
                    Write-W2VInfo -text "Package path: $PSItem"
                    Add-WindowsPackage -Path $windowsDrive -PackagePath $PSItem | Out-Null
                }
            }

            #
            # Remove system partition access path, if necessary
            #
            if ($DiskLayout -eq "UEFI")
            {
                $systemPartition | Remove-PartitionAccessPath -AccessPath $systemPartition.AccessPaths[0]
            }

            if ([String]::IsNullOrEmpty($vhdFinalName))
            {
                # We need to generate a file name.
                Write-W2VInfo "Generating name for $($VHDFormat)..."
                $hive         = Mount-RegistryHive -Hive (Join-Path $windowsDrive "Windows\System32\Config\Software")

                $buildLabEx   = (Get-ItemProperty "HKLM:\$($hive)\Microsoft\Windows NT\CurrentVersion").BuildLabEx
                $installType  = (Get-ItemProperty "HKLM:\$($hive)\Microsoft\Windows NT\CurrentVersion").InstallationType
                $editionId    = (Get-ItemProperty "HKLM:\$($hive)\Microsoft\Windows NT\CurrentVersion").EditionID
                $skuFamily    = $null

                Dismount-RegistryHive -HiveMountPoint $hive

                # Is this ServerCore?
                # Since we're only doing this string comparison against the InstallType key, we won't get
                # false positives with the Core SKU.
                if ($installType.ToUpper().Contains("CORE"))
                {
                    $editionId += "Core"
                }

                # What type of SKU are we?
                if ($installType.ToUpper().Contains("SERVER"))
                {
                    $skuFamily = "Server"
                }
                elseif ($installType.ToUpper().Contains("CLIENT"))
                {
                    $skuFamily = "Client"
                }
                else
                {
                    $skuFamily = "Unknown"
                }

                #
                # ISSUE - do we want VL here?
                #
                $vhdFinalName = "$($buildLabEx)_$($skuFamily)_$($editionId)_.$($VHDFormat.ToLower())"
                Write-W2VTrace "$VHDFormat final name is : $vhdFinalName"
            }

            Write-W2VInfo "Dismounting $VHDFormat..."
            Dismount-VHD -Path $VHDPath

            $vhdFinalPath = Join-Path (Split-Path $VHDPath -Parent) $vhdFinalName
            Write-W2VTrace "$VHDFormat final path is : $vhdFinalPath"

            if (Test-Path $vhdFinalPath)
            {
                Write-W2VInfo "Deleting pre-existing $VHDFormat : $(Split-Path $vhdFinalPath -Leaf)..."
                Remove-Item -Path $vhdFinalPath -Force
            }

            Write-W2VTrace -Text "Renaming $VHDFormat at $VHDPath to $vhdFinalName"
            Rename-Item -Path (Resolve-Path $VHDPath).Path -NewName $vhdFinalName -Force
            $vhd += Get-DiskImage -ImagePath $vhdFinalPath

            $vhdFinalName = $null
        }
        catch
        {
            Write-W2VError $_
            Write-W2VInfo "Log folder is $logFolder"
        }
        finally
        {
            # If we still have a WIM image open, close it.
            if ($openWim -ne $null)
            {
                Write-W2VInfo "Closing Windows image..."
                $openWim.Close()
            }

            # If we still have a registry hive mounted, dismount it.
            if ($mountedHive -ne $null)
            {
                Write-W2VInfo "Closing registry hive..."
                Dismount-RegistryHive -HiveMountPoint $mountedHive
            }

            # If VHD is mounted, unmount it
            if (Test-Path $VHDPath)
            {
                if ((Get-VHD -Path $VHDPath).Attached)
                {
                    Dismount-VHD -Path $VHDPath
                }
            }

            # If we still have an ISO open, close it.
            if ($openIso -ne $null)
            {
                Write-W2VInfo "Closing ISO..."
                Dismount-DiskImage $ISOPath
            }

            if (-not $CacheSource)
            {
                if ($tempSource -and (Test-Path $tempSource))
                {
                    Remove-Item -Path $tempSource -Force
                }
            }

            # Close out the transcript and tell the user we're done.
            Write-W2VInfo "Done."
            if ($transcripting)
            {
                $null = Stop-Transcript
            }
        }
    }

    End
    {
        if ($Passthru)
        {
            return $vhd
        }
    }
    #endregion Code
}
function Dismount-VHDDISMTasks {

    <#

        .SYNOPSIS
        Wrapper for Dismount-VHD (DiskImage)

    #>

    param (

        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [ValidateScript(
            {
                if (-Not ($_ | Test-Path) ) {
                    throw 'File does not exist.'
                }
                if (-Not ($_ | Test-Path -PathType Leaf) ) {
                    throw 'Argument must be a file.'
                }
                if ($_ -notmatch '(\.vhdx)') {
                    throw 'File specified must be of type vhdx.'
                }
                return $true
            }
        )]
        [System.IO.FileInfo[]]
        [Alias('SourcePath')]
        $VHDPath

    )

    begin {
        $Script:ErrorActionPreference = 'Stop'
    }

    process {
        $VHDPath | ForEach-Object {
            Get-DiskImage $VHDPath | Dismount-DiskImage
        }
    }

}
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
function Invoke-ErrorDISMTasks {

    <#

        .SYNOPSIS
        Function for common Error-Handling

    #>

    [CmdletBinding()]
    param(

        # The name and path of the Virtual Hard Disk to create.
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName
        )]
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

        $InputObject

    )

    begin {
        $Script:ErrorActionPreference = 'Stop'
    }

    process {

        'Error during build' | Write-Host -ForegroundColor Red
        $InputObject | Write-Host -ForegroundColor Red

        $VHDPath | Dismount-VHDDISMTasks

        Remove-Item $VHDPath -Force -Verbose

        throw $InputObject

    }


}
function Mount-VHDDISMTasks {

    <#

        .SYNOPSIS
        Wrapper for Mount-VHD (DiskImage)

    #>

    param (

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript(
            {
                if (-Not ($_ | Test-Path) ) {
                    throw 'File does not exist.'
                }
                if (-Not ($_ | Test-Path -PathType Leaf) ) {
                    throw 'Argument must be a file.'
                }
                if ($_ -notmatch '(\.vhdx)') {
                    throw 'File specified must be of type vhdx.'
                }
                return $true
            }
        )]
        [System.IO.FileInfo[]]
        [Alias('SourcePath')]
        $VHDPath

    )

    begin {
        $Script:ErrorActionPreference = 'Stop'
    }

    process {
        $VHDPath | ForEach-Object {

            try {

                $DiskImage = Mount-DiskImage $_
                $DriveLetter = $DiskImage | Get-Disk | Get-Partition | Get-Volume | Select-Object -ExpandProperty DriveLetter | Sort-Object -Unique

                if ($DriveLetter.Count -gt 1) { throw 'Multiple DriveLetters found!' }
                elseif ($DriveLetter.Count -lt 1) { throw 'No DriveLetters found!' }

                '{0}:\' -f $DriveLetter

            }
            catch {
                $_
                $DiskImage | Dismount-DiskImage
            }

        }
    }

}
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
