# PowerShell script to download FFmpeg for Bulk Clip Trimmer

$ErrorActionPreference = "Stop"

# Create directories if they don't exist
$binDir = "$PSScriptRoot\windows\ffmpeg"
$assetsDir = "$PSScriptRoot\assets\bin"

if (!(Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    Write-Host "Created directory: $binDir"
}

if (!(Test-Path $assetsDir)) {
    New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
    Write-Host "Created directory: $assetsDir"
}

# URLs for FFmpeg
$ffmpegUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
$downloadPath = "$env:TEMP\ffmpeg.zip"

Write-Host "Downloading FFmpeg from $ffmpegUrl..."
try {
    Invoke-WebRequest -Uri $ffmpegUrl -OutFile $downloadPath
    Write-Host "Download complete."
} catch {
    Write-Host "Error downloading FFmpeg: $_" -ForegroundColor Red
    exit 1
}

# Extract FFmpeg
Write-Host "Extracting FFmpeg..."
try {
    Expand-Archive -Path $downloadPath -DestinationPath "$env:TEMP\ffmpeg" -Force
    Write-Host "Extraction complete."
} catch {
    Write-Host "Error extracting FFmpeg: $_" -ForegroundColor Red
    exit 1
}

# Find ffmpeg.exe in the extracted files
$ffmpegExe = Get-ChildItem -Path "$env:TEMP\ffmpeg" -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1

if ($null -eq $ffmpegExe) {
    Write-Host "Could not find ffmpeg.exe in the extracted files." -ForegroundColor Red
    exit 1
}

# Copy FFmpeg to the application directories
Write-Host "Copying FFmpeg to application directories..."
try {
    Copy-Item -Path $ffmpegExe.FullName -Destination "$binDir\ffmpeg.exe" -Force
    Copy-Item -Path $ffmpegExe.FullName -Destination "$assetsDir\ffmpeg.exe" -Force
    Write-Host "FFmpeg copied successfully." -ForegroundColor Green
} catch {
    Write-Host "Error copying FFmpeg: $_" -ForegroundColor Red
    exit 1
}

# Clean up
Write-Host "Cleaning up temporary files..."
Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:TEMP\ffmpeg" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "FFmpeg has been successfully installed for Bulk Clip Trimmer!" -ForegroundColor Green
Write-Host "You can now run the application." -ForegroundColor Green
