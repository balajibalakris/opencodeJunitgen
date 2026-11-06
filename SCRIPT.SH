param (
    [string]$FilePath,
    [string]$ProjectDir
)

# 1. Validation
if (-not $FilePath -or -not $ProjectDir) {
    Write-Error "FilePath or ProjectDir not provided."
    exit 1
}

# Normalize path separators
$NormalizedPath = $FilePath.Replace('/', '\')

if (-not $NormalizedPath.Contains("src\main\java")) {
    Write-Host "Notice: File is not inside 'src\main\java'. Skipping."
    exit 0
}

# 2. Resolve the matching Test File Path
$TestFilePath = $NormalizedPath.Replace("src\main\java", "src\test\java")
$TestFilePath = $TestFilePath -replace "\.java$", "Test.java"

# 3. Get git diff for the file
Set-Location -Path $ProjectDir
$Diff = git diff HEAD -- "$FilePath"

if (-not $Diff) {
    $Diff = git diff HEAD~1 -- "$FilePath"
}

Write-Host "=========================================="
Write-Host "Source File : $FilePath"
Write-Host "Test File   : $TestFilePath"
Write-Host "=========================================="

# 4. Prompt OpenCode
$Prompt = @"
Follow the testing instructions and rules in agent.md.
Analyze the diff for '$FilePath' and update or create its unit tests in '$TestFilePath' to ensure full branch and line coverage for the new changes:

```diff
$Diff
