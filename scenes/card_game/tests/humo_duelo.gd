# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node

## Humo de la **vista** del duelo: monta `duelo.tscn` de verdad y juega duelos
## enteros de piloto random contra piloto random, con los visuales a máxima
## velocidad, hasta que el motor cierra el duelo.
##
## Para qué: los tests del motor corren sin escena (§ 8) y no tocan una sola línea
## de la vista. Acá se ejercita lo que el addon aporta y lo que hubo que construir
## encima: la fábrica, los contenedores, los labels vivos, la capa de objetivos, el
## diálogo de Promesas y el cableado motor→vista por señales. Un `SCRIPT ERROR` en
## cualquiera de esos caminos rompe esta prueba.
##
## Además chequea `test_sensores_no_se_solapan` (§ 8.5), el único test del diseño
## que necesita escena: si dos sensores se pisan, el primer contenedor que acepta
## se queda la carta (§ 6.2.8) y el jugador ve cartas que se van al lugar
## equivocado.
##
## Uso:
## [codeblock]
## godot --headless --path . res://scenes/card_game/tests/humo_duelo.tscn
## [/codeblock]

const ESCENA_DUELO: String = "res://scenes/card_game/vista/duelo.tscn"
const TOPE_DE_JUGADAS: int = 4000
const CORRIDAS: Array[Dictionary] = [
	{"etiqueta": "base", "mesa": "base", "semilla": 11, "lado": 0, "mostrar_todo": false},
	{"etiqueta": "el fiado", "mesa": "el_fiado", "semilla": 2027, "lado": 0, "mostrar_todo": true},
	{
		"etiqueta": "el fiado, jugador = Firma 1",
		"mesa": "el_fiado",
		"semilla": 404,
		"lado": 1,
		"mostrar_todo": false,
	},
]

var _fallos: Array[String] = []
var _vista: VistaDuelo = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	# Los tweens del addon son por tiempo: con el time_scale alto y la velocidad de
	# los naipes altísima, la vista no espera animaciones.
	Engine.time_scale = 30.0
	await _correr()


func _correr() -> void:
	var escena: PackedScene = load(ESCENA_DUELO) as PackedScene
	if escena == null:
		_fallar("no se pudo cargar %s" % ESCENA_DUELO)
		_terminar()
		return
	_vista = escena.instantiate() as VistaDuelo
	if _vista == null:
		_fallar("%s no instancia una VistaDuelo" % ESCENA_DUELO)
		_terminar()
		return
	_vista.mostrar_todo = true
	_vista.velocidad_naipes = 100000
	add_child(_vista)
	await get_tree().process_frame

	# Tres duelos que cubren lo que cambia de camino en la vista: la mesa base, la
	# mesa de El Fiado (Empeñadero + cartas boca abajo) y un duelo en el que el
	# jugador es la Firma 1, que es el que rompe si el mapeo de zonas está atado a
	# «propio = lado 0».
	for corrida: Dictionary in CORRIDAS:
		await _un_duelo(corrida)
		if not _fallos.is_empty():
			break
	_terminar()


func _un_duelo(corrida: Dictionary) -> void:
	var etiqueta: String = String(corrida["etiqueta"])
	var semilla: int = int(corrida["semilla"])
	var mesa: ConfigMesa = (
		ConfigMesa.base() if String(corrida["mesa"]) == "base" else ConfigMesa.el_fiado()
	)
	_vista.mostrar_todo = bool(corrida["mostrar_todo"])
	_rng.seed = semilla
	var motor: MotorDePalabra = MotorDePalabra.new(semilla)
	var mazo_a: Array[String] = PilotoRandom.mazo_al_azar(mesa, _rng)
	var mazo_b: Array[String] = PilotoRandom.mazo_al_azar(mesa, _rng)
	if mazo_a.size() != Palabra.MAZO_TAMANO or mazo_b.size() != Palabra.MAZO_TAMANO:
		_fallar("los mazos al azar salieron de %d y %d cartas" % [mazo_a.size(), mazo_b.size()])
		return
	motor.iniciar(mesa, mazo_a, mazo_b, 0)
	_vista.montar(motor, int(corrida["lado"]))
	await get_tree().process_frame
	_probar_sensores()

	var jugadas: int = 0
	while not motor.estado.terminado and jugadas < TOPE_DE_JUGADAS:
		jugadas += 1
		var activo: int = motor.estado.activo
		if activo == _vista.lado_jugador:
			# El lado del jugador se juega **por la vista**: los mismos caminos de
			# input que usa el mouse (seleccionar, soltar, elegir objetivo, firmar
			# la Promesa en el diálogo).
			await _turno_por_la_vista(motor)
		var j: JugadaDePalabra = PilotoRandom.elegir(motor, motor.estado.activo, _rng)
		if (
			j.tipo == Palabra.TipoJugada.PASAR
			and motor.estado.activo == _vista.lado_jugador
			and _rng.randf() < 0.5
		):
			_apretar_boton("Terminar")
		else:
			motor.ejecutar(j)
		await get_tree().process_frame
		_revisar_invariantes(motor)
		if not _fallos.is_empty():
			return
	_vista.sincronizar_ya()
	if not motor.estado.terminado:
		_fallar("el duelo «%s» no cerró en %d jugadas" % [etiqueta, jugadas])
		return
	print(
		(
			"-- duelo «%s»: %d jugadas, %d turnos, ganó la Firma %d (%s); aval %d a %d"
			% [
				etiqueta,
				jugadas,
				motor.estado.turno,
				motor.estado.ganador,
				motor.estado.motivo_fin,
				motor.estado.firma(0).aval,
				motor.estado.firma(1).aval,
			]
		)
	)


## Una acción del jugador pasando por la UI: apretar una carta de la mano,
## soltarla en el Estrado (o en el Empeñadero), resolver el objetivo en la capa y
## la Promesa en el diálogo, y de paso mandar a atacar a un Fiador del Estrado.
func _turno_por_la_vista(motor: MotorDePalabra) -> void:
	var lado: int = _vista.lado_jugador
	var mano: ManoDePalabra = _vista.get_node_or_null("Mesa/ManoPropia") as ManoDePalabra
	var estrado: EstradoDePalabra = (
		_vista.get_node_or_null("Mesa/EstradoPropio") as EstradoDePalabra
	)
	var estrado_rival: EstradoDePalabra = (
		_vista.get_node_or_null("Mesa/EstradoRival") as EstradoDePalabra
	)
	var empenadero: PilaDePalabra = (
		_vista.get_node_or_null("Mesa/EmpenaderoPropio") as PilaDePalabra
	)
	if mano == null or estrado == null or estrado_rival == null or empenadero == null:
		_fallar("la escena del duelo no tiene los contenedores esperados")
		return

	var cartas: Array[EstadoCarta] = motor.estado.firma(lado).mano
	if not cartas.is_empty():
		var ec: EstadoCarta = cartas[_rng.randi_range(0, cartas.size() - 1)]
		var naipe: NaipeDePalabra = _vista.naipe_de(ec.uid)
		if naipe != null:
			mano.on_card_pressed(naipe)
			var dado: float = _rng.randf()
			if motor.estado.mesa.empenar and dado < 0.2:
				empenadero.soltaron_naipe.emit(naipe, empenadero)
			elif motor.estado.mesa.al_fiado and dado < 0.4:
				# Los botones del HUD son el otro camino de entrada: se aprietan de
				# verdad, no se llama a la vista por atrás.
				_apretar_boton("AlFiado")
			elif dado < 0.55:
				_apretar_boton("Jugar")
			else:
				var destino: EstradoDePalabra = estrado
				if not ec.es_cuerpo() and _apunta_al_rival(ec):
					destino = estrado_rival
				destino.soltaron_naipe.emit(naipe, destino)
			await get_tree().process_frame
			await _resolver_decisiones()

	# Rescatar una prenda del Empeñadero rival y denunciar una carta en viaje: los
	# dos se piden apretando el naipe en la pila del rival (§ 3.3 y § 4.2).
	var rival: int = 1 - lado
	for z: Palabra.Zona in [Palabra.Zona.EMPENADERO, Palabra.Zona.VIAJE]:
		var pila: PilaDePalabra = _vista.contenedor_de(rival, z) as PilaDePalabra
		var ajenas: Array[EstadoCarta] = motor.estado.firma(rival).zona(z)
		if pila == null or ajenas.is_empty() or _rng.randf() > 0.5:
			continue
		var naipe: NaipeDePalabra = _vista.naipe_de(
			ajenas[_rng.randi_range(0, ajenas.size() - 1)].uid
		)
		if naipe == null:
			continue
		pila.apretaron_naipe.emit(naipe, pila)
		await get_tree().process_frame
		await _resolver_decisiones()

	var mios: Array[EstadoCarta] = motor.estado.firma(lado).estrado
	if not mios.is_empty():
		var atacante: EstadoCarta = mios[_rng.randi_range(0, mios.size() - 1)]
		var naipe: NaipeDePalabra = _vista.naipe_de(atacante.uid)
		if naipe != null:
			estrado.on_card_pressed(naipe)
			await get_tree().process_frame
			await _resolver_decisiones()


## Cierra lo que la vista haya abierto: la capa de objetivos y el diálogo. Sin
## esto el humo se quedaría esperando un clic que nunca llega.
func _resolver_decisiones() -> void:
	var capa: CapaObjetivo = _vista.get_node_or_null("CapaObjetivo") as CapaObjetivo
	var dialogo: DialogoDePalabra = (
		_vista.get_node_or_null("DialogoDePalabra") as DialogoDePalabra
	)
	if capa != null and capa.activa:
		var objetivos: Array[Dictionary] = capa.objetivos()
		if objetivos.is_empty():
			_fallar("la capa de objetivos se abrió sin objetivos")
			return
		var elegido: Dictionary = objetivos[_rng.randi_range(0, objetivos.size() - 1)]
		capa.cerrar()
		capa.elegido.emit(int(elegido.get("uid", -1)))
		await get_tree().process_frame
	if dialogo != null and dialogo.abierto():
		var caja: VBoxContainer = (
			dialogo.get_node_or_null("Panel/Caja/Scroll/Opciones") as VBoxContainer
		)
		if caja == null or caja.get_child_count() == 0:
			_fallar("el diálogo se abrió sin opciones")
			return
		var botones: Array[Node] = caja.get_children()
		var boton: Button = botones[_rng.randi_range(0, botones.size() - 1)] as Button
		if boton == null:
			_fallar("el diálogo tiene una opción que no es un botón")
			return
		boton.pressed.emit()
		await get_tree().process_frame


## Información que el jugador puede ver: su mano, y todo lo que no viaja boca
## abajo (§ 4.2).
func _deberia_verse(ec: EstadoCarta) -> bool:
	if ec.boca_abajo:
		return false
	if ec.zona == Palabra.Zona.MANO:
		return ec.dueno == _vista.lado_jugador
	return true


## Aprieta un botón del HUD de verdad (emite su señal `pressed`), para que la
## prueba pase por el mismo código que el mouse.
func _apretar_boton(nombre: String) -> void:
	var boton: Button = _vista.get_node_or_null("HUD/Botones/%s" % nombre) as Button
	if boton == null:
		_fallar("el HUD no tiene el botón %s" % nombre)
		return
	if not boton.disabled:
		boton.pressed.emit()


func _apunta_al_rival(ec: EstadoCarta) -> bool:
	if ec.def.objetivos.is_empty():
		return false
	return ec.def.objetivos[0] == MotorDePalabra.OBJ_ENEMIGO_O_FIRMA


## La vista tiene que quedar pegada al motor: un naipe por carta en zona visible,
## en el contenedor que le toca y con los números del motor.
func _revisar_invariantes(motor: MotorDePalabra) -> void:
	_vista.sincronizar_ya()
	for lado: int in [0, 1]:
		var f: EstadoFirma = motor.estado.firma(lado)
		for z: Palabra.Zona in VistaDuelo.ZONAS_CON_NAIPE:
			for ec: EstadoCarta in f.zona(z):
				var naipe: NaipeDePalabra = _vista.naipe_de(ec.uid)
				if naipe == null:
					_fallar(
						(
							"la carta %d (%s) está en %s y la vista no la dibuja"
							% [ec.uid, ec.id(), TextosDePalabra.zona(z)]
						)
					)
					return
				var donde: CardContainer = _vista.contenedor_de(lado, z)
				if naipe.card_container != donde:
					_fallar(
						(
							"el naipe de %s está en %s y el motor lo tiene en %s de la Firma %d"
							% [
								ec.id(),
								"ningún contenedor" if naipe.card_container == null else String(naipe.card_container.name),
								TextosDePalabra.zona(z),
								lado,
							]
						)
					)
					return
				if not _vista.mostrar_todo and naipe.show_front != _deberia_verse(ec):
					_fallar(
						(
							"%s en %s de la Firma %d muestra la cara %s"
							% [
								ec.id(),
								TextosDePalabra.zona(z),
								lado,
								"cuando es información oculta" if naipe.show_front else "y tendría que verse",
							]
						)
					)
					return
				if ec.zona == Palabra.Zona.ESTRADO and ec.tipo() != Palabra.Tipo.CLAUSULA:
					var esperado: String = str(motor.aguante_restante(ec))
					if naipe.etiqueta_aguante.text != esperado:
						_fallar(
							(
								"%s muestra aguante %s y el motor dice %s"
								% [ec.id(), naipe.etiqueta_aguante.text, esperado]
							)
						)
						return
	if _vista.get_node_or_null("Mesa/EstradoPropio") != null:
		var estrado: EstradoDePalabra = (
			_vista.get_node("Mesa/EstradoPropio") as EstradoDePalabra
		)
		if estrado.get_card_count() > Palabra.ESTRADO_MAX:
			_fallar("el Estrado propio dibuja %d naipes" % estrado.get_card_count())


## § 8.5 `test_sensores_no_se_solapan`: dos sensores encimados hacen que el primer
## contenedor que acepta se quede la carta (§ 6.2.8).
func _probar_sensores() -> void:
	var contenedores: Array[CardContainer] = _vista.contenedores()
	if contenedores.size() < 11:
		_fallar("la mesa tiene %d contenedores: falta alguna zona" % contenedores.size())
		return
	var rects: Array[Rect2] = []
	var nombres: Array[String] = []
	for c: CardContainer in contenedores:
		if c.drop_zone == null or c.drop_zone.sensor == null:
			_fallar("%s no tiene sensor: no se le puede soltar nada (§ 6.2.9)" % c.name)
			continue
		rects.append(c.drop_zone.sensor.get_global_rect())
		nombres.append(String(c.name))
	for i: int in rects.size():
		for j: int in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j], false):
				_fallar(
					(
						"los sensores de %s %s y %s %s se solapan (§ 6.2.8)"
						% [nombres[i], str(rects[i]), nombres[j], str(rects[j])]
					)
				)
	print("-- %d contenedores, sensores sin solaparse" % rects.size())


func _fallar(mensaje: String) -> void:
	_fallos.append(mensaje)


func _terminar() -> void:
	if _fallos.is_empty():
		print("OK — humo de la vista del duelo")
		get_tree().quit(0)
		return
	for f: String in _fallos:
		printerr("FALLO: %s" % f)
	printerr("FALLÓ — %d problema(s)" % _fallos.size())
	get_tree().quit(1)
