# PowerShell script to build a standalone executable for Bulk Clip Trimmer

$ErrorActionPreference = "Stop"

# Configuration
$appName = "Bulk Clip Trimmer"
$publisherName = "Kumaji.dev"
$outputDir = "$PSScriptRoot\standalone"

# Create output directory
if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Kill any running instances of the application
Write-Host "Checking for running instances..." -ForegroundColor Cyan
try {
    $processes = Get-Process -Name "bulk_clip_trimmer" -ErrorAction SilentlyContinue
    if ($processes) {
        Write-Host "Closing running instances of the application..." -ForegroundColor Yellow
        $processes | ForEach-Object { $_.Kill() }
        Start-Sleep -Seconds 2  # Give time for processes to close
    }
} catch {
    Write-Host "Error checking for running processes: $_" -ForegroundColor Yellow
}

# Clean up any existing executable
if (Test-Path "$outputDir\$appName.exe") {
    Write-Host "Removing existing executable..." -ForegroundColor Cyan
    try {
        Remove-Item -Path "$outputDir\$appName.exe" -Force
    } catch {
        Write-Host "Warning: Could not remove existing executable. It may be in use." -ForegroundColor Yellow
        Write-Host "Please close any running instances and try again." -ForegroundColor Yellow
        exit 1
    }
}

# Build the Flutter application in release mode
Write-Host "Building Flutter application..." -ForegroundColor Cyan
try {
    flutter clean | Out-Null
    flutter build windows --release | Out-Null
} catch {
    Write-Host "Error building Flutter application: $_" -ForegroundColor Red
    exit 1
}

# Check if NSIS is installed
$nsisPath = "C:\Program Files (x86)\NSIS\makensis.exe"
if (!(Test-Path $nsisPath)) {
    Write-Host "NSIS not found at $nsisPath. Please ensure NSIS is installed correctly." -ForegroundColor Red
    exit 1
}

# Create the standalone EXE using NSIS
Write-Host "Creating standalone executable..." -ForegroundColor Cyan
try {
    & $nsisPath "$PSScriptRoot\installer.nsi"
    
    # Verify the executable was created
    if (!(Test-Path "$outputDir\$appName.exe")) {
        Write-Host "Failed to create standalone executable." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Standalone executable created successfully!" -ForegroundColor Green
} catch {
    Write-Host "Error creating standalone executable: $_" -ForegroundColor Red
    exit 1
}

# Create a README file
$readmePath = "$outputDir\README.txt"
@"
$appName - Standalone Edition

This is a standalone version of $appName with bundled FFmpeg.

To run the application:
- Simply double-click the "$appName.exe" file

Note: 
- The application will extract to a temporary directory when run
- FFmpeg binaries will be extracted to your user directory on first run (this is normal and required for operation)
- Trim jobs do NOT persist across sessions - each launch starts with a clean slate
- All temporary files will be cleaned up when the application exits

Created: $(Get-Date -Format "yyyy-MM-dd")
Publisher: $publisherName
"@ | Out-File -FilePath $readmePath -Encoding utf8

Write-Host "Done! Your standalone executable is ready at $outputDir\$appName.exe" -ForegroundColor Green
