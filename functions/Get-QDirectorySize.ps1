function Get-QDirectorySize {
    [CmdletBinding(DefaultParameterSetName = "byHumanSize")]
    param (
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Path to one or more locations.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            { Test-Path -Path $_ -PathType "Container" },
            ErrorMessage = "{0} - there is no such catalog. Specify existing catalog."
        )]
        [string[]]$Path,
        [Parameter(Mandatory = $false, ParameterSetName = "bySizeInBytes")]
        [switch]$SizeInBytes,
        [Parameter(Mandatory = $false)]
        [switch]$SkipInaccessible,
        [Parameter(Mandatory = $false, ParameterSetName = "byHumanSize")]
        [int]$FractionalDigits = 2
    )

    begin {
        $ErrorActionPreference = "Stop"
    }

    process {
        $Path | ForEach-Object -Process {
            try {
                [System.IO.DirectoryInfo]$Item = Get-Item -Path $_ -Force

                [System.IO.EnumerationOptions]$EnumerationOptions = [System.IO.EnumerationOptions]::new()
                $EnumerationOptions.RecurseSubdirectories = $true
                $EnumerationOptions.IgnoreInaccessible = $SkipInaccessible
                $EnumerationOptions.AttributesToSkip = [System.IO.FileAttributes]::ReparsePoint

                # Get list of files
                Write-Host -Object "Get list of files from:  $($Item.FullName)" -ForegroundColor "Cyan"
                [String[]]$FilesAsFullName = [System.IO.Directory]::GetFiles($Item.FullName, "*", $EnumerationOptions)

                # Get batch size
                if ($FilesAsFullName.Count -ge 100) {
                    [double]$Batch = [System.Math]::Round(($FilesAsFullName.Count / 100))
                }
                else {
                    [double]$Batch = 1
                }
                Write-Host -Object "Batch size:  $Batch" -ForegroundColor "Cyan"

                # Get sum of file sizes
                [UInt32]$i = 0    # Counter for progress bar
                [UInt64]$OverallSize = $null
                [System.Linq.Enumerable]::Chunk($FilesAsFullName, $Batch) | ForEach-Object -Process {
                    $_ | ForEach-Object -Process {
                        $OverallSize = $OverallSize + ([System.IO.FileInfo]::new($_)).Length
                    }

                    # Progress bar
                    $i++
                    [int]$Completed = ($i * $Batch / $FilesAsFullName.Count) * 100
                    if ($Completed -gt 100) {
                        [int]$Completed = 100
                    }
                    Write-Progress -Activity "Getting file size" -Status "Processing files: $($i*$Batch)/$($FilesAsFullName.Count)" -PercentComplete $Completed
                }

                # Convert to human format
                [double]$Size = $OverallSize
                $Unit = "Bytes"
                if ($SizeInBytes -ne $true) {
                    if ((($OverallSize) / 1KB -gt 1) -and (($OverallSize) / 1MB -le 1)) {
                        [double]$Size = $OverallSize / 1KB
                        $Unit = "KB"
                    }
                    elseif ((($OverallSize) / 1MB -gt 1) -and (($OverallSize) / 1GB -le 1)) {
                        [double]$Size = $OverallSize / 1MB
                        $Unit = "MB"
                    }
                    elseif ((($OverallSize) / 1GB -gt 1) -and (($OverallSize) / 1TB -le 1)) {
                        [double]$Size = $OverallSize / 1GB
                        $Unit = "GB"
                    }
                    elseif (($OverallSize) / 1TB -gt 1) {
                        [double]$Size = $OverallSize / 1TB
                        $Unit = "TB"
                    }

                    [double]$RoundedSize = [System.Math]::Round($Size, $FractionalDigits)
                    [string]$SizeAsString = "$($RoundedSize.ToString()) $Unit"
                }

                # Prepare result object
                if ($SizeInBytes -ne $true) {
                    $ResultSize = $SizeAsString
                    $SizeProperty = "Size"
                }
                else {
                    $ResultSize = $OverallSize
                    $SizeProperty = "Bytes"
                }
                $ResultObject = [PSCustomObject]@{
                    Path          = $Item.FullName
                    $SizeProperty = $ResultSize
                    FilesCount    = $FilesAsFullName.Count
                }

                return $ResultObject
            }
            catch {
                $ErrorActionPreference = "Continue"
                Write-Error -ErrorRecord $_
                $ErrorActionPreference = "Stop"
            }
        }
    }
    
    end {}
}