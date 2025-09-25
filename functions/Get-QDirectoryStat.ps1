function Get-QDirectoryStat {
    [CmdletBinding()]
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
        [Parameter(Mandatory = $false)]
        [switch]$SkipInaccessible
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

                # Get count of files
                Write-Host -Object "Get count of files from:  $($Item.FullName)" -ForegroundColor "Cyan"
                [UInt64]$FilesCount = ([System.IO.Directory]::GetFiles($Item.FullName, "*", $EnumerationOptions)).Count

                # Get count of directories
                Write-Host -Object "Get count of directories from:  $($Item.FullName)" -ForegroundColor "Cyan"
                [UInt64]$DirectoriesCount = ([System.IO.Directory]::GetDirectories($Item.FullName, "*", $EnumerationOptions)).Count

                [System.IO.Directory]::get

                # Prepare result object
                $ResultObject = [PSCustomObject]@{
                    Path             = $Item.FullName
                    LinkTarget       = $item.LinkTarget
                    FilesCount       = $FilesCount
                    DirectoriesCount = $DirectoriesCount
                    CreationTime     = $Item.CreationTime
                    LastAccessTime   = $Item.LastAccessTime
                    LastWriteTime    = $Item.LastWriteTime
                    Mode             = $Item.Mode
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