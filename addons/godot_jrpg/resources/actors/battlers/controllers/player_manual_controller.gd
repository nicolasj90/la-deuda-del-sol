class_name PlayerManualController extends PlayerController

@export var input_assignment: InputAssignment

var engine: BattleEngine
var handler: BattleInputHandler
var actor: Battler

# LA DEUDA PATCH (deuda «Signal already connected», con síntoma REAL comprobado):
# [code]battle_signals.tres[/code] es un Resource único que vive todo el proceso, y
# este controller también (cuelga del .tres del personaje). El upstream conecta en
# cada [method setup] y NUNCA desconecta, así que:
#   1. de la segunda batalla en adelante Godot tira 7 errores «Signal ... is
#      already connected» por personaje repetido (ruido);
#   2. y lo grave: un personaje que peleó una batalla y NO está en la party de la
#      siguiente queda conectado a las señales compartidas con [code]engine[/code]
#      apuntando a un BattleEngine ya liberado. Reproducido con teclado en
#      [code]scenes/dev/party_encogida_test.tscn[/code] (party 5 -> Ciro solo): cada
#      vez que el jugador toca un botón del menú en la batalla 2 salen cuatro
#      «Invalid access to property 'current_phase'/'leader' on a previously freed»
#      (uno por controller fantasma) — 39 errores en una batalla.
# Arreglo: se guarda la lista de conexiones y se desconecta de verdad en
# [method teardown], que llama [method BattleEngine._exit_tree] al desmontar la
# batalla (y [method setup] al empezar, para no depender de que la anterior haya
# limpiado). Además cada handler chequea que el engine siga vivo, por si algún día
# alguien monta una batalla sin pasar por el desmonte.
var _senales: BattleSignals


func setup(_engine: BattleEngine, _handler: BattleInputHandler, _actor: Battler):
	teardown()
	engine = _engine
	handler = _handler
	actor = _actor
	handler.action_pressed.connect(_on_action_pressed)
	handler.cancel_pressed.connect(_on_cancel_pressed)
	# LA DEUDA PATCH: click del mouse destraba SOLO «¡Aparecieron enemigos!».
	handler.click_pressed.connect(_on_click_pressed)
	_senales = engine.battle_signals
	for par: Array in _conexiones_de_senales():
		var senal: Signal = par[0]
		var destino: Callable = par[1]
		if not senal.is_connected(destino):
			senal.connect(destino)


## Corta TODAS las conexiones hechas en [method setup]. Con [param por_engine] no
## nulo solo desconecta si el controller sigue siendo de ESE engine: así el
## desmonte de una batalla vieja no puede pisar a una batalla nueva que ya llamó
## [method setup] (pasa en el boss de dos fases, encadenadas en el mismo frame).
func teardown(por_engine: BattleEngine = null) -> void:
	if por_engine != null and engine != por_engine:
		return
	if handler != null and is_instance_valid(handler):
		if handler.action_pressed.is_connected(_on_action_pressed):
			handler.action_pressed.disconnect(_on_action_pressed)
		if handler.cancel_pressed.is_connected(_on_cancel_pressed):
			handler.cancel_pressed.disconnect(_on_cancel_pressed)
		if handler.click_pressed.is_connected(_on_click_pressed):
			handler.click_pressed.disconnect(_on_click_pressed)
	if _senales != null:
		for par: Array in _conexiones_de_senales():
			var senal: Signal = par[0]
			var destino: Callable = par[1]
			if senal.is_connected(destino):
				senal.disconnect(destino)
	_senales = null
	engine = null
	handler = null
	actor = null


func _conexiones_de_senales() -> Array[Array]:
	return [
		[_senales.fight_button_up, _on_fight_button_up],
		[_senales.player_selected, _on_player_selected],
		[_senales.attack_button_up, _on_attack_button_up],
		[_senales.defend_button_up, _on_defend_button_up],
		[_senales.items_button_up, _on_items_button_up],
		[_senales.skills_button_up, _on_skills_button_up],
		[_senales.enemy_button_up, _on_enemy_button_up],
	]


## ¿Sigue habiendo una batalla viva atrás de este controller?
func _en_batalla() -> bool:
	return engine != null and is_instance_valid(engine)


## LA DEUDA PATCH: el click izquierdo solo arranca la batalla desde
## «¡Aparecieron enemigos!»; el resto de los menús ya es clickeable por Buttons.
func _on_click_pressed():
	if not _en_batalla(): return
	if engine.current_phase is BattlePhaseInit and engine.leader == actor and engine.current_phase.is_finished:
		BattleInputStartBattle.new().resolve(engine)


func _on_action_pressed():
	if not _en_batalla(): return
	if engine.current_phase is BattlePhaseInit and engine.leader == actor and engine.current_phase.is_finished:
		BattleInputStartBattle.new().resolve(engine)
	elif engine.current_phase is BattlePhaseItemTarget and engine.leader == actor:
		var phase := engine.current_phase as BattlePhaseItemTarget
		if BattleTarget.is_target_scope_all(phase.targets.scope) and BattleTarget.is_target_side_allies(phase.targets.side):
			engine.battle_signals.all_allies_confirmed_emitted.emit()
		elif BattleTarget.is_target_scope_all(phase.targets.scope) and BattleTarget.is_target_side_enemies(phase.targets.side):
			engine.battle_signals.all_enemies_confirmed_emitted.emit()
		elif BattleTarget.is_target_scope_all(phase.targets.scope) and BattleTarget.is_target_side_both(phase.targets.side):
			var focused := engine.get_viewport().gui_get_focus_owner()
			if focused is BattleEnemyUI:
				engine.battle_signals.all_enemies_confirmed_emitted.emit()
			elif focused is BattlePlayerUI:
				engine.battle_signals.all_allies_confirmed_emitted.emit()
		elif BattleTarget.is_target_side_everyone(phase.targets.side):
			engine.battle_signals.all_everyone_confirmed_emitted.emit()
		elif BattleTarget.is_target_side_self(phase.targets.side):
			engine.battle_signals.self_target_confirmed_emitted.emit()
	elif engine.current_phase is BattlePhaseSkillTarget and engine.leader == actor:
		var phase := engine.current_phase as BattlePhaseSkillTarget
		if BattleTarget.is_target_scope_all(phase.targets.scope) and BattleTarget.is_target_side_allies(phase.targets.side):
			engine.battle_signals.all_skill_allies_confirmed_emitted.emit()
		elif BattleTarget.is_target_scope_all(phase.targets.scope) and BattleTarget.is_target_side_enemies(phase.targets.side):
			engine.battle_signals.all_skill_enemies_confirmed_emitted.emit()
		elif BattleTarget.is_target_scope_all(phase.targets.scope) and BattleTarget.is_target_side_both(phase.targets.side):
			var focused := engine.get_viewport().gui_get_focus_owner()
			if focused is BattleEnemyUI:
				engine.battle_signals.all_skill_enemies_confirmed_emitted.emit()
			elif focused is BattlePlayerUI:
				engine.battle_signals.all_skill_allies_confirmed_emitted.emit()
		elif BattleTarget.is_target_side_everyone(phase.targets.side):
			engine.battle_signals.all_skill_everyone_confirmed_emitted.emit()
		elif BattleTarget.is_target_side_self(phase.targets.side):
			engine.battle_signals.self_skill_target_confirmed_emitted.emit()

func _on_cancel_pressed():
	if not _en_batalla(): return
	engine.current_phase.handle_cancel(engine)

func _on_fight_button_up():
	if not _en_batalla(): return
	if engine.current_phase is BattlePhaseSelection and engine.leader == actor:
		BattleInputPlayersMenu.new().resolve(engine)
		
func _on_player_selected(player: BattlerPlayer):
	if not _en_batalla(): return
	if engine.leader != actor:
		return
	if engine.current_phase is BattlePhasePlayers:
		BattleInputFightMenu.new().resolve(engine)
	elif engine.current_phase is BattlePhaseItemTarget:
		var phase := engine.current_phase as BattlePhaseItemTarget
		if BattleTarget.is_target_scope_all(phase.targets.scope) and BattleTarget.is_target_side_both(phase.targets.side):
			return
		var targets: Array[Battler] = [player]
		BattleInputPlayerSelect.new(targets).resolve(engine)
	elif engine.current_phase is BattlePhaseSkillTarget:
		var phase := engine.current_phase as BattlePhaseSkillTarget
		if BattleTarget.is_target_scope_all(phase.targets.scope) and BattleTarget.is_target_side_both(phase.targets.side):
			return
		var targets: Array[Battler] = [player]
		BattleInputPlayerSelect.new(targets).resolve(engine)

func _on_attack_button_up():
	if not _en_batalla(): return
	if engine.current_phase is BattlePhaseFight:
		BattleInputAttack.new().resolve(engine)

func _on_defend_button_up():
	if not _en_batalla(): return
	if engine.current_phase is BattlePhaseFight:
		BattleInputDefend.new().resolve(engine)

func _on_items_button_up():
	if not _en_batalla(): return
	if engine.current_phase is BattlePhaseFight:
		BattleInputItems.new().resolve(engine)

func _on_skills_button_up():
	if not _en_batalla(): return
	if engine.current_phase is BattlePhaseFight:
		BattleInputSkills.new().resolve(engine)

func _on_enemy_button_up(target_enemy: Enemy):
	if not _en_batalla(): return
	if engine.leader == actor:
		if engine.current_phase is BattlePhaseAttackTarget or \
		   engine.current_phase is BattlePhaseItemTarget or \
		   engine.current_phase is BattlePhaseSkillTarget:

			if engine.current_phase is BattlePhaseItemTarget:
				var phase := engine.current_phase as BattlePhaseItemTarget
				if BattleTarget.is_target_scope_all(phase.targets.scope) and BattleTarget.is_target_side_both(phase.targets.side):
					return
			elif engine.current_phase is BattlePhaseSkillTarget:
				var phase := engine.current_phase as BattlePhaseSkillTarget
				if BattleTarget.is_target_scope_all(phase.targets.scope) and BattleTarget.is_target_side_both(phase.targets.side):
					return

			var targets: Array[Battler] = [target_enemy]
			BattleInputEnemySelect.new(targets).resolve(engine)
