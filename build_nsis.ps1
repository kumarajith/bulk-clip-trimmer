# PowerShell script to build a standalone executable for Bulk Clip Trimmer using NSIS

$ErrorActionPreference = "Stop"

# Configuration
$appName = "Bulk Clip Trimmer"
$outputDir = "$PSScriptRoot\standalone"

# Create output directory
if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Build the Flutter application in release mode
Write-Host "Building Flutter application..."
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
Write-Host "Creating standalone executable..."
try {
    & $nsisPath "$PSScriptRoot\installer.nsi"
    
    # Verify the executable was created
    if (Test-Path "$outputDir\$appName.exe") {
        Write-Host "Standalone executable created successfully at $outputDir\$appName.exe" -ForegroundColor Green
    } else {
        Write-Host "Failed to create standalone executable." -ForegroundColor Red
        exit 1
    }
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
- Trim jobs do NOT persist across sessions - each launch starts with a clean slate (as per requirements)
- All temporary files will be cleaned up when the application exits

Created: $(Get-Date -Format "yyyy-MM-dd")
"@ | Out-File -FilePath $readmePath -Encoding utf8

Write-Host "Done! Your standalone executable is ready at $outputDir\$appName.exe"
