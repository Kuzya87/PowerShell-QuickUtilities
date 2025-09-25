function Enter-QPSSessionPC {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ComputerName,
        [Parameter(Mandatory = $false, Position = 1)]
        [pscredential]$Credential = $useraccount,
        [switch]$PS7
    )

    begin {
        $ErrorActionPreference = "Stop"
    }

    process {
        if ($PS7) {
            Enter-PSSession -Session (New-QPSSession -ComputerName $ComputerName -Credential $Credential)
        }
        else {
            Enter-PSSession -Session (New-QPSSession -ComputerName $ComputerName -Credential $Credential -UseWindowsPowerShell)
        }
    }

    end {}
}