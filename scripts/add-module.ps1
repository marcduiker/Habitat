<#
    This script renames files, folders and file contents based configuration values in the add-module-configuration.json file.
#>

$Global:LogToFile = "$PSScriptRoot\add-module.log"

. "$PSScriptRoot\_log.ps1"

$featureModuleType = "Feature"
$foundationModuleType = "Foundation"

function Create-Config
{
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$True)]
        [string]$jsonConfigFilePath,
        [Parameter(Position=1, Mandatory=$True)]
        [string]$moduleType,
        [Parameter(Position=2, Mandatory=$True)]
        [string]$moduleName
    )

    $jsonFile = Get-Content -Raw -Path "$jsonConfigFilePath" | ConvertFrom-Json
    
    if ($jsonFile)
    {
        $config = New-Object psobject
        Add-Member -InputObject $config -Name SourceFolderName -Value $jsonFile.config.sourceFolderName -MemberType NoteProperty
        Add-Member -InputObject $config -Name OldModuleType -Value $jsonFile.config.oldModuleType -MemberType NoteProperty
        Add-Member -InputObject $config -Name OldModuleName -Value $jsonFile.config.oldModuleName -MemberType NoteProperty
        Add-Member -InputObject $config -Name OldProjectGuid -Value $jsonFile.config.oldProjectGuid -MemberType NoteProperty
        Add-Member -InputObject $config -Name OldTestProjectGuid -Value $jsonFile.config.oldTestProjectGuid -MemberType NoteProperty
        Add-Member -InputObject $config -Name FileExtensionsToUpdateContentRegex -Value $jsonFile.config.fileExtensionsToUpdateContentRegex -MemberType NoteProperty
        Add-Member -InputObject $config -Name FileExtensionsToUpdateProjectGuidsRegex -Value $jsonFile.config.fileExtensionsToUpdateProjectGuidsRegex -MemberType NoteProperty
        Add-Member -InputObject $config -Name NewModuleType -Value $moduleType -MemberType NoteProperty
        Add-Member -InputObject $config -Name NewModuleName -Value $moduleName -MemberType NoteProperty
        $projectGuid = [guid]::NewGuid().toString().toUpper()
        Add-Member -InputObject $config -Name NewProjectGuid -Value $projectGuid -MemberType NoteProperty
        $testProjectGuid = [guid]::NewGuid().toString().toUpper()
        Add-Member -InputObject $config -Name NewTestProjectGuid -Value $testProjectGuid -MemberType NoteProperty
        
        $newNamespacePrefix = ""
        if ($moduleType -eq $featureModuleType)
        {
            $newNamespacePrefix = $jsonFile.config.newFeatureNamespacePrefix
        }
        if ($moduleType -eq $foundationModuleType)
        {
            $newNamespacePrefix = $jsonFile.config.newFoundationNamespacePrefix
        }
        Add-Member -InputObject $config -Name NewNamespacePrefix -Value $newNamespacePrefix -MemberType NoteProperty

        return $config
    }
}

function Rename-Module
{
    [CmdletBinding()]
    Param(
        [Parameter(Position=1, Mandatory=$True)]
        [string]$startPath
    )

    Rename-Folders -StartPath "$startPath" -OldValue $config.OldModuleType -NewValue $config.NewModuleType
    Rename-Folders -StartPath "$startPath" -OldValue $config.OldModuleName -NewValue $config.NewModuleName

    Rename-Files -StartPath "$startPath" -OldValue $config.OldNamespacePrefix -NewValue $config.NewNamespacePrefix
    Rename-Files -StartPath "$startPath" -OldValue $config.OldModuleType -NewValue $config.NewModuleType
    Rename-Files -StartPath "$startPath" -OldValue $config.OldModuleName -NewValue $config.NewModuleName

    Update-FileContent -StartPath "$startPath" -OldValue $config.OldProjectGuid -NewValue $config.NewProjectGuid -FileExtensionsRegex $config.fileExtensionsToUpdateProjectGuidsRegex
    Update-FileContent -StartPath "$startPath" -OldValue $config.OldTestProjectGuid -NewValue $config.NewTestProjectGuid -FileExtensionsRegex $config.fileExtensionsToUpdateProjectGuidsRegex
    Update-FileContent -StartPath "$startPath" -OldValue $config.OldNamespacePrefix -NewValue $config.NewNamespacePrefix -FileExtensionsRegex $config.FileExtensionsToUpdateContentRegex
    Update-FileContent -StartPath "$startPath" -OldValue $config.OldModuleType -NewValue $config.NewModuleType -FileExtensionsRegex $config.FileExtensionsToUpdateContentRegex
    Update-FileContent -StartPath "$startPath" -OldValue $config.OldModuleName -NewValue $config.NewModuleName -FileExtensionsRegex $config.FileExtensionsToUpdateContentRegex
}

function Rename-Files
{
    [CmdletBinding()]
    Param(
        [Parameter(Position=1, Mandatory=$true)]
        [string]$startPath,
        [Parameter(Position=2, Mandatory=$true)]
        [string]$oldValue,
        [Parameter(Position=3, Mandatory=$true)]
        [string]$newValue
    )

    $pattern = "*$oldValue*"
    Log "Renaming $pattern files located in $startPath." -FontColor Magenta
    $fileItems = Get-ChildItem -File -Path "$startPath" -Filter $pattern -Recurse -Force | Where-Object { $_.FullName -notmatch "\\(obj|bin)\\?" } 
    $fileItems -join ", " | Log
    $fileItems | Rename-Item -NewName { $_.Name -replace $OldValue, $newValue } -Force
}

function Rename-Folders
{
    [CmdletBinding()]
    Param(
        [Parameter(Position=1, Mandatory=$true)]
        [string]$startPath,
        [Parameter(Position=2, Mandatory=$true)]
        [string]$oldValue,
        [Parameter(Position=3, Mandatory=$true)]
        [string]$newValue
    )

    $pattern = "*$oldValue*"
    Log "Renaming $pattern folders located in $startPath." -FontColor Magenta
    $folderItems = Get-ChildItem -Directory -Path "$startPath" -Recurse -Filter $pattern -Force | Where-Object { $_.FullName -notmatch "\\(obj|bin)\\?" } | Sort-Object { $_.FullName.Length } -Descending
    $folderItems -join ", " | Log

    $folderItems | Rename-Item -NewName { $_.Name -replace $oldValue, $newValue } -Force
}

function Update-FileContent
{
    [CmdletBinding()]
    Param(
        [Parameter(Position=1, Mandatory=$true)]
        [string]$startPath,
        [Parameter(Position=2, Mandatory=$true)]
        [string]$oldValue,
        [Parameter(Position=3, Mandatory=$true)]
        [string]$newValue,
        [Parameter(Position=4, Mandatory=$true)]
        [string]$fileExtensionsRegex
    )

    Log "Renaming $oldValue to $newValue in files matching $fileExtensionsRegex located in $startPath." -FontColor Magenta

    $filesToUpdate = Get-ChildItem -File -Path "$startPath" -Recurse -Force | Where-Object { ( $_.FullName -notmatch "\\(obj|bin)\\?") -and ($_.Name -match $fileExtensionsRegex) } | Select-String -Pattern $oldValue | group Path | select -ExpandProperty Name
    $filesToUpdate -join ", " | Log
    foreach ($fileToUpdate in $filesToUpdate)
    {
        (Get-Content $fileToUpdate) -ireplace [regex]::Escape($oldValue), $newValue | Set-Content $fileToUpdate -Force
    }
}

function Ask-ModuleType
{
    $question = 'Enter [0] to create a Feature module, [1] to create a Foundation module or [X] to exit.'
    $feature = New-Object Management.Automation.Host.ChoiceDescription "&0 - Feature", "Creates a Feature Module"
    $foundation = New-Object Management.Automation.Host.ChoiceDescription "&1 - Foundation", "Creates a Foundation Module"
    $exit = New-Object Management.Automation.Host.ChoiceDescription "&X - Exit", "Exits the script"
    $options = [Management.Automation.Host.ChoiceDescription[]]($feature, $foundation, $exit)
    $decision = $Host.UI.PromptForChoice("", $question, $options, 0)

    return $decision
}

function Show-Confirmation
{
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [string]$moduleType,
        [Parameter(Position=1, Mandatory=$true)]
        [string]$moduleName
    )

    $message  = "You are about to add the following module: $moduleType.$moduleName"
    $question = "Do you want to continue?"
    $yes = New-Object Management.Automation.Host.ChoiceDescription "&Yes", "Continues with adding a new module."
    $no = New-Object Management.Automation.Host.ChoiceDescription "&No", "Stops the script"
    $options = [Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $decision = $Host.UI.PromptForChoice($message, $question, $options, 0)

    return $decision
}

function Get-ModulePath
{
    $sourceFolderPath = Resolve-Path "$PSScriptRoot\..\$($config.SourceFolderName)"
    $moduleTypePath = Join-Path -Path "$sourceFolderPath" -ChildPath $config.NewModuleType
    $modulePath = Join-Path -Path "$moduleTypePath" -ChildPath $config.NewModuleName
    if (Test-Path $modulePath)
    {
        throw [System.ArgumentException] "$modulePath already exists."
    }

    return $modulePath
}

try
{
    $configJsonFile = "$PSScriptRoot\add-module-configuration.json"
    if (-not (Test-Path $configJsonFile))
    {
        throw [System.IO.DirectoryNotFoundException] "$configJsonFile not found."
    }

    Write-Host ""
    Write-Host "This script can create a new folder structure and Visual Studio project for a Sitecore Feature or Foundation module."
    Write-Host "The module name should not include any whitespace nor include the Feature or Foundation prefix."
    Write-Host "   EXAMPLE: Carousel"
    $moduleName = Read-Host -Prompt "Please enter a name for the new module"
    $decisionModuleType = Ask-ModuleType
    if (($decisionModuleType -eq 0) -or ($decisionModuleType -eq 1)) 
    {
        $moduleType = ""
        switch ($decisionModuleType)
        {
            0 { $moduleType = $featureModuleType }
            1 { $moduleType = $foundationModuleType }
        }
        
        $decisionConfirmation = Show-Confirmation -moduleType $moduleType -moduleName $moduleName
        if ($decisionConfirmation -eq 0)
        {
            $config = Create-Config -jsonConfigFilePath "$configJsonFile" -moduleType $moduleType -moduleName $moduleName
            $copyModuleFromLocation = Resolve-Path "$PSScriptRoot\..\module-template\$($config.OldModuleName)"
            if (-not (Test-Path $copyModuleFromLocation))
            {
                throw [System.IO.DirectoryNotFoundException] "module-template folder not found."
            }
            
            $modulePath = Get-ModulePath
            Log "Copying module template to $modulePath." -FontColor Magenta
            Copy-Item -Path "$copyModuleFromLocation" -Destination "$modulePath" -Recurse
            Rename-Module  -StartPath "$modulePath"

            Log "Completed adding $moduleType $moduleName." -FontColor Green
        }
    } 
    else 
    {
        Log 'Cancelled the addition of a module.' -FontColor Yellow
    } 
}
catch
{
    Log $error[0] -FontColor "Red"
    exit
}