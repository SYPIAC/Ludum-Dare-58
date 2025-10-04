@echo off
setlocal

REM Build script for export project
REM Creates executable and zip file similar to the main project

echo Building export project...

REM Create bin directory if it doesn't exist
if not exist bin mkdir bin

REM Remove old files if they exist
if exist bin\game.love del bin\game.love
if exist bin\export.exe del bin\export.exe

REM Create the game.love file with all game files
powershell -Command "Compress-Archive -Force -Path *.lua, *.dat, gfx -DestinationPath game.zip"
rename game.zip game.love
move game.love bin\

REM Copy the LOVE executable and rename it
copy "C:\Program Files\LOVE\love.exe" "bin\export.exe"

REM Append the .love file to the executable
copy /b bin\export.exe+bin\game.love bin\export.exe

REM Copy all necessary DLL files if they don't exist in bin
for %%F in ("C:\Program Files\LOVE\*.dll") do (
    if not exist bin\%%~nxF copy "%%F" "bin\%%~nxF"
)

REM Create export.zip for distribution
echo Creating distribution package export.zip...
if exist export.zip del export.zip
REM Package all the required files into a single zip for easy distribution
powershell -Command "Compress-Archive -Force -Path bin\* -DestinationPath export.zip"
if %ERRORLEVEL% NEQ 0 (
    echo Error creating export.zip package
) else (
    echo Distribution package export.zip created successfully
)

echo Build complete! Executable is in the bin folder.
