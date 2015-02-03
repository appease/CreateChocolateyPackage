function CreateChocolateyPackage(
[string]$Version,
[string]$Tools,
[string]$OutputDirectory){
    # init working dir
    $workingDirPath = "$env:TEMP\Posh-CI-CreateChocolateyPackage-Build-Chocolatey"
    if(Test-Path $workingDirPath){
        Remove-Item $workingDirPath -Force -Recurse
    }
    New-Item $workingDirPath -ItemType Directory | Out-Null

    $chocolateyPackageToolsDirPath = "$workingDirPath\tools"
    New-Item $chocolateyPackageToolsDirPath -ItemType Directory | Out-Null

    # install chocolatey
    try{
        Get-Command choco -ErrorAction Stop | Out-Null
    }
    catch{             
        iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    }

    $nuspecFileName = 'posh-ci-createchocolateypackage.nuspec'

    Copy-Item `
    -Path "$PSScriptRoot\Chocolatey\$nuspecFileName" `
    -Destination $workingDirPath

    Copy-Item `
    -Path "$PSScriptRoot\Chocolatey\*" `
    -Destination $chocolateyPackageToolsDirPath `
    -Exclude $nuspecFileName

    Copy-Item `
    -Path "$Tools\*" `
    -Destination $chocolateyPackageToolsDirPath `
    -Recurse
           
    $nuspecFilePath = "$workingDirPath\$nuspecFileName"

    # substitute vars into nuspec
    (gc $nuspecFilePath).Replace('$version$',$Version)|sc $nuspecFilePath

    Push-Location $OutputDirectory
    chocolatey pack $nuspecFilePath
    Pop-Location 

}

function Compile(
[string]$Version,
[string]$SourceDirPath,
[string]$OutputDirPath){

    # Import-Module looks for module manifest with same name as containing folder
    $compiledPowerShellModuleDirPath = "$OutputDirPath\Posh-CI-CreateChocolateyPackage"
    New-Item $compiledPowerShellModuleDirPath -ItemType Directory | Out-Null

    # Copy the source files to the output
    Copy-Item `
    -Path "$SourceDirPath\*" `
    -Destination $compiledPowerShellModuleDirPath `
    -Recurse

    # Generate powershell module manifest
    New-ModuleManifest `
        -Path "$compiledPowerShellModuleDirPath\Posh-CI-CreateChocolateyPackage.psd1" `
        -ModuleVersion $Version `
        -Guid '90f3b2fd-318a-492c-8a47-8ef5a21253e1' `
        -Author 'Chris Dostert' `
        -Description 'A Posh-CI step that creates one or more Chocolatey packages' `
        -PowerShellVersion '3.0' `
        -RootModule 'Posh-CI-CreateChocolateyPackage.psm1'
}

function New-Build(
[string]$Version,
[string]$ArtifactsDirPath,
[string]$SourceDirPath = "$PSScriptRoot\..\Source"){

    $ArtifactsDirPath = Resolve-Path $ArtifactsDirPath
    
    # init PowerShell module compiler output dir
    $compilerOutputDir = "$env:TEMP\Posh-CI-CreateChocolateyPackage-Compiler-Output"
    if(Test-Path $compilerOutputDir){
        Remove-Item $compilerOutputDir -Force -Recurse
    }
    New-Item $compilerOutputDir -ItemType Directory | Out-Null

    Compile -Version $Version -SourceDirPath $SourceDirPath -OutputDirPath $compilerOutputDir
    CreateChocolateyPackage -Version $Version -Tools $compilerOutputDir -OutputDirectory $ArtifactsDirPath
        
}
