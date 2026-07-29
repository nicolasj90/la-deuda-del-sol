# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node
## Bridge de encuentros: lanza batallas del addon godot_jrpg como overlay
## sobre el mapa de Threadbare, sin cambiar de escena.
##
## El mapa nunca sale del árbol: se pausa (process_mode DISABLED), se monta
## battle.tscn dentro de un CanvasLayer propio y al terminar se desmonta todo.
## La party viva en [code]GameManager.party[/code] es el MISMO Resource que usa
## la batalla, así que XP / level-ups / plata / loot persisten solos.

## Resultado de un encuentro: &"victory", &"defeat" o &"fled".
signal encounter_finished(result: StringName, summary: Dictionary)

## Punto de extensión: se emite con el engine ya configurado pero ANTES de
## montar la batalla en el árbol. Sirve para ajustar el engine (los tests
## headless apagan visuals_enabled acá) o para colgar música/VFX por zona.
signal battle_mounting(engine: BattleEngine)

## Punto de extensión F3 (drops de cartas): se emite SOLO en victoria, cuando
## el addon ya aplicó XP / level-ups / plata / loot sobre la party viva.
## summary trae "money_gained", "xp_gained" y "level_ups".
## TODO(F3): enganchar acá el sistema de cartas — resolver el drop según la
## zona/enemigos y agregar "cards" al summary antes de re-emitirlo.
signal victory_rewards_applied(summary: Dictionary)

const BATTLE_SCENE_UID := "uid://bgyg5l0h0l00g"

## La party canon del juego: Ciro, Ferra, Salu, Odila y Fiel (F2-datos).
## Es el MISMO Resource que referencian los BattleSettings de
## res://resources/combate/encuentros/, así que XP/plata/loot persisten.
const PARTY_DEUDA: Party = preload("res://resources/combate/party_deuda.tres")

## Capa por debajo de PauseOverlay (2) y Transitions (10).
const BATTLE_CANVAS_LAYER := 1

var _battle_running: bool = false


func _ready() -> void:
	# F2-datos: pisar la party de prueba del addon (game_manager.tscn exporta
	# tests/actors/test_party.tres) por la party canon del juego.
	GameManager.party = PARTY_DEUDA
	# TODO(F2b): confirmar el nombre canon de la moneda en el concepto
	# (por ahora "reales"; solo aparece en mensajes de victoria).
	GameManager.money_name = "reales"


## Corre un encuentro completo y devuelve el resultado (&"victory" | &"defeat" | &"fled").
## Uso: [code]var result := await Encounters.start_encounter(settings)[/code]
func start_encounter(settings: BattleSettings) -> StringName:
	if _battle_running:
		push_warning("[Encounters] Ya hay una batalla corriendo; se ignora el encuentro.")
		return &"ignored"
	_battle_running = true

	if settings.party == null:
		settings.party = GameManager.party

	# Foto de la party antes de pelear, para armar el summary de recompensas
	# (el addon aplica XP/plata/loot directo sobre estos Resources).
	var money_before: int = settings.party.money
	var xp_before: Dictionary = {}
	var levels_before: Dictionary = {}
	for player: BattlerPlayer in settings.party.players:
		xp_before[player] = player.xp
		levels_before[player] = player.level

	# Pausar el mapa (la escena actual de Threadbare) sin sacarlo del árbol.
	var map_scene: Node = get_tree().current_scene
	if map_scene:
		map_scene.process_mode = Node.PROCESS_MODE_DISABLED

	var layer := CanvasLayer.new()
	layer.layer = BATTLE_CANVAS_LAYER
	get_tree().root.add_child(layer)

	var battle: Node = load(BATTLE_SCENE_UID).instantiate()
	var engine: BattleEngine = battle.get_node("BattleEngine")
	# Ojo: BattleEngine._ready() arranca BattlePhaseInit apenas entra al árbol,
	# así que los settings van seteados ANTES de add_child (battle.initialize()
	# upstream llega tarde y además espera una señal que ya se emitió al boot).
	engine.battle_settings = settings
	var signals: BattleSignals = engine.battle_signals

	var result: Array[StringName] = []
	var on_victory := func() -> void: result.append(&"victory")
	var on_defeat := func() -> void: result.append(&"defeat")
	# Pendiente conocido upstream: el botón "Run" no tiene listener (huir no
	# implementado). Placeholder: huir termina el encuentro sin premios.
	var on_run := func() -> void: result.append(&"fled")
	signals.inner_battle_ended.connect(on_victory)
	signals.battle_lost.connect(on_defeat)
	signals.run_button_up.connect(on_run)

	battle_mounting.emit(engine)
	layer.add_child(battle)

	while result.is_empty():
		await get_tree().process_frame

	signals.inner_battle_ended.disconnect(on_victory)
	signals.battle_lost.disconnect(on_defeat)
	signals.run_button_up.disconnect(on_run)

	battle.queue_free()
	layer.queue_free()
	if map_scene:
		map_scene.process_mode = Node.PROCESS_MODE_INHERIT

	# Recompensas: el addon ya las aplicó sobre la party (BattlePhaseVictory);
	# acá solo se resume el delta para quien escuche.
	var level_ups: Array[Dictionary] = []
	var xp_gained: int = 0
	for player: BattlerPlayer in settings.party.players:
		xp_gained = maxi(xp_gained, player.xp - int(xp_before.get(player, player.xp)))
		var old_level: int = levels_before.get(player, player.level)
		if player.level > old_level:
			level_ups.append({"player": player.name, "from": old_level, "to": player.level})
	var summary := {
		"money_gained": settings.party.money - money_before,
		"xp_gained": xp_gained,
		"level_ups": level_ups,
	}
	_battle_running = false
	if result[0] == &"victory":
		# TODO(F3): los drops de cartas se cuelgan de esta señal.
		victory_rewards_applied.emit(summary)
	encounter_finished.emit(result[0], summary)
	return result[0]
