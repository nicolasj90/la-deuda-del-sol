# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

## Smoke headless de los dos puzzles jugables del Acto 1.
##
## Instancia las escenas de dungeon reales y las resuelve por código en el orden
## en que las resolvería el jugador (cargar agua, regar, empujar, rotar), y
## verifica que la puerta final se abra. Imprime PASS/FAIL por chequeo y sale con
## código 0 si todo pasa, 1 si algo falla.
##
## Correr:
## [codeblock]
## scenes/dev/puzzles/smoke_dungeons.sh
## # o bien
## ~/tools/godot/Godot_v4.7-stable_linux.x86_64 --headless --path . \
##     res://scenes/dev/puzzles/smoke_dungeons.tscn
## [/codeblock]

const VINEDO := preload(
	"res://scenes/quests/story_quests/la_deuda_del_sol/vinedo_en_prenda/vinedo_en_prenda.tscn"
)
const ARCHIVO := preload(
	"res://scenes/quests/story_quests/la_deuda_del_sol/archivo_bajo/archivo_bajo.tscn"
)
const CAMINO := preload(
	"res://scenes/quests/story_quests/la_deuda_del_sol/camino_del_diezmo.tscn"
)
const VILLARRUBRICA := preload(
	"res://scenes/quests/story_quests/la_deuda_del_sol/villarrubrica.tscn"
)

var _total: int = 0
var _fallos: int = 0


func _ready() -> void:
	print("== SMOKE dungeons del Acto 1 ==")
	_armar_perro_guardian()
	await _d0_entradas_desde_el_mapa()
	await _d1_vinedo_en_prenda()
	await _d2_archivo_bajo()

	print("== RESUMEN: %d chequeos, %d fallos ==" % [_total, _fallos])
	if _fallos == 0:
		print("SMOKE OK")
	else:
		print("SMOKE FALLÓ")
	get_tree().quit(1 if _fallos > 0 else 0)


# --- Infraestructura -------------------------------------------------------


func _armar_perro_guardian(segundos: float = 120.0) -> void:
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


func _esperar_hasta(condicion: Callable, segundos: float = 3.0) -> bool:
	var limite := int(segundos * 60.0) + 2
	for _i in limite:
		if condicion.call():
			return true
		await get_tree().physics_frame
	return condicion.call()


## Empuja un bloque una celda y espera a que termine de deslizarse.
func _empujar(bloque: BloqueEmpujable, direccion: Vector2i) -> bool:
	if not bloque.intentar_empujar(direccion):
		return false
	await _esperar_hasta(func() -> bool: return not bloque.deslizandose)
	await _fisica(2)
	return true


## Instancia una escena de dungeon con el tiempo de físicas ya corrido.
func _montar(escena: PackedScene, nombre: String) -> Node2D:
	var raiz: Node2D = escena.instantiate()
	raiz.name = nombre
	add_child(raiz)
	await _fisica(6)
	return raiz


func _colisiona_como_pared(puerta: PuertaSellada) -> bool:
	var colisionador := puerta.get_node(^"%ColisionadorCerrada") as StaticBody2D
	return colisionador.get_collision_layer_value(Enums.CollisionLayers.WALLS)


# --- D0: cómo se llega desde el mapa --------------------------------------


## Un portal está bien cableado si su escena destino existe y el punto de
## aparición que pide está en esa escena y en el grupo [code]spawn_point[/code].
func _revisar_portal(
	nombre: String, portal: Node, destino_esperado: PackedScene, destino: Node
) -> void:
	_check("%s existe" % nombre, portal != null)
	if portal == null:
		return

	var camino_destino: String = ResourceUID.ensure_path(portal.next_scene)
	_check(
		"%s apunta a %s" % [nombre, destino_esperado.resource_path.get_file()],
		camino_destino == destino_esperado.resource_path,
		camino_destino
	)

	var punto := destino.get_node_or_null(portal.spawn_point_path)
	_check(
		"%s aterriza en %s" % [nombre, portal.spawn_point_path],
		punto != null and punto.is_in_group(&"spawn_point")
	)


func _d0_entradas_desde_el_mapa() -> void:
	print("-- D0 entradas y salidas: los dungeons cuelgan del mapa")

	# Se instancian sin agregarlas al árbol: alcanza para revisar el cableado.
	var camino: Node = CAMINO.instantiate()
	var villarrubrica: Node = VILLARRUBRICA.instantiate()
	var vinedo: Node = VINEDO.instantiate()
	var archivo: Node = ARCHIVO.instantiate()

	_revisar_portal(
		"D0 Camino del Diezmo → Viñedo en Prenda",
		camino.get_node_or_null(^"Teleporters/TeleporterVinedo"),
		VINEDO,
		vinedo
	)
	_revisar_portal(
		"D0 Viñedo en Prenda → Camino (salida oeste)",
		vinedo.get_node_or_null(^"Teleporters/SalidaOeste"),
		CAMINO,
		camino
	)
	_revisar_portal(
		"D0 Viñedo en Prenda → Camino (salida del fondo)",
		vinedo.get_node_or_null(^"Teleporters/SalidaEste"),
		CAMINO,
		camino
	)
	_revisar_portal(
		"D0 Villarrúbrica → Archivo Bajo",
		villarrubrica.get_node_or_null(^"Teleporters/TeleporterArchivoBajo"),
		ARCHIVO,
		archivo
	)
	_revisar_portal(
		"D0 Archivo Bajo → Villarrúbrica (salida oeste)",
		archivo.get_node_or_null(^"Teleporters/SalidaOeste"),
		VILLARRUBRICA,
		villarrubrica
	)
	_revisar_portal(
		"D0 Archivo Bajo → Villarrúbrica (salida del fondo)",
		archivo.get_node_or_null(^"Teleporters/SalidaEste"),
		VILLARRUBRICA,
		villarrubrica
	)

	camino.free()
	villarrubrica.free()
	vinedo.free()
	archivo.free()
	await _fisica(1)


# --- D1: Viñedo en Prenda (E13) -------------------------------------------


func _d1_vinedo_en_prenda() -> void:
	print("-- D1 Viñedo en Prenda (E13): dos bloques en mora")
	var vinedo := await _montar(VINEDO, "Vinedo")

	var aljibe: Aljibe = vinedo.aljibe
	var parra: ParraSeca = vinedo.parra
	var tranquera: BloqueEmpujable = vinedo.tranquera
	var marco: PlacaPresion = vinedo.marco_tranquera
	var bloque_parra: BloqueEnMora = vinedo.bloque_parra
	var bloque_tranquera: BloqueEnMora = vinedo.bloque_tranquera
	var sello_parra: PlacaPresion = vinedo.sello_parra
	var sello_tranquera: PlacaPresion = vinedo.sello_tranquera
	var puerta: PuertaSellada = vinedo.puerta_final

	var resueltos: Array[int] = [0]
	vinedo.dungeon_resuelto.connect(func() -> void: resueltos[0] += 1)
	var cumplidas: Array[int] = [0]
	vinedo.tareas_cumplidas.connect(func() -> void: cumplidas[0] += 1)

	_check("D1 la puerta del fondo arranca cerrada", not puerta.abierta)
	_check("D1 la puerta cerrada colisiona como pared", _colisiona_como_pared(puerta))
	_check(
		"D1 los dos bloques arrancan en mora",
		bloque_parra.en_mora and bloque_tranquera.en_mora
	)
	_check(
		"D1 un bloque en mora no se puede empujar",
		not bloque_parra.puede_moverse(Vector2i.UP)
		and not bloque_parra.intentar_empujar(Vector2i.UP)
	)
	_check("D1 la tranquera caída sí se puede empujar", tranquera.puede_moverse(Vector2i.RIGHT))

	# Tarea 1: regar la parra del cerco sur (el balde pierde: dos viajes).
	_check("D1 regar sin agua no cuenta", not parra.regar() and parra.baldes == 0)
	_check("D1 el aljibe carga el balde", aljibe.cargar() and aljibe.tiene_agua())
	_check("D1 primer balde volcado", parra.regar() and parra.baldes == 1)
	_check("D1 el balde queda vacío tras regar", not aljibe.tiene_agua())
	_check(
		"D1 con un solo balde el bloque sigue en mora",
		bloque_parra.en_mora and not parra.viva
	)
	# El segundo viaje va por el camino real: el botón de interacción.
	aljibe.interact_area.start_interaction(null, false)
	await _fisica(3)
	_check("D1 el aljibe carga por interacción del jugador", aljibe.tiene_agua())
	parra.interact_area.start_interaction(null, false)
	await _fisica(3)
	_check("D1 la parra se riega por interacción del jugador", parra.baldes == 2)
	_check("D1 la parra quedó regada", parra.viva)
	_check("D1 cumplir alivió el bloque de la parra", not bloque_parra.en_mora)

	# Tarea 2: devolver la tranquera al tercer poste.
	var pasos := 0
	for _i in 4:
		if marco.occupied:
			break
		if not await _empujar(tranquera, Vector2i.RIGHT):
			break
		pasos += 1
	_check("D1 la tranquera llegó al tercer poste", marco.occupied, "pasos=%d" % pasos)
	_check("D1 el marco quedó calzado (placa permanente)", marco.permanente and marco.occupied)
	await _fisica(2)
	_check("D1 cumplir alivió el bloque de la tranquera", not bloque_tranquera.en_mora)
	_check("D1 las dos tareas quedaron cumplidas", cumplidas[0] == 1, str(cumplidas))
	_check("D1 la lámpara de palabra del porche prendió", vinedo.lampara_encendida())

	# Los bloques aliviados van a sus baldosas-sello.
	_check("D1 el bloque aliviado ya se puede empujar", await _empujar(bloque_parra, Vector2i.UP))
	await _esperar_hasta(func() -> bool: return sello_parra.occupied)
	_check("D1 primer sello cubierto", sello_parra.occupied)
	_check("D1 con un sello la puerta sigue cerrada", not puerta.abierta and puerta.activas() == 1)

	_check(
		"D1 el segundo bloque aliviado se empuja",
		await _empujar(bloque_tranquera, Vector2i.UP)
	)
	await _esperar_hasta(func() -> bool: return sello_tranquera.occupied)
	_check("D1 segundo sello cubierto", sello_tranquera.occupied)

	await _esperar_hasta(func() -> bool: return puerta.abierta)
	_check("D1 con los dos sellos SE ABRE LA PUERTA DEL FONDO", puerta.abierta)
	_check("D1 la puerta abierta deja pasar", not _colisiona_como_pared(puerta))
	_check("D1 emitió dungeon_resuelto", resueltos[0] == 1, str(resueltos))

	# Recompensa: cofre placeholder en el galpón de Vidal.
	_check("D1 el cofre del galpón se abre", vinedo.cofre.abrir())
	_check("D1 el cofre paga algo", not vinedo.cofre.recompensa.is_empty())
	_check("D1 el cofre no se abre dos veces", not vinedo.cofre.abrir())

	vinedo.queue_free()
	await _fisica(2)


# --- D2: Archivo Bajo (E09) -----------------------------------------------


func _d2_archivo_bajo() -> void:
	print("-- D2 Archivo Bajo (E09): Cerradura de Testigos tutorial")
	var archivo := await _montar(ARCHIVO, "Archivo")

	var estatua: EstatuaTestigo = archivo.primer_rubrica
	var primera: BloqueEmpujable = archivo.estanteria_primera
	var segunda: BloqueEmpujable = archivo.estanteria_segunda
	var estrado: ReceptorDeFe = archivo.estrado
	var puerta: PuertaSellada = archivo.puerta_final

	var resueltos: Array[int] = [0]
	archivo.dungeon_resuelto.connect(func() -> void: resueltos[0] += 1)
	var convergencias: Array[int] = [0]
	archivo.fe_publica_convergio.connect(func() -> void: convergencias[0] += 1)

	_check("D2 la puerta del archivo profundo arranca cerrada", not puerta.abierta)
	_check("D2 la puerta cerrada colisiona como pared", _colisiona_como_pared(puerta))
	_check("D2 el estrado arranca apagado", not estrado.iluminado)
	_check(
		"D2 el Primer Rúbrica arranca mirando al piso",
		estatua.direccion == EstatuaTestigo.Direccion.ABAJO,
		str(estatua.direccion)
	)

	# «Al levante primero. Siempre primero al levante.»
	# El primer giro va por el camino real: el interruptor de tinta.
	estatua.interact_area.start_interaction(null, false)
	await _fisica(3)
	_check(
		"D2 el interruptor de tinta gira la estatua por interacción",
		estatua.direccion != EstatuaTestigo.Direccion.ABAJO,
		str(estatua.direccion)
	)
	var giros := 1
	for _i in 4:
		if estatua.direccion == EstatuaTestigo.Direccion.DERECHA:
			break
		estatua.rotar()
		giros += 1
	await _fisica(3)
	_check(
		"D2 el interruptor de tinta la deja mirando al levante",
		estatua.direccion == EstatuaTestigo.Direccion.DERECHA,
		"giros=%d" % giros
	)
	_check(
		"D2 los anaqueles tapan la mirada",
		not estrado.iluminado and estatua.objetivo_actual == null
	)
	_check("D2 la puerta sigue cerrada con el haz tapado", not puerta.abierta)

	# «Después la letra: corra los anaqueles.»
	# La primera va empujada de verdad: un doble del jugador apoyado contra la
	# cara sur. Si esto pasa, el jugador tiene lugar para empujar en la escena.
	var celda_inicial := primera.celda_actual()
	var jugador := JugadorFalso.crear(primera.global_position + Vector2(0, 48))
	archivo.get_node(^"OnTheGround").add_child(jugador)
	await _fisica(3)
	_check("D2 la estantería siente al que empuja", primera.cuerpos_en_contacto() >= 1)
	jugador.input_vector = Vector2(0, -200)
	await _esperar_hasta(func() -> bool: return primera.celda_actual() != celda_inicial, 4.0)
	jugador.input_vector = Vector2.ZERO
	await _esperar_hasta(func() -> bool: return not primera.deslizandose)
	jugador.queue_free()
	await _fisica(3)
	_check(
		"D2 el jugador corre la primera estantería apoyándose (una celda al norte)",
		primera.celda_actual() == celda_inicial + Vector2i.UP,
		str(primera.celda_actual())
	)
	_check(
		"D2 con una sola estantería corrida el haz no llega",
		not estrado.iluminado and not archivo.haz_en_el_estrado()
	)

	_check("D2 la segunda estantería corre una celda", await _empujar(segunda, Vector2i.UP))
	await _esperar_hasta(func() -> bool: return estrado.iluminado)

	# «Al final, el estrado.»
	_check("D2 el haz cae limpio sobre el estrado", estrado.iluminado)
	_check("D2 el haz apunta al estrado", archivo.haz_en_el_estrado())
	_check("D2 emitió fe_publica_convergio", convergencias[0] == 1, str(convergencias))
	await _esperar_hasta(func() -> bool: return puerta.abierta)
	_check("D2 SE ABRE LA PUERTA DEL ARCHIVO PROFUNDO", puerta.abierta)
	_check("D2 la puerta abierta deja pasar", not _colisiona_como_pared(puerta))
	_check("D2 emitió dungeon_resuelto", resueltos[0] == 1, str(resueltos))
	_check("D2 el archivo devuelve «NO CONSTA»", (archivo.get_node(^"%NoConsta") as Label).visible)

	# El estrado es permanente: volver a tapar el haz no cierra el archivo.
	_check("D2 la estantería vuelve a la línea de vista", await _empujar(segunda, Vector2i.DOWN))
	await _fisica(4)
	_check("D2 el estrado quedó encendido (fe pública ya consta)", estrado.iluminado)
	_check("D2 la puerta quedó abierta (permanente)", puerta.abierta)

	# Recompensa: el resguardo, placeholder. Se abre por interacción.
	archivo.acta_mayor.interact_area.start_interaction(null, false)
	await _fisica(3)
	_check("D2 el Acta Mayor entrega el resguardo por interacción", archivo.acta_mayor.ya_abierto)
	_check("D2 el resguardo tiene texto", not archivo.acta_mayor.recompensa.is_empty())

	archivo.queue_free()
	await _fisica(2)
