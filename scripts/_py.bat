@echo off
REM ===========================================================================
REM _py.bat — Resuelve el interprete Python del proyecto y deja en %PY%.
REM Incluye con:  call "%~dp0_py.bat"
REM Prioridad: .venv\Scripts\python.exe (Windows) -> python del PATH.
REM ===========================================================================

set "ROOT=%~dp0.."

set "PY=%ROOT%\.venv\Scripts\python.exe"
if not exist "%PY%" set "PY=python"

if "%PY%"=="python" (
  python -c "import yaml,pandas,jaydebeapi" >nul 2>&1
  if errorlevel 1 (
    echo FAIL: no hay .venv con dependencias ^(python\requirements.txt^). 1>&2
    echo FAIL: crea el venv con:  python -m venv .venv  ^&^&  .venv\Scripts\python -m pip install -r python\requirements.txt 1>&2
    exit /b 1
  )
)
exit /b 0