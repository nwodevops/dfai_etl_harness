#!/usr/bin/env bash
# Copia environments/<env>.json -> project-config.json (estructura Hop).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
ENV="${1:-local}"
SRC="$ROOT/environments/${ENV}.json"
DST="$ROOT/project-config.json"
if [[ ! -f "$SRC" ]]; then
  echo "No existe: $SRC" >&2
  exit 1
fi
CRED="$ROOT/docs/credenciales/${ENV}.txt"
python3 - "$SRC" "$DST" "$CRED" <<'PY'
import json, sys
from pathlib import Path

src, dst, cred = sys.argv[1], sys.argv[2], sys.argv[3]
data = json.load(open(src, encoding="utf-8"))
vars_ = data.get("variables") or data.get("config", {}).get("variables") or []

def overlay_dw(variables, cred_path: str) -> None:
    path = Path(cred_path)
    if not path.is_file():
        return
    wanted = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        key, val = line.split(":", 1)
        key, val = key.strip(), val.strip()
        if key in ("Host", "Port", "Service", "User", "Password"):
            wanted[key] = val
    missing = [k for k in ("Host", "Port", "Service", "User", "Password") if not wanted.get(k)]
    if missing:
        raise SystemExit(f"Faltan {', '.join(missing)} en {cred_path}")
    host, port, service = wanted["Host"], wanted["Port"], wanted["Service"]
    mapping = {
        "DB_ORA_DW_HOST": host,
        "DB_ORA_DW_PORT": port,
        "DB_ORA_DW_DATABASE": service,
        "DB_ORA_DW_USERNAME": wanted["User"],
        "DB_ORA_DW_PASSWORD": wanted["Password"],
        "DB_ORA_DW_URL": f"jdbc:oracle:thin:@//{host}:{port}/{service}",
    }
    for item in variables:
        name = item.get("name")
        if name in mapping:
            item["value"] = mapping[name]
    print(f"DW: {host}:{port}/{service} user={wanted['User']}")

overlay_dw(vars_, cred)
out = {
    "metadataBaseFolder": "${PROJECT_HOME}/metadata",
    "unitTestsBasePath": "${PROJECT_HOME}",
    "dataSetsCsvFolder": "${PROJECT_HOME}/datasets",
    "enforcingExecutionInHome": True,
    "parentProjectName": "default",
    "config": {"variables": vars_},
}
json.dump(out, open(dst, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
print(f"OK: {src} -> {dst}")
PY
