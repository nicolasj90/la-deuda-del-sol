class_name BattlePhaseGameOver extends BattlePhase

# LA DEUDA PATCH: el resolve() original hacía Fade + CommandChangeScene(game_over),
# que con Director.instance == null destruye la escena actual del árbol (el mapa
# de Threadbare). Ahora la derrota es una señal: el bridge (Encounters) decide
# qué hacer (checkpoint, rearmar encuentro, etc.).

func _init() -> void:
	resource_name = "GameOver"

func resolve(engine: BattleEngine):
	await engine.get_tree().create_timer(1.5).timeout
	# LA DEUDA PATCH (encontrado jugando la derrota con teclado): al perder no
	# aparecía NADA en pantalla — la party quedaba en 0 PV, la mesa se congelaba
	# 1,5 s y el fundido te dejaba en el pueblo sin saber qué había pasado. La
	# victoria sí se canta («¡Victoria!»), así que la derrota se canta igual, por
	# el mismo mensajero.
	engine.clear_focus()
	engine.battle_signals.toggle_messenger_emitted.emit(true)
	engine.battle_signals.message_emitted.emit("¡La compañía cayó!")
	await engine.get_tree().create_timer(2.0).timeout
	engine.battle_signals.toggle_messenger_emitted.emit(false)
	engine.battle_signals.battle_lost.emit()
	end()
