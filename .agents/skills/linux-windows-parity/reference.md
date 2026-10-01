# Referencia — paridad Linux / Windows

Hechos de la corrida `fase-4` (`progress/impl_fase-4-windows.md`). No redescubrirlos.

## Esquema Oracle

`python/io/escribir_oracle.py` leía `APP` fijo. En remote el usuario es `REPOCSEP` y Oracle respondió `ORA-01918: el usuario 'APP' no existe`. El esquema sale de `DB_ORA_DW_SCHEMA` (`environments/local.json` = `APP`, `environments/remote.json` = `REPOCSEP`). Si falta, `require_live_conn` usa el usuario en mayúsculas.

## switch-env

Los dos scripts deben crear `project-config.json` si no existe y sobreponer `DB_ORA_DW_*` desde `docs/credenciales/<env>.txt`. No pisar un valor real con un placeholder `<...>`. No copiar `SysPassword`.

## cmd.exe

- No incrustar `python -c` dentro de ``for /f `...` ``. El quoting se come la variable y puede dejar la ruta del intérprete. Leer JSON con `scripts/get_var.ps1`.
- `call :sub` + `goto :fail` no corta el `for` que invocó la subrutina. El `errorlevel` del `for` es el de la última vuelta y el script puede imprimir `HARNESS OK` tras varios `FAIL`. Acumular un flag `FAILED` en el mismo bloque.
- Cada `scripts/step_*.bat` termina con `exit /b %errorlevel%`. Hop marca la acción en falso solo si el `.bat` devuelve distinto de 0.

## H2

`mem:csep` en `localhost:9092` lo comparten `compromisos_`, `dfai_`, `diego_`, `etl_informes_` y `multa_`. Todos hacen `DROP ALL OBJECTS`. No solapar corridas. `init.bat` encadena los cuatro pasos en un proceso para acortar esa ventana. No es aislamiento.

En Windows el server es la tarea `H2_SERVICE_MEM_CSEP`. `reset_and_create.bat` no lo mata: comprueba el puerto y reaplica `00_reset.sql` + `01_schema.sql`. En Linux `reset_and_create.sh` sí hace stop + start, y `start_h2.sh` necesita `nohup` o Hop se queda colgado.

Cambiar la base a `mem:dfai` es decisión de equipo: hoy los `.sh` y `.bat` de `h2/scripts/` tienen `mem:csep` fijo.

## Hop Windows

```bat
D:\Eder\hop\hop-run.bat -j dfai_etl_harness -r local -f <repo>\workflows\wf_main_windows.hwf -l BASIC
```

`HOP_HOME` y `%USERPROFILE%\apps\hop` no existen en ese equipo. El proyecto Hop se llama como la carpeta.

## Red y pandas

`sheets.googleapis.com` dio `getaddrinfo failed` de forma intermitente. Fallan juntos `create_stg.py` (introspección) y `cargar_sheets.py`. Reintentar la corrida. Windows resolvió `pandas>=2.0` a 3.0.6; no fijar otra versión sin mirar el venv de Linux.
