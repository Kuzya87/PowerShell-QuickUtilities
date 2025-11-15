function New-QPSSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]]$ComputerName,
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet("WindowsPowerShell", "PowerShell7")]
        [string]$PowerShellVersion = $QPSSession_PowerShell_Version,
        [Parameter(Mandatory = $false, Position = 2)]
        [pscredential]$Credential
    )

    begin {
        $ErrorActionPreference = "Stop"
    }

    process {
        $QPSSessions = @()
        foreach ($computer in $ComputerName) {
            if (-not($Credential)) {
                if (($computer.StartsWith("kz")) -or ($computer.EndsWith(".kz"))) {
                    $Credential = $admaccountkz
                }
                else {
                    $Credential = $admaccountac
                }
            }

            if ($PowerShellVersion -eq "PowerShell7") {
                $ConfigurationName = "PowerShell.7"    # Use PowerShell 7
            }
            else {
                $ConfigurationName = "microsoft.powershell"    # Use builtin Windows PowerShell
            }

            $QPSSession = [QPSSession]::new()
            $QPSSession.ComputerName = $computer
            $QPSSession.Credential = $Credential
            $QPSSession.AuthMode = "Kerberos"
            $QPSSession.ConfigurationName = $ConfigurationName
            $QPSSession.SSL = $true
            $QPSSession.SkipCertCheck = $false
            $QPSSession.Create()

            $QPSSessions += $QPSSession
        }

        return $QPSSessions
    }

    end {}
}