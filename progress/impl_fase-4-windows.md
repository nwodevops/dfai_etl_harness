# impl_fase-4-windows — corrida del ETL DFAI en Windows contra Oracle remoto

Fecha: 2026-10-01. Objetivo: ejecutar en este equipo Windows el ETL que se
desarrolló en Linux contra el entorno `local`, apuntando al `remote`.

## Contexto

- En Linux el destino era `localhost:1524/BD_CURSOR`, usuario `app`, esquema `APP`.
- Acá el destino es `10.6.0.15:1532/dvoefacore`, usuario `REPOCSEP`, esquema `REPOCSEP`.
- No había `.venv` ni `project-config.json`. El repositorio tampoco traía
  `init.bat` ni workflow para Windows (los repos hermanos sí los traían).

## Cambios

### Nuevo

| Archivo | Qué |
|---|---|
| `init.bat` | Equivalente Windows de `init.sh`. `init.bat [local\|remote]`, default `remote`. |
| `workflows/wf_main_windows.hwf` | Workflow Hop Windows: 4 acciones SHELL → `scripts\step_*.bat` + Success. |
| `scripts\_py.bat` | Resuelve el intérprete (`.venv\Scripts\python.exe`, fallback `python`) y valida deps. |
| `scripts\step_reset_h2.bat` | Paso 1 → `h2\scripts\reset_and_create.bat`. |
| `scripts\step_create_stg.bat` | Paso 2 → `python\create_stg.py`. |
| `scripts\step_cargar_sheets.bat` | Paso 3 → `python\cargar_sheets.py`. |
| `scripts\step_main.bat` | Paso 4 → `python\main.py`. |
| `scripts\get_var.ps1` | Imprime una variable de `project-config.json` (evita el quoting frágil de un `-c` inline dentro de `for /f`). |

Los `scripts\step_*.bat` son la única definición de cada paso: los usan tanto
`init.bat` como las acciones SHELL del workflow, así que no pueden divergir.

### Modificado

| Archivo | Qué |
|---|---|
| `switch-env.ps1` | Antes fallaba si `project-config.json` no existía (lo hacía `init.sh`) y no sobreponía credenciales. Ahora crea el `project-config.json` si falta, sobrepone `DB_ORA_DW_*` desde `docs/credenciales/<env>.txt`, y no pisa valores reales cuando la plantilla trae placeholders. |
| `python/config.py` | `conn_vars` expone `schema` (`DB_ORA_DW_SCHEMA`); `require_live_conn` cae al usuario en mayúsculas si falta. |
| `python/io/escribir_oracle.py` | `_SCHEMA = "APP"` hardcodeado → esquema de config. |
| `environments/local.json` | + `DB_ORA_DW_SCHEMA` = `APP`. |
| `environments/remote.json` | + `DB_ORA_DW_SCHEMA` = `REPOCSEP`. |
| `docs/verification.md`, `docs/harness/platform.md`, `AGENTS.md`, `CHECKPOINTS.md`, `progress/current.md` | Añadida la columna Windows/remote y el gotcha de H2 compartido. |

## Bloqueos encontrados y resueltos

1. **`python3` no existe en Windows.** `init.sh` es POSIX. Por eso `init.bat`.

2. **`.venv` ausente.** El Python global no tiene `jaydebeapi` ni `JPype1`
   (obligatorios para hablar JDBC con H2). Creado el venv e instaladas las deps.

3. **`ORA-01918: el usuario 'APP' no existe`.** El código tenía el esquema
   fijo en `APP`. En el remoto el esquema es `REPOCSEP`. Se parametrizó con
   `DB_ORA_DW_SCHEMA` en vez de parchear el valor.

   Nota: `REPOCSEP` solo tiene `CREATE SESSION` y `CREATE VIEW` en
   `USER_SYS_PRIVS`. No hizo falta: desde Oracle 12.2 `CREATE TABLE` no es
   requisito de privilegio para objetos en el propio esquema.

4. **`switch-env.ps1` roto para su propio caso de uso.** `init.sh` lo invoca
   cuando `project-config.json` no existe, y el script hacía
   `Get-Content` sobre ese archivo sin verificarlo. Además no sobreponía las
   credenciales de `docs/credenciales/`, que era justo lo que lo diferenciaba
   de una copia de plantilla.

5. **Colisión de H2 entre repos hermanos.** `mem:csep` en `localhost:9092` lo
   comparten los 5 repos (`compromisos_`, `dfai_`, `diego_`, `etl_informes_`,
   `multa_`) y todos hacen `DROP ALL OBJECTS`. El servidor vivo en 9092 lo
   había arrancado `diego_etl_archetype` el 30/09, y su `DROP` borró las
   `STG_GS*` de este repo entre corridas. Mitigación: `init.bat` encadena los 4
   pasos en un solo proceso. No es aislamiento real (ver Pendientes).

6. **Dos bugs propios en `init.bat`** que hicieron que la primera versión
   pasara sin comprobar nada:
   - `for /f` con Python inline dentro de backticks: el quoting se rompe y
     `SCHEMA` quedaba con la ruta del intérprete. Resuelto con
     `scripts\get_var.ps1`.
   - `call :check` con `goto :fail` desde la subrutina: el `goto` no aborta el
     `for` que la invocó (el exit code de un `for` solo refleja su última
     iteración), así que se imprimían los 3 `FAIL` y aun así salía
     `HARNESS OK`. Resuelto acumulando en un flag `FAILED` sin `call`.

## Verificación

```bat
init.bat remote
```

Salida final:

```
==> Harness Windows DFAI: entorno remote
==> Validando feature_list.json
features: 3, in_progress: 0
==> Prerrequisitos
==> Esquema destino Oracle: REPOCSEP
==> Paso 1/4: Reset H2 clean            → Reset+Create OK
==> Paso 2/4: Python create STG         → 3 tablas STG_*
==> Paso 3/4: Cargar Sheets a H2        → 19015 / 2296 / 8887 filas
==> Paso 4/4: Python main               → Oracle REPOCSEP.DW_DFAI_*: 19015 / 2296 / 8887
                                        → Excel: output\resultado.xlsx
==> Comprobando salidas
HARNESS OK
```

## Pendientes

1. ~~**`wf_main_windows.hwf` sin ejecutar en Hop.**~~ Resuelto: Hop está en
   `D:\Eder\hop` (no se encontraba antes porque no se buscaba ahí; `HOP_HOME`
   y `%USERPROFILE%\apps\hop` no existen en esta máquina). Corrida headless
   verificada:

   ```bat
   D:\Eder\hop\hop-run.bat -j dfai_etl_harness -r local ^
     -f D:\Eder\workspace_etl_oefa\dfai_etl_harness\workflows\wf_main_windows.hwf -l BASIC
   ```

   Las 4 acciones SHELL ejecutan vía `cmd.exe`, devuelven `result=[true]` y el
   workflow llega a `Success` (exit 0). Confirmado además contra Oracle:
   `LAST_DDL_TIME = 2026-10-01 10:09:43` en las 3 tablas de `REPOCSEP`, con
   19015 / 2296 / 8887 filas.

   En la primera corrida Hop el workflow **abortó correctamente** por un fallo de
   DNS hacia `sheets.googleapis.com`: es decir, el `if errorlevel 1 exit /b 1`
   de los `.bat` propaga el fallo a Hop y no se llega a `Success`.

2. **Aislamiento de H2.** La solución robusta sería `DB_H2_DATABASE=mem:dfai` en
   `environments/*.json` + en los `.sh`/`.bat` de `h2/scripts/`, que hoy tienen
   `mem:csep` fijo en la URL. No se hizo: diverge de los repos hermanos y es
   una decisión del equipo.

3. **Versión de pandas.** Windows resolvió `pandas>=2.0` a 3.0.6; Linux probablemente
   corre 2.x. No hubo diferencias observadas en esta corrida, pero conviene
   fijar la versión si Linux y Windows deben dar idéntico.

4. **DNS intermitente hacia `sheets.googleapis.com`.** Falló en 2 de ~8 corridas
   con `getaddrinfo failed`, y resolvió bien en las demás. No es del código, pero
   `create_stg.py` también depende de la API de Sheets (introspecta columnas),
   así que fallan los pasos 2 y 3 juntos. Valorar reintentos si aparece en
   producción.
