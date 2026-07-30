# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node

## Escena de verificación **manual** del duelo de «De Palabra».
##
## Lanza por [code]DueloLauncher[/code] el mismo duelo que E03 (jugador humano con
## el mazo prestado de la casa y la mano cantada de Ciro, contra el perfil
## [code]garante[/code] de Rosaura), sin tener que recorrer el juego para llegar.
## Es la escena que se exporta a web para jugar la mesa con el mouse.
##
## En web: [code]index.html#res://scenes/dev/duelo_dev.tscn[/code].
##
## La [SondaDeMesa] que trae al lado imprime por consola dónde está cada carta,
## que es lo que le permite al arnés de Playwright apuntar el mouse (ver su doc).
##
## [b]Variables de entorno[/b] (solo sirven fuera de web):
## [br]— [code]DUELO_DEV_AUTO=1[/code]: la IA juega también el lado del jugador
##   (humo del camino completo sin mouse).
## [br]— [code]DUELO_DEV_SEMILLA=n[/code]: semilla del duelo (0 = azar).

## Semilla por defecto: fija, para que la mano inicial no cambie entre corridas
## del arnés.
const SEMILLA_POR_DEFECTO: int = 20260730


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		# Sin mouse no hay nada que verificar a mano: el humo headless corre rápido.
		Engine.time_scale = 20.0
	await get_tree().process_frame
	var semilla: int = SEMILLA_POR_DEFECTO
	if not OS.get_environment("DUELO_DEV_SEMILLA").is_empty():
		semilla = int(OS.get_environment("DUELO_DEV_SEMILLA"))
	var opciones: Dictionary = {
		# Idéntico a MapaLacrevieja.duelo_con_rosaura(): mazo prestado de la casa,
		# la mano que Ciro canta en voz alta y el perfil Garante de Rosaura.
		"mazo_jugador":
		ArmadorDeMazos.completar(Coleccion.MAZO_DE_LA_CASA, ConfigMesa.base(), "garante"),
		"mano_jugador": MapaLacrevieja.MANO_DE_CIRO_E03.duplicate(),
		"anuncio_jugador": MapaLacrevieja.MANO_DE_CIRO_E03.duplicate(),
		"semilla": semilla,
		# Acá no hay mapa atrás que pausar, y la escena pausada no correría la sonda.
		"pausar_mapa": false,
		# En el juego el cartel del final dura 1.5 s porque atrás sigue el diálogo;
		# acá es lo último que se ve, así que da tiempo de leerlo (y de fotografiarlo).
		"pausa_cierre": 6.0,
	}
	if OS.get_environment("DUELO_DEV_AUTO") == "1":
		opciones["auto"] = true
	var gano: bool = await DueloLauncher.duelo("garante", opciones)
	print(
		(
			"== DUELO_DEV RESULT: %s (%s) =="
			% ["victoria" if gano else "derrota", DueloLauncher.motivo]
		)
	)
