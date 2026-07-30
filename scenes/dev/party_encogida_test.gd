# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node
## Banco de pruebas de la deuda «Signal already connected» del addon, en el caso
## peor: dos batallas seguidas donde la [b]party se encoge[/b].
##
## [b]Por qué[/b]: [code]battle_signals.tres[/code] es un Resource ÚNICO
## precargado (vive todo el proceso) y el [PlayerManualController] de cada
## personaje también es un Resource de vida larga. [BattlePhaseInit.setup_players]
## llama [method PlayerManualController.setup] en cada batalla y ahí conecta las
## señales de menú, sin desconectar nunca: de la segunda batalla en adelante
## Godot escupe «Signal ... is already connected» (7 por personaje repetido).
##
## Mientras la party solo crece eso es ruido: la conexión que sobrevive apunta al
## MISMO controller, que en la batalla nueva ya tiene [code]engine[/code] fresco.
## El caso que puede doler es el que se prueba acá: un personaje que peleó la
## batalla 1 y [b]no está[/b] en la party de la batalla 2 se queda conectado con
## [code]engine[/code] apuntando al BattleEngine liberado; cuando el jugador toca
## un botón, ese controller fantasma corre igual.
##
## Secuencia (jugable con teclado, sin auto-juego):
## [br]1. batalla con la party de 5 ([code]party_deuda.tres[/code]) — se juega y
##    se gana (o se huye);
## [br]2. batalla con la party del acto ([code]party_acto1.tres[/code], Ciro
##    solo): Ferra, Salu, Odila y Fiel quedan fuera.
##
## Lo que hay que mirar en la consola de la batalla 2: si aparecen errores del
## tipo «Attempt to access ... on a previously freed instance» o los menús dejan
## de responder, la deuda tiene síntoma real y hay que desconectar de verdad.
##
## Correr en el build web:
## [codeblock]
## http://localhost:8931/#res://scenes/dev/party_encogida_test.tscn
## [/codeblock]

const CAMINO_UID: String = "uid://bcaminodiezmo"
const PARTY_ACTO1: String = "res://resources/combate/party_acto1.tres"
const ENCUENTRO_2: String = "res://resources/combate/encuentros/e05_alguaciles.tres"

var _mapa: Node


func _ready() -> void:
	_correr.call_deferred()


func _correr() -> void:
	GameState.set_scene(ResourceUID.ensure_path(CAMINO_UID))
	_mapa = (load(CAMINO_UID) as PackedScene).instantiate()
	get_tree().root.add_child(_mapa)
	get_tree().current_scene = _mapa
	await get_tree().physics_frame
	await get_tree().physics_frame

	var areas: Array[Node] = get_tree().get_nodes_in_group(&"encounter_area")
	if areas.is_empty():
		push_error("[PartyEncogida] no hay EncounterArea en el mapa.")
		return
	var area: EncounterArea = areas[0] as EncounterArea

	print("== [PartyEncogida] BATALLA 1: party de 5 (%s) ==" % _nombres())
	var r1: StringName = await area.trigger_encounter()
	print("== [PartyEncogida] batalla 1: %s ==" % r1)
	if r1 == &"defeat":
		push_error("[PartyEncogida] se perdió la batalla 1; la prueba necesita ganarla.")
		return

	# La party se encoge a Ciro solo, como en E05 (arrancar_party_del_acto()).
	var acto: Party = load(PARTY_ACTO1) as Party
	if acto == null:
		push_error("[PartyEncogida] no se pudo cargar %s" % PARTY_ACTO1)
		return
	GameManager.party = acto
	BanderasDeuda.quitar_ferra()
	BanderasDeuda.curar_party()
	print("== [PartyEncogida] party encogida a: %s ==" % _nombres())

	# Batalla 2 con otro grupo de enemigos, en la misma área.
	var settings: BattleSettings = load(ENCUENTRO_2) as BattleSettings
	if settings == null:
		push_error("[PartyEncogida] no se pudo cargar %s" % ENCUENTRO_2)
		return
	print("== [PartyEncogida] BATALLA 2: mismo mapa, party encogida ==")
	var r2: StringName = await Encounters.start_encounter(settings)
	print("== [PartyEncogida] batalla 2: %s ==" % r2)
	print("== [PartyEncogida] fin de la prueba ==")


func _nombres() -> String:
	var party: Party = GameManager.party
	if party == null:
		return "(sin party)"
	return ", ".join(party.players.map(func(j: BattlerPlayer) -> String: return j.name))
