"""ENTRADA staging: Google Sheets → filas en STG_* (H2 ya tiene el DDL).

No abre Oracle. No aplica reglas de negocio.
"""

from __future__ import annotations

from pathlib import Path

from config import load_sources, load_vars
from h2_conn import connect_h2
from introspect.h2_ddl import sanitize_ident

_BATCH = 400


def _as_int(source: dict, key: str, default: int) -> int:
    raw = source.get(key, default)
    try:
        value = int(raw)
    except (TypeError, ValueError) as exc:
        raise ValueError(
            f"{source.get('stg_table')}: {key} debe ser entero, recibido {raw!r}"
        ) from exc
    if value < 1:
        raise ValueError(f"{source.get('stg_table')}: {key} debe ser >= 1")
    return value


def _columnas(headers: list, stg: str) -> tuple[list[str], list[int]]:
    used: set[str] = set()
    names: list[str] = []
    indexes: list[int] = []
    for i, header in enumerate(headers):
        if header is None or str(header).strip() == "":
            continue
        names.append(sanitize_ident(str(header), used))
        indexes.append(i)
    if not names:
        raise ValueError(f"{stg}: fila de headers sin columnas usables")
    return names, indexes


def _filas(grid: list[list], indexes: list[int], start: int) -> list[tuple]:
    rows: list[tuple] = []
    for raw in grid[start - 1 :]:
        vals = []
        empty = True
        for i in indexes:
            cell = raw[i] if i < len(raw) else ""
            text = "" if cell is None else str(cell).strip()
            if text:
                empty = False
            vals.append(text or None)
        if not empty:
            rows.append(tuple(vals))
    return rows


def _columnas_h2(cur, stg: str) -> list[str]:
    cur.execute(
        """
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE UPPER(TABLE_SCHEMA) = 'PUBLIC' AND UPPER(TABLE_NAME) = ?
        ORDER BY ORDINAL_POSITION
        """,
        [stg.upper()],
    )
    found = [str(row[0]).upper() for row in cur.fetchall()]
    if not found:
        raise ValueError(f"{stg}: no existe en H2. Corre create_stg.py antes.")
    return found


def cargar_sheets(root: Path, variables: dict[str, str] | None = None) -> dict[str, int]:
    variables = variables if variables is not None else load_vars(root)
    sources = [s for s in load_sources(root, variables) if s["type"] == "sheets"]
    if not sources:
        raise ValueError("inputs.yaml no declara fuentes type: sheets")

    try:
        import gspread
    except ImportError as exc:
        raise SystemExit(
            "Falta gspread. Instala: pip install -r python/requirements.txt"
        ) from exc

    secret = root / "client_secret.json"
    if not secret.is_file():
        raise FileNotFoundError(f"No se encuentra {secret}")

    gc = gspread.service_account(filename=str(secret))
    books: dict[str, object] = {}
    conteos: dict[str, int] = {}

    conn = connect_h2(root, variables)
    try:
        cur = conn.cursor()
        try:
            for src in sources:
                stg = src["stg_table"]
                key = (src.get("spreadsheet_key") or "").strip()
                worksheet = src.get("worksheet")
                if not key or not worksheet:
                    raise ValueError(f"{stg}: falta spreadsheet_key o worksheet")
                header_row = _as_int(src, "header_row", 1)
                data_start = _as_int(src, "data_start_row", header_row + 1)
                if data_start <= header_row:
                    raise ValueError(
                        f"{stg}: data_start_row ({data_start}) debe ser > header_row ({header_row})"
                    )

                if key not in books:
                    books[key] = gc.open_by_key(key)
                sheet = books[key].worksheet(str(worksheet))
                grid = sheet.get_all_values()
                if len(grid) < header_row:
                    raise ValueError(f"{stg}: la hoja no tiene fila {header_row}")

                names, indexes = _columnas(grid[header_row - 1], stg)
                h2_cols = _columnas_h2(cur, stg)
                if names != h2_cols:
                    raise ValueError(
                        f"{stg}: columnas de la hoja {names} no coinciden con H2 {h2_cols}"
                    )

                rows = _filas(grid, indexes, data_start)
                quoted = ", ".join(f'"{c}"' for c in names)
                marks = ", ".join("?" for _ in names)
                cur.execute(f"DELETE FROM PUBLIC.{stg}")
                sql = f"INSERT INTO PUBLIC.{stg} ({quoted}) VALUES ({marks})"
                for offset in range(0, len(rows), _BATCH):
                    cur.executemany(sql, rows[offset : offset + _BATCH])
                conteos[stg] = len(rows)
                print(f"{stg}: {len(rows)} filas")
        finally:
            cur.close()
        conn.commit()
    finally:
        conn.close()
    return conteos
