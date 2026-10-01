"""SALIDA: DataFrames de logica/ → tablas APP.DW_DFAI_* (reemplazo total)."""

from __future__ import annotations

from pathlib import Path

import pandas as pd

from config import require_live_conn
from introspect.h2_ddl import sanitize_ident

_SCHEMA = "APP"
_VARCHAR = 4000
_BATCH = 400

# Clave inyectada en logica/ → tabla destino
TABLAS = {
    "RSDRD": "DW_DFAI_RSDRD",
    "MEDIDAS": "DW_DFAI_MEDIDAS_CORRECTIVAS",
    "MULTAS": "DW_DFAI_MULTAS",
}


def _columnas(df: pd.DataFrame) -> list[str]:
    used: set[str] = set()
    cols = [sanitize_ident(str(c), used) for c in df.columns]
    if not cols:
        raise ValueError("DataFrame sin columnas")
    return cols


def _filas(df: pd.DataFrame) -> list[tuple]:
    rows: list[tuple] = []
    for rec in df.itertuples(index=False, name=None):
        vals = []
        for cell in rec:
            if cell is None or (isinstance(cell, float) and pd.isna(cell)):
                vals.append(None)
                continue
            if pd.isna(cell):
                vals.append(None)
                continue
            text = str(cell).strip()
            if not text or text.lower() == "nat":
                vals.append(None)
                continue
            if len(text) > _VARCHAR:
                raise ValueError(
                    f"valor de {len(text)} caracteres supera VARCHAR2({_VARCHAR})"
                )
            vals.append(text)
        rows.append(tuple(vals))
    return rows


def _conectar(variables: dict[str, str]):
    try:
        import oracledb
    except ImportError as exc:
        raise SystemExit(
            "Falta oracledb. Instala: pip install -r python/requirements.txt"
        ) from exc

    cv = require_live_conn("oracle_dw", variables)
    port = int(cv["port"]) if str(cv["port"]).isdigit() else 1521
    return oracledb.connect(
        user=cv["username"],
        password=cv["password"],
        host=cv["host"],
        port=port,
        service_name=cv["database"],
    )


def escribir_oracle(
    frames: dict[str, pd.DataFrame],
    root: Path,
    variables: dict[str, str],
) -> dict[str, int]:
    del root  # el destino sale de project-config, no de una ruta
    faltan = [k for k in TABLAS if k not in frames]
    if faltan:
        raise ValueError(f"Faltan DataFrames para Oracle: {faltan}")

    conn = _conectar(variables)
    conteos: dict[str, int] = {}
    try:
        cur = conn.cursor()
        try:
            for clave, tabla in TABLAS.items():
                df = frames[clave]
                if not isinstance(df, pd.DataFrame):
                    raise ValueError(f"{clave} no es un DataFrame")
                cols = _columnas(df)
                rows = _filas(df)
                qualified = f'{_SCHEMA}."{tabla}"'
                cur.execute(
                    """
                    SELECT COUNT(*)
                    FROM ALL_TABLES
                    WHERE OWNER = :owner AND TABLE_NAME = :tname
                    """,
                    {"owner": _SCHEMA, "tname": tabla},
                )
                if int(cur.fetchone()[0]) > 0:
                    cur.execute(f"DROP TABLE {qualified} PURGE")
                body = ",\n".join(f'    "{c}" VARCHAR2({_VARCHAR})' for c in cols)
                cur.execute(f"CREATE TABLE {qualified} (\n{body}\n)")
                if rows:
                    marks = ", ".join(f":{i + 1}" for i in range(len(cols)))
                    quoted = ", ".join(f'"{c}"' for c in cols)
                    sql = f"INSERT INTO {qualified} ({quoted}) VALUES ({marks})"
                    for offset in range(0, len(rows), _BATCH):
                        cur.executemany(sql, rows[offset : offset + _BATCH])
                conteos[tabla] = len(rows)
                print(f"Oracle {_SCHEMA}.{tabla}: {len(rows)} filas")
        finally:
            cur.close()
        conn.commit()
    finally:
        conn.close()
    return conteos
