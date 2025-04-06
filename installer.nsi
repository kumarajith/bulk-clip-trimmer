; NSIS Script for Bulk Clip Trimmer Standalone Executable

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"

; Application metadata
!define APPNAME "Bulk Clip Trimmer"
!define VERSION "1.0.0"
!define PUBLISHER "Kumaji.dev"
!define DESCRIPTION "Batch video trimming application"
!define COPYRIGHT " 2025 Kumaji.dev"

; General settings
Name "${APPNAME}"
OutFile "standalone\${APPNAME}.exe"
Unicode true
SetCompressor /SOLID lzma

; Add version information
VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${APPNAME}"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "${COPYRIGHT}"
VIAddVersionKey "FileDescription" "${DESCRIPTION}"
VIAddVersionKey "CompanyName" "${PUBLISHER}"

; No installation, just extract and run
SilentInstall silent
AutoCloseWindow true

; Request minimal permissions
RequestExecutionLevel user

; Temporary directory for extraction
Var /GLOBAL TEMPDIR

Section
    ; Create unique temporary directory in user's AppData folder (no UAC needed)
    ${GetTime} "" "L" $0 $1 $2 $3 $4 $5 $6
    StrCpy $TEMPDIR "$APPDATA\${APPNAME}\Temp\$2$1$0$4$5$6"
    CreateDirectory $TEMPDIR
    
    ; Extract application files to temp directory
    SetOutPath $TEMPDIR
    File /r "build\windows\x64\runner\Release\*.*"
    
    ; Run the application
    ExecWait '"$TEMPDIR\bulk_clip_trimmer.exe"'
    
    ; Clean up temporary files when application exits
    RMDir /r $TEMPDIR
SectionEnd
