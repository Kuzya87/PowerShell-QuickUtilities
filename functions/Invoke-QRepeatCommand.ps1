function Invoke-QRepeatCommand {

    <#
    .SYNOPSIS
        Repeated execution of command or set of commands (scriptblock).
    .DESCRIPTION
        Function for repeating execution of command or set of commands (scriptblock). It is possible to specify total duration of work, as well as time interval for pausing between iterations.
    .EXAMPLE
        $Command = { Get-FileHash -Path "D:\MyImage.iso" -Algorithm "SHA256" }
        Invoke-RepeatCommand -Command $Command -DurationSeconds 21 -EverySeconds 5

        Hash calculation and output every 5 seconds for 21 seconds. If calculation is not completed in 5 seconds, another calculation will be added.
    .EXAMPLE
        $Command = { Get-FileHash -Path "D:\MyImage.iso" -Algorithm "SHA256" }
        Invoke-RepeatCommand -Command $Command -DurationSeconds 21 -EverySeconds 5 -NoNewInstanceIfBusy

        Hash calculation and output every 5 seconds for 21 seconds. No new calculation will be added until current one is completed.
    .EXAMPLE
        $Command = { Get-FileHash -Path "D:\MyImage.iso" -Algorithm "SHA256" }
        Invoke-RepeatCommand -Command $Command -DurationSeconds 21 -EverySeconds 5 -WaitCommandComplete

        After each calculation is completed, there will be 5-second pause before next one starts.
    .INPUTS
        None
    .OUTPUTS
        The target command (scriptblock) can return any output.
    #>
    
    [CmdletBinding(
        DefaultParameterSetName = "NoWaitCommandComplete"
    )]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [scriptblock]$Command,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$DurationSeconds,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int]$EverySeconds,
        [Parameter(Mandatory = $true,
            ParameterSetName = "WaitCommandComplete")]
        [switch]$WaitCommandComplete,    # With waiting complete execution of target command
        [Parameter(Mandatory = $false,
            ParameterSetName = "NoWaitCommandComplete")]
        [switch]$NoNewInstanceIfBusy    # Do not start new instance if current one is still running
    )
    
    begin {
        $ErrorActionPreference = "Stop"
    }
    
    process {
        $Timer = New-TimeSpan -Seconds $DurationSeconds
        $Clock = [diagnostics.stopwatch]::StartNew()
        [string]$JobSession = Get-Random    # Unique number for job session
        while ($Clock.Elapsed -lt $Timer) {
            if ($WaitCommandComplete) {
                # With waiting complete execution of target command
                $Job = Start-Job -ScriptBlock $Command -Name "Invoke-RepeatCommand_$($JobSession)_$(Get-Date -Format 'HH:mm:ss:ms')"
                Receive-Job -Job $Job -Wait -AutoRemoveJob    # Return result after complete execution of target command; deletes job after it returns job results
            }
            else {
                # No waiting complete execution of target command
                if ($NoNewInstanceIfBusy) {
                    # Do not start new instance if current one is still running
                    if (-not($Job) -or ($Job.State -in ("Completed", "Failed"))) {
                        $Job = Start-Job -ScriptBlock $Command -Name "Invoke-RepeatCommand_$($JobSession)_$(Get-Date -Format 'HH:mm:ss:ms')"
                    }
                }
                else {
                    # Start new instance, even if current one is still running
                    $Job = Start-Job -ScriptBlock $Command -Name "Invoke-RepeatCommand_$($JobSession)_$(Get-Date -Format 'HH:mm:ss:ms')"
                }
                $EndedJobs = Get-Job -Name "Invoke-RepeatCommand_$($JobSession)_*" | Where-Object -FilterScript { # Get completed or failed jobs
                    ($_.PSJobTypeName -eq "BackgroundJob") -and ($_.State -in ("Completed", "Failed"))
                }
                if ($EndedJobs) {
                    Receive-Job -Job $EndedJobs    # Return results of completed or failed jobs
                    Remove-Job -Job $EndedJobs
                }
            }
            Start-Sleep -Seconds $EverySeconds
        }
    }
    
    end {
        Write-Host -Object "`nTimer end" -ForegroundColor "Cyan"
    }
}