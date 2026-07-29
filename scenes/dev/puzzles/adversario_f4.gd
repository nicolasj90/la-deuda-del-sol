# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

## Revisión ADVERSARIAL de F4: edge cases que el smoke de F4 no cubre.
##
## No repite los chequeos felices; ataca los bordes:
## empuje físico contra pared/bloque, placa que se libera, mora sin aliviar,
## haz cortado en el medio, re-entrada al dungeon, fuentes liberadas, tween en curso.

const BLOQUE := preload(
	"res://scenes/game_elements/props/puzzles/bloque_empujable/bloque_empujable.tscn"
)
const BLOQUE_MORA := preload(
	"res://scenes/game_elements/props/puzzles/bloque_en_mora/bloque_en_mora.tscn"
)
const PLACA := preload("res://scenes/game_elements/props/puzzles/placa_presion/placa_presion.tscn")
const PUERTA_SELLADA := preload(
	"res://scenes/game_elements/props/puzzles/puerta_sellada/puerta_sellada.tscn"
)
const ESTATUA := preload(
	"res://scenes/game_elements/props/puzzles/estatua_testigo/estatua_testigo.tscn"
)
const RECEPTOR := preload(
	"res://scenes/game_elements/props/puzzles/receptor_de_fe/receptor_de_fe.tscn"
)
const LLAVE := preload("res://scenes/game_elements/props/puzzles/llave/llave.tscn")
const PUERTA_CERRADURA := preload(
	"res://scenes/game_elements/props/puzzles/puerta_con_cerradura/puerta_con_cerradura.tscn"
)
const VINEDO := "res://scenes/quests/story_quests/la_deuda_del_sol/vinedo_en_prenda/vinedo_en_prenda.tscn"
const ARCHIVO := "res://scenes/quests/story_quests/la_deuda_del_sol/archivo_bajo/archivo_bajo.tscn"

var _total: int = 0
var _fallos: int = 0


func _ready() -> void:
	print("== ADVERSARIO F4: edge cases ==")
	_perro_guardian()
	await _a1_empuje_fisico_contra_obstaculos()
	await _a2_placa_se_libera_y_puerta_recierra()
	await _a3_mora_sin_aliviar()
	await _a4_haz_cortado_en_el_medio()
	await _a5_reentrada_al_dungeon()
	await _a6_fuentes_liberadas_y_estado_raro()
	await _a7_empuje_durante_el_deslizamiento()
	await _a8_llave_doble_uso()
	await _a9_puerta_cerrada_no_se_puede_cruzar()

	print("== RESUMEN ADVERSARIO: %d chequeos, %d fallos ==" % [_total, _fallos])
	print("ADVERSARIO OK" if _fallos == 0 else "ADVERSARIO FALLÓ")
	get_tree().quit(1 if _fallos > 0 else 0)


# --- Infraestructura -------------------------------------------------------


func _perro_guardian(segundos: float = 120.0) -> void:
	var reloj := get_tree().create_timer(segundos, true, false, true)
	reloj.timeout.connect(
		func() -> void:
			print("FAIL - el adversario se colgó tras %.0f s" % segundos)
			print("ADVERSARIO FALLÓ")
			get_tree().quit(1)
	)


func _check(nombre: String, ok: bool, detalle: String = "") -> void:
	_total += 1
	if ok:
		print("PASS - %s" % nombre)
		return
	_fallos += 1
	print("FAIL - %s%s" % [nombre, "" if detalle.is_empty() else " (%s)" % detalle])


func _fisica(cuadros: int = 1) -> void:
	for _i in cuadros:
		await get_tree().physics_frame


func _esperar_hasta(condicion: Callable, segundos: float = 2.0) -> bool:
	for _i in int(segundos * 60.0) + 2:
		if condicion.call():
			return true
		await get_tree().physics_frame
	return condicion.call()


func _caja(nombre: String) -> Node2D:
	var caja := Node2D.new()
	caja.name = nombre
	add_child(caja)
	return caja


func _limpiar(caja: Node) -> void:
	caja.queue_free()
	await _fisica(2)


func _pared(en: Vector2, tamano: Vector2 = Vector2(64, 64)) -> StaticBody2D:
	var pared := StaticBody2D.new()
	pared.name = "Pared"
	pared.collision_layer = 16  # WALLS (capa 5)
	pared.collision_mask = 0
	pared.position = en
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = tamano
	forma.shape = rect
	pared.add_child(forma)
	return pared


## Empuja físicamente con el doble del jugador, moviéndolo con move_and_slide.
func _empujar_fisico(
	jugador: JugadorFalso, direccion: Vector2, cuadros: int, fuerza: float = 220.0
) -> void:
	jugador.input_vector = direccion.normalized() * fuerza
	for _i in cuadros:
		jugador.velocity = jugador.input_vector
		jugador.move_and_slide()
		await get_tree().physics_frame
	jugador.input_vector = Vector2.ZERO
	jugador.velocity = Vector2.ZERO


# --- A1: el bloque no atraviesa pared ni bloque (empuje FÍSICO sostenido) ---


func _a1_empuje_fisico_contra_obstaculos() -> void:
	print("-- A1 empuje físico sostenido contra pared y contra otro bloque")
	var caja := _caja("A1")

	# Pared a la derecha del bloque.
	caja.add_child(_pared(Vector2(64, 0)))
	var bloque: BloqueEmpujable = BLOQUE.instantiate()
	bloque.position = Vector2.ZERO
	bloque.retardo_empuje = 0.1
	bloque.duracion_deslizamiento = 0.06
	caja.add_child(bloque)

	var jugador := JugadorFalso.crear(Vector2(-53, 0))
	caja.add_child(jugador)
	await _fisica(4)

	var bloqueos: Array[int] = [0]
	bloque.empuje_bloqueado.connect(func(_d: Vector2i) -> void: bloqueos[0] += 1)
	var movidas: Array[int] = [0]
	bloque.moved.connect(func(_a: Vector2, _b: Vector2) -> void: movidas[0] += 1)

	# 90 cuadros (1.5 s) de empuje sostenido contra la pared.
	await _empujar_fisico(jugador, Vector2.RIGHT, 90)
	await _fisica(4)
	_check("A1 el bloque NO atravesó la pared", movidas[0] == 0, "movidas=%d" % movidas[0])
	_check(
		"A1 el bloque sigue en su celda",
		bloque.celda_actual() == Vector2i.ZERO and bloque.global_position.is_equal_approx(Vector2.ZERO),
		"%s %s" % [bloque.celda_actual(), bloque.global_position]
	)
	_check("A1 avisó empuje_bloqueado al menos una vez", bloqueos[0] >= 1, "n=%d" % bloqueos[0])

	# Ahora: bloque contra bloque. Reubico al jugador al oeste del bloque A.
	var vecino: BloqueEmpujable = BLOQUE.instantiate()
	vecino.position = Vector2(-192, 0)
	vecino.retardo_empuje = 0.1
	vecino.duracion_deslizamiento = 0.06
	caja.add_child(vecino)
	await _fisica(4)

	# El vecino está en -192; lo empujo hacia la derecha: a -128 hay lugar,
	# después choca contra el bloque de 0. Nunca debería llegar a 0.
	var mov_vecino: Array[int] = [0]
	vecino.moved.connect(func(_a: Vector2, _b: Vector2) -> void: mov_vecino[0] += 1)
	jugador.global_position = Vector2(-245, 0)
	await _fisica(3)
	await _empujar_fisico(jugador, Vector2.RIGHT, 150)
	await _fisica(4)
	# Hay 2 celdas libres (-128 y -64) antes del bloque de 0: debe frenar en -64.
	_check(
		"A1 bloque-contra-bloque: se detuvo pegado, sin superponerse",
		vecino.global_position.is_equal_approx(Vector2(-64, 0)),
		"pos=%s movidas=%d" % [vecino.global_position, mov_vecino[0]]
	)
	_check(
		"A1 los dos bloques NO se superponen (>= 1 celda de separación)",
		absf(vecino.global_position.x - bloque.global_position.x) >= 64.0,
		"%s vs %s" % [vecino.global_position, bloque.global_position]
	)
	_check(
		"A1 el vecino quedó alineado a la retícula de 64",
		is_zero_approx(fposmod(vecino.global_position.x, 64.0))
		and is_zero_approx(fposmod(vecino.global_position.y, 64.0)),
		str(vecino.global_position)
	)
	_check(
		"A1 no lo empujó de más (2 celdas libres = 2 movidas)",
		mov_vecino[0] == 2,
		"movidas=%d" % mov_vecino[0]
	)

	# Empuje diagonal: no debe saltar en diagonal.
	var antes := vecino.celda_actual()
	jugador.global_position = vecino.global_position + Vector2(-53, -20)
	await _fisica(3)
	await _empujar_fisico(jugador, Vector2(1, -1), 90)
	await _fisica(4)
	var delta: Vector2i = vecino.celda_actual() - antes
	_check(
		"A1 el empuje diagonal no mueve en diagonal",
		absi(delta.x) + absi(delta.y) <= 1,
		"delta=%s" % delta
	)

	await _limpiar(caja)


# --- A2: placa que se libera -> ¿la puerta se re-cierra? -------------------


func _a2_placa_se_libera_y_puerta_recierra() -> void:
	print("-- A2 placa liberada: puerta normal se re-cierra, permanente no")
	var caja := _caja("A2")

	var placa: PlacaPresion = PLACA.instantiate()
	placa.position = Vector2.ZERO
	caja.add_child(placa)

	var placa_perm: PlacaPresion = PLACA.instantiate()
	placa_perm.position = Vector2(600, 0)
	placa_perm.permanente = true
	caja.add_child(placa_perm)

	var puerta: PuertaSellada = PUERTA_SELLADA.instantiate()
	puerta.position = Vector2(0, -300)
	puerta.requiere_n = 1
	puerta.fuentes = [placa]
	caja.add_child(puerta)

	var puerta_perm: PuertaSellada = PUERTA_SELLADA.instantiate()
	puerta_perm.position = Vector2(600, -300)
	puerta_perm.requiere_n = 1
	puerta_perm.permanente = true
	puerta_perm.fuentes = [placa_perm]
	caja.add_child(puerta_perm)
	await _fisica(6)

	var abiertas: Array[int] = [0]
	var cerradas: Array[int] = [0]
	puerta.opened.connect(func() -> void: abiertas[0] += 1)
	puerta.closed.connect(func() -> void: cerradas[0] += 1)

	_check("A2 la puerta arranca cerrada", not puerta.abierta)

	var jugador := JugadorFalso.crear(Vector2.ZERO)
	caja.add_child(jugador)
	await _fisica(6)
	_check("A2 la placa se hunde con el jugador", placa.occupied)
	_check("A2 la puerta se abrió", puerta.abierta and abiertas[0] == 1, "n=%d" % abiertas[0])
	_check("A2 puerta abierta: el colisionador deja de ser pared", not _es_pared(puerta))

	# El jugador se va: la placa se libera y la puerta debe re-cerrarse.
	jugador.global_position = Vector2(0, 500)
	await _fisica(6)
	_check("A2 la placa se liberó", not placa.occupied)
	_check(
		"A2 LA PUERTA SE RE-CERRÓ al liberarse la placa",
		not puerta.abierta and cerradas[0] == 1,
		"abierta=%s cerradas=%d" % [puerta.abierta, cerradas[0]]
	)
	_check("A2 puerta re-cerrada: vuelve a ser pared", _es_pared(puerta))

	# La permanente NO debe re-cerrarse.
	jugador.global_position = Vector2(600, 0)
	await _fisica(6)
	_check("A2 puerta permanente abierta", puerta_perm.abierta)
	jugador.global_position = Vector2(600, 500)
	await _fisica(6)
	_check("A2 placa permanente sigue hundida", placa_perm.occupied)
	_check("A2 puerta permanente NO se re-cerró", puerta_perm.abierta)

	# Ciclo de apertura/cierre repetido: no debe desincronizarse.
	for i in 3:
		jugador.global_position = Vector2.ZERO
		await _fisica(5)
		jugador.global_position = Vector2(0, 500)
		await _fisica(5)
	_check(
		"A2 tras 3 ciclos la puerta quedó cerrada y las cuentas cuadran",
		not puerta.abierta and abiertas[0] == 4 and cerradas[0] == 4,
		"abierta=%s ab=%d ce=%d" % [puerta.abierta, abiertas[0], cerradas[0]]
	)
	_check("A2 el contador de fuentes volvió a cero", puerta.activas() == 0, str(puerta.activas()))

	await _limpiar(caja)


func _es_pared(puerta: Node) -> bool:
	var col := puerta.get_node_or_null(^"%ColisionadorCerrada")
	if col is StaticBody2D:
		return (col as StaticBody2D).get_collision_layer_value(Enums.CollisionLayers.WALLS)
	return false


# --- A3: bloque en mora empujado SIN aliviar -------------------------------


func _a3_mora_sin_aliviar() -> void:
	print("-- A3 bloque en mora sin aliviar: inamovible por empuje físico")
	var caja := _caja("A3")

	var bloque: BloqueEnMora = BLOQUE_MORA.instantiate()
	bloque.position = Vector2.ZERO
	bloque.en_mora = true
	bloque.retardo_empuje = 0.1
	bloque.duracion_deslizamiento = 0.06
	caja.add_child(bloque)

	var jugador := JugadorFalso.crear(Vector2(-53, 0))
	caja.add_child(jugador)
	await _fisica(4)

	var movidas: Array[int] = [0]
	bloque.moved.connect(func(_a: Vector2, _b: Vector2) -> void: movidas[0] += 1)

	_check("A3 arranca en mora", bloque.en_mora)
	await _empujar_fisico(jugador, Vector2.RIGHT, 120)
	await _fisica(4)
	_check("A3 NO se movió con 2 s de empuje", movidas[0] == 0, "movidas=%d" % movidas[0])
	_check(
		"A3 sigue clavado en su celda",
		bloque.global_position.is_equal_approx(Vector2.ZERO),
		str(bloque.global_position)
	)
	_check("A3 puede_moverse() dice no en las 4 direcciones", (
		not bloque.puede_moverse(Vector2i.RIGHT)
		and not bloque.puede_moverse(Vector2i.LEFT)
		and not bloque.puede_moverse(Vector2i.UP)
		and not bloque.puede_moverse(Vector2i.DOWN)
	))
	_check("A3 intentar_empujar() directo también falla", not bloque.intentar_empujar(Vector2i.RIGHT))
	_check(
		"A3 sigue en mora tras el forcejeo (no se auto-alivió)",
		bloque.en_mora and movidas[0] == 0
	)

	# Aliviar y volver a empujar: ahora sí.
	bloque.aliviar()
	await _fisica(2)
	_check("A3 aliviado deja de estar en mora", not bloque.en_mora)
	await _empujar_fisico(jugador, Vector2.RIGHT, 60)
	await _esperar_hasta(func() -> bool: return movidas[0] >= 1, 2.0)
	_check("A3 aliviado sí se mueve", movidas[0] >= 1, "movidas=%d" % movidas[0])

	# Volver a poner en mora en pleno empuje: no debe seguir moviéndose.
	var antes := bloque.celda_actual()
	bloque.poner_en_mora()
	await _empujar_fisico(jugador, Vector2.RIGHT, 90)
	await _fisica(4)
	_check(
		"A3 re-puesto en mora se congela otra vez",
		bloque.celda_actual() == antes,
		"%s -> %s" % [antes, bloque.celda_actual()]
	)

	await _limpiar(caja)


# --- A4: haz cortado por una estantería en el medio ------------------------


func _a4_haz_cortado_en_el_medio() -> void:
	print("-- A4 haz de la estatua cortado por un bloque intermedio")
	var caja := _caja("A4")

	var estatua: EstatuaTestigo = ESTATUA.instantiate()
	estatua.position = Vector2.ZERO
	estatua.direccion = EstatuaTestigo.Direccion.DERECHA
	estatua.alcance = 512.0
	caja.add_child(estatua)

	var receptor: ReceptorDeFe = RECEPTOR.instantiate()
	receptor.position = Vector2(384, 0)
	caja.add_child(receptor)
	await _fisica(6)

	_check("A4 sin obstáculos el haz llega", receptor.iluminado, "haces=%d" % receptor.cantidad_haces())

	# Estantería EN EL MEDIO del trayecto.
	var estanteria: BloqueEmpujable = BLOQUE.instantiate()
	estanteria.position = Vector2(192, 0)
	caja.add_child(estanteria)
	await _fisica(8)

	_check(
		"A4 EL BLOQUE INTERMEDIO CORTA EL HAZ",
		not receptor.iluminado,
		"iluminado=%s haces=%d" % [receptor.iluminado, receptor.cantidad_haces()]
	)
	_check("A4 la estatua perdió el objetivo", estatua.objetivo_actual == null, str(estatua.objetivo_actual))
	_check("A4 el receptor no cuenta haces fantasma", receptor.cantidad_haces() == 0)

	# Correr la estantería fuera de la línea: el haz vuelve.
	estanteria.global_position = Vector2(192, -128)
	await _fisica(8)
	_check("A4 corrida la estantería el haz vuelve", receptor.iluminado)
	_check("A4 el objetivo vuelve a ser el receptor", estatua.objetivo_actual == receptor)

	# Una pared también corta.
	caja.add_child(_pared(Vector2(256, 0)))
	await _fisica(8)
	_check("A4 una pared corta el haz", not receptor.iluminado)

	# Rotar la estatua lejos del receptor.
	estatua.direccion = EstatuaTestigo.Direccion.ARRIBA
	await _fisica(6)
	_check("A4 rotada a otro lado no ilumina", not receptor.iluminado)
	# 4 rotaciones vuelven al origen.
	var d0 := estatua.direccion
	estatua.rotar(4)
	_check("A4 rotar(4) vuelve al punto de partida", estatua.direccion == d0)
	estatua.rotar(-1)
	_check("A4 rotar(-1) no rompe el módulo", int(estatua.direccion) >= 0 and int(estatua.direccion) <= 3, str(estatua.direccion))

	# Receptor permanente: cortarle el haz no lo apaga.
	var perm: ReceptorDeFe = RECEPTOR.instantiate()
	perm.position = Vector2(0, 384)
	perm.permanente = true
	caja.add_child(perm)
	var estatua2: EstatuaTestigo = ESTATUA.instantiate()
	estatua2.position = Vector2(0, 0)
	estatua2.direccion = EstatuaTestigo.Direccion.ABAJO
	caja.add_child(estatua2)
	await _fisica(8)
	_check("A4 receptor permanente se enciende", perm.iluminado)
	estatua2.direccion = EstatuaTestigo.Direccion.DERECHA
	await _fisica(8)
	_check("A4 receptor permanente NO se apaga al perder el haz", perm.iluminado)

	await _limpiar(caja)


# --- A5: salir del dungeon y volver ---------------------------------------


func _a5_reentrada_al_dungeon() -> void:
	print("-- A5 entrar, resolver a medias, salir y volver a entrar")
	for ruta: String in [VINEDO, ARCHIVO]:
		var nombre := ruta.get_file()
		var paquete := load(ruta) as PackedScene
		_check("A5 %s carga" % nombre, paquete != null)
		if paquete == null:
			continue

		# Huella virgen de referencia: instancia limpia, sin tocar nada.
		var virgen: Node = paquete.instantiate()
		add_child(virgen)
		await _fisica(8)
		var huella_virgen := _huella(virgen)
		await _limpiar(virgen)

		# Primera visita: instanciar, tocar estado, liberar.
		var visita1: Node = paquete.instantiate()
		add_child(visita1)
		await _fisica(8)
		var tocados := _mutar_estado(visita1)
		_check("A5 %s: la primera visita cambió estado" % nombre, tocados > 0, "tocados=%d" % tocados)
		await _fisica(6)
		var huella1 := _huella(visita1)
		await _limpiar(visita1)

		# Segunda visita: instancia nueva del mismo PackedScene.
		var visita2: Node = paquete.instantiate()
		add_child(visita2)
		await _fisica(8)
		var huella2 := _huella(visita2)
		_check(
			"A5 %s: la primera visita dejó huella distinta de la virgen" % nombre,
			huella1 != huella_virgen,
			"virgen=%s post=%s" % [huella_virgen, huella1]
		)
		_check(
			"A5 %s: la re-entrada NO crashea y el estado RESETEA (consistente)" % nombre,
			huella2 == huella_virgen,
			"virgen=%s h1(post)=%s h2=%s" % [huella_virgen, huella1, huella2]
		)
		# Resolverlo de nuevo en la segunda visita debe funcionar igual.
		var tocados2 := _mutar_estado(visita2)
		await _fisica(6)
		_check(
			"A5 %s: la segunda visita se puede volver a resolver" % nombre,
			tocados2 == tocados,
			"%d vs %d" % [tocados2, tocados]
		)
		await _limpiar(visita2)
	# Ida y vuelta rápida: 3 ciclos seguidos sin crash.
	var paquete2 := load(ARCHIVO) as PackedScene
	for i in 3:
		var v: Node = paquete2.instantiate()
		add_child(v)
		await _fisica(4)
		await _limpiar(v)
	_check("A5 3 idas y vueltas seguidas sin crash", true)


## Cambia el estado observable del dungeon (abre puertas, alivia bloques, riega).
func _mutar_estado(raiz: Node) -> int:
	var n := 0
	for nodo: Node in _todos(raiz):
		if nodo is ReceptorDeFe:
			(nodo as ReceptorDeFe).iluminar(self)
			n += 1
		elif nodo is PlacaPresion:
			(nodo as PlacaPresion).occupied = true
			n += 1
		elif nodo is BloqueEnMora:
			(nodo as BloqueEnMora).aliviar()
			n += 1
		elif nodo is Aljibe:
			(nodo as Aljibe).cargar()
			n += 1
	return n


## Firma del estado del dungeon: puertas abiertas + moras + receptores.
func _huella(raiz: Node) -> String:
	var puertas := 0
	var moras := 0
	var luces := 0
	var aguas := 0
	for nodo: Node in _todos(raiz):
		if nodo is PuertaSellada and (nodo as PuertaSellada).abierta:
			puertas += 1
		if nodo is BloqueEnMora and (nodo as BloqueEnMora).en_mora:
			moras += 1
		if nodo is ReceptorDeFe and (nodo as ReceptorDeFe).iluminado:
			luces += 1
		if nodo is Aljibe and (nodo as Aljibe).tiene_agua():
			aguas += 1
	return "p%d/m%d/l%d/a%d" % [puertas, moras, luces, aguas]


func _todos(raiz: Node) -> Array[Node]:
	var salida: Array[Node] = [raiz]
	for hijo: Node in raiz.get_children():
		salida.append_array(_todos(hijo))
	return salida


# --- A6: fuentes liberadas / estado raro ----------------------------------


func _a6_fuentes_liberadas_y_estado_raro() -> void:
	print("-- A6 fuentes liberadas, requiere_n raro, invertir")
	var caja := _caja("A6")

	# Dos placas, puerta que pide las dos. Se libera una FUENTE (queue_free).
	var p1: PlacaPresion = PLACA.instantiate()
	p1.position = Vector2.ZERO
	caja.add_child(p1)
	var p2: PlacaPresion = PLACA.instantiate()
	p2.position = Vector2(200, 0)
	caja.add_child(p2)

	var puerta: PuertaSellada = PUERTA_SELLADA.instantiate()
	puerta.position = Vector2(0, -300)
	puerta.requiere_n = 2
	puerta.fuentes = [p1, p2]
	caja.add_child(puerta)
	await _fisica(6)

	p1.occupied = true
	p1.pressed.emit()
	p2.occupied = true
	p2.pressed.emit()
	await _fisica(4)
	_check("A6 con las 2 placas la puerta abre", puerta.abierta, "activas=%d" % puerta.activas())

	# Liberar una placa activa: la puerta no debería quedar abierta por un
	# fantasma. (Si queda abierta pero no crashea, lo anoto como consistente.)
	p2.queue_free()
	await _fisica(6)
	var cuenta_post := puerta.activas()
	_check(
		"A6 liberar una fuente activa no crashea",
		is_instance_valid(puerta),
		"activas=%d abierta=%s" % [cuenta_post, puerta.abierta]
	)
	print("--   nota A6: tras liberar la fuente, activas()=%d abierta=%s" % [cuenta_post, puerta.abierta])

	# requiere_n = 0 -> debería abrir sola.
	var p0: PuertaSellada = PUERTA_SELLADA.instantiate()
	p0.position = Vector2(400, -300)
	p0.requiere_n = 0
	p0.fuentes = []
	caja.add_child(p0)
	await _fisica(6)
	_check("A6 requiere_n=0 abre sola", p0.abierta)

	# requiere_n mayor que la cantidad de fuentes -> nunca abre, no crashea.
	var imposible: PuertaSellada = PUERTA_SELLADA.instantiate()
	imposible.position = Vector2(800, -300)
	imposible.requiere_n = 5
	imposible.fuentes = [p1]
	caja.add_child(imposible)
	await _fisica(6)
	_check("A6 requiere_n imposible no abre ni crashea", not imposible.abierta)

	# Fuente basura (sin señales): warning, no crash.
	var basura := Node2D.new()
	basura.name = "Basura"
	caja.add_child(basura)
	var con_basura: PuertaSellada = PUERTA_SELLADA.instantiate()
	con_basura.position = Vector2(1200, -300)
	con_basura.requiere_n = 1
	con_basura.fuentes = [basura, null]
	caja.add_child(con_basura)
	await _fisica(6)
	_check("A6 fuente sin señales (y null) no crashea", is_instance_valid(con_basura))

	# invertir: arranca abierta y cierra al cumplirse.
	var p3: PlacaPresion = PLACA.instantiate()
	p3.position = Vector2(1600, 0)
	caja.add_child(p3)
	var inv: PuertaSellada = PUERTA_SELLADA.instantiate()
	inv.position = Vector2(1600, -300)
	inv.requiere_n = 1
	inv.invertir = true
	inv.fuentes = [p3]
	caja.add_child(inv)
	await _fisica(6)
	_check("A6 invertir: arranca abierta", inv.abierta)
	p3.occupied = true
	p3.pressed.emit()
	await _fisica(4)
	_check("A6 invertir: se cierra al cumplirse", not inv.abierta)
	p3.occupied = false
	p3.released.emit()
	await _fisica(4)
	_check("A6 invertir: reabre al liberarse", inv.abierta)

	await _limpiar(caja)


# --- A7: empujar mientras el bloque se desliza -----------------------------


func _a7_empuje_durante_el_deslizamiento() -> void:
	print("-- A7 empuje en pleno deslizamiento: sin doble salto ni desalineo")
	var caja := _caja("A7")

	var bloque: BloqueEmpujable = BLOQUE.instantiate()
	bloque.position = Vector2.ZERO
	bloque.duracion_deslizamiento = 0.4
	caja.add_child(bloque)
	await _fisica(4)

	var movidas: Array[int] = [0]
	bloque.moved.connect(func(_a: Vector2, _b: Vector2) -> void: movidas[0] += 1)

	_check("A7 arranca el deslizamiento", bloque.intentar_empujar(Vector2i.RIGHT))
	await _fisica(2)
	_check("A7 deslizandose es true en pleno tween", bloque.deslizandose)
	# Martillar intentos durante el tween.
	var rechazos := 0
	for _i in 10:
		if not bloque.intentar_empujar(Vector2i.RIGHT):
			rechazos += 1
		if not bloque.intentar_empujar(Vector2i.DOWN):
			rechazos += 1
		await get_tree().physics_frame
	await _esperar_hasta(func() -> bool: return not bloque.deslizandose, 2.0)
	await _fisica(3)
	_check("A7 los intentos durante el tween se rechazan", rechazos == 20, "rechazos=%d" % rechazos)
	_check("A7 sólo una moved", movidas[0] == 1, "movidas=%d" % movidas[0])
	_check(
		"A7 quedó a exactamente una celda, alineado",
		bloque.global_position.is_equal_approx(Vector2(64, 0)),
		str(bloque.global_position)
	)
	_check("A7 celda coherente", bloque.celda_actual() == Vector2i(1, 0), str(bloque.celda_actual()))

	# 6 empujes en cadena: la grilla no debe derivar.
	for i in 6:
		bloque.intentar_empujar(Vector2i.DOWN)
		await _esperar_hasta(func() -> bool: return not bloque.deslizandose, 2.0)
	await _fisica(2)
	_check(
		"A7 tras 6 empujes en cadena no hay deriva de grilla",
		bloque.global_position.is_equal_approx(Vector2(64, 384)),
		str(bloque.global_position)
	)

	# fijado: no se mueve nunca.
	bloque.fijado = true
	_check("A7 fijado rechaza el empuje", not bloque.intentar_empujar(Vector2i.LEFT))

	await _limpiar(caja)


# --- A8: llave y cerradura, dobles usos -----------------------------------


func _a8_llave_doble_uso() -> void:
	print("-- A8 llave: recoger dos veces, consumir dos veces, puerta sin llave")
	var caja := _caja("A8")

	var jugador := JugadorFalso.crear(Vector2(-400, 0))
	caja.add_child(jugador)

	var llave: Llave = LLAVE.instantiate()
	llave.position = Vector2.ZERO
	llave.tipo = &"prueba"
	caja.add_child(llave)

	var puerta: PuertaConCerradura = PUERTA_CERRADURA.instantiate()
	puerta.position = Vector2(300, 0)
	puerta.tipo_llave = &"prueba"
	caja.add_child(puerta)
	await _fisica(6)

	_check("A8 la puerta arranca cerrada", not puerta.abierta)
	_check("A8 sin llave no abre", not puerta.intentar_abrir())
	_check("A8 sigue cerrada tras el intento fallido", not puerta.abierta)

	var recogidas: Array[int] = [0]
	llave.recogida.connect(func(_l: Llave) -> void: recogidas[0] += 1)
	_check("A8 recoger la llave funciona", llave.recoger())
	await _fisica(2)
	_check("A8 recoger dos veces no cuenta doble", not llave.recoger() and recogidas[0] == 1, "n=%d" % recogidas[0])
	_check("A8 la llave está en el llavero", puerta.tiene_llave())
	_check("A8 con llave la puerta abre", puerta.intentar_abrir())
	await _fisica(2)
	_check("A8 la puerta quedó abierta", puerta.abierta)
	_check("A8 abrir dos veces no revienta", is_instance_valid(puerta))
	print("--   nota A8: tras abrir, tiene_llave()=%s" % puerta.tiene_llave())

	# Llave de otro tipo no sirve.
	var otra: Llave = LLAVE.instantiate()
	otra.position = Vector2(0, 200)
	otra.tipo = &"otra_cosa"
	caja.add_child(otra)
	await _fisica(4)
	_check("A8 una llave sin recoger no sirve para nada", not otra.sirve_para(&"otra_cosa"))
	otra.recoger()
	await _fisica(2)
	_check(
		"A8 recogida, sirve_para discrimina el tipo",
		otra.sirve_para(&"otra_cosa") and not otra.sirve_para(&"prueba")
	)
	_check("A8 la llave consumida ya no sirve", not llave.sirve_para(&"prueba"))

	var puerta2: PuertaConCerradura = PUERTA_CERRADURA.instantiate()
	puerta2.position = Vector2(300, 400)
	puerta2.tipo_llave = &"inexistente"
	caja.add_child(puerta2)
	await _fisica(4)
	_check("A8 puerta de tipo inexistente no abre", not puerta2.intentar_abrir())

	await _limpiar(caja)


# --- A9: la puerta cerrada no se puede cruzar caminando -------------------


func _a9_puerta_cerrada_no_se_puede_cruzar() -> void:
	print("-- A9 puerta sellada cerrada: no se cruza ni por el medio ni por el borde")
	var caja := _caja("A9")

	var placa: PlacaPresion = PLACA.instantiate()
	placa.position = Vector2(-600, 0)
	caja.add_child(placa)

	# La puerta sella la celda de (0,-64) a (0,0): centro del sello en (0,-32).
	var puerta: PuertaSellada = PUERTA_SELLADA.instantiate()
	puerta.position = Vector2.ZERO
	puerta.requiere_n = 1
	puerta.fuentes = [placa]
	caja.add_child(puerta)
	await _fisica(6)
	_check("A9 arranca cerrada", not puerta.abierta)

	# Intento cruzar de sur a norte por el eje del sello.
	var jugador := JugadorFalso.crear(Vector2(0, 40))
	caja.add_child(jugador)
	await _fisica(4)
	await _empujar_fisico(jugador, Vector2.UP, 120)
	await _fisica(2)
	_check(
		"A9 NO cruzó la puerta cerrada por el medio",
		jugador.global_position.y > -32.0,
		"y=%.1f" % jugador.global_position.y
	)

	# Intento por el borde del sello (x = +-30, todavía dentro del 64 de ancho).
	for x: float in [-30.0, 30.0]:
		jugador.global_position = Vector2(x, 40)
		jugador.velocity = Vector2.ZERO
		await _fisica(3)
		await _empujar_fisico(jugador, Vector2.UP, 120)
		await _fisica(2)
		_check(
			"A9 NO cruzó por el borde x=%.0f" % x,
			jugador.global_position.y > -32.0,
			"y=%.1f" % jugador.global_position.y
		)

	# Abierta: ahora sí tiene que pasar.
	placa.occupied = true
	placa.pressed.emit()
	await _fisica(6)
	_check("A9 la puerta se abrió", puerta.abierta)
	jugador.global_position = Vector2(0, 40)
	jugador.velocity = Vector2.ZERO
	await _fisica(3)
	await _empujar_fisico(jugador, Vector2.UP, 120)
	await _fisica(2)
	_check(
		"A9 abierta SÍ deja pasar",
		jugador.global_position.y < -64.0,
		"y=%.1f" % jugador.global_position.y
	)

	# Y un bloque tampoco atraviesa la puerta cerrada.
	placa.occupied = false
	placa.released.emit()
	await _fisica(6)
	_check("A9 la puerta se volvió a cerrar", not puerta.abierta)
	var bloque: BloqueEmpujable = BLOQUE.instantiate()
	bloque.position = Vector2(0, 64)
	caja.add_child(bloque)
	await _fisica(4)
	_check(
		"A9 el bloque no puede entrar en la celda de la puerta cerrada",
		not bloque.puede_moverse(Vector2i.UP)
	)

	await _limpiar(caja)
