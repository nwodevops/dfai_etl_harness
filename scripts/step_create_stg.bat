@echo off
REM ===========================================================================
REM step_create_stg.bat — Paso 2: inputs.yaml -> CREATE TABLE STG_* en H2 (sin filas).
REM ===========================================================================
setlocal
cd /d "%~dp0.."
call "%~dp0_py.bat"
if errorlevel 1 exit /b 1
"%PY%" python\create_stg.py
exit /b %errorlevel%