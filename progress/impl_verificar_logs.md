# impl — conteo real y bitácora

Fecha: 2026-10-01. Linux verificado con `./init.sh`.

## Qué cambió

- `python/verificar.py` hace `SELECT COUNT(*)` en las 3 `STG_GS*` y en las 3 `DW_DFAI_*`. Falla si alguna está en 0 o no coinciden. El esquema sale de `DB_ORA_DW_SCHEMA`.
- `init.sh` e `init.bat` llaman a esa comprobación. Ya no dan `HARNESS OK` por un grep del print.
- La corrida queda en `logs/init_YYYYMMDD.log`. No se borra.

## Linux

`./init.sh` → `HARNESS OK`. Pares: 19015, 2296, 8887. Esquema `APP`. Archivo: `logs/init_20261001.log`.

## Windows (pendiente de ese agente)

```bat
init.bat remote
```

Tiene que terminar en `HARNESS OK` con `VERIF OK` y esquema `REPOCSEP`, y dejar `logs\init_YYYYMMDD.log`.
