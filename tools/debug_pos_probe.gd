# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
#
# SONDA TEMPORAL DE DEPURACIÓN — NO ES PARTE DEL JUEGO.
# Autoload que imprime por consola la celda donde está el jugador, para que el
# arnés de Playwright pueda navegar en lazo cerrado y verificar que cada captura
# se sacó donde dice su nombre. Se engancha a mano en project.godot sólo durante
# una corrida de capturas y se saca después (el build final no la lleva).
extends Node

const CELDA := 64.0


func _ready() -> void:
	var t := Timer.new()
	t.wait_time = 0.25
	t.autostart = true
	t.timeout.connect(_reportar)
	add_child(t)


func _reportar() -> void:
	var jugadores := get_tree().get_nodes_in_group("player")
	if jugadores.is_empty():
		print("POS none")
		return
	var n := jugadores[0] as Node2D
	if n == null:
		print("POS none")
		return
	var p := n.global_position
	print("POS %d %d %.1f %.1f" % [int(floor(p.x / CELDA)), int(floor(p.y / CELDA)), p.x, p.y])
