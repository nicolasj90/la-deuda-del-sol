# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node
## Prueba de humo del core de batalla (addon godot_jrpg) SIN interfaz.
##
## Usa el split lógica/UI del engine ([code]visuals_enabled = false[/code]) para
## correr una batalla completa por script: todos los jugadores atacan al primer
## enemigo vivo cada turno, los enemigos deciden con su brain, y el proceso
## termina con exit code 0 si la batalla llega a victoria o derrota.
##
## Correr headless:
## [codeblock]
## ~/tools/godot/Godot_v4.7-stable_linux.x86_64 --headless --path . res://scenes/dev/battle_test.tscn
## [/codeblock]

const BATTLE_SCENE_UID := "uid://bgyg5l0h0l00g"
## Encuentro por defecto: datos propios del Acto 1 (party de 5 de La Deuda
## del Sol vs Bandido ×2 + Lobo del Diezmo). Se puede pisar con el env
## BATTLE_TEST_SETTINGS=<res://...tres> para probar otro BattleSettings.
const DEFAULT_SETTINGS_PATH := "res://resources/combate/encuentros/encuentro_ruta.tres"
## Tope de seguridad para que la corrida nunca quede colgada.
const MAX_TURNS := 30

var _engine: BattleEngine
var _signals: BattleSignals
var _started: bool = false
var _last_selection: BattlePhase = null
var _turns: int = 0
var _finished: bool = false


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		# Los timers de las fases corren en tiempo real; acelerarlos.
		Engine.time_scale = 20.0

	var battle: Node = load(BATTLE_SCENE_UID).instantiate()
	_engine = battle.get_node("BattleEngine")
	# Solo lógica: la BattleUI no se conecta a las señales (setup_ui no corre).
	_engine.visuals_enabled = false
	# Datos propios del juego (o el BattleSettings que pida el env). Van seteados
	# ANTES de add_child: BattleEngine._ready() arranca BattlePhaseInit al toque.
	var settings_path: String = OS.get_environment("BATTLE_TEST_SETTINGS")
	if settings_path.is_empty():
		settings_path = DEFAULT_SETTINGS_PATH
	_engine.battle_settings = load(settings_path)
	_signals = _engine.battle_signals
	_signals.battler_damaged.connect(_on_battler_damaged)
	_signals.inner_battle_ended.connect(_on_battle_won)
	_signals.battle_lost.connect(_on_battle_lost)
	# El engine arranca BattlePhaseInit apenas entra al árbol.
	add_child(battle)


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
		print("== [BattleTest] Turno %d ==" % _turns)
		if _turns > MAX_TURNS:
			_fail("la batalla no terminó en %d turnos" % MAX_TURNS)
			return
		_choose_turn_actions(phase)


## Con visuals apagados nadie emite damage_finished (lo emite la UI al final de
## la animación de daño); lo emitimos diferido para destrabar el await de
## BattleActionAttack.resolve().
func _on_battler_damaged(_battler: Battler) -> void:
	_signals.damage_finished.emit.call_deferred()


## "IA" de prueba: todos los jugadores vivos atacan al primer enemigo vivo.
## Después cerramos la fase Selection y pasamos directo a ResolveActions
## (los enemigos deciden solos ahí adentro, vía su brain).
##
## Con BATTLE_TEST_MODE=defeat los jugadores quedan con 1 HP y NO atacan
## (si atacaran, la party de 5 podría ganar antes de caer), así los enemigos
## los liquidan y se ejercita el camino de derrota
## (BattlePhaseGameOver parcheado -> battle_lost).
func _choose_turn_actions(phase: BattlePhase) -> void:
	var defeat_mode: bool = OS.get_environment("BATTLE_TEST_MODE") == "defeat"
	for player: BattlerPlayer in _engine.players:
		if player.is_alive():
			if defeat_mode:
				player.current_hp = 1
			else:
				var targets: Array[Battler] = [_engine.get_first_alive_enemy()]
				_engine.action_pool.append(BattleActionAttack.new(player, targets))
	phase.end()
	_engine.change_phase(BattlePhaseResolveActions.new())


func _on_battle_won() -> void:
	_report(&"victory")


func _on_battle_lost() -> void:
	_report(&"defeat")


func _report(result: StringName) -> void:
	if _finished:
		return
	_finished = true
	var party: Party = _engine.battle_settings.party
	var alive_players: int = _engine.players.filter(
		func(p: BattlerPlayer) -> bool: return p.is_alive()
	).size()
	print("== BATTLE_TEST RESULT: %s ==" % result)
	print("== turnos: %d | jugadores vivos: %d/%d | money de la party: %d ==" % [
		_turns, alive_players, _engine.players.size(), party.money,
	])
	get_tree().quit(0)


func _fail(reason: String) -> void:
	_finished = true
	push_error("[BattleTest] FALLÓ: %s" % reason)
	get_tree().quit(1)
