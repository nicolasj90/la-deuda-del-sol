#!/usr/bin/env bash
# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
#
# Corre el smoke headless del vocabulario de puzzles.
# Uso: scenes/dev/puzzles/smoke_puzzles.sh
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
DIR="$(cd "$(dirname "$0")/../../.." && pwd)"

timeout 300 "$GODOT" --headless --path "$DIR" \
	res://scenes/dev/puzzles/smoke_puzzles.tscn 2>&1 |
	grep -E "^(PASS|FAIL|--|==|SMOKE)"
exit "${PIPESTATUS[0]}"
