@echo off
REM ===========================================================================
REM step_cargar_sheets.bat — Paso 3: Google Sheets -> STG_GS1_RSDRD,
REM STG_GS2_MEDIDAS, STG_GS3_MULTAS (necesita client_secret.json en la raiz).
REM ===========================================================================
setlocal
cd /d "%~dp0.."
call "%~dp0_py.bat"
if errorlevel 1 exit /b 1
"%PY%" python\cargar_sheets.py
exit /b %errorlevel%