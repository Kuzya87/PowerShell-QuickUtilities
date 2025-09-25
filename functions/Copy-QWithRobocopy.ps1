function StartRobocopy ($SourceFolder, $DestinationRootFolder, $RobocopyLogFile, $CopyMode) {
    $ErrorActionPreference = "Stop"

    [string]$DestinationFullName = Join-Path -Path $DestinationRootFolder -ChildPath $SourceFolder.BaseName
    if ($CopyMode -eq "DTSO") {
        $Argument = '"' + $SourceFolder.FullName + '" "' + $DestinationFullName + '" /mir /copy:DTSO /dcopy:DT /unilog:"' + $RobocopyLogFile + '"'
    }
    if ($CopyMode -eq "DTO") {
        $Argument = '"' + $SourceFolder.FullName + '" "' + $DestinationFullName + '" /mir /copy:DTO /dcopy:DT /unilog:"' + $RobocopyLogFile + '"'
    }
    Write-Verbose -Message "robocopy $Argument"
    Start-Process -FilePath "robocopy" -ArgumentList $Argument -Wait
}

function TestRobocopyLog ($RobocopyLogFile) {
    $ErrorActionPreference = "Stop"

    if (-not(Test-Path -Path $RobocopyLogFile -PathType "Leaf")) {
        return "Robocopy log file not found"
    }
    [string]$SectionDelimiter = '------------------------------------------------------------------------------'
    [string[]]$SectionDelimiterIsPresent = Get-Content -Path $RobocopyLogFile | Select-String -Pattern $SectionDelimiter
    if (-not($SectionDelimiterIsPresent)) {
        return "Not a robocopy log file"
    }
    elseif (-not($SectionDelimiterIsPresent[3])) {
        return "Result section missing"
    }
    else {
        [string[]]$ResultSection = Get-Content -Path $RobocopyLogFile -Tail 13
        [string]$DirsResult = ($ResultSection | Select-String -Pattern ' : ')[0]
        [string[]]$DirsResultCounters = ($DirsResult -split "^\s*\w+\s+:\s+")[-1] -split "\s+"
        Write-Verbose -Message "DirsResultCounters: $DirsResultCounters"
        [string]$FilesResult = ($ResultSection | Select-String -Pattern ' : ')[1]
        [string[]]$FilesResultCounters = ($FilesResult -split "^\s*\w+\s+:\s+")[-1] -split "\s+"
        Write-Verbose -Message "FilesResultCounters: $FilesResultCounters"
        if (
            ($DirsResultCounters[3] -ne 0) `
                -or ($DirsResultCounters[4] -ne 0) `
                -or ($FilesResultCounters[3] -ne 0) `
                -or ($FilesResultCounters[4] -ne 0)) {
            return "There are errors with some files or directories"
        }
        else {
            return "Success"
        }
    }
    return "Unknown error in testing robocopy log"
}

function Copy-QWithRobocopy {
    <#
    .SYNOPSIS
        Копирование каталогов с помощью robocopy.
    .DESCRIPTION
        Copy-QWithRobocopy является обёрткой над утилитой robocopy (входит в состав Windows).
        Явно указанные параметры robocopy: /mir /copy:<DTSO/DTO> /dcopy:DT /unilog:<log-file>
        Полный набор используемых параметров: *.* /S /E /DCOPY:DT /COPY:<DTSO/DTO> /PURGE /MIR /R:1000000 /W:30
        Важно помнить, что robocopy приводит конечный каталог в идентичное исходному каталогу состояние. Это означает, что если в конечном каталоге есть данные, которых не было в исходном каталоге, то они будут удалены.

        Существуют задачи по управлению файлами и папками, которые по тем или иным причинам затруднительно выполнить с помощью штатных командлетов PowerShell, например из-за ограничения на длину имени файлов. В таких случаях помогает robocopy.
        Однако для robocopy нужно правильным образом выставлять ключи запуска, нужно создавать пакетные задания при необходимости обработать сразу несколько каталогов, нужно вручную проверять результаты работы по логам и так далее. При этом с robocopy невозможно взаимодействовать как с командлетом PowerShell, передавая по конвейеру каталоги.
        Между тем Copy-QWithRobocopy может принимать на вход сразу список каталогов, в том числе через конвейер, что может быть полезно, когда нужно скопировать сразу много каталогов из одного места в другое.
        Также Copy-QWithRobocopy автоматически проводит анализ логов работы robocopy и сразу выдаёт краткое резюме (успешно/проблемы) для каждого обработанного каталога, причём одновременно как на экран, так и в свой собственный отдельный краткий лог-файл. В результате работы останутся доступны и логи самого robocopy, будет сохранён отдельный лог-файл для каждого обработанного каталога.
    .EXAMPLE
        PS C:\>Copy-QWithRobocopy -SourceFolders "D:\Data\marketing" -DestinationRootFolder "E:\Share"
        
        Копирование с помощью robocopy каталога "D:\Data\marketing" в новое местоположение. В результате будет создан аналогичный каталог "E:\Share\marketing".
        Файлы логов будут сохранены в каталоге "E:\Share".
        По умолчанию используется режим DTSO ("/copy:DTSO /dcopy:DT"), поэтому будут скопированы: содержимое файлов/каталогов, штампы времени, права доступа ACL и владельцы.
    .EXAMPLE
        PS C:\>Copy-QWithRobocopy -SourceFolders "'D:\Data\marketing", "D:\Data\HR" -DestinationRootFolder "E:\Share" -RobocopyLogFolder "E:\Logs" -CopyMode "DTO"
        
        Копирование с помощью robocopy двух указанных каталогов в новое местоположение. В результате в каталоге "E:\Share" будут созданы аналогичные подкаталоги.
        Файлы логов будут сохранены в каталоге "E:\Logs".
        Выбран режим DTO ("/copy:DTO /dcopy:DT"), поэтому будут скопированы: содержимое файлов/каталогов, штампы времени и владельцы. Не будут копироваться права доступа ACL.
    .EXAMPLE
        PS C:\>Get-ChildItem -Path "D:\Data\" -Directory | Copy-QWithRobocopy -DestinationRootFolder "E:\Share"
        
        Передача через конвейер списка подкаталогов в каталоге "D:\Data". В результате с помощью robocopy в каталоге "E:\Share" будут созданы аналогичные подкаталоги.
        Файлы логов будут сохранены в каталоге "E:\Share".
        По умолчанию используется режим DTSO ("/copy:DTSO /dcopy:DT"), поэтому будут скопированы: содержимое файлов/каталогов, штампы времени, права доступа ACL и владельцы.
    .EXAMPLE
        PS C:\>$folders = Get-ChildItem -Path "D:\Data\" -Directory
        PS C:\>$folders += Get-ChildItem -Path "F:\Business\" -Directory
        PS C:\>$folders += Get-Item -Path "H:\Video\"
        PS C:\>$folders | Copy-QWithRobocopy -DestinationRootFolder "E:\Share"
        
        Сбор разных каталогов в переменную-массив (как группами через Get-ChildItem, так и поодиночке через Get-Item) и дальнейшая передача через конвейер.
    .INPUTS
        System.IO.DirectoryInfo
    .OUTPUTS
        None
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Path to one or more source folders.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            { Test-Path -Path $_ -PathType "Container" },
            ErrorMessage = "{0} - there is no such catalog. Specify existing catalog."
        )]
        [string[]]$SourceFolders,
        [Parameter(Mandatory = $true,
            Position = 1,
            HelpMessage = "Path to destination root folder.")]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationRootFolder,
        [Parameter(Mandatory = $false,
            HelpMessage = "Path to robocopy logs folder.")]
        [ValidateNotNullOrEmpty()]
        [string]$RobocopyLogFolder = $DestinationRootFolder,
        [Parameter(Mandatory = $false,
            HelpMessage = "Copy with ACL+owner (DTSO) or only with owner (DTO).")]
        [ValidateSet("DTSO", "DTO")]
        [string]$CopyMode = "DTSO"
    )
    
    begin {
        $ErrorActionPreference = "Stop"

        New-Item -Path $DestinationRootFolder -ItemType "Directory" -Force | Out-Null
        [string]$OverallLogFile = Join-Path -Path $RobocopyLogFolder -ChildPath "overall.log"
        (Get-Date -Format s) + "  START SESSION" | Out-File -FilePath $OverallLogFile -Force
        "robocopy using parameters:  /mir /copy:$CopyMode /dcopy:DT /unilog:$RobocopyLogFolder..." | Out-File -FilePath $OverallLogFile -Append
        "" | Out-File -FilePath $OverallLogFile -Append
    }
    
    process {
        foreach ($sourceFolder in $SourceFolders) {
            $sourceFolder = ($sourceFolder -split "\\$")[0]    # убирает косую черту в конце пути, если таковая есть; robocopy на дух не переносит подобное
            [System.IO.DirectoryInfo]$objSourceFolder = Get-Item -Path $sourceFolder
            "---------------------------" | Out-File -FilePath $OverallLogFile -Append
            (Get-Date -Format "s") + "  Start:  " + $objSourceFolder.FullName | Write-Host -ForegroundColor "Cyan"
            (Get-Date -Format "s") + "  Start:  " + $objSourceFolder.FullName | Out-File -FilePath $OverallLogFile -Append
            [string]$RobocopyLogFile = Join-Path -Path $RobocopyLogFolder -ChildPath ($objSourceFolder.BaseName + ".log")
            if (Test-Path -Path $RobocopyLogFile -PathType "Leaf") {
                Remove-Item -Path $RobocopyLogFile -Force
            }
            StartRobocopy -SourceFolder $objSourceFolder -DestinationRootFolder $DestinationRootFolder -RobocopyLogFile $RobocopyLogFile -CopyMode $CopyMode
            [string]$Result = TestRobocopyLog -RobocopyLogFile $RobocopyLogFile
            (Get-Date -Format "s") + "  Finish:  " + $Result | Write-Host -ForegroundColor "Cyan"
            (Get-Date -Format "s") + "  Finish:  " + $Result | Out-File -FilePath $OverallLogFile -Append
        }
    }
    
    end {
        "---------------------------" | Out-File -FilePath $OverallLogFile -Append
        "" | Out-File -FilePath $OverallLogFile -Append
        (Get-Date -Format "s") + "  END SESSION" | Out-File -FilePath $OverallLogFile -Append
    }
}