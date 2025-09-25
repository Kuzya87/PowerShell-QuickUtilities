function Import-QPSSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ComputerName,
        [Parameter(Mandatory = $false, Position = 1)]
        [pscredential]$Credential = $admaccount,
        [Parameter(Mandatory = $true, ParameterSetName = "byCommand")]
        [string[]]$Cmdlets,
        [Parameter(Mandatory = $true, ParameterSetName = "byModule")]
        [string[]]$Modules,
        [switch]$UseWindowsPowerShell
    )

    begin {
        $ErrorActionPreference = "Stop"
    }

    process {
        if ($UseWindowsPowerShell -eq $false) {
            $PSSession = New-QPSSession -ComputerName $ComputerName -Credential $Credential -CredSSP
        }
        else {
            $PSSession = New-QPSSession -ComputerName $ComputerName -Credential $Credential -CredSSP -UseWindowsPowerShell
        }

        if ($Cmdlets) {
            $ImportedModules = Import-PSSession -Session $PSSession -CommandName $Cmdlets
        }
        if ($Modules) {
            $ImportedModules = Import-PSSession -Session $PSSession -Module $Modules
        }
        $ImportedModules | Import-Module -Global
    }

    end {}
}