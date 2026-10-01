# CHECKPOINTS — registro mensual DFAI

Criterios para marcar features `done` en [`feature_list.json`](feature_list.json).  
Verificación: [`./init.sh`](init.sh) (Linux) / [`init.bat remote`](init.bat) (Windows).

---

## Global

- [x] `./init.sh` termina con **`HARNESS OK`** (Linux, `local`).
- [x] `init.bat remote` termina con **`HARNESS OK`** (Windows, `remote`).
- [x] Sin passwords reales en `project-config.json` / `environments/` (el password DW vive en `docs/credenciales/<env>.txt`, gitignored, y se copia al `project-config.json` generado).
- [x] Log sin literales `${VAR}`.
- [x] Un solo `.py` en `logica/`.
- [x] Máximo **una** feature `in_progress`.

---

## Fase 1 — Entorno {#fase-1}

- [x] H2 levanta en puerto 9092 (`reset_and_create.sh` / `.bat`).
- [x] `./switch-env.sh local` deja `DB_ORA_DW_*` apuntando a `localhost:1524/BD_CURSOR`, usuario `app`.
- [x] `.\switch-env.ps1 remote` deja `DB_ORA_DW_*` apuntando a `10.6.0.15:1532/dvoefacore`, usuario `REPOCSEP`.
- [x] `python/create_stg.py` crea `STG_GS1_RSDRD`, `STG_GS2_MEDIDAS`, `STG_GS3_MULTAS`.
- [x] `wf_main.hwf` (Linux) cableado: Reset → create STG → cargar sheets → Run Python.
- [x] `wf_main_windows.hwf` (Windows) cableado con los mismos 4 pasos vía `scripts\step_*.bat`.

---

## Fase 2 — Fuentes STG {#fase-2}

- [x] Tres fuentes `sheets` en `inputs.yaml` (libro DFAI, pestañas RSDRD, MEDIDAS CORRECTIVAS, MULTAS).
- [x] Tablas `STG_GS*` creadas en H2.
- [x] `python/cargar_sheets.py` cableado después de create STG.
- [x] Cada `STG_GS*` con conteo > 0 en el log.

La instalación de Hop no incluye transform Google Sheets: la extracción es Python, Hop solo orquesta.

---

## Fase 3 — Lógica y Oracle {#fase-3}

- [x] Claves `RSDRD`, `MEDIDAS`, `MULTAS` en `python/io/leer_h2.py`.
- [x] `logica/dfai_registro.py` produce `RESULTADO` con los tres conteos.
- [x] `DW_DFAI_RSDRD`, `DW_DFAI_MEDIDAS_CORRECTIVAS` y `DW_DFAI_MULTAS` recreadas en cada corrida, filas > 0, mismo conteo que la STG correspondiente.
- [x] `output/resultado.xlsx` generado.
- [x] Esquema destino parametrizado por `DB_ORA_DW_SCHEMA` (`APP` en local, `REPOCSEP` en remote) — antes estaba fijo `APP` y el remoto fallaba con `ORA-01918`.

Contrato: [`python/CONTRATO.md`](python/CONTRATO.md).

---

## Fase 4 — Corrida en Windows / remoto {#fase-4}

- [x] `.venv` Windows con `python/requirements.txt` (incluye `jaydebeapi` + `JPype1`, ausentes en el Python global).
- [x] `scripts/step_*.bat` reutilizables por `init.bat` y por las acciones SHELL de Hop.
- [x] `init.bat [local|remote]` con las mismas comprobaciones que `init.sh`.
- [x] Google Sheets y Oracle remoto accesibles desde este equipo.
- [x] `wf_main_windows.hwf` ejecutado **dentro de Apache Hop** (`D:\Eder\hop`, run configuration `local`): las 4 acciones dan `result=[true]` y llega a `Success`. Verificado además por `LAST_DDL_TIME` de las 3 tablas en `REPOCSEP`.

## Gotcha conocido

`mem:csep` en `localhost:9092` lo comparten los repos hermanos (`compromisos_`,
`diego_`, `etl_informes_`, `multa_`) y todos ejecutan `DROP ALL OBJECTS`. Las
corridas no se pueden solapar; `init.bat` encadena los pasos en un solo proceso
para acortar la ventana.

## Gotcha conocido: DNS intermitente

`sheets.googleapis.com` dio `getaddrinfo failed` en dos corridas (una por
`init.bat`, otra por Hop) y resolvió bien en las demás. Es del resolver, no del
código: `create_stg.py` **también** llama a la API de Sheets (via
`python/introspect/sheets.py`), así que ambos pasos necesitan red. Si aparece en
producción, reintentar la corrida.
