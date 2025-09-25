# Import classes
$ClassesFiles = Get-ChildItem -Path "$PSScriptRoot\classes" -Filter "*.ps1"
foreach ($file in $ClassesFiles) {
    . $file.FullName
}

# Import functions
$FunctionFiles = Get-ChildItem -Path "$PSScriptRoot\functions" -Filter "*.ps1"
foreach ($file in $FunctionFiles) {
    . $file.FullName
}

# Set aliases
New-Alias -Name "pssession" -Value "New-QPSSession"
New-Alias -Name "enter" -Value "Enter-QPSSession"
New-Alias -Name "enterpc" -Value "Enter-QPSSessionPC"
New-Alias -Name "import" -Value "Import-QPSSession"
New-Alias -Name "reboot" -Value "Restart-QComputer"
New-Alias -Name "cpr" -Value "Copy-QWithRobocopy"