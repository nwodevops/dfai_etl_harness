# AGENTS.md — mapa para agentes (cascarón Hop + H2 + Python)

ETL **Apache Hop + H2 in-memory + Python**. Arquitectura: [`docs/arquitectura.md`](docs/arquitectura.md).

**Verificación:** `./init.sh` (Linux) o `init.bat remote` (Windows) debe terminar en **`HARNESS OK`**. Criterios: [`CHECKPOINTS.md`](CHECKPOINTS.md).

## Harness

| Archivo | Propósito |
|---|---|
| [`feature_list.json`](feature_list.json) | Alcance; **una** `in_progress` a la vez |
| [`progress/current.md`](progress/current.md) | Plan de sesión activa |
| [`progress/history.md`](progress/history.md) | Bitácora append-only |
| [`docs/harness/workflow.md`](docs/harness/workflow.md) | Roles líder / implementador / revisor |
| [`docs/harness/platform.md`](docs/harness/platform.md) | Hop, H2, variables |

## Skill

- [`.agents/skills/hop-python-etl/SKILL.md`](.agents/skills/hop-python-etl/SKILL.md)

## Inicio rápido

### Linux (desarrollo, entorno `local`)

```bash
./switch-env.sh local
./init.sh
~/apps/hop/hop-gui.sh   # → wf_main.hwf
```

### Windows (este equipo, entorno `remote`)

```bat
powershell -ExecutionPolicy Bypass -File switch-env.ps1 remote
init.bat remote
REM Hop GUI → workflows\wf_main_windows.hwf
```

## Entornos

| | Oracle | Esquema `DW_DFAI_*` |
|---|---|---|
| `local` | `localhost:1524/BD_CURSOR` | `APP` |
| `remote` | `10.6.0.15:1532/dvoefacore` | `REPOCSEP` |

Esquema vía `DB_ORA_DW_SCHEMA`; credenciales Oracle solo en `docs/credenciales/*.txt` (gitignored), sobrepuestas por `switch-env.sh` / `switch-env.ps1`.

## Reglas críticas

1. **Un solo `.py`** en `logica/` (hoy `dfai_registro.py`).
2. **Sin secretos** en git (`project-config.json` es generado).
3. **Sin `${VAR}` literal** en logs Hop = variable mal definida.
4. `logica/` no abre conexiones. I/O en `python/io/`.
5. **No solapar corridas**: `mem:csep`:9092 es compartido con los repos hermanos y todos hacen `DROP ALL OBJECTS`.

## Nuevo proyecto

Este repo es un cascarón. Fuentes → `inputs.yaml`. Lecturas → `python/io/leer_h2.py`. Transformación → `logica/<tu>.py`. Destino demo → Excel.
