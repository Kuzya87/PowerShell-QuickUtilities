function Wait-ScheduledTime {
    param (
        [Parameter(Mandatory = $true)]
        [int]$CheckIntervalMinutes
    )

    begin {
        $ErrorActionPreference = "Stop"
    }

    process {
        if ($CheckIntervalMinutes -ge 1) {
            $StartTime = [datetime]::Now
            $Time = $StartTime.AddMinutes($CheckIntervalMinutes)
            $ScheduledTime = [datetime]::new($Time.Year, $Time.Month, $Time.Day, $Time.Hour, $Time.Minute, 0)
            [timespan]$TimeSpan = $ScheduledTime.Subtract($StartTime)
            Start-Sleep -Seconds $TimeSpan.TotalSeconds
        }
        else {
            Start-Sleep -Seconds 1
        }
    }

    end {}
}

function Watch-QDNSName {
    <#
.SYNOPSIS
    Periodic check of DNS records availability.
.DESCRIPTION
    The script checks whether certain DNS records can be resolved using certain DNS servers and with a specified frequency in minutes.
    The goal is to periodically check the possibility of resolving a DNS record, for example, in order to track the availability of a critical DNS name to users on the Internet.
    Only unsuccessful attempts to resolve DNS records are displayed in the console, they can also be written to a CSV file.
    
    You can set multiple DNS records for monitoring at once, but of the same type.
    For example, you can monitor the resolution of records type A for 8 hours every minute for mail.ru, yandex.ru and vk.com via DNS servers 8.8.8.8, 1.1.1.1, and 77.88.8.8, with save failed attempts to a CSV file.
    
    The script is designed to run from the Task Scheduler.
.NOTES
    Only for PowerShell 7.2 or higher on Windows. MacOS and Linux are not compatible.
.PARAMETER DNSName
    One or several DNS records.
.PARAMETER DNSRRType
    Type of DNS record.
.PARAMETER DNSServer
    One or several DNS server.
.PARAMETER RunHours 
    Hours for script running.
.PARAMETER CheckIntervalMinutes
    Interval in minutes between check attempts. 0 - non-stop check with delay of 1 second.
.PARAMETER WorkingLogPath
    Technical log for script start and errors.
.PARAMETER ErrorLogCSVPath
    DNS resolve failure log in CSV.
.EXAMPLE
    $Params = @{
        DNSName = "ya.ru", "web.archive.org", "mail.ru"
        DNSRRType = "A"
        DNSServer = "8.8.8.8", "1.1.1.1", "77.88.8.8"
        RunHours = 6
        CheckIntervalMinutes = 1
        WorkingLogPath = "D:\Watch-DNSName.log"
        ErrorLogCSVPath = "D:\DNSErrors.csv"
    }
    Watch-QDNSName @Params

    Script will be running 6 hours with check all three DNS records (type A) every 1 minute.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$DNSName,
        [Parameter(Mandatory = $true)]
        [string]$DNSRRType,
        [Parameter(Mandatory = $true)]
        [string[]]$DNSServer,
        [Parameter(Mandatory = $true)]
        [double]$RunHours,
        [Parameter(Mandatory = $true)]
        [int]$CheckIntervalMinutes,
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path -Path $_ -PathType "Leaf" -IsValid })]
        [string]$WorkingLogPath,
        [Parameter(Mandatory = $false)]
        [ValidateScript({ Test-Path -Path $_ -PathType "Leaf" -IsValid })]
        [string]$ErrorLogCSVPath
    )

    begin {
        $ErrorActionPreference = "Stop"

        # Create working log file
        Get-Date -Format "dd.MM.yyyy HH:mm:ss" | Out-File -FilePath $WorkingLogPath
        "DNSName: $DNSName" | Out-File -FilePath $WorkingLogPath -Append
        "DNSRRType: $DNSRRType" | Out-File -FilePath $WorkingLogPath -Append
        "DNSServer: $DNSServer" | Out-File -FilePath $WorkingLogPath -Append
        "RunHours: $RunHours" | Out-File -FilePath $WorkingLogPath -Append
        "CheckIntervalMinutes: $CheckIntervalMinutes" | Out-File -FilePath $WorkingLogPath -Append
        "ErrorLogCSVPath: $ErrorLogCSVPath`n" | Out-File -FilePath $WorkingLogPath -Append

        # Create error resolving log file
        if (-not(Test-Path -Path $ErrorLogCSVPath -PathType "Leaf")) {
            New-Item -Path $ErrorLogCSVPath -ItemType "File" -Force | Out-Null
        }

        [datetime]$EndTime = ([datetime]::Now).AddHours($RunHours)
    }

    process {
        # Create all combinations of DNSNames and DNSServers
        [DNSChecker[]]$Sets = foreach ($dnsitem in $DNSName) {
            foreach ($serveritem in $DNSServer) {
                [DNSChecker]::new($dnsitem, $DNSRRType, $serveritem)
            }
        }
    
        do {
            Import-Module -Name "DnsClient", "Microsoft.PowerShell.Utility"    # Very important!!! It sucked my blood. Because "Foreach-Object -Parallel".
            $ErrorQueue = [System.Collections.Concurrent.ConcurrentQueue[System.Object]]::new()
        
            try {
                # Processing section
                $Sets | Foreach-Object -ThrottleLimit 1 -Parallel {
                    $ErrorQueue = $Using:ErrorQueue
                    $_.Check()
                    if ($_.State -ne $true) {
                        $ErrorQueue.Enqueue($_)
                    }
                }
        
                # Output section
                if (-not($ErrorQueue.IsEmpty)) {
                    $ErrorQueue.ToArray() | ForEach-Object -Process {
                        $String = "$($_.CheckTime.ToString('s')) - $($_.RRName) ($($_.RRType)) - $($_.Server) - not exist"
                        Write-Host -Object $String -ForegroundColor "DarkRed"
                        if ($ErrorLogCSVPath) {
                            $_ | Select-Object -Property "CheckTime", @{Name = "DNSName"; Expression = { "$($_.RRName) ($($_.RRType))" } }, "Server" | Export-Csv -Path $ErrorLogCSVPath -Append
                        }
                    }
                }
            }
            catch {
                Get-Date -Format "dd.MM.yyyy HH:mm:ss" | Out-File -FilePath $WorkingLogPath -Append
                $_ | Out-File -FilePath $WorkingLogPath -Append
                throw
            }
    
            Wait-ScheduledTime -CheckIntervalMinutes $CheckIntervalMinutes
        } while (
            [datetime]::Now -lt $EndTime
        )

        "`nFinish" | Out-File -FilePath $WorkingLogPath -Append
    }

    end {}
}