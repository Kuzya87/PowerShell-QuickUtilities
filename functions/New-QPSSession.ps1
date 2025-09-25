function New-QPSSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]]$ComputerName,
        [Parameter(Mandatory = $false, Position = 1)]
        [pscredential]$Credential = $admaccount,
        [switch]$CredSSP,
        [switch]$UseWindowsPowerShell
    )

    begin {
        $ErrorActionPreference = "Stop"
    }

    process {
        if ($CredSSP -eq $true) {
            $Authentication = "Credssp"
        }
        else {
            $Authentication = "Kerberos"
        }

        try {
            if ($UseWindowsPowerShell -eq $false) {
                $PSSessions = New-PSSession -ComputerName $ComputerName -Credential $Credential -Authentication $Authentication -ConfigurationName "PowerShell.7"
            }
            else {
                $PSSessions = New-PSSession -ComputerName $ComputerName -Credential $Credential -Authentication $Authentication
            }
            return $PSSessions
        }
        catch {
            throw $_
        }
    }

    end {}
}