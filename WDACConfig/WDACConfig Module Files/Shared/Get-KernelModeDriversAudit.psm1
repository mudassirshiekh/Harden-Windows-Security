Function Get-KernelModeDriversAudit {
    <#
    .DESCRIPTION
        This function will scan the Code Integrity event logs for kernel mode drivers that have been loaded since the audit mode policy has been deployed
        It will save them in a folder containing symbolic links to the driver files.
    .INPUTS
        System.IO.DirectoryInfo
    .OUTPUTS
        System.Void
    .PARAMETER SavePath
        The directory path to save the folder containing the symbolic links to the driver files
    .NOTES
        Get-SystemDriver only includes .sys files when -UserPEs parameter is not used, but Get-KernelModeDriversAudit function includes .dll files as well just in case

        When Get-SystemDriver -UserPEs is used, Dlls and .exe files are included as well
    #>
    [CmdletBinding()]
    [OutputType([System.Void])]
    param(
        [Parameter(Mandatory = $true)][System.IO.DirectoryInfo]$SavePath
    )
    begin {
        . "$([WDACConfig.GlobalVars]::ModuleRootPath)\CoreExt\PSDefaultParameterValues.ps1"

        Write-Verbose -Message 'Importing the required sub-modules'
        Import-Module -FullyQualifiedName "$([WDACConfig.GlobalVars]::ModuleRootPath)\Shared\Receive-CodeIntegrityLogs.psm1" -Force

        [System.IO.FileInfo[]]$KernelModeDriversPaths = @()
    }

    process {

        # Get the Code Integrity event logs for kernel mode drivers that have been loaded since the audit mode policy has been deployed
        [System.Object[]]$RawData = Receive-CodeIntegrityLogs -Date (Get-CommonWDACConfig -StrictKernelModePolicyTimeOfDeployment)

        Write-Verbose -Message "RawData count: $($RawData.count)"

        Write-Verbose -Message 'Saving the file paths to a variable'
        [System.IO.FileInfo[]]$KernelModeDriversPaths = $RawData.'File Name'

        Write-Verbose -Message 'Filtering based on files that exist with .sys and .dll extensions'
        $KernelModeDriversPaths = foreach ($Item in $KernelModeDriversPaths) {
            if (($Item.Extension -in ('.sys', '.dll')) -and $Item.Exists) {
                $Item
            }
        }

        Write-Verbose -Message "KernelModeDriversPaths count after filtering based on files that exist with .sys and .dll extensions: $($KernelModeDriversPaths.count)"

        Write-Verbose -Message 'Removing duplicates based on file path'
        $KernelModeDriversPaths = foreach ($Item in ($KernelModeDriversPaths | Group-Object -Property 'FullName')) {
            $Item.Group[0]
        }

        Write-Verbose -Message "KernelModeDriversPaths count after deduplication based on file path: $($KernelModeDriversPaths.count)"

        Write-Verbose -Message 'Creating symbolic links to the driver files'
        Foreach ($File in $KernelModeDriversPaths) {
            $null = New-Item -ItemType SymbolicLink -Path (Join-Path -Path $SavePath -ChildPath $File.Name) -Target $File.FullName
        }
    }
}
Export-ModuleMember -Function 'Get-KernelModeDriversAudit'
