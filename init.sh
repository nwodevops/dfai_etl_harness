#!/usr/bin/env bash
# Harness — Sheets DFAI → H2 STG_* → Oracle DW_DFAI_*.
# Bitácora del día: logs/init_YYYYMMDD.log (no se borra).
# El conteo lo lee python/verificar.py en H2 y en Oracle.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

mkdir -p "$ROOT/logs"
DAILY="$ROOT/logs/init_$(date +%Y%m%d).log"
RUNLOG="$(mktemp)"

cleanup() {
  if [[ -f "${RUNLOG:-}" ]]; then
    cat "$RUNLOG" >> "$DAILY"
    rm -f "$RUNLOG"
  fi
}
trap cleanup EXIT

log() { printf '%s\n' "$*" | tee -a "$RUNLOG"; }
fail() { echo -e "${RED}FAIL:${NC} $*" | tee -a "$RUNLOG" >&2; exit 1; }
warn() { echo -e "${YELLOW}AVISO:${NC} $*" | tee -a "$RUNLOG"; }
step() { echo -e "${GREEN}==>${NC} $*" | tee -a "$RUNLOG"; }

run() {
  set +e
  "$@" 2>&1 | tee -a "$RUNLOG"
  local rc=${PIPESTATUS[0]}
  set -e
  return "$rc"
}

log "=== inicio $(date -Iseconds) env=local ==="

PY=python3
[ -x .venv/bin/python ] && PY=.venv/bin/python

step "Validando feature_list.json"
run "$PY" - <<'PY' || fail "feature_list.json"
import json, sys
from pathlib import Path
data = json.loads(Path("feature_list.json").read_text(encoding="utf-8"))
active = [f for f in data.get("features", []) if f.get("status") == "in_progress"]
if len(active) > 1:
    sys.exit(f"más de una in_progress: {', '.join(f['id'] for f in active)}")
print(f"features: {len(data.get('features', []))}, in_progress: {len(active)}")
PY

step "Prerrequisitos"
command -v java >/dev/null 2>&1 || fail "java no está en PATH"
[ -f h2/lib/h2-2.4.240.jar ] || fail "jar H2 no encontrado"
if [ ! -x .venv/bin/python ]; then
  fail "venv ausente o roto. Desde el repo padre: ./scripts/nuevo_etl.sh lo crea. A mano: python3 -m venv .venv && .venv/bin/python -m pip install -r python/requirements.txt"
fi
"$PY" -c "import yaml, pandas, jaydebeapi, oracledb" >/dev/null 2>&1 \
  || fail "el .venv no tiene dependencias (¿venv sin pip?). .venv/bin/python -m pip install -r python/requirements.txt"
if [ ! -f project-config.json ]; then
  step "Generando project-config.json (switch-env local)"
  run ./switch-env.sh local || fail "switch-env local"
fi
if [ ! -f client_secret.json ]; then
  fail "falta client_secret.json"
fi

step "Reset H2 + DDL"
run ./h2/scripts/reset_and_create.sh || fail "reset H2"

step "Python create STG"
run "$PY" python/create_stg.py || fail "python/create_stg.py terminó con error"

step "Cargar Sheets a H2"
run "$PY" python/cargar_sheets.py || fail "python/cargar_sheets.py terminó con error"

step "Python main"
run "$PY" python/main.py || fail "python/main.py terminó con error"

grep -q "Excel:" "$RUNLOG" || warn "no se escribió Excel (opcional si falla openpyxl)"
if grep -q '\${[A-Za-z0-9_]\+}' "$RUNLOG"; then
  fail "log contiene variables Hop sin resolver"
fi

step "Verificar conteos en H2 y Oracle"
run "$PY" python/verificar.py || fail "conteos STG y Oracle no coinciden"

echo "" | tee -a "$RUNLOG"
echo -e "${GREEN}HARNESS OK${NC} — conteos leídos de H2 y Oracle. Bitácora: $DAILY" | tee -a "$RUNLOG"
exit 0
