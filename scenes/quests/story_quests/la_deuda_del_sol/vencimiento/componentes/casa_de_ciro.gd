# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends EscenaGuionada
## E05 — «Los tasadores»: director de la escena de la casa de Ciro, madrugada.
##
## Secuencia: diálogo de la notificación de embargo → [b]combate tutorial
## obligatorio[/b] (Ciro solo contra dos alguaciles, disparado por el «Alguaciles.»
## del Decano, no por pisada) → diálogo de la fuga → se marca la bandera de E05 y se
## pasa al patio de la notaría (E06).
##
## Requisito de guion: la bandera de E04 (la ceremonia de la Mayoría de Palabra).
## Mientras E04 no esté implementada, entrar acá la marca sola con un aviso, así el
## bloque E05→E07 se puede jugar y testear de punta a punta.

const DIALOGO: String = "res://scenes/quests/story_quests/la_deuda_del_sol/vencimiento/componentes/e05_los_tasadores.dialogue"
const ESCENA_PATIO: String = "res://scenes/quests/story_quests/la_deuda_del_sol/vencimiento/patio_notaria.tscn"

## Barks del tutorial de combate, TEXTUALES del guion (E05).
const BARKS: Dictionary = {
	1: ["Ciro: Empeño palabra: ¡prometo no defenderme este turno!"],
	2:
	[
		"Decano: Consta que el embargado opone resistencia. Consta asimismo que la resistencia está correctamente redactada."
	],
}

## El encuentro tutorial: dos alguaciles. Sin CollisionShape2D a propósito — se
## dispara por evento desde el diálogo, no cuando el jugador pisa.
@export var area_alguaciles: EncounterArea

## Arrancar la escena sola al entrar (en los tests se apaga y se llama a [method correr]).
@export var autoarranque: bool = true

## Pasar al patio de la notaría al terminar (los tests lo apagan para no cambiar de escena).
@export var encadenar_a_e06: bool = true

var _corriendo: bool = false


func _ready() -> void:
	if autoarranque:
		correr.call_deferred()


## Corre E05 entera. Devuelve [code]false[/code] si se perdió el combate obligatorio.
func correr() -> bool:
	if _corriendo:
		return false
	_corriendo = true

	if not BanderasDeuda.tiene(BanderasDeuda.E04_MAYORIA):
		push_warning(
			"[E05] la bandera de E04 no está puesta (ceremonia sin implementar): se asume."
		)
		BanderasDeuda.marcar(BanderasDeuda.E04_MAYORIA)

	# Ciro solo: Ferra todavía es de la Cámara.
	BanderasDeuda.arrancar_party_del_acto()
	BanderasDeuda.curar_party()

	await correr_dialogo(DIALOGO, "e05_notificacion")

	var resultado: StringName = await pelear(area_alguaciles, BARKS)
	if resultado != &"victory":
		_corriendo = false
		escena_terminada.emit(false)
		return false

	await correr_dialogo(DIALOGO, "e05_fuga")

	BanderasDeuda.marcar(BanderasDeuda.E05_TASADORES)
	# La corrida de la casa a la notaría (ver BanderasDeuda.curar_party).
	BanderasDeuda.curar_party()
	_corriendo = false
	escena_terminada.emit(true)

	if encadenar_a_e06:
		SceneSwitcher.change_to_file_with_transition(
			ESCENA_PATIO, ^"", Transition.Effect.FADE, Transition.Effect.FADE
		)
	return true
