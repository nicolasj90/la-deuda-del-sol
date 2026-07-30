## The main class for battle system. 
##
## It simply receives [BattleSettings] from a [CommandStartBattle]; await for 
## [InputManager] to setup; reference [BattleEngine] and [BattleUI] and initialize 
## the battle engine with battle settings and battle UI. 
class_name Battle extends Node

## Used to inform that the battle finished.
signal battle_finished

func _enter_tree() -> void:
	print("[Battle] Starting battle.")

## It receives [BattleSettings] from a [CommandStartBattle]; await for [InputManager] 
## to setup; reference [BattleEngine] and [BattleUI] and initialize the battle engine 
## with battle settings and battle UI.
## [b]LA DEUDA PATCH[/b]: el await es condicional. [InputManager] es un autoload
## que emite [signal InputManager.input_setup_complete] una sola vez, en el boot;
## si la batalla se monta después (nuestro bridge de encuentros la monta como
## overlay sobre el mapa) el await no vuelve nunca. Con la bandera
## [member InputManager.setup_complete] la función termina de forma síncrona
## cuando el input ya está listo, así se puede llamar ANTES de
## [method Node.add_child] (que es cuando [BattleEngine] arranca
## [BattlePhaseInit] y necesita los settings puestos).
func initialize(settings: BattleSettings):
	if not InputManager.setup_complete:
		await InputManager.input_setup_complete
	var engine: BattleEngine = $BattleEngine
	var ui: BattleUI = $BattleUI
	engine.initialize(settings, ui)
	engine.battle_signals.inner_battle_ended.connect(_on_inner_battle_ended)

func _on_inner_battle_ended():
	print("[Battle]: Battle finished.")
	battle_finished.emit()
