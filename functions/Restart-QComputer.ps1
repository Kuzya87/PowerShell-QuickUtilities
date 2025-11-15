function Restart-QComputer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]]$ComputerName,
        [Parameter(Mandatory = $false, Position = 1)]
        [pscredential]$Credential,
        [Parameter(Mandatory = $false)]
        [switch]$AsJob
    )

    begin {
        $ErrorActionPreference = "Stop"
    }

    process {
        if (-not($Credential)) {
            if (($computer.StartsWith("kz")) -or ($computer.EndsWith(".kz"))) {
                $Credential = $admaccountkz
            }
            else {
                $Credential = $admaccountac
            }
        }

        $Command = { Restart-Computer -ComputerName $ComputerName -WsmanAuthentication "Kerberos" -Credential $Credential -Wait -For "WinRM" -Force }
        try {
            if ($AsJob) {
                $Timestamp = Get-Date -Format "s"
                if ($ComputerName.Count -eq 1) {
                    $JobName = "Rebooting $ComputerName ($Timestamp)"
                }
                else {
                    $Count = $ComputerName.Count
                    $JobName = "Rebooting $Count computers ($Timestamp)"
                }
                Start-Job -ScriptBlock $Command -Name $JobName
            }
            else {
                Invoke-Command -ScriptBlock $Command
            }
        }
        catch {
            throw $_
        }
    }

    end {}
}