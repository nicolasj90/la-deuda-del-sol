# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node

## Autoload [b]DueloLauncher[/b]: lanza un duelo de «De Palabra» desde un diálogo.
##
## Mismo patrón que el bridge de encuentros ([code]Encounters[/code]): el mapa
## nunca sale del árbol, se pausa ([constant Node.PROCESS_MODE_DISABLED]), la mesa
## se monta en un [CanvasLayer] propio y al cerrar el duelo se desmonta todo y el
## mapa sigue donde estaba.
##
## La vista ([VistaDuelo]) juega el lado del jugador con el mouse; el lado rival lo
## juega [PilotoDePalabra] con el [PerfilIA] que se le pase.
##
## [b]Desde un [code].dialogue[/code][/b] (Dialogue Manager espera las corrutinas de
## un [code]do[/code], así que la línea siguiente ya corre con el duelo cerrado):
## [codeblock]
## do balloon.hide()
## do DueloLauncher.duelo("garante", {"mazo_jugador": ["gallina_lacrevieja"]})
## do balloon.show()
## if DueloLauncher.gano:
##     Rosaura: Me ganó anunciando la mano.
## else:
##     Rosaura: Otra vez, y esta vez callate la mano.
## [/codeblock]
##
## [b]Opciones[/b] (todas opcionales):
## [br][code]mesa[/code]: [code]"base"[/code] (default), [code]"el_fiado"[/code] o un [ConfigMesa].
## [br][code]mazo_jugador[/code]: ids (Array o [code]{id: copias}[/code]). Default: el
##   mazo activo de [code]Coleccion[/code]. En E03 se pasa el mazo prestado de la casa.
## [br][code]mazo_rival[/code]: ids, o el nombre de un arquetipo. Default: el
##   arquetipo del perfil, armado por [ArmadorDeMazos].
## [br][code]mano_jugador[/code] / [code]mano_rival[/code]: mano inicial fijada por
##   script — la regla no negociable del guion (§ 4f.1: «Ciro no puede mentir ni por
##   desincronización»). Ojo: la mano que se reemplaza se va al descarte (es el
##   gancho de depuración del motor), así que conviene usarla solo en mesas de guion.
## [br][code]anuncio_jugador[/code] / [code]anuncio_rival[/code]: lo que cada lado
##   anunció en voz alta; la IA decide si creerlo (§ 7.2.6).
## [br][code]premio[/code]: cartas que entrega [code]Coleccion[/code] al ganar.
## [br][code]semilla[/code]: 0 = azar de verdad.
## [br][code]primero[/code]: 0 = empieza el jugador (default), 1 = empieza el rival.
## [br][code]lado_jugador[/code]: 0 (default) o 1.
## [br][code]auto[/code]: la IA juega también el lado del jugador (demos y tests).
## [br][code]perfil_jugador[/code]: perfil de esa IA (default [code]"casa"[/code]).
## [br][code]pausar_mapa[/code]: default [code]true[/code].
## [br][code]mostrar_todo[/code]: mostrar la información oculta (espectador).
## [br][code]ritmo[/code]: segundos entre jugadas del rival (default [member ritmo_ia]).
## [br][code]pausa_cierre[/code]: segundos que queda el cartel del final en pantalla.

## Se emite al montar la mesa, con el motor ya arrancado: sirve para colgar música,
## barks por disparador o un overlay de tutorial.
signal duelo_montado(motor: MotorDePalabra, vista: VistaDuelo)

## Se emite al cerrar el duelo, ya con el premio entregado.
signal duelo_terminado(gano: bool, motivo: String)

const ESCENA_DUELO: String = "res://scenes/card_game/vista/duelo.tscn"

## Misma capa que usa el bridge de encuentros: por debajo de PauseOverlay (2) y
## Transitions (10).
const CAPA_DUELO: int = 1

## Cota anti-cuelgue del bucle de la IA (solo pega en modo [code]auto[/code]).
const TOPE_VUELTAS: int = 20000

## Resultado del último duelo. Es lo que lee el [code].dialogue[/code].
var gano: bool = false
## Motivo de cierre del último duelo (§ 1.2: [code]"aval"[/code], [code]"incobrable"[/code]…).
var motivo: String = ""
## Firma ganadora del último duelo, o -1.
var ganador: int = -1
## Turnos que duró el último duelo.
var turnos: int = 0
## Cartas que entregó el premio del último duelo ([code]id -> copias[/code]).
var premio_entregado: Dictionary = {}
## True mientras hay una mesa montada.
var en_curso: bool = false
## Segundos entre jugadas del rival, para que el turno de la IA se vea.
var ritmo_ia: float = 0.45

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Corre un duelo entero y devuelve [code]true[/code] si ganó el jugador.
## Es una corrutina: [code]await DueloLauncher.duelo(...)[/code] desde código, o
## [code]do DueloLauncher.duelo(...)[/code] desde un [code].dialogue[/code].
func duelo(perfil_id: String, opciones: Dictionary = {}) -> bool:
	if en_curso:
		push_warning("[DueloLauncher] ya hay un duelo en curso; se ignora el pedido.")
		return false
	var perfil_rival: PerfilIA = CatalogoDePerfiles.obtener(perfil_id)
	if perfil_rival == null:
		push_error("[DueloLauncher] no existe el perfil de IA «%s»." % perfil_id)
		return false

	var mesa: ConfigMesa = _mesa_de(opciones.get("mesa", "base"))
	var auto: bool = bool(opciones.get("auto", false))
	var lado_jugador: int = clampi(int(opciones.get("lado_jugador", 0)), 0, 1)
	var primero_pedido: int = clampi(int(opciones.get("primero", 0)), 0, 1)
	var primero: int = lado_jugador if primero_pedido == 0 else 1 - lado_jugador
	var semilla: int = int(opciones.get("semilla", 0))
	if semilla == 0:
		semilla = randi()
	_rng.seed = semilla

	var mazo_jugador: Array[String] = _mazo_del_jugador(opciones, mesa)
	if mazo_jugador.is_empty():
		push_error(
			(
				"[DueloLauncher] el jugador no tiene mazo: pasá «mazo_jugador» "
				+ "(el mazo prestado de la casa) o entregá el mazo inicial."
			)
		)
		return false
	var mazo_rival: Array[String] = _mazo_del_rival(opciones, mesa, perfil_id)

	var perfil_jugador: PerfilIA = null
	if auto:
		perfil_jugador = CatalogoDePerfiles.obtener(String(opciones.get("perfil_jugador", "casa")))
		if perfil_jugador == null:
			perfil_jugador = perfil_rival

	en_curso = true
	gano = false
	motivo = ""
	ganador = -1
	turnos = 0
	premio_entregado = {}

	var motor: MotorDePalabra = MotorDePalabra.new(semilla)
	if lado_jugador == 0:
		motor.iniciar(mesa, mazo_jugador, mazo_rival, primero)
	else:
		motor.iniciar(mesa, mazo_rival, mazo_jugador, primero)
	fijar_mano_inicial(motor, lado_jugador, opciones.get("mano_jugador", null))
	fijar_mano_inicial(motor, 1 - lado_jugador, opciones.get("mano_rival", null))

	# --- montaje del overlay ---
	var mapa: Node = get_tree().current_scene
	var pausar: bool = bool(opciones.get("pausar_mapa", true))
	if pausar and mapa != null:
		mapa.process_mode = Node.PROCESS_MODE_DISABLED
	# El HUD de teclas del mapa (autoload InputHud, capa 36) va por encima de la
	# mesa; en un duelo no aplica y tapa la mano de abajo.
	var hud_visible: bool = InputHud.visible
	InputHud.visible = false
	var capa: CanvasLayer = CanvasLayer.new()
	capa.layer = CAPA_DUELO
	var escena: PackedScene = load(ESCENA_DUELO) as PackedScene
	var vista: VistaDuelo = escena.instantiate() as VistaDuelo
	vista.mostrar_todo = bool(opciones.get("mostrar_todo", false))
	vista.velocidad_naipes = int(opciones.get("velocidad_naipes", 0))
	# La vista se monta sobre el motor en su _ready(), al entrar la capa al árbol.
	vista.motor = motor
	vista.lado_jugador = lado_jugador
	capa.add_child(vista)
	# DEFERRED: el duelo puede pedirse desde el _ready() de un nodo (o desde una
	# mutación de Dialogue Manager en el mismo pase), y ahí la raíz todavía está
	# armando hijos y un add_child() directo falla.
	get_tree().root.add_child.call_deferred(capa)
	var espera: int = 120
	while not capa.is_inside_tree() and espera > 0:
		espera -= 1
		await get_tree().process_frame
	if not capa.is_inside_tree():
		push_error("[DueloLauncher] no se pudo montar la mesa en el árbol.")
		capa.free()
		InputHud.visible = hud_visible
		if pausar and mapa != null:
			mapa.process_mode = Node.PROCESS_MODE_INHERIT
		en_curso = false
		return false
	duelo_montado.emit(motor, vista)

	# --- el duelo ---
	var anuncio_jugador: Array[String] = ArmadorDeMazos.normalizar(
		opciones.get("anuncio_jugador", null)
	)
	var anuncio_rival: Array[String] = ArmadorDeMazos.normalizar(
		opciones.get("anuncio_rival", null)
	)
	var ritmo: float = float(opciones.get("ritmo", ritmo_ia))
	var vueltas: int = TOPE_VUELTAS
	while not motor.estado.terminado and vueltas > 0:
		vueltas -= 1
		var activo: int = motor.estado.activo
		var es_de_la_ia: bool = auto or activo != lado_jugador
		if es_de_la_ia and motor.estado.fase == Palabra.Fase.ACCIONES:
			if ritmo > 0.0:
				await get_tree().create_timer(ritmo).timeout
				if not is_inside_tree() or motor.estado.terminado:
					break
			var perfil: PerfilIA = perfil_rival if activo != lado_jugador else perfil_jugador
			var anuncio: Array[String] = (
				anuncio_jugador if activo != lado_jugador else anuncio_rival
			)
			PilotoDePalabra.jugar_turno(motor, perfil, _rng, anuncio)
			vista.sincronizar_ya()
			if motor.estado.activo == activo and not motor.estado.terminado:
				# El turno no avanzó: cortar antes de colgar (no debería pasar).
				push_error("[DueloLauncher] la IA no pudo cerrar el turno %d." % motor.estado.turno)
				break
		await get_tree().process_frame
	if vueltas <= 0 and not motor.estado.terminado:
		# Con un jugador humano el bucle espera lo que haga falta, así que llegar
		# acá quiere decir que nadie jugaba ese lado (¿faltó «auto»?).
		push_error(
			(
				"[DueloLauncher] el duelo no cerró en %d vueltas: el lado %d nunca jugó."
				% [TOPE_VUELTAS, motor.estado.activo]
			)
		)

	# --- cierre ---
	ganador = motor.estado.ganador
	motivo = motor.estado.motivo_fin
	turnos = motor.estado.turno
	gano = ganador == lado_jugador
	var pausa_cierre: float = float(opciones.get("pausa_cierre", 0.0 if auto else 1.5))
	if pausa_cierre > 0.0:
		await get_tree().create_timer(pausa_cierre).timeout
	# Desmontar YA, no en la cola de borrado. El [CardManager] del addon se
	# registra en el meta «card_manager» de la escena actual y se desregistra en su
	# [method Node._exit_tree]; con [method Node.queue_free] eso pasa recién al
	# final del cuadro, DESPUÉS de los deferred, así que la mesa siguiente se monta
	# mientras la vieja todavía está registrada, sus contenedores agarran el
	# CardManager viejo y a los pocos cuadros revientan como «previously freed»
	# (se veía al jugar dos duelos seguidos: Rosaura y Cosme en E03).
	if capa.is_inside_tree():
		capa.get_parent().remove_child(capa)
	vista.queue_free()
	capa.queue_free()
	InputHud.visible = hud_visible
	if pausar and mapa != null and is_instance_valid(mapa):
		mapa.process_mode = Node.PROCESS_MODE_INHERIT
	# Mismo bug que en el bridge de encuentros: con el mapa pausado el jugador no
	# recibe el «keyup» de la flecha y al cerrar la mesa salía caminando solo.
	Encounters.resincronizar_caminata_del_jugador()
	en_curso = false

	if gano:
		premio_entregado = _entregar_premio(opciones.get("premio", null))
	duelo_terminado.emit(gano, motivo)
	return gano


## Azúcar para los [code].dialogue[/code] y los tests: un duelo que se juega solo.
func duelo_auto(perfil_id: String, semilla: int = 0, opciones: Dictionary = {}) -> bool:
	var op: Dictionary = opciones.duplicate()
	op["auto"] = true
	op["semilla"] = semilla
	op["ritmo"] = 0.0
	op["pausa_cierre"] = 0.0
	op["mostrar_todo"] = true
	op["velocidad_naipes"] = 100000
	return await duelo(perfil_id, op)


# ---------------------------------------------------------------------------
# Internos
# ---------------------------------------------------------------------------


func _mesa_de(valor: Variant) -> ConfigMesa:
	if valor is ConfigMesa:
		return valor
	match String(valor):
		"el_fiado":
			return ConfigMesa.el_fiado()
		_:
			return ConfigMesa.base()


func _mazo_del_jugador(opciones: Dictionary, mesa: ConfigMesa) -> Array[String]:
	var pedido: Array[String] = ArmadorDeMazos.normalizar(opciones.get("mazo_jugador", null))
	if pedido.is_empty():
		var coleccion: Node = get_node_or_null(^"/root/Coleccion")
		if coleccion != null:
			pedido = ArmadorDeMazos.normalizar(coleccion.mazo_actual())
	for e: String in ArmadorDeMazos.errores_de_mazo(pedido, mesa, false):
		push_warning("[DueloLauncher] mazo del jugador: %s" % e)
	return pedido


func _mazo_del_rival(opciones: Dictionary, mesa: ConfigMesa, perfil_id: String) -> Array[String]:
	var pedido: Variant = opciones.get("mazo_rival", null)
	if pedido is String and not String(pedido).is_empty():
		return ArmadorDeMazos.por_arquetipo(String(pedido), mesa)
	var lista: Array[String] = ArmadorDeMazos.normalizar(pedido)
	if lista.is_empty():
		return ArmadorDeMazos.por_arquetipo(ArmadorDeMazos.arquetipo_de_perfil(perfil_id), mesa)
	for e: String in ArmadorDeMazos.errores_de_mazo(lista, mesa, false):
		push_warning("[DueloLauncher] mazo rival: %s" % e)
	return lista


## Mano inicial fijada por script (§ 4f.1: la mano de Ciro tiene que coincidir con
## la que anuncia en voz alta). Usa los ganchos de depuración del motor: vacía la
## mano de ese lado y pone exactamente las cartas pedidas, en ese orden.
func fijar_mano_inicial(motor: MotorDePalabra, lado: int, ids: Variant) -> void:
	var mano: Array[String] = ArmadorDeMazos.normalizar(ids)
	if mano.is_empty():
		return
	motor.depurar_vaciar_mano(lado)
	for id: String in mano:
		if motor.depurar_poner_en_mano(lado, id) < 0:
			push_error("[DueloLauncher] mano fijada: «%s» no existe en el set." % id)


func _entregar_premio(premio: Variant) -> Dictionary:
	var pedido: Dictionary = ArmadorDeMazos.cuenta(premio)
	if pedido.is_empty():
		return {}
	var coleccion: Node = get_node_or_null(^"/root/Coleccion")
	if coleccion == null:
		return {}
	return coleccion.agregar_varias(pedido)
