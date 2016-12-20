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
        [string]$JsonConfigFilePath,
        [Parameter(Position=1, Mandatory=$True)]
        [string]$ModuleType,
        [Parameter(Position=2, Mandatory=$True)]
        [string]$ModuleName
    )

    $jsonFile = Get-Content -Raw -Path "$JsonConfigFilePath" | ConvertFrom-Json
    
    if ($jsonFile)
    {
        $config = New-Object psobject
        Add-Member -InputObject $config -Name SourceFolderName -Value $jsonFile.config.sourceFolderName -MemberType NoteProperty
        Add-Member -InputObject $config -Name OldNamespacePrefix -Value $jsonFile.config.oldNamespacePrefix -MemberType NoteProperty
        Add-Member -InputObject $config -Name OldModuleType -Value $jsonFile.config.oldModuleType -MemberType NoteProperty
        Add-Member -InputObject $config -Name OldModuleName -Value $jsonFile.config.oldModuleName -MemberType NoteProperty
        Add-Member -InputObject $config -Name OldProjectGuid -Value $jsonFile.config.oldProjectGuid -MemberType NoteProperty
        Add-Member -InputObject $config -Name OldTestProjectGuid -Value $jsonFile.config.oldTestProjectGuid -MemberType NoteProperty
        Add-Member -InputObject $config -Name FileExtensionsToUpdateContentRegex -Value $jsonFile.config.fileExtensionsToUpdateContentRegex -MemberType NoteProperty
        Add-Member -InputObject $config -Name FileExtensionsToUpdateProjectGuidsRegex -Value $jsonFile.config.fileExtensionsToUpdateProjectGuidsRegex -MemberType NoteProperty
        Add-Member -InputObject $config -Name NewModuleType -Value $ModuleType -MemberType NoteProperty
        Add-Member -InputObject $config -Name NewModuleName -Value $ModuleName -MemberType NoteProperty
        $projectGuid = [guid]::NewGuid().toString().toUpper()
        Add-Member -InputObject $config -Name NewProjectGuid -Value $projectGuid -MemberType NoteProperty
        $testProjectGuid = [guid]::NewGuid().toString().toUpper()
        Add-Member -InputObject $config -Name NewTestProjectGuid -Value $testProjectGuid -MemberType NoteProperty
        
        $newNamespacePrefix = ""
        if ($ModuleType -eq $featureModuleType)
        {
            $newNamespacePrefix = $jsonFile.config.newFeatureNamespacePrefix
        }
        if ($ModuleType -eq $foundationModuleType)
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
        [string]$StartPath
    )

    Rename-Folders -StartPath "$StartPath" -OldValue $config.OldModuleType -NewValue $config.NewModuleType
    Rename-Folders -StartPath "$StartPath" -OldValue $config.OldModuleName -NewValue $config.NewModuleName

    Rename-Files -StartPath "$StartPath" -OldValue $config.OldNamespacePrefix -NewValue $config.NewNamespacePrefix
    Rename-Files -StartPath "$StartPath" -OldValue $config.OldModuleType -NewValue $config.NewModuleType
    Rename-Files -StartPath "$StartPath" -OldValue $config.OldModuleName -NewValue $config.NewModuleName

    Update-FileContent -StartPath "$StartPath" -OldValue $config.OldProjectGuid -NewValue $config.NewProjectGuid -FileExtensionsRegex $config.fileExtensionsToUpdateProjectGuidsRegex
    Update-FileContent -StartPath "$StartPath" -OldValue $config.OldTestProjectGuid -NewValue $config.NewTestProjectGuid -FileExtensionsRegex $config.fileExtensionsToUpdateProjectGuidsRegex
    Update-FileContent -StartPath "$StartPath" -OldValue $config.OldNamespacePrefix -NewValue $config.NewNamespacePrefix -FileExtensionsRegex $config.FileExtensionsToUpdateContentRegex
    Update-FileContent -StartPath "$StartPath" -OldValue $config.OldModuleType -NewValue $config.NewModuleType -FileExtensionsRegex $config.FileExtensionsToUpdateContentRegex
    Update-FileContent -StartPath "$StartPath" -OldValue $config.OldModuleName -NewValue $config.NewModuleName -FileExtensionsRegex $config.FileExtensionsToUpdateContentRegex
}

function Rename-Files
{
    [CmdletBinding()]
    Param(
        [Parameter(Position=1, Mandatory=$true)]
        [string]$StartPath,
        [Parameter(Position=2, Mandatory=$true)]
        [string]$OldValue,
        [Parameter(Position=3, Mandatory=$true)]
        [string]$NewValue
    )

    $pattern = "*$OldValue*"
    Log "Renaming $pattern files located in $StartPath." -FontColor Magenta
    $fileItems = Get-ChildItem -File -Path "$StartPath" -Filter $pattern -Recurse -Force | Where-Object { $_.FullName -notmatch "\\(obj|bin)\\?" } 
    $fileItems -join ", " | Log
    $fileItems | Rename-Item -NewName { $_.Name -replace $OldValue, $NewValue } -Force
}

function Rename-Folders
{
    [CmdletBinding()]
    Param(
        [Parameter(Position=1, Mandatory=$true)]
        [string]$StartPath,
        [Parameter(Position=2, Mandatory=$true)]
        [string]$OldValue,
        [Parameter(Position=3, Mandatory=$true)]
        [string]$NewValue
    )

    $pattern = "*$OldValue*"
    Log "Renaming $pattern folders located in $StartPath." -FontColor Magenta
    $folderItems = Get-ChildItem -Directory -Path "$StartPath" -Recurse -Filter $pattern -Force | Where-Object { $_.FullName -notmatch "\\(obj|bin)\\?" } | Sort-Object { $_.FullName.Length } -Descending
    $folderItems -join ", " | Log

    $folderItems | Rename-Item -NewName { $_.Name -replace $OldValue, $NewValue } -Force
}

function Update-FileContent
{
    [CmdletBinding()]
    Param(
        [Parameter(Position=1, Mandatory=$true)]
        [string]$StartPath,
        [Parameter(Position=2, Mandatory=$true)]
        [string]$OldValue,
        [Parameter(Position=3, Mandatory=$true)]
        [string]$NewValue,
        [Parameter(Position=4, Mandatory=$true)]
        [string]$FileExtensionsRegex
    )

    Log "Renaming $OldValue to $NewValue in files matching $FileExtensionsRegex located in $StartPath." -FontColor Magenta

    $filesToUpdate = Get-ChildItem -File -Path "$StartPath" -Recurse -Force | Where-Object { ( $_.FullName -notmatch "\\(obj|bin)\\?") -and ($_.Name -match $FileExtensionsRegex) } | Select-String -Pattern $OldValue | group Path | select -ExpandProperty Name
    $filesToUpdate -join ", " | Log
    foreach ($fileToUpdate in $filesToUpdate)
    {
        (Get-Content $fileToUpdate) -ireplace [regex]::Escape($OldValue), $NewValue | Set-Content $fileToUpdate -Force
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
            Rename-Module -StartPath "$modulePath"

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