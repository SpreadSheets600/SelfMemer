#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "[START] Sel fMemer — checking requirements..."
command -v node    >/dev/null 2>&1 || { echo "[START] ERROR: node not found (need Node.js 18+)"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "[START] ERROR: python3 not found (need 3.10+)"; exit 1; }
python3 -c "import flask" 2>/dev/null || {
  echo "[START] flask not installed — run: pip install flask"
  exit 1
}
[ -f config.json ] || {
  echo "[START] config.json missing — run: cp config.example.json config.json"
  exit 1
}

echo "[START] Launching process manager (bots)..."
node manager.js &
MANAGER_PID=$!
echo "[START] Manager PID: $MANAGER_PID"

cleanup() {
  echo "[START] Shutting down..."
  kill "$MANAGER_PID" "$SERVER_PID" 2>/dev/null || true
  wait "$MANAGER_PID" "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "[START] Launching dashboard on http://localhost:5000 ..."
python3 server.py &
SERVER_PID=$!

wait "$SERVER_PID"
