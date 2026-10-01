# Verificación — DFAI

## Automática

### Linux (desarrollo, entorno `local`)

```bash
./init.sh    # HARNESS OK
```

### Windows (este equipo, entorno `remote`)

```bat
init.bat remote
REM init.bat local   REM contra el Oracle local
REM HARNESS OK
```

Comprueba: H2, `create_stg.py`, `cargar_sheets.py`, `main.py`, salida `RESULTADO`,
filas en las 3 `STG_GS*` y en las 3 `Oracle <esquema>.DW_DFAI_*`, y que el log
no tenga `${VAR}` literal.

## Automática Hop

| Workflow | SO | Uso |
|---|---|---|
| [`wf_main.hwf`](../workflows/wf_main.hwf) | Linux | Corrida `local` |
| [`wf_main_windows.hwf`](../workflows/wf_main_windows.hwf) | Windows | Corrida `remote` |

Ambos encadenan los mismos 4 pasos vía SHELL: `step_reset_h2.bat`/
`reset_and_create.sh` → `create_stg.py` → `cargar_sheets.py` → `main.py`.

### Headless

Hop está en `D:\Eder\hop` en este equipo. El proyecto se llama igual que la
carpeta, así que se puede correr sin abrir la GUI:

```bat
D:\Eder\hop\hop-run.bat -j dfai_etl_harness -r local ^
  -f D:\Eder\workspace_etl_oefa\dfai_etl_harness\workflows\wf_main_windows.hwf -l BASIC
```

`-l MINIMAL` solo imprime errores; con `BASIC` se ve cada paso. Hop devuelve
exit code 0 si el workflow terminó bien.

## Manual Hop

1. Abrir [`workflows/wf_main_windows.hwf`](../workflows/wf_main_windows.hwf) en Hop GUI.
2. Run configuration `local`.
3. Run. Cada acción llama a `scripts\step_*.bat`, así que el log coincide con
   `init.bat`.

Verificado en Hop 2.x sobre Windows 11: las 4 acciones dan `result=[true]` y
terminan en `Success`. Un fallo de red en Sheets aborta el workflow en la acción
correspondiente, sin llegar a `Success`.

## Manual Python

```bat
.venv\Scripts\python python\main.py
REM -> output\resultado.xlsx
```

## Antes de la primera corrida en un equipo nuevo

```bat
python -m venv .venv
.venv\Scripts\python -m pip install -r python\requirements.txt
powershell -ExecutionPolicy Bypass -File switch-env.ps1 remote
init.bat remote
```

## Gotcha: H2 compartido

`mem:csep` en el puerto 9092 lo comparten los repos hermanos
(`compromisos_`, `diego_`, `etl_informes_`, `multa_`). Cada uno hace
`DROP ALL OBJECTS`, así que **las corridas no se pueden solapar**. `init.bat`
encadena los 4 pasos en un solo proceso justamente para acortar esa ventana.

## Tras añadir fuentes (Fase 2)

1. Entradas en `inputs.yaml`
2. `pl_stage_*.hpl` cableado en el `wf_main` del SO
3. `init.sh` / `init.bat` con conteos STG > 0