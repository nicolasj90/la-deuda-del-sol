# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D
## Puerta de entrada al Vencimiento (E05): la casa de Ciro, en Lacrevieja.
##
## Se instancia en [code]lacrevieja.tscn[/code] sobre la casa. Cuando el jugador
## entra al área, si ya pasó la ceremonia de la Mayoría de Palabra (E04) y todavía
## no pasó el embargo (E05), cambia a la escena de la madrugada siguiente.
##
## La bandera de E04 es la misma que marca la ceremonia de la zona tutorial
## ([constant BanderasDeuda.E04_MAYORIA], que [code]MapaLacrevieja[/code] usa como
## [code]HECHO_CEREMONIA[/code]): una sola fuente de verdad para el enganche E04→E05.
## [member asumir_e04] es solo para probar el Vencimiento sin jugar la ceremonia; con
## E04 ya implementada tiene que quedar apagado, o el claro se abre en plena fiesta.

const ESCENA_CASA: String = "res://scenes/quests/story_quests/la_deuda_del_sol/vencimiento/casa_de_ciro.tscn"

@export var zona: Area2D

## Atajo de desarrollo: entrar a E05 sin la ceremonia de E04 (con aviso).
@export var asumir_e04: bool = false

var _yendo: bool = false


func _ready() -> void:
	if zona != null:
		zona.body_entered.connect(_al_entrar, CONNECT_DEFERRED)


func _al_entrar(cuerpo: Node2D) -> void:
	if _yendo or cuerpo == null or not cuerpo.is_in_group("player"):
		return
	if BanderasDeuda.tiene(BanderasDeuda.E05_TASADORES):
		# El embargo ya pasó: la casa quedó atrás.
		return
	if not BanderasDeuda.tiene(BanderasDeuda.E04_MAYORIA):
		if not asumir_e04:
			return
		push_warning("[Vencimiento] E04 sin implementar: se entra a E05 asumiendo la ceremonia.")
	_yendo = true
	SceneSwitcher.change_to_file_with_transition(
		ESCENA_CASA, ^"", Transition.Effect.FADE, Transition.Effect.FADE
	)
