@echo off
title Alpha Desk - Rucna Claude Analiza
color 0A
echo.
echo  ================================================
echo   Alpha Desk - Pokretanje Claude macro analize
echo  ================================================
echo.
echo  Faze: Pull - Claude analiza - Validacija - Push
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0update-macro.ps1"
echo.
echo  ================================================
if %ERRORLEVEL% EQU 0 (
    echo   OK Analiza zavrsena! Osvjezi app u pregledniku.
) else (
    echo   GRESKA - provjeri poruke iznad
)
echo  ================================================
echo.
pause
