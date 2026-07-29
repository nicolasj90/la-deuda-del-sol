# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

## Smoke headless del vocabulario de puzzles.
##
## Ejercita por código la lógica de cada prop (empuje sostenido, presión,
## conteo de fuentes, llavero, rotación y haz) e imprime PASS/FAIL por chequeo.
## Sale con código 0 si todo pasa, 1 si algo falla.
##
## Correr:
## [codeblock]
## ~/tools/godot/Godot_v4.7-stable_linux.x86_64 --headless --path . \
##     res://scenes/dev/puzzles/smoke_puzzles.tscn
## [/codeblock]

const BLOQUE := preload(
	"res://scenes/game_elements/props/puzzles/bloque_empujable/bloque_empujable.tscn"
)
const BLOQUE_MORA := preload(
	"res://scenes/game_elements/props/puzzles/bloque_en_mora/bloque_en_mora.tscn"
)
const PLACA := preload("res://scenes/game_elements/props/puzzles/placa_presion/placa_presion.tscn")
const PALANCA := preload("res://scenes/game_elements/props/puzzles/palanca/palanca.tscn")
const PUERTA_SELLADA := preload(
	"res://scenes/game_elements/props/puzzles/puerta_sellada/puerta_sellada.tscn"
)
const LLAVE := preload("res://scenes/game_elements/props/puzzles/llave/llave.tscn")
const PUERTA_CERRADURA := preload(
	"res://scenes/game_elements/props/puzzles/puerta_con_cerradura/puerta_con_cerradura.tscn"
)
const ESTATUA := preload(
	"res://scenes/game_elements/props/puzzles/estatua_testigo/estatua_testigo.tscn"
)
const RECEPTOR := preload(
	"res://scenes/game_elements/props/puzzles/receptor_de_fe/receptor_de_fe.tscn"
)

var _total: int = 0
var _fallos: int = 0


func _ready() -> void:
	print("== SMOKE vocabulario de puzzles ==")
	_armar_perro_guardian()
	await _t1_bloque_grilla_y_bloqueo()
	await _t2_bloque_empuje_sostenido()
	await _t3_placa_presion()
	await _t4_palanca()
	await _t5_puerta_sellada()
	await _t6_llave_y_cerradura()
	await _t7_estatua_y_receptor()
	await _t8_bloque_en_mora()
	await _t9_escenas_de_prueba()

	print("== RESUMEN: %d chequeos, %d fallos ==" % [_total, _fallos])
	if _fallos == 0:
		print("SMOKE OK")
	else:
		print("SMOKE FALLÓ")
	get_tree().quit(1 if _fallos > 0 else 0)


# --- Infraestructura -------------------------------------------------------


## Red de seguridad: si algún await se cuelga, el smoke igual termina en FAIL.
func _armar_perro_guardian(segundos: float = 90.0) -> void:
	var reloj := get_tree().create_timer(segundos, true, false, true)
	reloj.timeout.connect(
		func() -> void:
			print("FAIL - el smoke se colgó tras %.0f s" % segundos)
			print("SMOKE FALLÓ")
			get_tree().quit(1)
	)


func _check(nombre: String, ok: bool, detalle: String = "") -> void:
	_total += 1
	if ok:
		print("PASS - %s" % nombre)
		return
	_fallos += 1
	if detalle.is_empty():
		print("FAIL - %s" % nombre)
	else:
		print("FAIL - %s (%s)" % [nombre, detalle])


func _fisica(cuadros: int = 1) -> void:
	for _i in cuadros:
		await get_tree().physics_frame


func _esperar_hasta(condicion: Callable, segundos: float = 2.0) -> bool:
	var limite := int(segundos * 60.0) + 2
	for _i in limite:
		if condicion.call():
			return true
		await get_tree().physics_frame
	return condicion.call()


func _caja(nombre: String) -> Node2D:
	var caja := Node2D.new()
	caja.name = nombre
	add_child(caja)
	return caja


func _limpiar(caja: Node2D) -> void:
	caja.queue_free()
	await _fisica(2)


func _pared(en: Vector2, tamano: Vector2 = Vector2(64, 64)) -> StaticBody2D:
	var pared := StaticBody2D.new()
	pared.name = "Pared"
	pared.collision_layer = 16
	pared.collision_mask = 0
	pared.position = en
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = tamano
	forma.shape = rect
	pared.add_child(forma)
	return pared


# --- T1: grilla, snap y bloqueo -------------------------------------------


func _t1_bloque_grilla_y_bloqueo() -> void:
	print("-- T1 bloque_empujable: grilla, snap y bloqueo")
	var caja := _caja("T1")
	caja.add_child(_pared(Vector2(64, 0)))

	var vecino: BloqueEmpujable = BLOQUE.instantiate()
	vecino.position = Vector2(0, -64)
	caja.add_child(vecino)

	var bloque: BloqueEmpujable = BLOQUE.instantiate()
	bloque.position = Vector2.ZERO
	caja.add_child(bloque)
	await _fisica(4)

	_check(
		"T1 celda inicial es 0,0",
		bloque.celda_actual() == Vector2i.ZERO,
		str(bloque.celda_actual())
	)
	_check("T1 la pared bloquea a la derecha", not bloque.puede_moverse(Vector2i.RIGHT))
	_check("T1 otro bloque bloquea arriba", not bloque.puede_moverse(Vector2i.UP))
	_check("T1 la izquierda está libre", bloque.puede_moverse(Vector2i.LEFT))
	_check("T1 abajo está libre", bloque.puede_moverse(Vector2i.DOWN))

	var bloqueos: Array[Vector2i] = []
	bloque.empuje_bloqueado.connect(func(d: Vector2i) -> void: bloqueos.append(d))
	_check("T1 empujar contra la pared falla", not bloque.intentar_empujar(Vector2i.RIGHT))
	_check(
		"T1 emitió empuje_bloqueado",
		bloqueos.size() == 1 and bloqueos[0] == Vector2i.RIGHT,
		str(bloqueos)
	)

	var movidas: Array = []
	bloque.moved.connect(
		func(desde: Vector2, hacia: Vector2) -> void: movidas.append([desde, hacia])
	)
	_check("T1 empujar a celda libre arranca", bloque.intentar_empujar(Vector2i.LEFT))
	await _esperar_hasta(func() -> bool: return movidas.size() >= 1)
	_check("T1 emitió moved una vez", movidas.size() == 1, str(movidas.size()))
	_check(
		"T1 snap exacto a la celda vecina",
		bloque.global_position.is_equal_approx(Vector2(-64, 0)),
		str(bloque.global_position)
	)
	_check("T1 celda ahora -1,0", bloque.celda_actual() == Vector2i(-1, 0), str(bloque.celda_actual()))
	if movidas.size() >= 1:
		var m: Array = movidas[0]
		_check(
			"T1 moved trae desde/hacia",
			(m[0] as Vector2).is_equal_approx(Vector2.ZERO)
			and (m[1] as Vector2).is_equal_approx(Vector2(-64, 0)),
			str(m)
		)

	await _limpiar(caja)


# --- T2: empuje sostenido -------------------------------------------------


func _t2_bloque_empuje_sostenido() -> void:
	print("-- T2 bloque_empujable: empuje sostenido del jugador")
	var caja := _caja("T2")

	var bloque: BloqueEmpujable = BLOQUE.instantiate()
	bloque.position = Vector2.ZERO
	bloque.retardo_empuje = 0.15
	bloque.duracion_deslizamiento = 0.08
	caja.add_child(bloque)

	var jugador := JugadorFalso.crear(Vector2(-53, 0))
	caja.add_child(jugador)
	await _fisica(4)

	_check("T2 el bloque detecta al empujador", bloque.cuerpos_en_contacto() == 1)
	_check("T2 sin intención no hay empuje", bloque.direccion_de_empuje_actual() == Vector2i.ZERO)

	# Alejarse no empuja.
	jugador.input_vector = Vector2(-200, 0)
	await _fisica(3)
	_check("T2 alejarse no cuenta como empuje", bloque.direccion_de_empuje_actual() == Vector2i.ZERO)

	# Caminar en perpendicular no empuja.
	jugador.input_vector = Vector2(0, 200)
	await _fisica(3)
	_check(
		"T2 caminar en perpendicular no empuja",
		bloque.direccion_de_empuje_actual() == Vector2i.ZERO
	)

	# Apoyarse contra la cara izquierda sí empuja, hacia la derecha.
	var movidas: Array[int] = [0]
	bloque.moved.connect(func(_d: Vector2, _h: Vector2) -> void: movidas[0] += 1)
	jugador.input_vector = Vector2(200, 0)
	await _fisica(2)
	_check("T2 apoyarse define la dirección", bloque.direccion_de_empuje_actual() == Vector2i.RIGHT)
	await _esperar_hasta(func() -> bool: return movidas[0] >= 1, 3.0)
	jugador.input_vector = Vector2.ZERO
	_check("T2 el empuje sostenido lo desliza", movidas[0] >= 1, str(movidas))
	_check(
		"T2 se deslizó exactamente una celda",
		bloque.global_position.is_equal_approx(Vector2(64, 0)),
		str(bloque.global_position)
	)

	await _limpiar(caja)


# --- T3: placa de presión -------------------------------------------------


func _t3_placa_presion() -> void:
	print("-- T3 placa_presion: acepta_jugador / acepta_bloque")
	var caja := _caja("T3")

	var placa: PlacaPresion = PLACA.instantiate()
	placa.position = Vector2.ZERO
	caja.add_child(placa)

	var solo_bloques: PlacaPresion = PLACA.instantiate()
	solo_bloques.position = Vector2(400, 0)
	solo_bloques.acepta_jugador = false
	caja.add_child(solo_bloques)

	var presionadas: Array[int] = [0]
	var liberadas: Array[int] = [0]
	placa.pressed.connect(func() -> void: presionadas[0] += 1)
	placa.released.connect(func() -> void: liberadas[0] += 1)
	var presionadas_solo_bloques: Array[int] = [0]
	var liberadas_solo_bloques: Array[int] = [0]
	solo_bloques.pressed.connect(func() -> void: presionadas_solo_bloques[0] += 1)
	solo_bloques.released.connect(func() -> void: liberadas_solo_bloques[0] += 1)

	var jugador := JugadorFalso.crear(Vector2(0, -300))
	caja.add_child(jugador)
	await _fisica(3)
	_check("T3 placa libre al inicio", not placa.occupied and presionadas[0] == 0)

	jugador.global_position = Vector2.ZERO
	await _esperar_hasta(func() -> bool: return placa.occupied)
	_check("T3 el jugador la hunde", placa.occupied and presionadas[0] == 1, str(presionadas))

	jugador.global_position = Vector2(0, -300)
	await _esperar_hasta(func() -> bool: return not placa.occupied)
	_check("T3 al salir se libera", not placa.occupied and liberadas[0] == 1, str(liberadas))

	jugador.global_position = Vector2(400, 0)
	await _fisica(6)
	_check(
		"T3 acepta_jugador=false ignora al jugador",
		not solo_bloques.occupied and presionadas_solo_bloques[0] == 0
	)
	jugador.global_position = Vector2(0, -300)
	await _fisica(3)

	# Un bloque empujado encima sí la hunde.
	var bloque: BloqueEmpujable = BLOQUE.instantiate()
	bloque.position = Vector2(400, -64)
	bloque.duracion_deslizamiento = 0.08
	caja.add_child(bloque)
	await _fisica(3)
	_check("T3 la placa de bloques sigue libre", not solo_bloques.occupied)

	bloque.intentar_empujar(Vector2i.DOWN)
	await _esperar_hasta(func() -> bool: return solo_bloques.occupied, 3.0)
	_check(
		"T3 el bloque encima la hunde",
		solo_bloques.occupied and presionadas_solo_bloques[0] == 1,
		"occupied=%s presionadas=%d" % [solo_bloques.occupied, presionadas_solo_bloques[0]]
	)

	await _esperar_hasta(func() -> bool: return not bloque.deslizandose, 3.0)
	_check("T3 el bloque salió del empuje anterior", not bloque.deslizandose)
	_check("T3 el bloque se puede volver a empujar", bloque.intentar_empujar(Vector2i.DOWN))
	await _esperar_hasta(func() -> bool: return not solo_bloques.occupied, 3.0)
	_check(
		"T3 el bloque al salir la libera",
		not solo_bloques.occupied and liberadas_solo_bloques[0] == 1,
		str(liberadas_solo_bloques)
	)

	await _limpiar(caja)


# --- T4: palanca ----------------------------------------------------------


func _t4_palanca() -> void:
	print("-- T4 palanca: interacción y un_solo_uso")
	var caja := _caja("T4")

	var palanca: Palanca = PALANCA.instantiate()
	caja.add_child(palanca)
	var estados: Array[bool] = []
	palanca.toggled.connect(func(on: bool) -> void: estados.append(on))
	await _fisica(3)

	_check("T4 arranca apagada", not palanca.on)
	palanca.interact_area.start_interaction(null, false)
	await _fisica(3)
	_check(
		"T4 la interacción la enciende",
		palanca.on and estados.size() == 1 and estados[0],
		str(estados)
	)

	palanca.interact_area.start_interaction(null, false)
	await _fisica(3)
	_check(
		"T4 la segunda interacción la apaga",
		not palanca.on and estados.size() == 2 and estados[0] and not estados[1],
		str(estados)
	)

	var sellada: Palanca = PALANCA.instantiate()
	sellada.position = Vector2(200, 0)
	sellada.un_solo_uso = true
	caja.add_child(sellada)
	await _fisica(2)
	_check("T4 un_solo_uso: primer accionar sirve", sellada.alternar())
	_check("T4 un_solo_uso: no vuelve atrás", not sellada.alternar() and sellada.on)

	await _limpiar(caja)


# --- T5: puerta sellada ---------------------------------------------------


func _t5_puerta_sellada() -> void:
	print("-- T5 puerta_sellada: contador de fuentes (requiere_n)")
	var caja := _caja("T5")

	var placa_a: PlacaPresion = PLACA.instantiate()
	placa_a.position = Vector2(-300, 0)
	caja.add_child(placa_a)
	var placa_b: PlacaPresion = PLACA.instantiate()
	placa_b.position = Vector2(300, 0)
	caja.add_child(placa_b)
	var palanca: Palanca = PALANCA.instantiate()
	palanca.position = Vector2(0, 300)
	caja.add_child(palanca)

	var puerta: PuertaSellada = PUERTA_SELLADA.instantiate()
	puerta.requiere_n = 3
	var fuentes: Array[Node] = [placa_a, placa_b, palanca]
	puerta.fuentes = fuentes
	caja.add_child(puerta)

	var aperturas: Array[int] = [0]
	var cierres: Array[int] = [0]
	puerta.opened.connect(func() -> void: aperturas[0] += 1)
	puerta.closed.connect(func() -> void: cierres[0] += 1)
	await _fisica(4)

	_check("T5 cerrada al inicio", not puerta.abierta and puerta.activas() == 0, str(puerta.activas()))
	var colisionador := puerta.get_node(^"%ColisionadorCerrada") as StaticBody2D
	_check(
		"T5 cerrada: colisiona como pared",
		colisionador.get_collision_layer_value(Enums.CollisionLayers.WALLS)
	)

	var jugador_a := JugadorFalso.crear(Vector2(-300, 0))
	caja.add_child(jugador_a)
	await _esperar_hasta(func() -> bool: return puerta.activas() == 1)
	_check("T5 una fuente no alcanza", not puerta.abierta and puerta.activas() == 1)

	var jugador_b := JugadorFalso.crear(Vector2(300, 0))
	caja.add_child(jugador_b)
	await _esperar_hasta(func() -> bool: return puerta.activas() == 2)
	_check("T5 dos fuentes tampoco", not puerta.abierta and puerta.activas() == 2)

	palanca.alternar()
	await _fisica(3)
	_check("T5 con las tres fuentes se abre", puerta.abierta and aperturas[0] == 1, str(aperturas))
	_check(
		"T5 abierta: deja de colisionar",
		not colisionador.get_collision_layer_value(Enums.CollisionLayers.WALLS)
	)

	jugador_a.global_position = Vector2(0, -600)
	await _esperar_hasta(func() -> bool: return not puerta.abierta, 3.0)
	_check("T5 al soltar una fuente se cierra", not puerta.abierta and cierres[0] == 1, str(cierres))

	# La misma fuente gritando dos veces no cuenta doble.
	puerta.set_activacion(placa_b, true)
	puerta.set_activacion(placa_b, true)
	_check("T5 el contador es por fuente distinta", puerta.activas() == 2, str(puerta.activas()))

	await _limpiar(caja)


# --- T6: llave y cerradura ------------------------------------------------


func _t6_llave_y_cerradura() -> void:
	print("-- T6 llave_y_cerradura: llavero por grupo local")
	var caja := _caja("T6")

	var puerta: PuertaConCerradura = PUERTA_CERRADURA.instantiate()
	puerta.tipo_llave = &"lacre"
	caja.add_child(puerta)
	var fallidos: Array[int] = [0]
	puerta.intento_fallido.connect(func() -> void: fallidos[0] += 1)

	var llave: Llave = LLAVE.instantiate()
	llave.tipo = &"lacre"
	llave.position = Vector2(300, 0)
	caja.add_child(llave)
	await _fisica(3)

	_check("T6 sin llave no abre", not puerta.intentar_abrir() and not puerta.abierta)
	_check("T6 emitió intento_fallido", fallidos[0] == 1, str(fallidos))
	_check("T6 la llave no está en el llavero", not puerta.tiene_llave())

	var jugador := JugadorFalso.crear(Vector2(300, 0))
	caja.add_child(jugador)
	await _esperar_hasta(func() -> bool: return llave.recolectada)
	_check(
		"T6 la llave se recoge al tocarla",
		llave.recolectada and llave.is_in_group(Llave.GRUPO_RECOGIDAS)
	)
	_check("T6 la cerradura la ve en el llavero", puerta.tiene_llave())

	_check("T6 con llave abre", puerta.intentar_abrir() and puerta.abierta)
	_check(
		"T6 la llave se consume",
		llave.consumida and not llave.is_in_group(Llave.GRUPO_RECOGIDAS)
	)

	var otra_puerta: PuertaConCerradura = PUERTA_CERRADURA.instantiate()
	otra_puerta.position = Vector2(0, 200)
	otra_puerta.tipo_llave = &"lacre"
	caja.add_child(otra_puerta)
	await _fisica(2)
	_check("T6 la llave gastada ya no sirve", not otra_puerta.intentar_abrir())

	var llave_bronce: Llave = LLAVE.instantiate()
	llave_bronce.tipo = &"bronce"
	llave_bronce.position = Vector2(0, 400)
	caja.add_child(llave_bronce)
	await _fisica(2)
	llave_bronce.recoger()
	_check("T6 una llave de otro tipo no abre", not otra_puerta.intentar_abrir())

	var puerta_bronce: PuertaConCerradura = PUERTA_CERRADURA.instantiate()
	puerta_bronce.position = Vector2(0, 600)
	puerta_bronce.tipo_llave = &"bronce"
	puerta_bronce.consume_llave = false
	caja.add_child(puerta_bronce)
	await _fisica(2)
	_check("T6 la llave del tipo correcto abre", puerta_bronce.intentar_abrir())
	_check("T6 consume_llave=false no la gasta", not llave_bronce.consumida)

	await _limpiar(caja)


# --- T7: estatua testigo y receptor de fe ---------------------------------


func _t7_estatua_y_receptor() -> void:
	print("-- T7 estatua_testigo + receptor_de_fe: haz de lacre")
	var caja := _caja("T7")

	var receptor: ReceptorDeFe = RECEPTOR.instantiate()
	receptor.position = Vector2(256, -24)
	caja.add_child(receptor)

	var estatua: EstatuaTestigo = ESTATUA.instantiate()
	estatua.direccion = EstatuaTestigo.Direccion.ABAJO
	estatua.alcance = 512.0
	caja.add_child(estatua)
	await _fisica(4)

	var llegadas: Array[Node] = []
	var perdidos: Array[Node] = []
	estatua.haz_llega_a.connect(func(o: Node) -> void: llegadas.append(o))
	estatua.haz_perdido.connect(func(o: Node) -> void: perdidos.append(o))
	var rotaciones: Array[int] = []
	estatua.rotada.connect(func(d: int) -> void: rotaciones.append(d))

	_check(
		"T7 mirando a otro lado el haz no llega",
		estatua.objetivo_actual == null and not receptor.iluminado
	)

	estatua.rotar(-1)
	await _fisica(3)
	_check(
		"T7 rotar cambia la dirección",
		estatua.direccion == EstatuaTestigo.Direccion.DERECHA and rotaciones.size() == 1,
		str(estatua.direccion)
	)
	_check(
		"T7 el haz alcanza el receptor",
		estatua.objetivo_actual == receptor and receptor.iluminado and llegadas.size() == 1,
		"objetivo=%s iluminado=%s" % [estatua.objetivo_actual, receptor.iluminado]
	)
	_check("T7 el receptor cuenta un haz", receptor.cantidad_haces() == 1)

	# Un bloque en medio corta la línea de vista.
	var bloque: BloqueEmpujable = BLOQUE.instantiate()
	bloque.position = Vector2(128, -24)
	caja.add_child(bloque)
	await _fisica(4)
	_check(
		"T7 un bloque corta el haz",
		estatua.objetivo_actual == null and not receptor.iluminado and perdidos.size() == 1,
		"objetivo=%s iluminado=%s" % [estatua.objetivo_actual, receptor.iluminado]
	)

	bloque.get_parent().remove_child(bloque)
	bloque.queue_free()
	await _fisica(4)
	_check(
		"T7 al despejar, el haz vuelve",
		estatua.objetivo_actual == receptor and receptor.iluminado and llegadas.size() == 2
	)

	# Cuatro rotaciones vuelven al punto de partida.
	var inicial := estatua.direccion
	estatua.rotar(4)
	await _fisica(2)
	_check("T7 cuatro rotaciones dan la vuelta", estatua.direccion == inicial)

	var vistas: Dictionary = {}
	for _i in 4:
		vistas[estatua.vector_direccion()] = true
		estatua.rotar(1)
		await _fisica(1)
	_check("T7 las cuatro direcciones son distintas", vistas.size() == 4, str(vistas.keys()))

	estatua.activa = false
	await _fisica(3)
	_check("T7 estatua inactiva no proyecta", estatua.objetivo_actual == null)

	await _limpiar(caja)


# --- T8: bloque en mora ---------------------------------------------------


func _t8_bloque_en_mora() -> void:
	print("-- T8 bloque_en_mora: inamovible hasta cumplir la tarea")
	var caja := _caja("T8")

	var palanca: Palanca = PALANCA.instantiate()
	palanca.position = Vector2(-300, 0)
	caja.add_child(palanca)

	var bloque: BloqueEnMora = BLOQUE_MORA.instantiate()
	bloque.position = Vector2.ZERO
	bloque.tarea = "regar la parra"
	bloque.duracion_deslizamiento = 0.08
	bloque.disparador = palanca
	bloque.senal_disparador = &"toggled"
	caja.add_child(bloque)
	await _fisica(4)

	_check("T8 nace en mora", bloque.en_mora)
	_check("T8 en mora no se puede mover", not bloque.puede_moverse(Vector2i.RIGHT))
	_check("T8 en mora el empuje falla", not bloque.intentar_empujar(Vector2i.RIGHT))
	_check(
		"T8 en mora no se movió",
		bloque.global_position.is_equal_approx(Vector2.ZERO),
		str(bloque.global_position)
	)

	var alivios: Array[int] = [0]
	bloque.aliviado.connect(func() -> void: alivios[0] += 1)

	palanca.alternar()
	await _fisica(3)
	_check("T8 la tarea cumplida lo alivia", not bloque.en_mora and alivios[0] == 1, str(alivios))

	_check("T8 aliviado se puede mover", bloque.puede_moverse(Vector2i.RIGHT))
	var movidas: Array[int] = [0]
	bloque.moved.connect(func(_d: Vector2, _h: Vector2) -> void: movidas[0] += 1)
	_check("T8 aliviado acepta el empuje", bloque.intentar_empujar(Vector2i.RIGHT))
	await _esperar_hasta(func() -> bool: return movidas[0] >= 1, 3.0)
	_check(
		"T8 se deslizó una celda con snap",
		bloque.global_position.is_equal_approx(Vector2(64, 0)),
		str(bloque.global_position)
	)

	bloque.poner_en_mora()
	_check(
		"T8 se puede volver a poner en mora",
		bloque.en_mora and not bloque.puede_moverse(Vector2i.RIGHT)
	)
	bloque.aliviar()
	_check("T8 aliviar sobre un bloque en mora reemite una vez", alivios[0] == 2, str(alivios))

	await _limpiar(caja)


# --- T9: las escenas de prueba cargan y quedan cableadas -------------------


func _t9_escenas_de_prueba() -> void:
	print("-- T9 escenas de prueba de scenes/dev/puzzles/")
	var esperado: Dictionary = {
		"prueba_bloque_empujable.tscn": 3,
		"prueba_placa_presion.tscn": 4,
		"prueba_palanca.tscn": 2,
		"prueba_puerta_sellada.tscn": 6,
		"prueba_llave_y_cerradura.tscn": 5,
		"prueba_estatua_testigo.tscn": 6,
		"prueba_bloque_en_mora.tscn": 7,
	}
	for archivo: String in esperado:
		var ruta := "res://scenes/dev/puzzles/" + archivo
		var escena := load(ruta) as PackedScene
		_check("T9 %s carga" % archivo, escena != null)
		if escena == null:
			continue
		var raiz := escena.instantiate()
		var caja := _caja("T9_" + archivo.get_basename())
		caja.add_child(raiz)
		await _fisica(4)
		var props := 0
		for hijo: Node in raiz.get_children():
			if (
				hijo is BloqueEmpujable
				or hijo is PlacaPresion
				or hijo is Palanca
				or hijo is PuertaSellada
				or hijo is PuertaConCerradura
				or hijo is Llave
				or hijo is EstatuaTestigo
				or hijo is ReceptorDeFe
			):
				props += 1
		_check(
			"T9 %s trae %d props" % [archivo, esperado[archivo]],
			props == int(esperado[archivo]),
			"contados %d" % props
		)
		for hijo: Node in raiz.get_children():
			if hijo is PuertaSellada:
				var puerta := hijo as PuertaSellada
				var validas := 0
				for f: Node in puerta.fuentes:
					if f != null:
						validas += 1
				_check(
					"T9 %s: %s tiene sus fuentes resueltas" % [archivo, puerta.name],
					validas == puerta.fuentes.size() and validas >= 1,
					"%d de %d" % [validas, puerta.fuentes.size()]
				)
			if hijo is BloqueEnMora:
				var bloque := hijo as BloqueEnMora
				_check(
					"T9 %s: %s tiene disparador" % [archivo, bloque.name],
					bloque.disparador != null and bloque.en_mora
				)
		await _limpiar(caja)
