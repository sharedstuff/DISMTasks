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
