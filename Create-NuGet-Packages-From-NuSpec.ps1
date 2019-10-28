<#
.SYNOPSIS
    Create a NuGet package following a TFS build from a NuSpec file contained in the solution
.DESCRIPTION
    Creates a NuGet package based on configuration information contained in one or more NuSpec files found in the TFS build output directory.
.PARAMETER BinDirectory
    The location of the binary files to bundle into the NuGet package. If running under TFS Build, this value will be overridden with the TFS Build binaries directory.
.PARAMETER FileSpec
    A file specification (*.nuspec) identifying the NuSpec files that NuGet packages should be created for.
.PARAMETER NuGetPath
    The path to the NuGet executable (optional).
.EXAMPLE
    TFSNuGet -BinDirectory "C:\Builds\1\Nick\SPADemos\bin\" -FileSpec *.nuspec -NuGetPath C:\Data\Programs\NuGet\NuGet.exe
#>
param(
    [Parameter(Mandatory=$true)][string]$BinDirectory,
    [Parameter(Mandatory=$true)][string[]]$FileSpec,
    [Parameter()][string]$NuGetPath
)

function Create-NuPkg($nuGetPath, $binDirectory, $nuspecName)
{
    $nuGet = $nuGetPath
    $nuspec = $binDirectory + '\' + $nuspecName

    Write-Host 'Creating NuGet package from nuspec file' $nuspec
    & $nuGet pack "$nuspec"      
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
}

# Navigate to the binaries directory
cd $BinDirectory

# Create NuSpec files for the assemblies that match the provided file specification
$FileSpec | ForEach-Object {
    Get-ChildItem .\ -Filter $_ | ForEach-Object {
        Create-NuPkg $NuGetPath $BinDirectory $_.Name
    }
}