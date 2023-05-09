$MonoCecilFileName = "Mono.Cecil.dll"
$ModsToCheckFolder = "ModsToCheck"
$ApprovedModsFolder = "ApprovedMods"
$ReposFolder = "Repos"

$currentDirectory = Get-Location
$monoCecilPath = Join-Path $currentDirectory $MonoCecilFileName
$modsToCheckPath = Join-Path $currentDirectory $ModsToCheckFolder
$approvedModsPath = Join-Path $currentDirectory $ApprovedModsFolder

Write-Host ""

if (-not (Test-Path $monoCecilPath)) {
    Write-Host "Mono.Cecil.dll not found in the current directory."
    exit 1
}

if (-not (Test-Path $modsToCheckPath)) {
    Write-Host "ModsToCheck folder not found in the current directory. Creating it now."
    New-Item -ItemType Directory -Path $modsToCheckPath | Out-Null
}

$dllFiles = Get-ChildItem $modsToCheckPath -Filter *.dll

if ($dllFiles.Count -eq 0) {
    Write-Host "No DLL files found in the ModsToCheck folder."
    exit 1
}

# Windows like to block access to files from the webs
Unblock-File $monoCecilPath

# Load Cecil into this powershell session
Add-Type -Path $monoCecilPath

if (-not (Test-Path $approvedModsPath)) {
    Write-Host "$ApprovedModsFolder folder not found in the current directory. Creating it now."
    New-Item -ItemType Directory -Path $approvedModsPath | Out-Null
}

# Remove current mods in the approved folder
Remove-Item "$approvedModsPath/*.dll" -Recurse -Force

# Fetch the data from the API endpoint
$cvrmgResponse = Invoke-WebRequest -Uri "https://api.cvrmg.com/v1/mods/" -UseBasicParsing

# Convert the JSON response to a PowerShell object
$cvrmgMods = $cvrmgResponse.Content | ConvertFrom-Json

Write-Host "Looking for previously approved mods matching the ones we want to check..."
Write-Host ""
# Find the verified mod corresponding to the Dlls and download them into the approved folder
foreach ($dllFile in $dllFiles) {
    $resolvedDllPath = $dllFile.FullName
    $resolvedDllName = $dllFile.Name

    # Use Cecil to read the assembly metadata
    $assembly = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($resolvedDllPath)

    # Get the MelonLoader.MelonInfoAttribute custom attribute
    $melonInfoAttribute = $assembly.CustomAttributes | where { $_.AttributeType.FullName -eq 'MelonLoader.MelonInfoAttribute' }

    # Get the second constructor argument of the MelonLoader.MelonInfoAttribute custom attribute
    $melonName = $melonInfoAttribute.ConstructorArguments[1].Value

    # Find the matching mod with approvalStatus = 1
    $matchingMod = $cvrmgMods | Where-Object {
        ($_.aliases -contains $melonName) -and ($_.versions.approvalStatus -eq 1)
    }

    # Get the downloadLink
    if ($matchingMod) {
        $downloadLink = $matchingMod.versions.downloadLink

        Write-Host "`tFound the latest approved $melonName! Download Link: $downloadLink"
        $outputFile = Join-Path $approvedModsPath $resolvedDllName
        Write-Host "`tDownloading to: $outputFile"
        Invoke-WebRequest -Uri $downloadLink -UseBasicParsing -OutFile $outputFile

    }
    else {
        Write-Host "`tNo approved mod found for $melonName"
    }
    Write-Host ""
}

Write-Host ""
Read-Host -Prompt "Press Enter to decompile the Mods"
Write-Host ""

# Decompile the Mods to Check
foreach($dllFile in $dllFiles) {

    # Reset to starting dir each loop
    Set-Location $currentDirectory

    Write-Host "`tHandling $dllFile"

    #Find matching approved mods
    $approvedDlls = Get-ChildItem -Path $approvedModsPath -Filter $dllFile.Name

    $skipApproved = $False
    if ($approvedDlls.Count -ne 1) {
        Write-Host -ForegroundColor Red "`t`tDid not find matching approved mod, or found more than one. It won't not have a diff."
        $skipApproved = $True
    }

    # Save project name
    $projectName = [System.IO.Path]::GetFileNameWithoutExtension($dllFile.Name)

    $projectFolderPath = [IO.Path]::Combine($currentDirectory, $ReposFolder, $projectName)

    # Delete the folder if already exists
    if (Test-Path $projectFolderPath) {
        Remove-Item -Recurse -Force $projectFolderPath
    }

    # Create folder
    New-Item -ItemType Directory -Force -Path $projectFolderPath | Out-Null

    # Initialize Git repo
    Set-Location $projectFolderPath
    git init | Out-Null

    # Run dnSpy commands
    if(!$skipApproved) {
        $approvedDllPath = Join-Path $approvedModsPath $dllFile.Name
        dnSpy.Console --sln-name "$projectName.sln" --no-tokens --sort-members --sort-custom-attrs -o ".\" $approvedDllPath
        git add . | Out-Null
        git commit -m "Approved Decompilation" | Out-Null
        Write-Host "`t`tDecompiled the approved version of the mod and commited. "

        # Delete everything except the .git folder
        Get-ChildItem $projectFolderPath -Exclude '.git' | Remove-Item -Recurse -Force
    }

    $toCheckDllPath = Join-Path $modsToCheckPath $dllFile.Name
    dnSpy.Console --sln-name "$projectName.sln" --no-tokens --sort-members --sort-custom-attrs -o ".\" $toCheckDllPath
    git add . | Out-Null
    Write-Host "`t`tDecompiled the version of the mod to check and staged the files. "
}

Set-Location $currentDirectory

Write-Host ""
Write-Host "Finished!"
Write-Host ""
Read-Host -Prompt "Press Enter to exit"
