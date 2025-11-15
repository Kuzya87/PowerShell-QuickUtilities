function Import-QPSSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ComputerName,
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet("WindowsPowerShell", "PowerShell7")]
        [string]$PowerShellVersion = $QPSSession_PowerShell_Version,
        [Parameter(Mandatory = $false, Position = 2)]
        [pscredential]$Credential,
        [Parameter(Mandatory = $true, ParameterSetName = "byCommand")]
        [string[]]$Cmdlets,
        [Parameter(Mandatory = $true, ParameterSetName = "byModule")]
        [string[]]$Modules
    )

    begin {
        $ErrorActionPreference = "Stop"
    }

    process {
        $Params = @{
            ComputerName      = $ComputerName
            PowerShellVersion = $PowerShellVersion
        }
        if ($Credential) {
            $Params.Add("Credential", $Credential)
        }
        $QPSSession = New-QPSSession @Params

        if ($Cmdlets) {
            $QPSSession.ImportCmdlets($Cmdlets)
        }
        if ($Modules) {
            $QPSSession.ImportModules($Modules)
        }
    }

    end {}
}