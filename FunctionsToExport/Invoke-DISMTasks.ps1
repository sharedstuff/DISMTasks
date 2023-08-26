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
