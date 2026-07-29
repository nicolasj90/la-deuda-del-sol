#!/usr/bin/env bash
# Verificación headless de La Deuda del Sol: importar + smoke run.
# Uso: ./verify.sh [segundos_de_run]   (default 15)
set -u

_resolve_godot() {
	for cand in "${GODOT_BIN:-}" "$HOME/tools/godot/Godot_v4.7-stable_linux.x86_64"; do
		if [ -n "$cand" ] && [ -x "$cand" ]; then
			echo "$cand"
			return 0
		fi
	done
	echo "ERROR: no se encontró Godot 4.7 (GODOT_BIN o ~/tools/godot/)." >&2
	return 1
}

GODOT="$(_resolve_godot)" || exit 1
DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_SECS="${1:-15}"
LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

echo "== Importando (1/2)..."
timeout 600 "$GODOT" --headless --import "$DIR" >"$LOG" 2>&1
echo "== Importando (2/2)..."
timeout 600 "$GODOT" --headless --import "$DIR" >"$LOG" 2>&1
IMPORT_ERRS=$(grep -c "SCRIPT ERROR" "$LOG" || true)

echo "== Smoke run ${RUN_SECS}s..."
timeout "$RUN_SECS" "$GODOT" --headless --path "$DIR" >"$LOG" 2>&1
RUN_ERRS=$(grep -c "SCRIPT ERROR" "$LOG" || true)
# Errores de display server son esperables en headless; no cuentan.
REAL_ERRS=$(grep "^ERROR" "$LOG" | grep -cv "display server" || true)

echo "-- import SCRIPT ERROR: $IMPORT_ERRS"
echo "-- run SCRIPT ERROR: $RUN_ERRS | otros ERROR (sin display): $REAL_ERRS"
if [ "$IMPORT_ERRS" -eq 0 ] && [ "$RUN_ERRS" -eq 0 ]; then
	echo "OK"
	exit 0
fi
grep -E "SCRIPT ERROR|^ERROR" "$LOG" | head -20
echo "FALLÓ"
exit 1
