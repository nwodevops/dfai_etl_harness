---
name: linux-windows-parity
description: >-
  Mantiene en paralelo la corrida Linux (desarrollo, entorno local) y la
  corrida Windows (otro agente, entorno remote) del ETL DFAI. Usar al cambiar
  init.sh, init.bat, wf_main.hwf, wf_main_windows.hwf, switch-env, un paso
  SHELL, el esquema Oracle, inputs.yaml o logica/; al portar a Windows; o
  cuando el usuario menciona Ubuntu, Windows, remote, init.bat o HARNESS OK.
---

# Paridad Linux / Windows

Linux desarrolla. Windows ejecuta lo mismo contra otro Oracle. Un solo Python de negocio. Dos orquestadores.

| | Linux (este Ubuntu) | Windows (el otro agente) |
|---|---|---|
| Rol | desarrollo | corrida |
| Entorno | `local` | `remote` (default de `init.bat`) |
| Oracle | `localhost:1524/BD_CURSOR` | `10.6.0.15:1532/dvoefacore` |
| Esquema | `APP` (`DB_ORA_DW_SCHEMA`) | `REPOCSEP` |
| Verificación | `./init.sh` → `HARNESS OK` | `init.bat remote` → `HARNESS OK` |
| Hop | `~/apps/hop`, `workflows/wf_main.hwf` | `D:\Eder\hop`, `workflows/wf_main_windows.hwf` |
| Config | `./switch-env.sh local` | `switch-env.ps1 remote` |

Credenciales solo en `docs/credenciales/<env>.txt` (gitignored). `switch-env.sh` y `switch-env.ps1` las sobreponen en `project-config.json`. No hardcodear host, password ni esquema.

## Al cambiar la corrida en Linux

El paso nuevo o modificado entra en los tres sitios Windows. La definición del comando vive una sola vez, en `scripts/step_<nombre>.bat`. `init.bat` y el SHELL de `wf_main_windows.hwf` llaman a ese `.bat`. No copies el `python …` dentro del `.hwf` ni lo dupliques en `init.bat`.

Hoy los cuatro pasos son:

1. `scripts/step_reset_h2.bat` → `h2/scripts/reset_and_create.bat`
2. `scripts/step_create_stg.bat` → `python/create_stg.py`
3. `scripts/step_cargar_sheets.bat` → `python/cargar_sheets.py`
4. `scripts/step_main.bat` → `python/main.py`

Si `init.sh` gana un grep de conteo, `init.bat` gana el mismo grep. El log de ambos debe poder decir `HARNESS OK` con las mismas tablas.

## Qué no se bifurca

- `inputs.yaml`, `logica/*.py`, `python/io/`, `python/create_stg.py`, `python/main.py`.
- Esquema destino: `DB_ORA_DW_SCHEMA` vía `config.require_live_conn`. Nunca un literal `APP` en el SQL.
- Intérprete Windows: `scripts/_py.bat` (`.venv\Scripts\python.exe`, si no `python`). En Windows no existe `python3` ni `.venv/bin/python`.

## Qué hace cada agente

- Agente Linux: implementa, corre `./init.sh`, deja el espejo Windows escrito (`.bat` + hop del workflow). No ejecuta `init.bat`. En `progress/impl_<id>.md` anota qué debe comprobar Windows.
- Agente Windows: no reescribe la lógica. Corre `init.bat remote` y, si tocó el workflow, `hop-run.bat` sobre `wf_main_windows.hwf`. Si el espejo falta, lo añade siguiendo esta skill. No des por cerrada una feature solo con el `HARNESS OK` de Linux.

Gotchas que ya costaron una corrida (esquema fijo, quoting de `for /f`, `goto` dentro de `call`, H2 compartido): [reference.md](reference.md).
