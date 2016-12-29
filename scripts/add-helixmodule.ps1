<#
    .SYNOPSIS
    This script contains the Add-Feature and Add-Foundation methods which can be used to add a new module to a Sitecore Helix based Visual Studio solution.
    
    The Visual Studio solution should contain a add-helix-module-configuration.json file containing variables which this script will use.
    
    The Add-Feature and Add-Foundation methods can be run from the Pacakge Console Manager as long as this script is loaded in the relevant PowerShell profile. 
    Run $profile in the Pacakge Manager Console to verify the which profile is used.
#>

# Some hardcoded values
$featureModuleType = "Feature"                                      # Used in Add-Feature and Create-Config.
$foundationModuleType = "Foundation"                                # Used in Add-Foundation and Create-Config.
$addHelixModuleConfigFile = "add-helix-module-configuration.json"   # Used in Add-Module.
$csprojExtension = ".csproj"                                        # Used in Add-Projects

<#
    .SYNOPSIS
    Creates a config object which is used in the other functions in this script file.

    .DESCRIPTION
    This function should be considered private and is called from the Add-Module function.

    .Parameter JsonConfigFilePath
    The path of the json based configuration file which contains the path to the module-template folder,
    namespaces and tokens to replace.

    .Parameter ModuleType
    The type of the new module, either 'Feature' or 'Foundation'.

    .Parameter ModuleName
    The name of the new module, excluding namespaces since these are retreived from the config object. 

    .Parameter SolutionRootFolder
    The path to the folder which contains the Visual Studio solution (sln) file.

#>
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
        
        # GUIDs are needed for the VS projects
        $projectGuid = [guid]::NewGuid().toString().toUpper()
        Add-Member -InputObject $config -Name ProjectGuid -Value $projectGuid -MemberType NoteProperty
        $testProjectGuid = [guid]::NewGuid().toString().toUpper()
        Add-Member -InputObject $config -Name TestProjectGuid -Value $testProjectGuid -MemberType NoteProperty
        
        # The json config file contains two namespace prefixes. One for Foundation modules and one for Feature modules.
        # This seperation is done to allow namespace differentiation between those module types. 
        # Foundation modules could be reusable across development projects while Feature module most likely will not. 
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

<#
    .SYNOPSIS
    The main function that calls the other rename* functions.

    .DESCRIPTION
    This function should be considered private and is called from the Add-Module function.

    .PARAMETER StartPath
    The full path of the new module folder. This is used as a path to start folder and file searches.

#>
function Rename-Module
{
    Param(
        [Parameter(Position=0, Mandatory=$True)]
        [string]$StartPath
    )

    # Rename all the folders from the copied module-template.
    Rename-Folders -StartPath "$StartPath" -OldValue $config.TemplateModuleType -NewValue $config.ModuleType
    Rename-Folders -StartPath "$StartPath" -OldValue $config.TemplateModuleName -NewValue $config.ModuleName

    # Rename all the files from the copied module-template.
    Rename-Files -StartPath "$StartPath" -OldValue $config.TemplateNamespacePrefix -NewValue $config.NamespacePrefix
    Rename-Files -StartPath "$StartPath" -OldValue $config.TemplateModuleType -NewValue $config.ModuleType
    Rename-Files -StartPath "$StartPath" -OldValue $config.TemplateModuleName -NewValue $config.ModuleName

    # Update file content for GUIDs.
    Update-FileContent -StartPath "$StartPath" -OldValue $config.TemplateProjectGuid -NewValue $config.ProjectGuid -FileExtensionsRegex $config.fileExtensionsToUpdateProjectGuidsRegex
    Update-FileContent -StartPath "$StartPath" -OldValue $config.TemplateTestProjectGuid -NewValue $config.TestProjectGuid -FileExtensionsRegex $config.fileExtensionsToUpdateProjectGuidsRegex
    
    # Update file content for namespaces, module tpyes and module name.
    Update-FileContent -StartPath "$StartPath" -OldValue $config.TemplateNamespacePrefix -NewValue $config.NamespacePrefix -FileExtensionsRegex $config.FileExtensionsToUpdateContentRegex
    Update-FileContent -StartPath "$StartPath" -OldValue $config.TemplateModuleType -NewValue $config.ModuleType -FileExtensionsRegex $config.FileExtensionsToUpdateContentRegex
    Update-FileContent -StartPath "$StartPath" -OldValue $config.TemplateModuleName -NewValue $config.ModuleName -FileExtensionsRegex $config.FileExtensionsToUpdateContentRegex
}

<#
    .SYNOPSIS
    Renames files, replaces OldValue with NewValue in the filename. 

    .DESCRIPTION
    This function should be considered private and is called from the Rename-Module function.

    .PARAMETER StartPath
    The full path of the new module folder. This is used as a path to start folder and file searches.

    .PARAMETER OldValue
    The part of the filename which is used to search and is replaced with NewValue.

    .PARAMETER NewValue
    The value which is used in the replacement of OldValue.

#>
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

<#
    .SYNOPSIS
    Renames folders, replaces OldValue with NewValue in the folder name. 

    .DESCRIPTION
    This function should be considered private and is called from the Rename-Module function.

    .PARAMETER StartPath
    The full path of the new module folder. This is used as a path to start folder and file searches.

    .PARAMETER OldValue
    The part of the folder name which is used to search and is replaced with NewValue.

    .PARAMETER NewValue
    The value which is used in the replacement of OldValue.

#>
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
    # Note the usage of Sort-Object { $_.FullName.Length } -Descending. 
    # This is done to prevent exceptions with nested folders that need to be renamed.
    # Folders are renamed from lowest level to highest level. 
    $folderItems = Get-ChildItem -Directory -Path "$StartPath" -Recurse -Filter $pattern -Force | Where-Object { $_.FullName -notmatch "\\(obj|bin)\\?" } | Sort-Object { $_.FullName.Length } -Descending
    $folderItems | Rename-Item -NewName { $_.Name -replace $OldValue, $NewValue } -Force
}

<#
    .SYNOPSIS
    Updates the content of files, replaces OldValue with NewValue. 

    .DESCRIPTION
    This function should be considered private and is called from the Rename-Module function.

    .PARAMETER StartPath
    The full path of the new module folder. This is used as a path to start folder and file searches.

    .PARAMETER OldValue
    The part of the filename which is used to search and is replaced with NewValue.

    .PARAMETER NewValue
    The value which is used in the replacement of OldValue.

    .PARAMETER FileExtensionsRegex
    A regular expression that describes which file extensions are searched for.

#>
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
    
    # -ireplace: case insensitive replacement
    $filesToUpdate | ForEach-Object { (Get-Content $_ ) -ireplace [regex]::Escape($OldValue), $NewValue | Set-Content $_ -Force }
}

<#
    .SYNOPSIS
    Returns the path of the new module.

    .DESCRIPTION
    The path is constructed as follows: SolutionRootFolder\SourceFolderName\ModuleType\ModuleName.
    This function should be considered private and is called from the Add-Module function.
#>
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

<#
    .SYNOPSIS
    Helper function to retrieve the literal 'Feature' or 'Foundation' solution folder.

    .DESCRIPTION
    This function should be considered private and is called from the Add-Projects function.
#>
function Get-ModuleTypeSolutionFolder
{
    return $dte.Solution.Projects | Where-Object { $_.Name -eq $config.ModuleType -and $_.Kind -eq [EnvDTE80.ProjectKinds]::vsProjectKindSolutionFolder } | Select-Object -First 1
}

<#
    .SYNOPSIS
    Adds new module project(s) to the solution.
    
    .DESCRIPTION
    Searches for csproj files in the new module folder and uses EnvDTE80 interfaces to add these to the solution.
    This function should be considered private and is called from the Add-Module function.
#>
function Add-Projects
{
     Param(
        [Parameter(Position=0, Mandatory=$True)]
        [string]$ModulePath
    )

    Write-Output "Adding project(s)..."
    $moduleTypeFolder = Get-ModuleTypeSolutionFolder
    Write-Output $moduleTypeFolder

    # When the literal 'Feature' or 'Foundation' solution folder does not exist in the solution it will be created. 
    if (-not $moduleTypeFolder)
    {
        $dte.Solution.AddSolutionFolder($config.ModuleType)
        $moduleTypeFolder = Get-ModuleTypeSolutionFolder
    }
    $folderInterface = Get-Interface $moduleTypeFolder.Object ([EnvDTE80.SolutionFolder])
    $moduleNameFolder = $folderInterface.AddSolutionFolder($config.ModuleName)
    $moduleNameInterface = Get-Interface $moduleNameFolder.Object ([EnvDTE80.SolutionFolder])
    
    # Search in the new module folder for csproj files and add those to the solution.
    Get-ChildItem -File -Path $ModulePath -Filter "*$csprojExtension" -Recurse | ForEach-Object { $moduleNameInterface.AddFromFile("$($_.FullName)")}
    Write-Output "Saving solution..."
    
    # Strangely enough the Solution interface does not contain a simple Save() method so a call to SaveAs(fileName) with the filename needs to be done.
    $dte.Solution.SaveAs($dte.Solution.FullName)
}

<#
    .SYNOPSIS
    Main function to add a new module.

    .DESCRIPTION
    This function should be considered private and is called from the Add-Feature or Add-Foundation function.

    .PARAMETER ModuleName
    The name of the new module.

    .PARAMETER ModuleType
    The type of the new module, either 'Feature' or 'Foundation'.
#>
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
        # Do a check if there is a solution active in Visual Studio.
        # If there is no active solution the Add-Projects function would fail.
        if (-not $dte.Solution.FullName)
        {
            throw [System.ArgumentException] "There is no active solution. Load a Sitecore Helix solution first which contains an $addHelixModuleConfigFile file."
        }

        # The only reason I do this check is because I need a path to start searching for the json based config file. 
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

        # Create a config object we can use throughout the other functions.
        $config = Create-Config -JsonConfigFilePath "$configJsonFile" -ModuleType $ModuleType -ModuleName $ModuleName -SolutionRootFolder $solutionRootFolder
        
        # Get the path to the module-template folder and verify that is exists on disk.
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

    .PARAMETER Name
    The name of the new Feature, excluding the namespace prefix since that comes from the json config file.

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

    .PARAMETER Name
    The name of the new Foundation module, excluding the namespace prefix since that comes from the json config file.

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