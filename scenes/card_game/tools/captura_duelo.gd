# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node

## Saca una foto de la mesa de «De Palabra» para poder mirar el layout sin jugar.
##
## Existe por la lección de `docs`: el feel y la UI se verifican sobre la escena
## real, no sobre un dibujo. Arranca un duelo, deja que el piloto random juegue
## unas cuantas jugadas para que haya cartas en el Estrado y en las pilas, y
## guarda un PNG.
##
## Uso (necesita display, no corre con `--headless`):
## [codeblock]
## godot --path . --resolution 1280x720 \
##     res://scenes/card_game/tools/captura_duelo.tscn -- /tmp/mesa.png
## [/codeblock]

const ESCENA_DUELO: String = "res://scenes/card_game/vista/duelo.tscn"
const JUGADAS: int = 26
const SEMILLA: int = 1971

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	await _correr()


## Deja la mesa con una carta seleccionada (para que se vea el panel de detalle) y,
## si hay a quién pegarle, con la capa de objetivos abierta: son las dos partes de
## la vista que no se pueden mirar en un log.
func _mostrar_una_decision(vista: VistaDuelo, motor: MotorDePalabra) -> void:
	var lado: int = vista.lado_jugador
	var mano: ManoDePalabra = vista.get_node_or_null("Mesa/ManoPropia") as ManoDePalabra
	var estrado: EstradoDePalabra = (
		vista.get_node_or_null("Mesa/EstradoPropio") as EstradoDePalabra
	)
	if mano == null or estrado == null:
		return
	var en_mano: Array[EstadoCarta] = motor.estado.firma(lado).mano
	if not en_mano.is_empty():
		var naipe: NaipeDePalabra = vista.naipe_de(en_mano[0].uid)
		if naipe != null:
			mano.on_card_pressed(naipe)
	for ec: EstadoCarta in motor.estado.firma(lado).estrado:
		var naipe: NaipeDePalabra = vista.naipe_de(ec.uid)
		if naipe == null:
			continue
		estrado.on_card_pressed(naipe)
		var capa: CapaObjetivo = vista.get_node_or_null("CapaObjetivo") as CapaObjetivo
		if capa != null and capa.activa:
			return


func _correr() -> void:
	var destino: String = "user://mesa_de_palabra.png"
	for arg: String in OS.get_cmdline_user_args():
		if arg.ends_with(".png"):
			destino = arg
	_rng.seed = SEMILLA
	var vista: VistaDuelo = (load(ESCENA_DUELO) as PackedScene).instantiate() as VistaDuelo
	vista.velocidad_naipes = 6000
	add_child(vista)
	var mesa: ConfigMesa = ConfigMesa.el_fiado()
	var motor: MotorDePalabra = MotorDePalabra.new(SEMILLA)
	motor.iniciar(
		mesa, PilotoRandom.mazo_al_azar(mesa, _rng), PilotoRandom.mazo_al_azar(mesa, _rng), 0
	)
	vista.montar(motor, 0)
	for _i: int in JUGADAS:
		if motor.estado.terminado:
			break
		motor.ejecutar(PilotoRandom.elegir(motor, motor.estado.activo, _rng))
		await get_tree().process_frame
	_mostrar_una_decision(vista, motor)
	# Que terminen los tweens de movimiento antes de la foto.
	for _i: int in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var imagen: Image = get_viewport().get_texture().get_image()
	var error: Error = imagen.save_png(destino)
	if error != OK:
		printerr("no se pudo guardar %s (error %d)" % [destino, error])
	else:
		print("foto de la mesa en %s" % destino)
	get_tree().quit(0 if error == OK else 1)
