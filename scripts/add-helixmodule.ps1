<#
    This script renames files, folders and file contents based configuration values in the add-helix-module-configuration.json file.
#>

$featureModuleType = "Feature"
$foundationModuleType = "Foundation"
$addHelixModuleConfigFile = "add-helix-module-configuration.json"

function Create-Config
{
    Param(
        [Parameter(Position=0, Mandatory=$True)]
        [string]$JsonConfigFilePath,
        [Parameter(Position=1, Mandatory=$True)]
        [string]$ModuleType,
        [Parameter(Position=2, Mandatory=$True)]
        [string]$ModuleName,
        [Parameter(Position=3, Mandatory=$True)]
        [string]$SolutionRootFolder
    )

    $jsonFile = Get-Content -Raw -Path "$JsonConfigFilePath" | ConvertFrom-Json
    
    if ($jsonFile)
    {
        $config = New-Object psobject
        Add-Member -InputObject $config -Name ModuleTemplatePath -Value $jsonFile.config.moduleTemplatePath -MemberType NoteProperty
        Add-Member -InputObject $config -Name SourceFolderName -Value $jsonFile.config.sourceFolderName -MemberType NoteProperty
        Add-Member -InputObject $config -Name TemplateNamespacePrefix -Value $jsonFile.config.templateNamespacePrefix -MemberType NoteProperty
        Add-Member -InputObject $config -Name TemplateModuleType -Value $jsonFile.config.templateModuleType -MemberType NoteProperty
        Add-Member -InputObject $config -Name TemplateModuleName -Value $jsonFile.config.templateModuleName -MemberType NoteProperty
        Add-Member -InputObject $config -Name TemplateProjectGuid -Value $jsonFile.config.templateProjectGuid -MemberType NoteProperty
        Add-Member -InputObject $config -Name TemplateTestProjectGuid -Value $jsonFile.config.templateTestProjectGuid -MemberType NoteProperty
        Add-Member -InputObject $config -Name FileExtensionsToUpdateContentRegex -Value $jsonFile.config.fileExtensionsToUpdateContentRegex -MemberType NoteProperty
        Add-Member -InputObject $config -Name FileExtensionsToUpdateProjectGuidsRegex -Value $jsonFile.config.fileExtensionsToUpdateProjectGuidsRegex -MemberType NoteProperty
        Add-Member -InputObject $config -Name ModuleType -Value $ModuleType -MemberType NoteProperty
        Add-Member -InputObject $config -Name ModuleName -Value $ModuleName -MemberType NoteProperty
        $projectGuid = [guid]::NewGuid().toString().toUpper()
        Add-Member -InputObject $config -Name ProjectGuid -Value $projectGuid -MemberType NoteProperty
        $testProjectGuid = [guid]::NewGuid().toString().toUpper()
        Add-Member -InputObject $config -Name TestProjectGuid -Value $testProjectGuid -MemberType NoteProperty
        
        $newNamespacePrefix = ""
        if ($ModuleType -eq $featureModuleType)
        {
            $newNamespacePrefix = $jsonFile.config.featureNamespacePrefix
        }
        if ($ModuleType -eq $foundationModuleType)
        {
            $newNamespacePrefix = $jsonFile.config.foundationNamespacePrefix
        }
        Add-Member -InputObject $config -Name NamespacePrefix -Value $newNamespacePrefix -MemberType NoteProperty
        Add-Member -InputObject $config -Name SolutionRootFolder -Value $SolutionRootFolder -MemberType NoteProperty

        return $config
    }
}

function Rename-Module
{
    Param(
        [Parameter(Position=0, Mandatory=$True)]
        [string]$StartPath
    )

    Rename-Folders -StartPath "$StartPath" -OldValue $config.TemplateModuleType -NewValue $config.ModuleType
    Rename-Folders -StartPath "$StartPath" -OldValue $config.TemplateModuleName -NewValue $config.ModuleName

    Rename-Files -StartPath "$StartPath" -OldValue $config.TemplateNamespacePrefix -NewValue $config.NamespacePrefix
    Rename-Files -StartPath "$StartPath" -OldValue $config.TemplateModuleType -NewValue $config.ModuleType
    Rename-Files -StartPath "$StartPath" -OldValue $config.TemplateModuleName -NewValue $config.ModuleName

    Update-FileContent -StartPath "$StartPath" -OldValue $config.TemplateProjectGuid -NewValue $config.ProjectGuid -FileExtensionsRegex $config.fileExtensionsToUpdateProjectGuidsRegex
    Update-FileContent -StartPath "$StartPath" -OldValue $config.TemplateTestProjectGuid -NewValue $config.TestProjectGuid -FileExtensionsRegex $config.fileExtensionsToUpdateProjectGuidsRegex
    Update-FileContent -StartPath "$StartPath" -OldValue $config.TemplateNamespacePrefix -NewValue $config.NamespacePrefix -FileExtensionsRegex $config.FileExtensionsToUpdateContentRegex
    Update-FileContent -StartPath "$StartPath" -OldValue $config.TemplateModuleType -NewValue $config.ModuleType -FileExtensionsRegex $config.FileExtensionsToUpdateContentRegex
    Update-FileContent -StartPath "$StartPath" -OldValue $config.TemplateModuleName -NewValue $config.ModuleName -FileExtensionsRegex $config.FileExtensionsToUpdateContentRegex
}

function Rename-Files
{
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [string]$StartPath,
        [Parameter(Position=1, Mandatory=$true)]
        [string]$OldValue,
        [Parameter(Position=2, Mandatory=$true)]
        [string]$NewValue
    )

    $pattern = "*$OldValue*"
    Write-Output "Renaming $pattern files located in $StartPath."
    $fileItems = Get-ChildItem -File -Path "$StartPath" -Filter $pattern -Recurse -Force | Where-Object { $_.FullName -notmatch "\\(obj|bin)\\?" } 
    $fileItems | Rename-Item -NewName { $_.Name -replace $OldValue, $NewValue } -Force
}

function Rename-Folders
{
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [string]$StartPath,
        [Parameter(Position=1, Mandatory=$true)]
        [string]$OldValue,
        [Parameter(Position=2, Mandatory=$true)]
        [string]$NewValue
    )

    $pattern = "*$OldValue*"
    Write-Output "Renaming $pattern folders located in $StartPath."
    $folderItems = Get-ChildItem -Directory -Path "$StartPath" -Recurse -Filter $pattern -Force | Where-Object { $_.FullName -notmatch "\\(obj|bin)\\?" } | Sort-Object { $_.FullName.Length } -Descending
    $folderItems | Rename-Item -NewName { $_.Name -replace $OldValue, $NewValue } -Force
}

function Update-FileContent
{
    Param(
        [Parameter(Position=0, Mandatory=$true)]
        [string]$StartPath,
        [Parameter(Position=1, Mandatory=$true)]
        [string]$OldValue,
        [Parameter(Position=2, Mandatory=$true)]
        [string]$NewValue,
        [Parameter(Position=3, Mandatory=$true)]
        [string]$FileExtensionsRegex
    )

    Write-Output "Renaming $OldValue to $NewValue in files matching $FileExtensionsRegex located in $StartPath."

    $filesToUpdate = Get-ChildItem -File -Path "$StartPath" -Recurse -Force | Where-Object { ( $_.FullName -notmatch "\\(obj|bin)\\?") -and ($_.Name -match $FileExtensionsRegex) } | Select-String -Pattern $OldValue | Group-Object Path | Select-Object -ExpandProperty Name
    
    $filesToUpdate | ForEach-Object { (Get-Content $_ ) -ireplace [regex]::Escape($OldValue), $NewValue | Set-Content $_ -Force }
    
    #foreach ($fileToUpdate in $filesToUpdate)
    #{
    #    (Get-Content $fileToUpdate) -ireplace [regex]::Escape($OldValue), $NewValue | Set-Content $fileToUpdate -Force
    #}
}

function Get-ModulePath
{
    $sourceFolderPath =  Join-Path -Path $config.SolutionRootFolder -ChildPath $config.SourceFolderName
    $moduleTypePath = Join-Path -Path "$sourceFolderPath" -ChildPath $config.ModuleType
    $modulePath = Join-Path -Path "$moduleTypePath" -ChildPath $config.ModuleName
    if (Test-Path $modulePath)
    {
        throw [System.ArgumentException] "$modulePath already exists."
    }

    return $modulePath
}

function Add-Projects
{
     Param(
        [Parameter(Position=0, Mandatory=$True)]
        [string]$ModulePath
    )

    Write-Output "Adding project(s)..."
    $moduleTypeFolder = Get-ModuleTypeSolutionFolder
    Write-Output $moduleTypeFolder
    if (-not $moduleTypeFolder)
    {
        $dte.Solution.AddSolutionFolder($config.ModuleType)
        $moduleTypeFolder = Get-ModuleTypeSolutionFolder
    }
    $folderInterface = Get-Interface $moduleTypeFolder.Object ([EnvDTE80.SolutionFolder])
    $moduleNameFolder = $folderInterface.AddSolutionFolder($config.ModuleName)
    $moduleNameInterface = Get-Interface $moduleNameFolder.Object ([EnvDTE80.SolutionFolder])
    Get-ChildItem -File -Path $ModulePath -Filter "*.csproj" -Recurse | ForEach-Object { $moduleNameInterface.AddFromFile("$($_.FullName)")}
    Write-Output "Saving solution..."
    $dte.Solution.SaveAs($dte.Solution.FullName)
}

function Get-ModuleTypeSolutionFolder
{
    return $dte.Solution.Projects | Where-Object { $_.Name -eq $config.ModuleType -and $_.Kind -eq [EnvDTE80.ProjectKinds]::vsProjectKindSolutionFolder } | Select-Object -First 1
}

function Add-Module
{
    Param(
        [Parameter(Position=0, Mandatory=$True)]
        [string]$ModuleName,
        [Parameter(Position=1, Mandatory=$True)]
        [string]$ModuleType
    )
    
    try
    {
        if (-not $dte.Solution.FullName)
        {
            throw [System.ArgumentException] "There is no active solution. Load a Sitecore Helix solution first which contains an $addHelixModuleConfigFile file."
        }

        $solutionRootFolder = [System.IO.Path]::GetDirectoryName($dte.Solution.FullName)
        if (-not (Test-Path "$solutionRootFolder"))
        {
            throw [System.IO.DirectoryNotFoundException] "$solutionRootFolder folder not found."
        }

        $configJsonFile = Get-ChildItem -Path "$solutionRootFolder" -File -Filter "$addHelixModuleConfigFile" -Recurse | Select-Object -First 1 | Select-Object -ExpandProperty FullName
        if (-not (Test-Path $configJsonFile))
        {
            throw [System.IO.DirectoryNotFoundException] "$configJsonFile not found."
        }

        $config = Create-Config -JsonConfigFilePath "$configJsonFile" -ModuleType $ModuleType -ModuleName $ModuleName -SolutionRootFolder $solutionRootFolder
        $copyModuleFromLocation = Join-Path -Path $config.ModuleTemplatePath -ChildPath $config.TemplateModuleName
        if (-not (Test-Path $copyModuleFromLocation))
        {
            throw [System.IO.DirectoryNotFoundException] "$copyModuleFromLocation folder not found."
        }
                
        $modulePath = Get-ModulePath
        Write-Output "Copying module template to $modulePath."
        Copy-Item -Path "$copyModuleFromLocation" -Destination "$modulePath" -Recurse
        Rename-Module -StartPath "$modulePath"
        Add-Projects -ModulePath "$modulePath"

        Write-Output "Completed adding $($config.NamespacePrefix).$moduleType.$moduleName."
    }
    catch
    {
        Write-Error $error[0]
        exit
    }
}

<#
.SYNOPSIS
    Adds a Sitecore Helix Feature module to the current solution.
    
.DESCRIPTION
    The solution should contain an add-helix-module-configuration.json file containing 
    paths to the module template folder and namespace settings for the new module. 

.EXAMPLE
    Add-Feature Navigation

#>
function Add-Feature
{
    Param(
        [Parameter(Position=0, Mandatory=$True)]
        [string]$Name
    )

    Add-Module -ModuleName $Name -ModuleType $featureModuleType
}

<#
.SYNOPSIS
    Adds a Sitecore Helix Foundation module to the current solution.
    
.DESCRIPTION
    The solution should contain an add-helix-module-configuration.json file containing 
    paths to the module template folder and namespace settings for the new module. 

.EXAMPLE
    Add-Foundation Dictionary

#>
function Add-Foundation
{
    Param(
        [Parameter(Position=0, Mandatory=$True)]
        [string]$Name
    )

    Add-Module -ModuleName $Name -ModuleType $foundationModuleType
}