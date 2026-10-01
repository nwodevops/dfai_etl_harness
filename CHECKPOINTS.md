# CHECKPOINTS — registro mensual DFAI

Criterios para marcar features `done` en [`feature_list.json`](feature_list.json).  
Verificación: [`./init.sh`](init.sh).

---

## Global

- [x] `./init.sh` termina con **`HARNESS OK`**.
- [x] Sin passwords reales en `project-config.json` / `environments/` (el password DW vive en `docs/credenciales/local.txt`, gitignored, y solo se copia al `project-config.json` generado).
- [x] Log sin literales `${VAR}`.
- [x] Un solo `.py` en `logica/`.
- [x] Máximo **una** feature `in_progress`.

---

## Fase 1 — Entorno {#fase-1}

- [x] H2 levanta en puerto 9092 (`reset_and_create.sh`).
- [x] `./switch-env.sh local` deja `DB_ORA_DW_*` apuntando a `localhost:1524/BD_CURSOR`, usuario `app`.
- [x] `python/create_stg.py` crea `STG_GS1_RSDRD`, `STG_GS2_MEDIDAS`, `STG_GS3_MULTAS`.
- [x] `wf_main.hwf` cableado: Reset → create STG → cargar sheets → Run Python. Hop no trae transform Google Sheets; la extracción es `python/cargar_sheets.py`.

---

## Fase 2 — Fuentes STG {#fase-2}

- [x] Tres fuentes `sheets` en `inputs.yaml` (libro DFAI, pestañas RSDRD, MEDIDAS CORRECTIVAS, MULTAS).
- [x] Tablas `STG_GS*` creadas en H2.
- [x] `python/cargar_sheets.py` cableado en `wf_main.hwf` después de create STG.
- [x] Cada `STG_GS*` con conteo > 0 en el log.

La instalación de Hop no incluye transform Google Sheets: la extracción es Python, Hop solo orquesta.

---

## Fase 3 — Lógica y Oracle {#fase-3}

- [x] Claves `RSDRD`, `MEDIDAS`, `MULTAS` en `python/io/leer_h2.py`.
- [x] `logica/dfai_registro.py` produce `RESULTADO` con los tres conteos.
- [x] `APP.DW_DFAI_RSDRD`, `APP.DW_DFAI_MEDIDAS_CORRECTIVAS` y `APP.DW_DFAI_MULTAS` recreadas en cada corrida, filas > 0, mismo conteo que la STG correspondiente.
- [x] `output/resultado.xlsx` generado.

Contrato: [`python/CONTRATO.md`](python/CONTRATO.md).
