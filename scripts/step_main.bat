@echo off
REM ===========================================================================
REM step_main.bat — Paso 4: python/main.py -> logica/dfai_registro.py ->
REM Oracle APP.DW_DFAI_* + output/resultado.xlsx
REM ===========================================================================
setlocal
cd /d "%~dp0.."
call "%~dp0_py.bat"
if errorlevel 1 exit /b 1
"%PY%" python\main.py
exit /b %errorlevel%