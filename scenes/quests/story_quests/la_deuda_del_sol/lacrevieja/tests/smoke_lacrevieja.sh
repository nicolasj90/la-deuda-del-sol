#!/usr/bin/env bash
# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
#
# Smoke headless de la zona tutorial de Lacrevieja (E01 → E04): pobla la plaza,
# corre el prólogo, cumple las tres promesitas, gana el duelo tutorial y refrenda
# la Mayoría de Palabra con su primera campanada.
# Uso: scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/tests/smoke_lacrevieja.sh
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
	res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/tests/smoke_lacrevieja.tscn 2>&1 |
	grep -E "^(PASS|FAIL|--|==|SMOKE)|SCRIPT ERROR"
exit "${PIPESTATUS[0]}"
