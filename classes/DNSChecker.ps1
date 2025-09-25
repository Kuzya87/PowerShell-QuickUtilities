class DNSChecker {
    [string]$RRName
    [string]$RRType
    [string]$Server
    [System.Nullable[datetime]]$CheckTime
    [System.Nullable[bool]]$State
    $ResultObject

    DNSChecker([string]$DNSName, [string]$DNSRRType, [string]$DNSServer) {
        $this.RRName = $DNSName
        $this.RRType = $DNSRRType
        $this.Server = $DNSServer
    }

    [void] Check() {
        try {
            $this.CheckTime = [datetime]::Now
            $ResolveObject = Resolve-DnsName -Name $this.RRName -Type $this.RRType -Server $this.Server -DnsOnly -NoHostsFile
            if ($ResolveObject.Type -eq $this.RRType) {
                $this.State = $true
                $this.ResultObject = $ResolveObject
            }
            else {
                $this.State = $false
                $this.ResultObject = $ResolveObject
            }
        }
        catch [System.ComponentModel.Win32Exception] {
            $this.State = $false
        }
        catch {
            throw $_
        }
    }
}