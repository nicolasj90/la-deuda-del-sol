class_name BattlePhaseGameOver extends BattlePhase

# LA DEUDA PATCH: el resolve() original hacía Fade + CommandChangeScene(game_over),
# que con Director.instance == null destruye la escena actual del árbol (el mapa
# de Threadbare). Ahora la derrota es una señal: el bridge (Encounters) decide
# qué hacer (checkpoint, rearmar encuentro, etc.).

func _init() -> void:
	resource_name = "GameOver"

func resolve(engine: BattleEngine):
	await engine.get_tree().create_timer(1.5).timeout
	engine.battle_signals.battle_lost.emit()
	end()
