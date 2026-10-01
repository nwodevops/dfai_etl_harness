# impl fase-1 / fase-2 / fase-3

Fecha: 2026-10-01. Una corrida de `./init.sh` cubre las tres features.

## Archivos

- `switch-env.sh`, `.gitignore` — `DB_ORA_DW_*` desde `docs/credenciales/local.txt` hacia `project-config.json`
- `inputs.yaml` — RSDRD, MEDIDAS CORRECTIVAS, MULTAS
- `python/cargar_sheets.py`, `python/io/cargar_sheets.py`
- `python/io/leer_h2.py`, `python/io/escribir_oracle.py`, `python/main.py`
- `logica/dfai_registro.py` (se borró `logica/demo.py`)
- `workflows/wf_main.hwf`

## `./init.sh`

```
HARNESS OK
STG_GS1_RSDRD: 19015 filas
STG_GS2_MEDIDAS: 2296 filas
STG_GS3_MULTAS: 8887 filas
Oracle APP.DW_DFAI_RSDRD: 19015 filas
Oracle APP.DW_DFAI_MEDIDAS_CORRECTIVAS: 2296 filas
Oracle APP.DW_DFAI_MULTAS: 8887 filas
```

Conteos STG y Oracle coinciden. Hop GUI no se lanzó: el workflow queda cableado y el mismo Python lo corre `init.sh`.
