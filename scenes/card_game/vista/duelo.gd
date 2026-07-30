# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name VistaDuelo
extends Control

## La vista del duelo de «De Palabra»: **solo dibuja y traduce input** (diseño § 0).
##
## Dirección de dependencia, no negociable: el motor emite [signal
## MotorDePalabra.evento] y la vista se suscribe. La vista **nunca** decide una
## regla; cuando el jugador pide algo, se lo pregunta al motor
## ([method MotorDePalabra.jugadas_legales] / [method MotorDePalabra.motivo_ilegal])
## y muestra el motivo si dice no. Si la vista y el motor discrepan, gana el motor:
## [method _sincronizar] vuelve a acomodar la mesa contra el estado real.
##
## Cómo se juega con el mouse:
##
## - **arrastrar** una carta de la mano al Estrado propio = jugarla; al Estrado
##   rival = jugar una Cláusula que pega del otro lado; al Empeñadero propio =
##   empeñarla (§ 3.3).
## - **apretar** una carta de la mano la selecciona (los botones «Jugar», «Al
##   fiado» y «Empeñar» actúan sobre la seleccionada, y sirven para las Cláusulas
##   sin objetivo en la mesa).
## - **apretar** un Fiador propio del Estrado abre la capa de objetivos para
##   atacar (§ 6.2.2: soltar carta sobre carta no existe en el addon).
## - **apretar** una prenda del Empeñadero rival la rescata; una carta en viaje
##   rival abre la denuncia (§ 4.2).
##
## Las Promesas se firman en un diálogo de confirmación ([DialogoDePalabra]): son
## un compromiso con plazo y no puede pasar que se firmen de arrastre.
##
## [b]Capas de dibujo[/b]: el addon le pone a cada naipe un [member
## CanvasItem.z_index] creciente (el índice en la mano o en el Estrado), y al
## dibujar el z_index le gana al orden del árbol. Sin contramedida la mano se
## dibuja **encima** del diálogo de Promesas y del cartel del final. Por eso
## `HUD` va en z 50, `CapaObjetivo` en 100 y `DialogoDePalabra` en 110 en
## `duelo.tscn`. (El ruteo de input sí usa el orden del árbol, así que los clics
## siempre llegaron bien: el problema era solo visual.)
##
## Lo que todavía es placeholder visual: no hay arte de carta (las 42 caras del
## § 9.4 son el cuello de botella real), así que el naipe se dibuja con marco,
## labels y nada más; el Mazo es un rótulo con el contador, sin pila de dorsos; y
## no hay animaciones de ataque ni de daño más allá del movimiento del addon.

## Se emite cuando el motor cierra el duelo. Lo escucha la escena que montó la
## vista (una escena de guion, o el humo de IA contra IA).
signal duelo_finalizado(ganador: int, motivo: String)

## Modo de input. Con la capa de objetivos o el diálogo abiertos no se acepta
## ninguna otra acción: no hay dos decisiones a medio tomar a la vez.
enum Modo { ESPERA, LIBRE, OBJETIVO, DIALOGO, TERMINADO }

## Zonas que la vista dibuja con naipes. El Mazo queda afuera a propósito: son 30
## cartas por lado que nunca se ven, y crear 60 nodos para mostrar un dorso es
## caro y no aporta (el contador va en el HUD).
const ZONAS_CON_NAIPE: Array[Palabra.Zona] = [
	Palabra.Zona.MANO,
	Palabra.Zona.ESTRADO,
	Palabra.Zona.MORA,
	Palabra.Zona.EMPENADERO,
	Palabra.Zona.DESCARTE,
	Palabra.Zona.VIAJE,
]

const MAX_LINEAS_REGISTRO: int = 80

## Mostrar la información oculta (mano rival, cartas al fiado). Solo para pruebas
## y para el modo espectador de IA contra IA.
@export var mostrar_todo: bool = false
## Velocidad de movimiento de los naipes en píxeles por segundo. 0 = la del addon.
## El humo headless la pone altísima para que el duelo no espere tweens.
@export var velocidad_naipes: int = 0

var motor: MotorDePalabra = null
var lado_jugador: int = 0

var _mesa: CardManager = null
var _fabrica: FabricaDePalabra = null
var _capa: CapaObjetivo = null
var _dialogo: DialogoDePalabra = null

var _firma_rival: Panel = null
var _etiqueta_firma_rival: Label = null
var _etiqueta_firma_propia: Label = null
var _etiqueta_turno: Label = null
var _etiqueta_mazo_rival: Label = null
var _etiqueta_mazo_propio: Label = null
var _detalle: Label = null
var _mensaje: Label = null
var _registro: RichTextLabel = null
var _cartel: Label = null
var _boton_jugar: Button = null
var _boton_al_fiado: Button = null
var _boton_empenar: Button = null
var _boton_terminar: Button = null

## zona -> contenedor del lado del jugador y del lado rival. La escena está
## dibujada «desde tu silla»: el mapeo depende de [member lado_jugador], que puede
## ser 1 (en un duelo de guion el jugador no siempre es la Firma 0).
var _propios: Dictionary = {}
var _rivales: Dictionary = {}
## uid del motor -> naipe.
var _naipes: Dictionary = {}

var _modo: Modo = Modo.ESPERA
var _seleccionado: NaipeDePalabra = null
## Decisión a medio tomar: qué se está por hacer cuando vuelva el objetivo.
var _pedido: Dictionary = {}
var _lineas: PackedStringArray = []
var _sucio: bool = false
## Jugadas legales del jugador, recalculadas una vez por sincronización.
var _legales: Array[JugadaDePalabra] = []


func _ready() -> void:
	_resolver_nodos()
	_conectar_contenedores()
	_conectar_hud()
	if _capa != null:
		_capa.elegido.connect(_al_elegir_objetivo)
		_capa.cancelado.connect(_al_cancelar_objetivo)
	if _dialogo != null:
		_dialogo.elegido.connect(_al_elegir_del_dialogo)
		_dialogo.cancelado.connect(_al_cancelar_dialogo)
	if _cartel != null:
		_cartel.visible = false
	if motor != null:
		montar(motor, lado_jugador)


# ---------------------------------------------------------------------------
# Montaje
# ---------------------------------------------------------------------------


## Engancha un duelo ya arrancado ([method MotorDePalabra.iniciar]). Los eventos
## que el motor ya emitió se recuperan de su registro, así el log arranca completo.
func montar(m: MotorDePalabra, lado: int = 0) -> void:
	if motor != null and motor.evento.is_connected(_al_evento):
		motor.evento.disconnect(_al_evento)
	_limpiar_naipes()
	_lineas = []
	_pedido = {}
	_seleccionado = null
	motor = m
	lado_jugador = lado
	if _cartel != null:
		_cartel.visible = false
	if motor == null:
		_modo = Modo.ESPERA
		return
	for e: EventoDuelo in motor.registro:
		_anotar(e)
	motor.evento.connect(_al_evento)
	_modo = Modo.TERMINADO if motor.estado.terminado else Modo.LIBRE
	_sincronizar()


## Sincroniza ya, sin esperar el frame. La usan las pruebas headless, que no
## quieren depender de cuántos frames pasaron.
func sincronizar_ya() -> void:
	_sucio = false
	_sincronizar()


func naipe_de(uid: int) -> NaipeDePalabra:
	return _naipes.get(uid, null) as NaipeDePalabra


## Contenedor en el que la vista dibuja una zona de un lado, ya resuelto «desde tu
## silla». Lo usan las pruebas para chequear que cada naipe esté donde va.
func contenedor_de(lado: int, z: Palabra.Zona) -> CardContainer:
	return _contenedor(lado, z)


## Contenedores de la mesa, para la prueba de layout del § 8.5
## (`test_sensores_no_se_solapan`).
func contenedores() -> Array[CardContainer]:
	var salida: Array[CardContainer] = []
	for por_zona: Dictionary in [_propios, _rivales]:
		for z: Palabra.Zona in por_zona.keys():
			var c: CardContainer = por_zona[z] as CardContainer
			if c != null and not salida.has(c):
				salida.append(c)
	return salida


func _process(_delta: float) -> void:
	# Un solo pase de sincronización por frame: una cascada de Letra chica puede
	# emitir veinte eventos y no hace falta reacomodar la mesa veinte veces.
	if _sucio:
		sincronizar_ya()


# ---------------------------------------------------------------------------
# Nodos de la escena
# ---------------------------------------------------------------------------


func _resolver_nodos() -> void:
	_mesa = get_node_or_null("Mesa") as CardManager
	if _mesa != null:
		_fabrica = _mesa.card_factory as FabricaDePalabra
	_capa = get_node_or_null("CapaObjetivo") as CapaObjetivo
	_dialogo = get_node_or_null("DialogoDePalabra") as DialogoDePalabra
	_firma_rival = get_node_or_null("HUD/FirmaRival") as Panel
	_etiqueta_firma_rival = get_node_or_null("HUD/FirmaRival/Texto") as Label
	_etiqueta_firma_propia = get_node_or_null("HUD/FirmaPropia/Texto") as Label
	_etiqueta_turno = get_node_or_null("HUD/Turno") as Label
	_etiqueta_mazo_rival = get_node_or_null("HUD/MazoRival") as Label
	_etiqueta_mazo_propio = get_node_or_null("HUD/MazoPropio") as Label
	_detalle = get_node_or_null("HUD/Detalle") as Label
	_mensaje = get_node_or_null("HUD/Mensaje") as Label
	_registro = get_node_or_null("HUD/Registro") as RichTextLabel
	_cartel = get_node_or_null("HUD/Cartel") as Label
	_boton_jugar = get_node_or_null("HUD/Botones/Jugar") as Button
	_boton_al_fiado = get_node_or_null("HUD/Botones/AlFiado") as Button
	_boton_empenar = get_node_or_null("HUD/Botones/Empenar") as Button
	_boton_terminar = get_node_or_null("HUD/Botones/Terminar") as Button
	if _mesa == null or _fabrica == null:
		push_error("VistaDuelo: falta el CardManager «Mesa» con la FabricaDePalabra")
	elif not _fabrica.errores().is_empty():
		for e: String in _fabrica.errores():
			push_error("VistaDuelo: la fábrica no está sana: %s" % e)
	_propios = {
		Palabra.Zona.MANO: get_node_or_null("Mesa/ManoPropia"),
		Palabra.Zona.ESTRADO: get_node_or_null("Mesa/EstradoPropio"),
		Palabra.Zona.MORA: get_node_or_null("Mesa/MoraPropia"),
		Palabra.Zona.EMPENADERO: get_node_or_null("Mesa/EmpenaderoPropio"),
		Palabra.Zona.DESCARTE: get_node_or_null("Mesa/DescartePropio"),
		Palabra.Zona.VIAJE: get_node_or_null("Mesa/ViajePropio"),
	}
	_rivales = {
		Palabra.Zona.MANO: get_node_or_null("Mesa/ManoRival"),
		Palabra.Zona.ESTRADO: get_node_or_null("Mesa/EstradoRival"),
		Palabra.Zona.MORA: get_node_or_null("Mesa/MoraRival"),
		Palabra.Zona.EMPENADERO: get_node_or_null("Mesa/EmpenaderoRival"),
		Palabra.Zona.DESCARTE: get_node_or_null("Mesa/DescarteRival"),
		Palabra.Zona.VIAJE: get_node_or_null("Mesa/ViajeRival"),
	}
	for z: Palabra.Zona in ZONAS_CON_NAIPE:
		if _propios.get(z, null) == null or _rivales.get(z, null) == null:
			push_error("VistaDuelo: falta un contenedor de %s" % TextosDePalabra.zona(z))


func _conectar_contenedores() -> void:
	var estrado_propio: EstradoDePalabra = _propios.get(Palabra.Zona.ESTRADO) as EstradoDePalabra
	var estrado_rival: EstradoDePalabra = _rivales.get(Palabra.Zona.ESTRADO) as EstradoDePalabra
	if estrado_propio != null:
		estrado_propio.validador = _puede_soltar_en_estrado.bind(true)
		estrado_propio.soltaron_naipe.connect(_al_soltar_para_jugar)
		estrado_propio.apretaron_naipe.connect(_al_apretar_en_estrado)
	if estrado_rival != null:
		estrado_rival.validador = _puede_soltar_en_estrado.bind(false)
		estrado_rival.soltaron_naipe.connect(_al_soltar_para_jugar)
		estrado_rival.apretaron_naipe.connect(_al_apretar_en_estrado)
	var mano: ManoDePalabra = _propios.get(Palabra.Zona.MANO) as ManoDePalabra
	if mano != null:
		mano.apretaron_naipe.connect(_al_apretar_en_mano)
	var empenadero: PilaDePalabra = _propios.get(Palabra.Zona.EMPENADERO) as PilaDePalabra
	if empenadero != null:
		empenadero.validador = _puede_empenar
		empenadero.soltaron_naipe.connect(_al_soltar_para_empenar)
	for por_zona: Dictionary in [_propios, _rivales]:
		for z: Palabra.Zona in [Palabra.Zona.EMPENADERO, Palabra.Zona.VIAJE, Palabra.Zona.DESCARTE]:
			var pila: PilaDePalabra = por_zona.get(z) as PilaDePalabra
			if pila != null:
				pila.apretaron_naipe.connect(_al_apretar_en_pila)


func _conectar_hud() -> void:
	if _boton_jugar != null:
		_boton_jugar.pressed.connect(func() -> void: _intentar_jugar(_seleccionado, false))
	if _boton_al_fiado != null:
		_boton_al_fiado.pressed.connect(func() -> void: _intentar_jugar(_seleccionado, true))
	if _boton_empenar != null:
		_boton_empenar.pressed.connect(func() -> void: _intentar_empenar(_seleccionado))
	if _boton_terminar != null:
		_boton_terminar.pressed.connect(_terminar_turno)


func _contenedor(lado: int, z: Palabra.Zona) -> CardContainer:
	var por_zona: Dictionary = _propios if lado == lado_jugador else _rivales
	return por_zona.get(z, null) as CardContainer


# ---------------------------------------------------------------------------
# Eventos del motor
# ---------------------------------------------------------------------------


func _al_evento(e: EventoDuelo) -> void:
	_anotar(e)
	_sucio = true
	if e.tipo == EventoDuelo.DUELO_TERMINADO:
		_modo = Modo.TERMINADO
		if _capa != null:
			_capa.cerrar()
		if _dialogo != null:
			_dialogo.cerrar()
		var ganador: int = int(e.datos.get("ganador", -1))
		var motivo: String = String(e.datos.get("motivo", ""))
		if _cartel != null:
			_cartel.text = (
				"Se cerró el duelo\n%s\n%s"
				% [
					(
						"Ganó tu Firma"
						if ganador == lado_jugador
						else "Ganó la Firma rival"
					),
					TextosDePalabra.motivo_fin(motivo),
				]
			)
			_cartel.visible = true
		sincronizar_ya()
		duelo_finalizado.emit(ganador, motivo)


func _anotar(e: EventoDuelo) -> void:
	var linea: String = TextosDePalabra.linea(e, _nombre_de_uid, lado_jugador)
	_lineas.append(linea)
	while _lineas.size() > MAX_LINEAS_REGISTRO:
		_lineas.remove_at(0)
	if _registro != null:
		_registro.text = "\n".join(_lineas)


func _nombre_de_uid(uid: int) -> String:
	if motor == null or motor.estado == null:
		return ""
	var ec: EstadoCarta = motor.estado.carta(uid)
	if ec == null or ec.def == null:
		return ""
	if ec.boca_abajo and not mostrar_todo:
		return "una carta al fiado"
	return ec.def.nombre


# ---------------------------------------------------------------------------
# Sincronización: el motor manda
# ---------------------------------------------------------------------------


func _sincronizar() -> void:
	if motor == null or motor.estado == null or _mesa == null:
		return
	var vistos: Dictionary = {}
	for lado: int in [0, 1]:
		var f: EstadoFirma = motor.estado.firma(lado)
		for z: Palabra.Zona in ZONAS_CON_NAIPE:
			var destino: CardContainer = _contenedor(lado, z)
			if destino == null:
				continue
			for ec: EstadoCarta in f.zona(z):
				vistos[ec.uid] = true
				var naipe: NaipeDePalabra = _asegurar_naipe(ec)
				if naipe == null:
					continue
				_mover(naipe, destino)
				_pintar_naipe(naipe, ec)
	for uid: int in _naipes.keys():
		if not vistos.has(uid):
			_liberar_naipe(uid)
	for lado: int in [0, 1]:
		var estrado: EstradoDePalabra = _contenedor(lado, Palabra.Zona.ESTRADO) as EstradoDePalabra
		if estrado != null:
			estrado.ordenar_por(_uids_de(motor.estado.firma(lado).estrado))
	_legales = []
	if _es_mi_turno():
		_legales = motor.jugadas_legales(lado_jugador)
	_refrescar_hud()
	_refrescar_afordancias()


func _asegurar_naipe(ec: EstadoCarta) -> NaipeDePalabra:
	if _naipes.has(ec.uid):
		return _naipes[ec.uid] as NaipeDePalabra
	if _fabrica == null:
		return null
	var naipe: NaipeDePalabra = _fabrica.crear_suelto(ec.id())
	if naipe == null:
		return null
	naipe.uid_motor = ec.uid
	if velocidad_naipes > 0:
		naipe.moving_speed = velocidad_naipes
	_naipes[ec.uid] = naipe
	return naipe


## Reparenta el naipe sin pasar por el historial del addon (§ 6.2.6) y sin pedirle
## permiso al contenedor: el destino ya lo decidió el motor.
func _mover(naipe: NaipeDePalabra, destino: CardContainer) -> void:
	if naipe.card_container == destino:
		return
	if naipe.card_container != null:
		naipe.card_container.remove_card(naipe)
	if naipe.get_parent() != destino.cards_node:
		if naipe.get_parent() != null:
			naipe.get_parent().remove_child(naipe)
		destino.cards_node.add_child(naipe)
	destino.add_card(naipe)


func _pintar_naipe(naipe: NaipeDePalabra, ec: EstadoCarta) -> void:
	naipe.uid_motor = ec.uid
	naipe.show_front = mostrar_todo or _es_visible(ec)
	naipe.pintar_numeros(
		motor.coste(ec), motor.ataque(ec), motor.aguante_restante(ec), motor.dano_de_clausula(ec)
	)


## Información oculta: la mano del rival y cualquier carta que viaja boca abajo
## (§ 4.2). Una carta boca abajo no muestra ni sus keywords (§ 2, aclaración 2).
func _es_visible(ec: EstadoCarta) -> bool:
	if ec.boca_abajo:
		return false
	if ec.zona == Palabra.Zona.MANO:
		return ec.dueno == lado_jugador
	return true


func _liberar_naipe(uid: int) -> void:
	var naipe: NaipeDePalabra = _naipes.get(uid, null) as NaipeDePalabra
	_naipes.erase(uid)
	if naipe == null or not is_instance_valid(naipe):
		return
	if _seleccionado == naipe:
		_seleccionado = null
	if naipe.card_container != null:
		naipe.card_container.remove_card(naipe)
	naipe.queue_free()


func _limpiar_naipes() -> void:
	for uid: int in _naipes.keys():
		_liberar_naipe(uid)
	_naipes = {}


func _uids_de(cartas: Array[EstadoCarta]) -> Array[int]:
	var salida: Array[int] = []
	for ec: EstadoCarta in cartas:
		salida.append(ec.uid)
	return salida


# ---------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------


func _refrescar_hud() -> void:
	if motor == null or motor.estado == null:
		return
	var estado: EstadoDuelo = motor.estado
	if _etiqueta_firma_propia != null:
		_etiqueta_firma_propia.text = "TU FIRMA — %s" % _texto_de_firma(lado_jugador)
	if _etiqueta_firma_rival != null:
		_etiqueta_firma_rival.text = "FIRMA RIVAL — %s" % _texto_de_firma(1 - lado_jugador)
	if _etiqueta_mazo_propio != null:
		_etiqueta_mazo_propio.text = "Mazo\n%d" % estado.firma(lado_jugador).mazo.size()
	if _etiqueta_mazo_rival != null:
		_etiqueta_mazo_rival.text = "Mazo\n%d" % estado.firma(1 - lado_jugador).mazo.size()
	if _etiqueta_turno != null:
		var quien: String = (
			"jugás vos" if estado.activo == lado_jugador else "juega la Firma rival"
		)
		if estado.terminado:
			quien = "duelo cerrado"
		_etiqueta_turno.text = (
			"Turno %d de %d · %s" % [estado.turno, estado.mesa.tope_turnos, quien]
		)
	var mi_turno: bool = _es_mi_turno() and _modo == Modo.LIBRE
	if _boton_terminar != null:
		_boton_terminar.disabled = not mi_turno
	if _boton_jugar != null:
		_boton_jugar.disabled = not mi_turno or _seleccionado == null
	if _boton_al_fiado != null:
		_boton_al_fiado.visible = estado.mesa.al_fiado
		_boton_al_fiado.disabled = not mi_turno or _seleccionado == null
	if _boton_empenar != null:
		_boton_empenar.visible = estado.mesa.empenar
		_boton_empenar.disabled = not mi_turno or _seleccionado == null


func _texto_de_firma(lado: int) -> String:
	var f: EstadoFirma = motor.estado.firma(lado)
	var partes: PackedStringArray = [
		"Aval %d" % f.aval,
		"Crédito %d/%d" % [f.credito, f.credito_max],
		"Mano %d" % f.mano.size(),
		"Mazo %d" % f.mazo.size(),
		"Estrado %d/%d" % [f.estrado.size(), Palabra.ESTRADO_MAX],
		"Descarte %d" % f.descarte.size(),
	]
	if motor.estado.mesa.empenar:
		partes.append("Empeñadero %d" % f.empenadero.size())
	if motor.estado.mesa.al_fiado:
		partes.append("Viaje %d" % f.viaje.size())
	if not f.mora.is_empty():
		partes.append("Mora %d" % f.mora.size())
	if f.mora_de_mazo > 0:
		partes.append("Mora de mazo %d" % f.mora_de_mazo)
	var texto: String = " · ".join(partes)
	var promesas: PackedStringArray = []
	for p: PromesaDePalabra in f.promesas_por_antiguedad():
		promesas.append(
			(
				"%s — quedan %d"
				% [TextosDePalabra.clausula(p.tipo, p.plazo_original), p.plazo_restante]
			)
		)
	if promesas.is_empty():
		return "%s\nPromesas: ninguna" % texto
	return "%s\nPromesas: %s" % [texto, " | ".join(promesas)]


func _mostrar_detalle(ec: EstadoCarta) -> void:
	if _detalle == null:
		return
	if ec == null or ec.def == null:
		_detalle.text = ""
		return
	if not mostrar_todo and not _es_visible(ec):
		_detalle.text = "Una carta boca abajo: viaja al fiado y no muestra nada."
		return
	var partes: PackedStringArray = [
		"%s — %s" % [ec.def.nombre, Palabra.nombre_tipo(ec.tipo())],
	]
	var kws: Array[String] = ec.keywords()
	if not kws.is_empty():
		partes.append(TextosDePalabra.keywords_de(kws))
	if ec.tipo() == Palabra.Tipo.CLAUSULA:
		partes.append("Coste %d · Daño %d" % [motor.coste(ec), motor.dano_de_clausula(ec)])
	else:
		partes.append(
			(
				"Coste %d · %d/%d"
				% [motor.coste(ec), motor.ataque(ec), motor.aguante_restante(ec)]
			)
		)
	if ec.interes > 0:
		partes.append("Interés devengado: %d" % ec.interes)
	if not ec.def.texto.is_empty():
		partes.append(ec.def.texto)
	if not ec.def.lore.is_empty():
		partes.append("«%s»" % ec.def.lore)
	_detalle.text = "\n".join(partes)


func _avisar(texto: String) -> void:
	if _mensaje != null:
		_mensaje.text = texto


func _refrescar_afordancias() -> void:
	var libre: bool = _modo == Modo.LIBRE and _es_mi_turno()
	for uid: int in _naipes.keys():
		var naipe: NaipeDePalabra = _naipes[uid] as NaipeDePalabra
		var ec: EstadoCarta = motor.estado.carta(uid)
		if naipe == null or ec == null:
			continue
		var motivo: String = ""
		var interactivo: bool = false
		match ec.zona:
			Palabra.Zona.MANO:
				if ec.dueno == lado_jugador:
					motivo = _motivo_de_jugar(ec)
					interactivo = libre
			Palabra.Zona.ESTRADO:
				if ec.dueno == lado_jugador:
					motivo = _motivo_de_atacar(ec)
					interactivo = libre and motivo.is_empty()
			Palabra.Zona.EMPENADERO:
				if ec.dueno != lado_jugador:
					motivo = motor.motivo_ilegal(
						JugadaDePalabra.rescatar(lado_jugador, ec.uid)
					)
					interactivo = libre and motivo.is_empty()
			Palabra.Zona.VIAJE:
				if ec.dueno != lado_jugador:
					motivo = motor.motivo_ilegal(
						JugadaDePalabra.denunciar(lado_jugador, ec.uid, ec.def.tipo)
					)
					interactivo = libre and motivo.is_empty()
		naipe.marcar_jugable(motivo.is_empty(), motivo)
		naipe.can_be_interacted_with = interactivo


## Motivo por el que la carta no se puede jugar, o "" si sí. Sale de las jugadas
## legales del motor: la vista no reimplementa el § 1.3.
func _motivo_de_jugar(ec: EstadoCarta) -> String:
	if not _jugadas_de_carta(ec.uid, false).is_empty():
		return ""
	if not _jugadas_de_carta(ec.uid, true).is_empty():
		return ""
	var motivo: String = motor.motivo_ilegal(JugadaDePalabra.jugar(ec.dueno, ec.uid))
	return motivo if not motivo.is_empty() else "no puede producir ningún efecto legal"


func _motivo_de_atacar(ec: EstadoCarta) -> String:
	var objetivos: Array[int] = motor.objetivos_de_ataque(ec)
	if objetivos.is_empty():
		return "no hay a quién pegarle"
	var ultimo: String = ""
	for uid: int in objetivos:
		var motivo: String = motor.motivo_ilegal(
			JugadaDePalabra.atacar(ec.dueno, ec.uid, uid)
		)
		if motivo.is_empty():
			return ""
		ultimo = motivo
	return ultimo


func _jugadas_de_carta(uid: int, al_fiado: bool) -> Array[JugadaDePalabra]:
	var salida: Array[JugadaDePalabra] = []
	for j: JugadaDePalabra in _legales:
		if (
			j.tipo == Palabra.TipoJugada.JUGAR
			and j.carta_uid == uid
			and j.al_fiado == al_fiado
		):
			salida.append(j)
	return salida


func _es_mi_turno() -> bool:
	if motor == null or motor.estado == null:
		return false
	return (
		not motor.estado.terminado
		and motor.estado.activo == lado_jugador
		and motor.estado.fase == Palabra.Fase.ACCIONES
	)


# ---------------------------------------------------------------------------
# Input del jugador
# ---------------------------------------------------------------------------


func _al_apretar_en_mano(naipe: Card) -> void:
	var np: NaipeDePalabra = naipe as NaipeDePalabra
	if np == null:
		return
	_seleccionado = np
	var ec: EstadoCarta = _estado_de(np)
	_mostrar_detalle(ec)
	if ec != null:
		var motivo: String = _motivo_de_jugar(ec)
		if motivo.is_empty():
			_avisar("Elegida: %s. Arrastrala al Estrado o apretá «Jugar»." % ec.def.nombre)
		else:
			_avisar("%s: %s." % [ec.def.nombre, motivo])
	_refrescar_hud()


func _al_apretar_en_estrado(naipe: Card, _contenedor_naipe: CardContainer) -> void:
	var ec: EstadoCarta = _estado_de(naipe as NaipeDePalabra)
	if ec == null:
		return
	_mostrar_detalle(ec)
	if ec.dueno != lado_jugador or not _libre():
		return
	var motivo: String = _motivo_de_atacar(ec)
	if not motivo.is_empty():
		_avisar("%s no puede atacar: %s." % [ec.def.nombre, motivo])
		return
	var objetivos: Array[Dictionary] = []
	for uid: int in motor.objetivos_de_ataque(ec):
		if not motor.motivo_ilegal(JugadaDePalabra.atacar(ec.dueno, ec.uid, uid)).is_empty():
			continue
		objetivos.append({"uid": uid, "nodo": _nodo_objetivo(uid)})
	_pedido = {"clase": "atacar", "uid": ec.uid}
	_pedir_objetivo(objetivos, "¿A quién le pega %s? (clic derecho: cancelar)" % ec.def.nombre)


func _al_apretar_en_pila(naipe: Card, contenedor: CardContainer) -> void:
	var ec: EstadoCarta = _estado_de(naipe as NaipeDePalabra)
	if ec == null:
		return
	_mostrar_detalle(ec)
	if not _libre() or ec.dueno == lado_jugador:
		return
	if contenedor == _contenedor(1 - lado_jugador, Palabra.Zona.EMPENADERO):
		_ejecutar(JugadaDePalabra.rescatar(lado_jugador, ec.uid))
		return
	if contenedor == _contenedor(1 - lado_jugador, Palabra.Zona.VIAJE):
		_pedir_denuncia(ec)


func _al_soltar_para_jugar(naipe: Card, contenedor: CardContainer) -> void:
	var np: NaipeDePalabra = naipe as NaipeDePalabra
	var ec: EstadoCarta = _estado_de(np)
	if ec == null:
		return
	var es_propio: bool = contenedor == _contenedor(lado_jugador, Palabra.Zona.ESTRADO)
	var mal_lado: String = _motivo_de_lado(ec, es_propio)
	if not mal_lado.is_empty():
		_seleccionado = np
		_mostrar_detalle(ec)
		_avisar("%s: %s." % [ec.def.nombre, mal_lado])
		_refrescar_hud()
		return
	_intentar_jugar(np, false)


func _al_soltar_para_empenar(naipe: Card, _contenedor_naipe: CardContainer) -> void:
	_intentar_empenar(naipe as NaipeDePalabra)


## Afordancia del drop. **Solo rechaza en seco lo que no es una carta de tu mano**:
## una carta tuya que no se puede jugar se acepta igual como *intención* y el
## motivo lo dice la vista al resolverla ([method _intentar_jugar]). Antes se
## rechazaba acá, y un drop que ningún contenedor acepta vuelve a la mano en
## silencio: el jugador soltaba la carta, la veía volver y no se enteraba de por
## qué (§ 1.3 pide que el rechazo diga el motivo).
func _puede_soltar_en_estrado(naipe: Card, _es_propio: bool) -> String:
	var ec: EstadoCarta = _estado_de(naipe as NaipeDePalabra)
	if ec == null or motor == null:
		return "esa carta no es de este duelo"
	if ec.dueno != lado_jugador or ec.zona != Palabra.Zona.MANO:
		return "esa carta no está en tu mano"
	return ""


## De qué lado de la mesa se suelta cada cosa: un Fiador sube a tu Estrado; una
## Cláusula, al lado al que le pega. El objetivo fino lo valida el motor después.
func _motivo_de_lado(ec: EstadoCarta, es_propio: bool) -> String:
	if ec.es_cuerpo():
		return "" if es_propio else "un Fiador sube a tu Estrado, no al del rival"
	if _clausula_apunta_al_rival(ec) == es_propio:
		return "esta Cláusula se juega del otro lado de la mesa"
	return ""


func _clausula_apunta_al_rival(ec: EstadoCarta) -> bool:
	if ec.def.objetivos.is_empty():
		return false
	return ec.def.objetivos[0] == MotorDePalabra.OBJ_ENEMIGO_O_FIRMA


## Mismo criterio que el Estrado: el Empeñadero acepta cualquier carta de tu mano
## y el motivo del rechazo lo muestra [method _intentar_empenar].
func _puede_empenar(naipe: Card) -> String:
	var ec: EstadoCarta = _estado_de(naipe as NaipeDePalabra)
	if ec == null or motor == null:
		return "esa carta no es de este duelo"
	if ec.dueno != lado_jugador or ec.zona != Palabra.Zona.MANO:
		return "esa carta no está en tu mano"
	return ""


func _intentar_jugar(naipe: NaipeDePalabra, al_fiado: bool) -> void:
	if naipe == null or not _libre():
		return
	var ec: EstadoCarta = _estado_de(naipe)
	if ec == null:
		return
	_seleccionado = naipe
	_mostrar_detalle(ec)
	var candidatas: Array[JugadaDePalabra] = _jugadas_de_carta(ec.uid, al_fiado)
	if candidatas.is_empty():
		var motivo: String = motor.motivo_ilegal(_jugada_base(ec, al_fiado))
		if motivo.is_empty():
			motivo = "no hay jugada legal"
		_avisar("No se puede jugar %s: %s." % [ec.def.nombre, motivo])
		return
	var objetivos: Array[int] = _objetivos_distintos(candidatas)
	if objetivos.size() > 1:
		var lista: Array[Dictionary] = []
		for uid: int in objetivos:
			lista.append({"uid": uid, "nodo": _nodo_objetivo(uid)})
		_pedido = {"clase": "jugar", "uid": ec.uid, "al_fiado": al_fiado}
		_pedir_objetivo(lista, "¿Sobre qué juega %s? (clic derecho: cancelar)" % ec.def.nombre)
		return
	_seguir_con_objetivo(ec.uid, al_fiado, objetivos[0] if not objetivos.is_empty() else -1)


func _intentar_empenar(naipe: NaipeDePalabra) -> void:
	if naipe == null or not _libre():
		return
	var ec: EstadoCarta = _estado_de(naipe)
	if ec == null:
		return
	_seleccionado = naipe
	_mostrar_detalle(ec)
	_ejecutar(JugadaDePalabra.empenar(lado_jugador, ec.uid))


func _terminar_turno() -> void:
	if not _libre():
		return
	_ejecutar(JugadaDePalabra.pasar(lado_jugador))


## Segunda mitad de la jugada: con el objetivo ya elegido, se ofrece la Promesa.
func _seguir_con_objetivo(uid: int, al_fiado: bool, objetivo: int) -> void:
	var ec: EstadoCarta = motor.estado.carta(uid)
	if ec == null:
		return
	var candidatas: Array[JugadaDePalabra] = []
	for j: JugadaDePalabra in _jugadas_de_carta(uid, al_fiado):
		if j.objetivo_uid == objetivo:
			candidatas.append(j)
	if candidatas.is_empty():
		_avisar("Ese objetivo ya no es legal.")
		return
	var opciones: Array[Dictionary] = _opciones_de_promesa(ec, candidatas)
	if opciones.size() <= 1 or _dialogo == null:
		_ejecutar(candidatas[0])
		return
	_pedido = {"clase": "promesa", "uid": uid, "al_fiado": al_fiado, "objetivo": objetivo}
	_modo = Modo.DIALOGO
	_apagar_naipes()
	_dialogo.preguntar(
		"¿Le agregás una Promesa a %s?" % ec.def.nombre,
		(
			"Una Promesa es una cláusula con plazo: si la cumplís, cobrás el bonus; "
			+ "si la rompés, nace un Quebranto que le pega a tu Firma."
		),
		opciones
	)


## Una opción por variante de Promesa que el motor ofrece, más «sin Promesa».
func _opciones_de_promesa(
	ec: EstadoCarta, candidatas: Array[JugadaDePalabra]
) -> Array[Dictionary]:
	var opciones: Array[Dictionary] = []
	var propias: Array[String] = []
	for oferta: Dictionary in ec.def.promesas:
		propias.append(String(oferta.get("tipo", "")))
	for j: JugadaDePalabra in candidatas:
		if j.promesa_tipo.is_empty():
			opciones.append({"texto": "Sin Promesa", "valor": {"tipo": "", "plazo": 0}})
	for j: JugadaDePalabra in candidatas:
		if j.promesa_tipo.is_empty():
			continue
		var etiqueta: String = TextosDePalabra.clausula(j.promesa_tipo, j.promesa_plazo)
		if not etiqueta.contains(str(j.promesa_plazo)):
			etiqueta = "%s (plazo %d)" % [etiqueta, j.promesa_plazo]
		if propias.has(j.promesa_tipo):
			etiqueta = "★ %s" % etiqueta
		opciones.append(
			{
				"texto": etiqueta,
				"ayuda": "La estrella es la cláusula que ofrece la propia carta.",
				"valor": {"tipo": j.promesa_tipo, "plazo": j.promesa_plazo},
			}
		)
	return opciones


func _pedir_denuncia(ec: EstadoCarta) -> void:
	var opciones: Array[Dictionary] = []
	for t: Palabra.Tipo in [Palabra.Tipo.FIADOR, Palabra.Tipo.SOPORTE, Palabra.Tipo.CLAUSULA]:
		var j: JugadaDePalabra = JugadaDePalabra.denunciar(lado_jugador, ec.uid, t)
		if not motor.motivo_ilegal(j).is_empty():
			continue
		opciones.append({"texto": Palabra.nombre_tipo(t), "valor": {"tipo_declarado": int(t)}})
	if opciones.is_empty() or _dialogo == null:
		_avisar("No se puede denunciar esa carta ahora.")
		return
	_pedido = {"clase": "denuncia", "uid": ec.uid}
	_modo = Modo.DIALOGO
	_apagar_naipes()
	_dialogo.preguntar(
		"¿De qué la denunciás?",
		(
			"Si acertás el tipo, la carta se rompe; si fallás, el viaje se acorta "
			+ "un turno. Se puede denunciar una vez por turno."
		),
		opciones
	)


# ---------------------------------------------------------------------------
# Capa de objetivos y diálogo
# ---------------------------------------------------------------------------


func _pedir_objetivo(objetivos: Array[Dictionary], texto: String) -> void:
	if objetivos.is_empty():
		_avisar("No hay objetivo legal.")
		_pedido = {}
		return
	if _capa == null:
		# Sin capa no se puede elegir: se resuelve con el primero legal antes que
		# dejar al jugador colgado.
		_al_elegir_objetivo(int(objetivos[0].get("uid", -1)))
		return
	_modo = Modo.OBJETIVO
	_apagar_naipes()
	# El texto largo lo pone la capa, centrado sobre la mesa; acá va el recordatorio.
	_avisar("Elegí un objetivo.")
	_capa.pedir(objetivos, texto)


## Todas las cartas se apagan mientras hay una decisión abierta (§ 6.2.2).
##
## Antes de apagarlas hay que soltar la que esté agarrada: el camino de atacar se
## abre **apretando** un Fiador, o sea con el botón del mouse todavía apretado, y
## una carta apagada ya no escucha el «mouse up» (queda pegada al cursor).
func _apagar_naipes() -> void:
	for uid: int in _naipes.keys():
		var naipe: NaipeDePalabra = _naipes[uid] as NaipeDePalabra
		if naipe != null:
			naipe.soltar_ya()
			naipe.can_be_interacted_with = false


## Nodo clicable de un objetivo: el naipe, o el panel de la Firma rival si el
## objetivo es la cara (uid -1).
func _nodo_objetivo(uid: int) -> Control:
	if uid < 0:
		return _firma_rival
	return naipe_de(uid)


func _al_elegir_objetivo(uid: int) -> void:
	var pedido: Dictionary = _pedido
	_pedido = {}
	_modo = Modo.LIBRE
	match String(pedido.get("clase", "")):
		"atacar":
			_ejecutar(JugadaDePalabra.atacar(lado_jugador, int(pedido.get("uid", -1)), uid))
		"jugar":
			_seguir_con_objetivo(
				int(pedido.get("uid", -1)), bool(pedido.get("al_fiado", false)), uid
			)
		_:
			_sucio = true


func _al_cancelar_objetivo() -> void:
	_pedido = {}
	_modo = Modo.LIBRE
	_avisar("Cancelado.")
	_sucio = true


func _al_elegir_del_dialogo(valor: Variant) -> void:
	var pedido: Dictionary = _pedido
	_pedido = {}
	_modo = Modo.LIBRE
	if not (valor is Dictionary):
		_sucio = true
		return
	var datos: Dictionary = valor
	match String(pedido.get("clase", "")):
		"promesa":
			var j: JugadaDePalabra = JugadaDePalabra.jugar(
				lado_jugador,
				int(pedido.get("uid", -1)),
				int(pedido.get("objetivo", -1)),
				String(datos.get("tipo", "")),
				int(datos.get("plazo", 0))
			)
			j.al_fiado = bool(pedido.get("al_fiado", false))
			_ejecutar(j)
		"denuncia":
			var declarado: Palabra.Tipo = int(datos.get("tipo_declarado", 0)) as Palabra.Tipo
			_ejecutar(
				JugadaDePalabra.denunciar(lado_jugador, int(pedido.get("uid", -1)), declarado)
			)
		_:
			_sucio = true


func _al_cancelar_dialogo() -> void:
	_pedido = {}
	_modo = Modo.LIBRE
	_avisar("Sin Promesa firmada: la jugada quedó sin hacer.")
	_sucio = true


# ---------------------------------------------------------------------------
# Ejecución
# ---------------------------------------------------------------------------


## Único punto por el que la vista le pide algo al motor.
func _ejecutar(j: JugadaDePalabra) -> bool:
	if motor == null:
		return false
	var motivo: String = motor.motivo_ilegal(j)
	if not motivo.is_empty():
		_avisar("No se puede: %s." % motivo)
		_sucio = true
		return false
	_seleccionado = null
	# El aviso es del pedido anterior: si la jugada salió, ya no aplica y quedaba
	# colgado en pantalla turnos enteros («Elegí un objetivo» después de elegirlo).
	_avisar("")
	var salio: bool = motor.ejecutar(j)
	_sucio = true
	return salio


func _libre() -> bool:
	return _modo == Modo.LIBRE and _es_mi_turno()


func _estado_de(naipe: NaipeDePalabra) -> EstadoCarta:
	if naipe == null or motor == null or motor.estado == null:
		return null
	return motor.estado.carta(naipe.uid_motor)


func _jugada_base(ec: EstadoCarta, al_fiado: bool) -> JugadaDePalabra:
	var j: JugadaDePalabra = JugadaDePalabra.jugar(lado_jugador, ec.uid)
	j.al_fiado = al_fiado
	return j


func _objetivos_distintos(candidatas: Array[JugadaDePalabra]) -> Array[int]:
	var salida: Array[int] = []
	for j: JugadaDePalabra in candidatas:
		if not salida.has(j.objetivo_uid):
			salida.append(j.objetivo_uid)
	return salida
