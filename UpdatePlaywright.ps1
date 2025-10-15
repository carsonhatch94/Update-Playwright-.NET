param(
    [string]$projectFile = "C:\Path\To\Your\File\project.csproj",
    [string]$propsFile = "C:\Path\To\Directory.Packages.props",
    [bool]$UsePropsFile = $true
)

$projectFolder = Split-Path $projectFile
$packages = @("Microsoft.Playwright", "Microsoft.Playwright.MSTest")
$allSucceeded = $true

if ($UsePropsFile) {
    [xml]$props = Get-Content $propsFile
    foreach ($pkg in $packages) {
        $pkgVersionNode = $props.Project.ItemGroup.PackageVersion | Where-Object { $_.Include -eq $pkg }
        $currentVersion = if ($pkgVersionNode) { $pkgVersionNode.Version } else { "" }
        $pkgLower = $pkg.ToLower()
        $nugetUrl = "https://api.nuget.org/v3-flatcontainer/$pkgLower/index.json"
        $response = Invoke-RestMethod -Uri $nugetUrl
        $latestVersion = $response.versions[-1]
        Write-Host "$pkg - Current: $currentVersion, Latest: $latestVersion"
        if ($latestVersion -ne $currentVersion) {
            Write-Host "Updating $pkg to $latestVersion in Directory.Packages.props..."
            $pkgVersionNode.Version = $latestVersion
            $props.Save($propsFile)
        } else {
            Write-Host "$pkg is up to date."
        }
    }
} else {
    [xml]$csproj = Get-Content $projectFile
    foreach ($pkg in $packages) {
        $pkgRef = $csproj.Project.ItemGroup.PackageReference | Where-Object { $_.Include -eq $pkg }
        $currentVersion = ""
        if ($pkgRef) {
            if ($pkgRef.Version) { $currentVersion = $pkgRef.Version.'#text' }
            elseif ($pkgRef.Version -eq $null -and $pkgRef.GetAttribute("Version")) { $currentVersion = $pkgRef.GetAttribute("Version") }
        }
        $pkgLower = $pkg.ToLower()
        $nugetUrl = "https://api.nuget.org/v3-flatcontainer/$pkgLower/index.json"
        $response = Invoke-RestMethod -Uri $nugetUrl
        $latestVersion = $response.versions[-1]
        Write-Host "$pkg - Current: $currentVersion, Latest: $latestVersion"
        if ($latestVersion -ne $currentVersion) {
            Write-Host "Updating $pkg to $latestVersion in project file..."
            dotnet add "$projectFile" package $pkg --version $latestVersion
        } else {
            Write-Host "$pkg is up to date."
        }
    }
}

# Build the project
Write-Host "Building project..."
dotnet build $projectFile
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed."
    $allSucceeded = $false
}

# Path to playwright.ps1
$playwrightScript = "$projectFolder\bin\Debug\netX.0\playwright.ps1"

# Install browsers
if (Test-Path $playwrightScript) {
    Write-Host "Installing browsers..."
    & $playwrightScript install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Playwright browser install failed."
        $allSucceeded = $false
    }
} else {
    Write-Host "playwright.ps1 not found at $playwrightScript"
    $allSucceeded = $false
}

if ($allSucceeded) {
    Write-Host "All steps completed successfully!"
}
