@echo off
REM ===========================================================================
REM step_reset_h2.bat — Paso 1: reset limpio de H2 (mem:csep, TCP 9092) + DDL.
REM Equivalente Windows de: ./h2/scripts/reset_and_create.sh
REM El server H2 corre como tarea programada independiente (start_h2_svc.bat);
REM este paso solo asegura el puerto y reaplica 00_reset.sql + 01_schema.sql.
REM ===========================================================================
setlocal
cd /d "%~dp0.."
call h2\scripts\reset_and_create.bat
exit /b %errorlevel%