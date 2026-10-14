# Contrato logica/ — registro mensual DFAI

## Flujo

```
python/create_stg.py          (DDL STG_* desde inputs.yaml)
python/cargar_sheets.py       (Google Sheets → H2)
python/main.py
  → io/leer_h2.py             (H2 → DataFrames)
  → logica/dfai_registro.py
  → io/escribir_oracle.py     (APP.DW_DFAI_*)
  → io/escribir_excel.py      (output/resultado.xlsx, conteos)
```

Hop (`wf_main.hwf`) orquesta los mismos pasos. No hay transform Google Sheets en esta instalación de Hop.

## Entrada

DataFrames con nombres = claves de `LECTURAS` en `python/io/leer_h2.py`.

| Clave | H2 | Oracle |
|---|---|---|
| `RSDRD` | `STG_GS1_RSDRD` | `APP.DW_DFAI_RSDRD` |
| `MEDIDAS` | `STG_GS2_MEDIDAS` | `APP.DW_DFAI_MEDIDAS_CORRECTIVAS` |
| `MULTAS` | `STG_GS3_MULTAS` | `APP.DW_DFAI_MULTAS` |

Headers: fila 1 en RSDRD y MEDIDAS CORRECTIVAS; fila 2 en MULTAS. Datos desde la fila 3. Todo `VARCHAR` / `VARCHAR2(4000)`.

## Salida obligatoria

| Nombre | Descripción |
|---|---|
| `RESULTADO` | Una fila de conteos por tabla destino |

`main.py` escribe en Oracle los tres DataFrames de entrada, no `RESULTADO`.

## Reglas

- Un solo `.py` en `logica/`.
- Sin conexiones ni drivers en `logica/` (I/O en `python/io/`).
- `pandas` inyectado como `pd`.
