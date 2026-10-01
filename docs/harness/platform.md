# Plataforma y ejecución (cascarón)

Divulgación progresiva desde [`AGENTS.md`](../../AGENTS.md).

## Linux (desarrollo, entorno `local`)

- Apache Hop en `~/apps/hop` (GUI: `~/apps/hop/hop-gui.sh`).
- Java en PATH (H2).
- Python: `.venv/` + `python/requirements.txt`.
- Verificación: `./init.sh` (o `./switch-env.sh local && ./init.sh`).

## Windows (este equipo, entorno `remote`)

- Java en PATH (H2).
- Python: `.venv\Scripts\python.exe` + `python/requirements.txt`.
- Config: `.\switch-env.ps1 remote` (lee `docs/credenciales/remote.txt`).
- Verificación: `.\init.bat remote`.
- Apache Hop en `D:\Eder\hop` (`hop-gui.bat` / `hop-run.bat`). El proyecto Hop
  se llama como la carpeta: `dfai_etl_harness`.

## Entornos

| Entorno | Oracle | Esquema `DW_DFAI_*` | Config |
|---|---|---|---|
| `local` | `localhost:1524/BD_CURSOR` | `APP` | `environments/local.json` |
| `remote` | `10.6.0.15:1532/dvoefacore` | `REPOCSEP` | `environments/remote.json` |

El esquema sale de `DB_ORA_DW_SCHEMA`; si no estuviera, `config.require_live_conn`
cae al usuario de conexión en mayúsculas. Antes estaba fijo `APP` en
`python/io/escribir_oracle.py` y el remoto fallaba con `ORA-01918`.

## Workflows

| Workflow | SO | Uso |
|---|---|---|
| `wf_create_stg.hwf` | Linux | Diseño STG |
| `wf_main.hwf` | Linux | Corrida `local` |
| `wf_main_windows.hwf` | Windows | Corrida `remote` |

Smoke sin Hop:

```bash
# Linux
./switch-env.sh local && ./h2/scripts/reset_and_create.sh && \
  .venv/bin/python python/create_stg.py && .venv/bin/python python/main.py
```

```bat
:: Windows
switch-env.ps1 remote
scripts\step_reset_h2.bat & scripts\step_create_stg.bat & scripts\step_main.bat
```

## Capa de lógica

- Un solo `.py` en `logica/` (`dfai_registro.py`).
- Entrada: DataFrames `LECTURAS` (`python/io/leer_h2.py`).
- Contrato: [`python/CONTRATO.md`](../../python/CONTRATO.md).

## H2

- BD in-memory `mem:csep`, TCP `9092`, modo Oracle.
- Reset: `h2/scripts/reset_and_create.sh` (Linux) / `.bat` (Windows).
- **Windows:** el server corre como tarea programada `H2_SERVICE_MEM_CSEP`
  (`start_h2_svc.bat`); `reset_and_create.bat` solo verifica el puerto y
  reaplica `00_reset.sql` + `01_schema.sql`.
- **Gotcha Linux:** `start_h2.sh` debe usar `nohup` y redirigir stdout; si no,
  Hop se queda colgado en Reset.
- **Gotcha transversal:** `mem:csep`:9092 es compartido entre repos hermanos y
  cada uno hace `DROP ALL OBJECTS`. No solapar corridas.

## Variables

- Fuente única: `project-config.json` → `config.variables`.
- Entorno: `./switch-env.sh local|remote` o `.\switch-env.ps1 local|remote`
  (copia `environments/*.json` y sobrepone `DB_ORA_DW_*` desde
  `docs/credenciales/<env>.txt`).
- `${VAR}` literal en log = variable no definida o proyecto Hop equivocado.

## Secretos

No commitear `project-config.json` ni `client_secret.json`. En `environments/`
solo placeholders `<...>`. El password Oracle real vive únicamente en
`docs/credenciales/*.txt` (gitignored).
