@echo off
REM ===========================================================================
REM init.bat — Harness Windows del ETL DFAI. Equivalente Windows de init.sh.
REM
REM   switch-env -> reset H2 -> create STG -> Sheets a H2 -> logica -> Oracle
REM
REM Uso: init.bat [local|remote]        (default: remote)
REM
REM NOTA: H2 es in-memory mem:csep en el puerto 9092, COMPARTIDO con los demas
REM repos hermanos (compromisos_, diego_, etl_informes_, multa_). Cada repo
REM hace DROP ALL OBJECTS sobre la misma BD, asi que la corrida debe ser
REM atomica: este script encadena los 4 pasos sin salir. No los ejecutes paso a
REM paso en consolas separadas mientras otro repo del mismo H2 este corriendo.
REM ===========================================================================
setlocal enabledelayedexpansion
cd /d "%~dp0"

set "ENV=%~1"
if "%ENV%"=="" set "ENV=remote"
echo ==^> Harness Windows DFAI: entorno %ENV%

set "PY=%~dp0.venv\Scripts\python.exe"
if not exist "%PY%" set "PY=python"

REM Bitácora del día en logs\. RUNLOG es solo esta corrida; se le agrega al diario y no se borra el diario.
set "LOGDIR=%~dp0logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
for /f %%a in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd"') do set "STAMP=%%a"
set "LOGFILE=%LOGDIR%\init_%STAMP%.log"
set "RUNLOG=%TEMP%\dfai_run_%RANDOM%.log"
set "STEPLOG=%TEMP%\dfai_step_%RANDOM%.log"
echo === inicio %date% %time% env=%ENV% === > "%RUNLOG%"
echo === inicio %date% %time% env=%ENV% ===

REM ---------------------------------------------------------------------------
echo ==^> Validando feature_list.json
"%PY%" -c "import json,sys;d=json.load(open('feature_list.json',encoding='utf-8'));act=[f for f in d.get('features',[]) if f.get('status')=='in_progress'];print('features: '+str(len(d.get('features',[])))+', in_progress: '+str(len(act)));sys.exit('mas de una in_progress: '+', '.join(f['id'] for f in act) if len(act)>1 else None)"
if errorlevel 1 (
  echo FAIL: feature_list.json ^(ver progress/current.md^)
  goto :fail
)

REM ---------------------------------------------------------------------------
echo ==^> Prerrequisitos
java -version >nul 2>&1
if errorlevel 1 (
  echo FAIL: java no esta en PATH ^(lo necesita el H2 TCP^)
  goto :fail
)

if not exist "%~dp0h2\lib\h2-2.4.240.jar" (
  echo FAIL: jar H2 no encontrado en h2\lib
  goto :fail
)

"%PY%" -c "import yaml,pandas,jaydebeapi,oracledb,gspread,openpyxl" >nul 2>&1
if errorlevel 1 (
  echo FAIL: %PY% no tiene las dependencias de python\requirements.txt
  echo FAIL: crea el venv con:  python -m venv .venv ^&^&  .venv\Scripts\python -m pip install -r python\requirements.txt
  goto :fail
)

if not exist "%~dp0client_secret.json" (
  echo FAIL: falta client_secret.json ^(cuenta de servicio de Google Sheets^)
  goto :fail
)

if not exist "%~dp0project-config.json" (
  echo ==^> Generando project-config.json ^(switch-env %ENV%^)
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0switch-env.ps1" %ENV%
  if errorlevel 1 (
    echo FAIL: switch-env %ENV%
    goto :fail
  )
)

REM El esquema destino de DW_DFAI_* viene de la config (local=APP, remote=REPOCSEP).
set "SCHEMA="
for /f "usebackq delims=" %%v in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\get_var.ps1" "%~dp0project-config.json" DB_ORA_DW_SCHEMA`) do set "SCHEMA=%%v"
if "%SCHEMA%"=="" set "SCHEMA=!SCHEMA!"
REM Si DB_ORA_DW_SCHEMA no esta, cae al usuario en mayusculas (ver config.require_live_conn).
if "%SCHEMA%"=="" for /f "usebackq delims=" %%u in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\get_var.ps1" "%~dp0project-config.json" DB_ORA_DW_USERNAME`) do set "SCHEMA=%%u"
if "%SCHEMA%"=="" (
  echo FAIL: no pude resolver el esquema destino ^(DB_ORA_DW_SCHEMA / DB_ORA_DW_USERNAME^)
  goto :fail
)
echo ==^> Esquema destino Oracle: %SCHEMA%

REM :runstep deja el exit code del .bat. No hace goto: un goto dentro de call no corta al caller.
echo ==^> Paso 1/5: Reset H2 clean
echo ==^> Paso 1/5: Reset H2 clean>> "%RUNLOG%"
call :runstep "%~dp0scripts\step_reset_h2.bat"
if errorlevel 1 (
  echo FAIL: reset H2
  echo FAIL: reset H2>> "%RUNLOG%"
  goto :fail
)

echo ==^> Paso 2/5: Python create STG
echo ==^> Paso 2/5: Python create STG>> "%RUNLOG%"
call :runstep "%~dp0scripts\step_create_stg.bat"
if errorlevel 1 (
  echo FAIL: python\create_stg.py
  echo FAIL: python\create_stg.py>> "%RUNLOG%"
  goto :fail
)

echo ==^> Paso 3/5: Cargar Sheets a H2
echo ==^> Paso 3/5: Cargar Sheets a H2>> "%RUNLOG%"
call :runstep "%~dp0scripts\step_cargar_sheets.bat"
if errorlevel 1 (
  echo FAIL: python\cargar_sheets.py ^(revisa las hojas y client_secret.json^)
  echo FAIL: python\cargar_sheets.py>> "%RUNLOG%"
  goto :fail
)

echo ==^> Paso 4/5: Python main ^(logica -^> Oracle %SCHEMA%.DW_DFAI_*^)
echo ==^> Paso 4/5: Python main>> "%RUNLOG%"
call :runstep "%~dp0scripts\step_main.bat"
if errorlevel 1 (
  echo FAIL: python\main.py
  echo FAIL: python\main.py>> "%RUNLOG%"
  goto :fail
)

findstr /c:"Excel:" "%RUNLOG%" >nul 2>&1
if errorlevel 1 echo AVISO: no se escribio output\resultado.xlsx

findstr /c:"${" "%RUNLOG%" >nul 2>&1
if not errorlevel 1 (
  echo FAIL: el log contiene variables Hop sin resolver ^(${VAR}^)
  echo FAIL: variables Hop sin resolver>> "%RUNLOG%"
  goto :fail
)

echo ==^> Paso 5/5: Verificar conteos en H2 y Oracle
echo ==^> Paso 5/5: Verificar conteos en H2 y Oracle>> "%RUNLOG%"
call :runstep "%~dp0scripts\step_verificar.bat"
if errorlevel 1 (
  echo FAIL: conteos STG y Oracle no coinciden
  echo FAIL: conteos STG y Oracle no coinciden>> "%RUNLOG%"
  goto :fail
)

echo.
echo HARNESS OK -^> conteos leidos de H2 y Oracle. Bitacora: %LOGFILE%
echo.>> "%RUNLOG%"
echo HARNESS OK esquema %SCHEMA%>> "%RUNLOG%"
call :savelog
endlocal
exit /b 0

REM ---------------------------------------------------------------------------
:runstep
call "%~1" > "%STEPLOG%" 2>&1
set "RC=%ERRORLEVEL%"
type "%STEPLOG%"
type "%STEPLOG%" >> "%RUNLOG%"
exit /b %RC%

:savelog
if exist "%RUNLOG%" type "%RUNLOG%" >> "%LOGFILE%"
if exist "%RUNLOG%" del /q "%RUNLOG%" >nul 2>&1
if exist "%STEPLOG%" del /q "%STEPLOG%" >nul 2>&1
exit /b 0

:fail
echo.
echo HARNESS FAIL -^> revisa el error de arriba. Bitacora: %LOGFILE%
echo HARNESS FAIL>> "%RUNLOG%"
call :savelog
endlocal
exit /b 1
