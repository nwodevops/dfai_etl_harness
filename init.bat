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
set "LOG=%TEMP%\dfai_harness_%RANDOM%.log"

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

REM ---------------------------------------------------------------------------
echo ==^> Paso 1/4: Reset H2 clean
call "%~dp0scripts\step_reset_h2.bat"
if errorlevel 1 (
  echo FAIL: reset H2
  goto :fail
)

echo ==^> Paso 2/4: Python create STG
call "%~dp0scripts\step_create_stg.bat"
if errorlevel 1 (
  echo FAIL: python\create_stg.py
  goto :fail
)

REM ---------------------------------------------------------------------------
echo ==^> Paso 3/4: Cargar Sheets a H2
call "%~dp0scripts\step_cargar_sheets.bat" > "%LOG%" 2>&1
if errorlevel 1 (
  type "%LOG%"
  echo FAIL: python\cargar_sheets.py ^(revisa las hojas y client_secret.json^)
  goto :fail
)
type "%LOG%"

REM ---------------------------------------------------------------------------
echo ==^> Paso 4/4: Python main ^(logica -^> Oracle %SCHEMA%^.DW_DFAI_*^)
call "%~dp0scripts\step_main.bat" >> "%LOG%" 2>&1
if errorlevel 1 (
  type "%LOG%"
  echo FAIL: python\main.py
  goto :fail
)
type "%LOG%"

REM ---------------------------------------------------------------------------
echo ==^> Comprobando salidas
findstr /c:"Salida RESULTADO" "%LOG%" >nul 2>&1
if errorlevel 1 (
  echo FAIL: no hay "Salida RESULTADO" en el log
  goto :fail
)

findstr /c:"Excel:" "%LOG%" >nul 2>&1
if errorlevel 1 echo AVISO: no se escribio output\resultado.xlsx

REM Acumula fallos en un flag en vez de usar subrutinas: un `goto :fail`
REM dentro de un `call` no aborta el `for` que lo invoco (el exit code de un
REM for solo refleja su ultima iteracion).
set "FAILED="

for %%t in (STG_GS1_RSDRD STG_GS2_MEDIDAS STG_GS3_MULTAS) do (
  findstr /r /c:"^%%t: [1-9][0-9]* filas$" "%LOG%" >nul 2>&1
  if errorlevel 1 (
    echo FAIL: sin filas en %%t
    set "FAILED=1"
  )
)

for %%t in (DW_DFAI_RSDRD DW_DFAI_MEDIDAS_CORRECTIVAS DW_DFAI_MULTAS) do (
  findstr /r /c:"^Oracle %SCHEMA%.%%t: [1-9][0-9]* filas$" "%LOG%" >nul 2>&1
  if errorlevel 1 (
    echo FAIL: sin filas en Oracle %SCHEMA%.%%t
    set "FAILED=1"
  )
)

if defined FAILED goto :fail

REM Cualquier ${ en el log es una variable Hop sin resolver.
findstr /c:"${" "%LOG%" >nul 2>&1
if not errorlevel 1 (
  echo FAIL: el log contiene variables Hop sin resolver ^(${VAR}^)
  goto :fail
)

del /q "%LOG%" >nul 2>&1

echo.
echo HARNESS OK -^> Sheets -^> H2 STG_GS* -^> logica -^> Oracle %SCHEMA%.DW_DFAI_* ^(ver CHECKPOINTS.md^)
endlocal
exit /b 0

REM ---------------------------------------------------------------------------
:fail
if exist "%LOG%" del /q "%LOG%" >nul 2>&1
echo.
echo HARNESS FAIL -^> revisa el error de arriba.
endlocal
exit /b 1