; NSIS Script for Bulk Clip Trimmer Standalone Executable

!include "MUI2.nsh"
!include "FileFunc.nsh"

; General settings
Name "Bulk Clip Trimmer"
OutFile "standalone\Bulk Clip Trimmer.exe"
Unicode true
SetCompressor /SOLID lzma

; No installation, just extract and run
SilentInstall silent
AutoCloseWindow true

; Temporary directory for extraction
Var /GLOBAL TEMPDIR

Section
    ; Create unique temporary directory
    ${GetTime} "" "L" $0 $1 $2 $3 $4 $5 $6
    StrCpy $TEMPDIR "$TEMP\BulkClipTrimmer\$2$1$0$4$5$6"
    CreateDirectory $TEMPDIR
    
    ; Extract application files to temp directory
    SetOutPath $TEMPDIR
    File /r "build\windows\x64\runner\Release\*.*"
    
    ; Run the application
    ExecWait '"$TEMPDIR\bulk_clip_trimmer.exe"'
    
    ; Clean up temporary files when application exits
    RMDir /r $TEMPDIR
SectionEnd
