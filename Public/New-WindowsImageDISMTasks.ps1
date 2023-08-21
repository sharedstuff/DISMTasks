function New-WindowsImageDISMTasks {

    [CmdletBinding()]
    param (

        # Mandatory

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
                if ($_ -notmatch '(\.iso|\.wim)') {
                    throw 'File must be either of type iso or wim.'
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

        # The name or image index of the image to apply from the WIM.
        [Parameter(Mandatory)]
        [string]
        $Edition,


        # Optional

        # The size of the Virtual Hard Disk to create.
        [Parameter()]
        [int64]
        $SizeBytes = 128GB,

        # The path of a directory for use as build cache
        [Parameter()]
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


        # Multiple Path

        # Directory(s) to copy/merge Content from
        [Parameter()]
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
        [Parameter()]
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

        # Directory(s) to add Driver(s) from
        [Parameter()]
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


        # Optimize VHD using Optimize-WindowsImageVHDDismTasks
        [Parameter()]
        [switch]
        $OptimizeVHD,


        # WindowsOptionalFeature, WindowsCapability

        # WindowsOptionalFeature(s)
        [Parameter()]
        [string[]]
        $WindowsOptionalFeature = @(),

        # WindowsCapability(s)
        [Parameter()]
        [string[]]
        $WindowsCapability = @(),


        # VM

        # The name of the VM to use/create.
        [Parameter()]
        [string]
        $Name,

        # Start the VM at the end of the build process.
        [Parameter()]
        [switch]
        $StartVM,

        # Connect to the VM at the end of the build process.
        [Parameter()]
        [switch]
        $ConnectVM,

        # VM SwitchName
        [Parameter()]
        [string]
        $SwitchName = 'Default Switch',

        # VM ProcessorCount
        [Parameter()]
        [int]
        $ProcessorCount = 4,

        # VM DynamicMemory
        [Parameter()]
        [bool]
        $DynamicMemory = $true,

        # VM MemoryStartupBytes
        [Parameter()]
        [int64]
        $MemoryStartupBytes = 2GB,

        # VM MemoryMinimumBytes
        [Parameter()]
        [int64]
        $MemoryMinimumBytes = 2GB,

        # VM MemoryMaximumBytes
        [Parameter()]
        [int64]
        $MemoryMaximumBytes = 8GB,

        # VM AutomaticStartAction
        [Parameter()]
        [string]
        $AutomaticStartAction = 'Nothing',

        # VM AutomaticStopAction
        [Parameter()]
        [string]
        $AutomaticStopAction = 'ShutDown',

        # VM CheckpointType
        [Parameter()]
        [string]
        $CheckpointType = 'Disabled'

    )

    begin {

        # Cache VHD
        'Create CacheVHD (at CachePath) ...' | Write-Host -ForegroundColor Yellow
        $ConvertWindowsImageDISMTasksParams = @{
            SourcePath = $SourcePath
            VHDPath    = Join-Path $CachePath (('{0}.{1}.vhdx') -f (Get-Item $SourcePath).BaseName, $Edition)
            Edition    = $Edition
            SizeBytes  = $SizeBytes
        }
        if (Test-Path $ConvertWindowsImageDISMTasksParams.VHDPath) {
            '... using cache ...' | Write-Host -ForegroundColor Green
        }
        else {
            '... process ...' | Write-Host -ForegroundColor Yellow
            Convert-WindowsImageDISMTasks @ConvertWindowsImageDISMTasksParams
        }
        '... done' | Write-Host -ForegroundColor Green


        # OptimizeVHD
        if ($OptimizeVHD) {
            'OptimizeVHD ...' | Write-Host -ForegroundColor Yellow


            # Optimize-WindowsImageVHDDISMTasks
            'Optimize-WindowsImageVHDDISMTasks ...' | Write-Host -ForegroundColor Yellow
            $OptimizeWindowsImageVHDDISMTasksParams = @{
                SourcePath = $ConvertWindowsImageDISMTasksParams.VHDPath
                VHDPath    = Join-Path $CachePath (('{0}.{1}.min.vhdx') -f (Get-Item $SourcePath).BaseName, $Edition)
            }
            if (Test-Path $OptimizeWindowsImageVHDDISMTasksParams.VHDPath) {
                '... using cache ...' | Write-Host -ForegroundColor Green
            }
            else {
                '... process ...' | Write-Host -ForegroundColor Yellow
                Optimize-WindowsImageDISMTasks @OptimizeWindowsImageVHDDISMTasksParams
            }
            '... done' | Write-Host -ForegroundColor Green


            # WorkVHD
            'Copy OptimizedWindowsImageVHD to WorkVHD (at VHDPath) ...' | Write-Host -ForegroundColor Yellow
            $CopyItemParams = @{
                Path        = $OptimizeWindowsImageVHDDISMTasksParams.VHDPath
                Destination = $VHDPath
                Force       = $true
            }
            '... process ...' | Write-Host -ForegroundColor Yellow
            Copy-Item @CopyItemParams
            '... done' | Write-Host -ForegroundColor Green


            '... OptimizeVHD done' | Write-Host -ForegroundColor Green
        }
        else {
            # WorkVHD
            'Copy CacheVHD to WorkVHD (at VHDPath) ...' | Write-Host -ForegroundColor Yellow
            $CopyItemParams = @{
                Path        = $ConvertWindowsImageDISMTasksParams.VHDPath
                Destination = $VHDPath
                Force       = $true
            }
            '... process ...' | Write-Host -ForegroundColor Yellow
            Copy-Item @CopyItemParams
            '... done' | Write-Host -ForegroundColor Green
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


            # MergePath
            if ($MergePath) {
                'MergePath ...' | Write-Host -ForegroundColor Yellow
                '... process ...' | Write-Host -ForegroundColor Yellow
                $MergePath | ForEach-Object {
                    $_ | Write-Host -ForegroundColor Yellow
                    Robocopy.exe $_ $VHDRoot /S
                }
                '... done' | Write-Host -ForegroundColor Green
            }


            # PackagePath
            if ($PackagePath) {
                'PackagePath ...' | Write-Host -ForegroundColor Yellow
                '... process ...' | Write-Host -ForegroundColor Yellow
                $PackagePath | ForEach-Object {
                    $_ | Write-Host -ForegroundColor Yellow
                    Add-WindowsPackage -Path $VHDRoot -PackagePath $_
                }
                '... done' | Write-Host -ForegroundColor Green
            }


            # DriverPath
            if ($DriverPath) {
                'DriverPath ...' | Write-Host -ForegroundColor Yellow
                '... process ...' | Write-Host -ForegroundColor Yellow
                $DriverPath | ForEach-Object {
                    $_ | Write-Host -ForegroundColor Yellow
                    # TBD
                }
                '... done' | Write-Host -ForegroundColor Green
            }


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

            # Unmount
            'Error during build' | Write-Host -ForegroundColor Red
            'Unmount-DiskImage ...' | Write-Host -ForegroundColor Red
            $null = $DiskImage | Dismount-DiskImage
            throw $_

        }

        finally {

            # Unmount
            'Unmount-DiskImage ...' | Write-Host -ForegroundColor Yellow
            '... process ...' | Write-Host -ForegroundColor Yellow
            $null = $DiskImage | Dismount-DiskImage
            '... done' | Write-Host -ForegroundColor Green

        }

        # Tasks on the VHD done
        '... Tasks on the VHD done' | Write-Host -ForegroundColor Green

    }

    end {

        # VM
        if ($Name) {

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
                '... process ...' | Write-Host -ForegroundColor Yellow
                $VM = New-VM @NewVMParams
                $VM | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName $SwitchName
                $VM | Get-VMIntegrationService | Where-Object Enabled -EQ $false | ForEach-Object { $VM | Enable-VMIntegrationService -Name $_.Name }
                $VM | Set-VM @SetVMParams
            }
            '... done' | Write-Host -ForegroundColor Green


            if ($VM -and $StartVM) {
                'Start-VM ...' | Write-Host -ForegroundColor Yellow
                '... process ...' | Write-Host -ForegroundColor Yellow
                $VM | Start-VM
                '... done' | Write-Host -ForegroundColor Green
            }


            if ($VM -and $StartVM -and $ConnectVM) {
                'Connect-VM (vmconnect.exe) ...' | Write-Host -ForegroundColor Yellow
                '... process ...' | Write-Host -ForegroundColor Yellow
                vmconnect.exe localhost $VM.Name
                '... done' | Write-Host -ForegroundColor Green
            }


            '... VM done' | Write-Host -ForegroundColor Green

        }

        # all done
        '... all done' | Write-Host -ForegroundColor Green

    }

}
