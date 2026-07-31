#!/usr/bin/env bash
# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
#
# Sonda de muros de Lacrevieja: camina el pueblo con el cuerpo del jugador para
# verificar que ninguna casa se atraviesa, que todo lo que el guion pide visitar se
# alcanza a pie y que ningún objeto interactuable quedó encerrado.
# Uso: scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/tests/sonda_muros.sh
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
DIR="$(cd "$(dirname "$0")/../../../../../.." && pwd)"

timeout 420 "$GODOT" --headless --path "$DIR" \
	res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/tests/sonda_muros.tscn 2>&1 |
	grep -E "^(PASS|FAIL|--|==|SONDA|   )|SCRIPT ERROR"
exit "${PIPESTATUS[0]}"
