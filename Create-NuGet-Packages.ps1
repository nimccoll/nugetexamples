<#
.SYNOPSIS
    Create a NuGet package following a TFS build
.DESCRIPTION
    Creates a NuGet package containing the assemblies found in the TFS build output directory.
.PARAMETER BinDirectory
    The location of the binary files to bundle into the NuGet package. If running under TFS Build, this value will be overridden with the TFS Build binaries directory.
.PARAMETER AssemblySpec
    A file specification (*.*, *.dll, *.exe) identifying the assemblies that NuGet packages should be created for.
.PARAMETER Version
    A version number for the NuGet package in the form 9.9.9.9 (optional). If running under TFS Build, this value will be computed from the TFS Build number.
.PARAMETER NuGetPath
    The path to the NuGet executable (optional).
.EXAMPLE
    TFSNuGet -BinDirectory "C:\Builds\1\Nick\SPADemos\bin\" -AssemblySpec *.* -Version 1.0.0.0 -NuGetPath C:\Data\Programs\NuGet\NuGet.exe
#>
param(
    [Parameter(Mandatory=$true)][string]$BinDirectory,
    [Parameter(Mandatory=$true)][string[]]$AssemblySpec,
    [Parameter()][string]$Version,
    [Parameter()][string]$NuGetPath
)

function Create-NuPkg($nuGetPath, $binDirectory, $assemblyName, $version)
{
    $nuGet = $nuGetPath
    $nuspec = $binDirectory + '\' + ($assemblyName -replace "dll", "nuspec")

    Write-Host 'Creating NuSpec file for assembly' $assemblyName
    & $nuGet spec -a $assemblyName      
    
    # Remove sample dependency entry
    $xml = [xml](Get-Content($nuspec))
    $package = $xml["package"]
    if ($package)
    {
        $metaData = $package["metadata"]
        if ($metaData)
        {
            $licenseUrl = $metaData["licenseUrl"]
            if ($licenseUrl)
            {
                $metaData.RemoveChild($licenseUrl)
            }
            $projectUrl = $metaData["projectUrl"]
            if ($projectUrl)
            {
                $metaData.RemoveChild($projectUrl)
            }
            $iconUrl = $metaData["iconUrl"]
            if ($iconUrl)
            {
                $metaData.RemoveChild($iconUrl)
            }
            $description = $metaData["description"]
            if ($description)
            {
                $description.InnerText = $assemblyName
            }
            $releaseNotes = $metaData["releaseNotes"]
            if ($releaseNotes)
            {
                $metaData.RemoveChild($releaseNotes)
            }
            $tags = $metaData["tags"]
            if ($tags)
            {
                $metaData.RemoveChild($tags)
            }
            $dependencies = $metaData["dependencies"]
            if ($dependencies)
            {
                $metaData.RemoveChild($dependencies)
            }
        }
    }
    
    $files = $xml.CreateElement("files")
    $file = $xml.CreateElement("file")
    $file.SetAttribute("src", $assemblyName)
    $file.SetAttribute("target", "lib")
    $files.AppendChild($file)
    $package.AppendChild($files)
    $xml.Save($nuspec)

    Write-Host 'Creating NuGet package from nuspec file' $nuspec
    & $nuGet pack "$nuspec" -Version $version      
}

# Default version
if ($Version -eq '')
{
    $Version = '1.0.0.0'
}

# Default NuGet path
if ($NuGetPath -eq '')
{
    $NuGetPath = 'C:\Program Files\Microsoft Team Foundation Server 12.0\Tools\NuGet.exe'
}

# Determine if we are executing under TFS Build
if ($env:TF_BUILD)
{
    $BinDirectory = $env:TF_BUILD_BINARIESDIRECTORY
    $buildNumber = $env:TF_BUILD_BUILDNUMBER
    $Version = $buildNumber.substring($buildNumber.indexof('_') + 1) + '.0.0'
}

# Navigate to the binaries directory
cd $BinDirectory

# Create NuSpec files for the assemblies that match the provided file specification
$AssemblySpec | ForEach-Object {
    Get-ChildItem .\ -Filter $_ | ForEach-Object {
        Create-NuPkg $NuGetPath $BinDirectory $_.Name $Version
    }
}