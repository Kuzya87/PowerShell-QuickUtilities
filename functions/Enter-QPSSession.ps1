function Enter-QPSSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ComputerName,
        [Parameter(Mandatory = $false, Position = 1)]
        [pscredential]$Credential = $admaccount,
        [switch]$UseWindowsPowerShell
    )

    begin {
        $ErrorActionPreference = "Stop"
    }

    process {
        if ($UseWindowsPowerShell -eq $false) {
            Enter-PSSession -Session (New-QPSSession -ComputerName $ComputerName -Credential $Credential)
        }
        else {
            Enter-PSSession -Session (New-QPSSession -ComputerName $ComputerName -Credential $Credential -UseWindowsPowerShell)
        }
    }

    end {}
}