#!/usr/bin/env python3
"""Cuenta filas en H2 y en Oracle. Falla si alguna está en 0 o no coinciden.

No usa el print de la carga. Es la comprobación del harness.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from config import load_vars, project_root, require_live_conn  # noqa: E402
from h2_conn import connect_h2  # noqa: E402

# Staging H2 → tabla destino. El esquema sale de DB_ORA_DW_SCHEMA.
PARES = (
    ("STG_GS1_RSDRD", "DW_DFAI_RSDRD"),
    ("STG_GS2_MEDIDAS", "DW_DFAI_MEDIDAS_CORRECTIVAS"),
    ("STG_GS3_MULTAS", "DW_DFAI_MULTAS"),
)

_IDENT = re.compile(r"^[A-Z][A-Z0-9_]*$")


def _ident(name: str) -> str:
    if not _IDENT.match(name):
        raise ValueError(f"identificador no permitido: {name!r}")
    return name


def _contar_h2(cur, tabla: str) -> int:
    tabla = _ident(tabla)
    cur.execute(f"SELECT COUNT(*) FROM PUBLIC.{tabla}")
    return int(cur.fetchone()[0])


def _contar_oracle(cur, schema: str, tabla: str) -> int:
    schema = _ident(schema)
    tabla = _ident(tabla)
    cur.execute(f'SELECT COUNT(*) FROM {schema}."{tabla}"')
    return int(cur.fetchone()[0])


def main() -> int:
    root = project_root()
    variables = load_vars(root)
    cv = require_live_conn("oracle_dw", variables)
    schema = _ident(cv["schema"])

    h2 = connect_h2(root, variables)
    try:
        h2_cur = h2.cursor()
        try:
            conteos_h2 = {stg: _contar_h2(h2_cur, stg) for stg, _ in PARES}
        finally:
            h2_cur.close()
    finally:
        h2.close()

    try:
        import oracledb
    except ImportError as exc:
        raise SystemExit(
            "Falta oracledb. Instala: pip install -r python/requirements.txt"
        ) from exc

    port = int(cv["port"]) if str(cv["port"]).isdigit() else 1521
    ora = oracledb.connect(
        user=cv["username"],
        password=cv["password"],
        host=cv["host"],
        port=port,
        service_name=cv["database"],
    )
    try:
        ora_cur = ora.cursor()
        try:
            conteos_ora = {
                tabla: _contar_oracle(ora_cur, schema, tabla) for _, tabla in PARES
            }
        finally:
            ora_cur.close()
    finally:
        ora.close()

    fallos = 0
    for stg, tabla in PARES:
        n_h2 = conteos_h2[stg]
        n_ora = conteos_ora[tabla]
        print(f"VERIF {stg}={n_h2} {schema}.{tabla}={n_ora}")
        if n_h2 <= 0 or n_ora <= 0 or n_h2 != n_ora:
            print(
                f"FAIL: {stg}={n_h2} {schema}.{tabla}={n_ora}",
                file=sys.stderr,
            )
            fallos += 1
    if fallos:
        return 1
    print(f"VERIF OK {len(PARES)} pares, esquema {schema}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (FileNotFoundError, ValueError, KeyError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
