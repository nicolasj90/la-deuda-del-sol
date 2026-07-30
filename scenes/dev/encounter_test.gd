# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node
## Prueba del puente overworld<->batalla (EncounterArea + Encounters).
##
## Flujo: monta camino_del_diezmo como current_scene (este nodo queda colgado
## de root como driver, así no lo pausa el bridge), dispara EncuentroOeste por
## código, corre la batalla completa y verifica el retorno al mapa en la misma
## posición, con el mapa despausado.
##
## Dos modos, según haya pantalla o no:
## [br]· [b]headless[/b]: la batalla corre sin UI ([code]visuals_enabled = false[/code],
##   misma técnica que battle_test.gd) y a 20x; al terminar sale del proceso.
## [br]· [b]con pantalla[/b] (el build web de depuración): la batalla corre
##   [b]CON UI[/b], para poder auditar cómo se ve la pantalla de combate, y al
##   terminar NO se llama [method SceneTree.quit] — cerrar el motor a mano desde
##   un script dispara errores de teardown en el runtime web y además borraría de
##   la pantalla lo que queremos mirar.
##
## Correr headless:
## [codeblock]
## ~/tools/godot/Godot_v4.7-stable_linux.x86_64 --headless --path . res://scenes/dev/encounter_test.tscn
## ENCOUNTER_TEST_MODE=defeat ...  # ejercita derrota + vuelta a home_scene
## [/codeblock]

const CAMINO_UID := "uid://bcaminodiezmo"
## Tope de seguridad para que la corrida nunca quede colgada.
const MAX_TURNS := 30

var _map: Node
var _engine: BattleEngine
var _signals: BattleSignals
var _started: bool = false
var _last_selection: BattlePhase = null
var _turns: int = 0
var _finished: bool = false
var _defeat_mode: bool = false
var _summary: Dictionary = {}
## Con pantalla la batalla se juega con UI; en headless, sin UI y a 20x.
var _con_pantalla: bool = false


func _ready() -> void:
	_con_pantalla = DisplayServer.get_name() != "headless"
	if not _con_pantalla:
		Engine.time_scale = 20.0
	_defeat_mode = OS.get_environment("ENCOUNTER_TEST_MODE") == "defeat"
	Encounters.battle_mounting.connect(_on_battle_mounting)
	Encounters.encounter_finished.connect(
		func(_result: StringName, summary: Dictionary) -> void: _summary = summary
	)
	_run.call_deferred()


func _run() -> void:
	# El mapa pasa a ser current_scene; este nodo queda como hermano en root
	# (Encounters pausa current_scene, no al driver).
	# GameState.scene lo inicializa normalmente SceneSwitcher; acá el mapa se
	# monta a mano, así que hay que sembrarlo o los props del mapa revientan en
	# su _ready() contra un GameState.scene nulo (luces, spawn points).
	GameState.set_scene(ResourceUID.ensure_path(CAMINO_UID))
	_map = (load(CAMINO_UID) as PackedScene).instantiate()
	get_tree().root.add_child(_map)
	get_tree().current_scene = _map
	await get_tree().physics_frame
	await get_tree().physics_frame

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		_fail("no hay player en camino_del_diezmo")
		return
	var pos_before: Vector2 = player.global_position

	var areas: Array[Node] = get_tree().get_nodes_in_group(&"encounter_area")
	if areas.size() != 2:
		_fail("se esperaban 2 EncounterArea en camino_del_diezmo, hay %d" % areas.size())
		return
	var area: EncounterArea = areas[0]

	print("== [EncounterTest] disparando encuentro por código: %s ==" % area.name)
	var result: StringName = await area.trigger_encounter()

	if _defeat_mode:
		await _check_defeat(result)
	else:
		_check_victory(result, player, pos_before)


func _check_victory(result: StringName, player: Node2D, pos_before: Vector2) -> void:
	if result != &"victory":
		_fail("se esperaba victory y el resultado fue %s" % result)
		return
	if get_tree().current_scene != _map:
		_fail("el mapa fue reemplazado durante la batalla")
		return
	if _map.process_mode != Node.PROCESS_MODE_INHERIT:
		_fail("el mapa quedó pausado después de la batalla")
		return
	if not is_instance_valid(player) or player.global_position.distance_to(pos_before) > 1.0:
		_fail("el player no volvió a la misma posición")
		return
	_finished = true
	print("== ENCOUNTER_TEST RESULT: victory ==")
	print("== mapa intacto | player en %s | money +%d | xp +%d | level_ups: %d ==" % [
		player.global_position,
		_summary.get("money_gained", 0),
		_summary.get("xp_gained", 0),
		(_summary.get("level_ups", []) as Array).size(),
	])
	_salir(0)


func _check_defeat(result: StringName) -> void:
	if result != &"defeat":
		_fail("se esperaba defeat y el resultado fue %s" % result)
		return
	# EncounterArea pidió SceneSwitcher.change_to_file_with_transition(home);
	# esperar a que la escena hogar sea la actual.
	var home_path: String = ResourceUID.ensure_path(
		ThreadbareProjectSettings.get_setting(ThreadbareProjectSettings.HOME_SCENE)
	)
	var arrived := false
	for i in 1200:
		await get_tree().process_frame
		var current: Node = get_tree().current_scene
		if current != null and current != _map and current.scene_file_path == home_path:
			arrived = true
			break
	if not arrived:
		_fail("tras la derrota no se llegó a home_scene (%s)" % home_path)
		return
	for player: BattlerPlayer in GameManager.party.players:
		if player.current_hp < 1:
			_fail("la party volvió muerta de la derrota (%s)" % player.name)
			return
	_finished = true
	print("== ENCOUNTER_TEST RESULT: defeat ==")
	print("== vuelta a home_scene (%s) | party revivida a >=1 HP ==" % home_path)
	_salir(0)


## Punto de extensión del bridge: acá el test decide si la batalla lleva UI y se
## engancha para manejarla por señales (split lógica/UI del addon).
func _on_battle_mounting(engine: BattleEngine) -> void:
	_engine = engine
	# OJO: esto se corre ANTES del add_child, o sea antes de BattlePhaseInit, que
	# es la fase que arma la UI. Apagar los visuals después no alcanza (y dejarlos
	# apagados con pantalla deja la UI cruda de battle.tscn tirada sobre el mapa).
	_engine.visuals_enabled = _con_pantalla
	_signals = engine.battle_signals
	if not _con_pantalla:
		_signals.battler_damaged.connect(_on_battler_damaged)


func _process(_delta: float) -> void:
	if _finished or _engine == null:
		return
	var phase: BattlePhase = _engine.current_phase
	if phase == null:
		return
	if not _started and phase is BattlePhaseInit and phase.is_finished:
		# Equivale al jugador apretando "action" en "Enemies appeared!".
		_started = true
		BattleInputStartBattle.new().resolve(_engine)
	elif phase is BattlePhaseSelection and phase != _last_selection:
		_last_selection = phase
		_turns += 1
		print("== [EncounterTest] Turno %d ==" % _turns)
		if _turns > MAX_TURNS:
			_fail("la batalla no terminó en %d turnos" % MAX_TURNS)
			return
		_choose_turn_actions(phase)


## Con visuals apagados nadie emite damage_finished (lo emite la UI al final
## de la animación de daño); lo emitimos diferido para destrabar el await de
## BattleActionAttack.resolve(). Con pantalla no se conecta: la emite la UI.
func _on_battler_damaged(_battler: Battler) -> void:
	_signals.damage_finished.emit.call_deferred()


## "IA" de prueba: todos los jugadores vivos atacan al primer enemigo vivo.
## Con ENCOUNTER_TEST_MODE=defeat los jugadores quedan con 1 HP y no atacan,
## así los enemigos los liquidan (camino de derrota garantizado).
func _choose_turn_actions(phase: BattlePhase) -> void:
	for player: BattlerPlayer in _engine.players:
		if player.is_alive():
			if _defeat_mode:
				player.current_hp = 1
				continue
			var targets: Array[Battler] = [_engine.get_first_alive_enemy()]
			_engine.action_pool.append(BattleActionAttack.new(player, targets))
	phase.end()
	_engine.change_phase(BattlePhaseResolveActions.new())


func _fail(reason: String) -> void:
	_finished = true
	push_error("[EncounterTest] FALLÓ: %s" % reason)
	_salir(1)


## Cerrar el motor a mano solo tiene sentido headless (es lo que le da el código
## de salida al CI). Con pantalla se deja la escena como quedó: en el runtime web
## un quit() por script tira un error de teardown en el JS del motor
## («Cannot read properties of null (reading 'currentTime')», el AudioContext ya
## desarmado) y encima borra de la pantalla lo que se quiere auditar.
func _salir(codigo: int) -> void:
	if _con_pantalla:
		print("== [EncounterTest] fin (código %d); con pantalla no se cierra el motor ==" % codigo)
		return
	get_tree().quit(codigo)
