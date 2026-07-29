# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
extends Node

## Regresión de F4: carga los 4 mapas del Acto 1 + los 2 dungeons nuevos y
## verifica la integridad de TODOS los teleporters del capítulo: que el
## [code]next_scene[/code] resuelva y que el [code]spawn_point_path[/code] exista
## de verdad en la escena destino (round-trip mapa <-> dungeon incluido).

const ESCENAS: Array[String] = [
	"res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja.tscn",
	"res://scenes/quests/story_quests/la_deuda_del_sol/el_fiado.tscn",
	"res://scenes/quests/story_quests/la_deuda_del_sol/camino_del_diezmo.tscn",
	"res://scenes/quests/story_quests/la_deuda_del_sol/villarrubrica.tscn",
	"res://scenes/quests/story_quests/la_deuda_del_sol/vinedo_en_prenda/vinedo_en_prenda.tscn",
	"res://scenes/quests/story_quests/la_deuda_del_sol/archivo_bajo/archivo_bajo.tscn",
]

var _total: int = 0
var _fallos: int = 0


func _ready() -> void:
	print("== REGRESIÓN F4: mapas del Acto 1 + integridad de portales ==")
	var reloj := get_tree().create_timer(120.0, true, false, true)
	reloj.timeout.connect(
		func() -> void:
			print("FAIL - la regresión se colgó")
			print("REGRESION FALLÓ")
			get_tree().quit(1)
	)

	# 1) Cada escena instancia, corre unos cuadros y se libera sin explotar.
	for ruta: String in ESCENAS:
		await _cargar_y_correr(ruta)

	# 2) Integridad de portales entre escenas.
	await _integridad_de_portales()

	print("== RESUMEN REGRESIÓN: %d chequeos, %d fallos ==" % [_total, _fallos])
	print("REGRESION OK" if _fallos == 0 else "REGRESION FALLÓ")
	get_tree().quit(1 if _fallos > 0 else 0)


func _check(nombre: String, ok: bool, detalle: String = "") -> void:
	_total += 1
	if ok:
		print("PASS - %s" % nombre)
		return
	_fallos += 1
	print("FAIL - %s%s" % [nombre, "" if detalle.is_empty() else " (%s)" % detalle])


func _cargar_y_correr(ruta: String) -> void:
	var nombre := ruta.get_file()
	var paquete := load(ruta) as PackedScene
	_check("carga %s" % nombre, paquete != null)
	if paquete == null:
		return
	var raiz: Node = paquete.instantiate()
	add_child(raiz)
	for _i in 12:
		await get_tree().physics_frame
	_check("%s corre 12 cuadros y sigue viva" % nombre, is_instance_valid(raiz))
	# El jugador tiene que existir y estar en el grupo player.
	var jugadores := get_tree().get_nodes_in_group(&"player")
	_check("%s tiene exactamente 1 jugador" % nombre, jugadores.size() == 1, "n=%d" % jugadores.size())
	raiz.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame


func _integridad_de_portales() -> void:
	print("-- integridad de portales (next_scene + spawn_point_path)")
	# Mapa uid -> ruta, para resolver los next_scene.
	var por_uid: Dictionary = {}
	for ruta: String in ESCENAS:
		por_uid[ResourceUID.path_to_uid(ruta)] = ruta

	var portales := 0
	for ruta: String in ESCENAS:
		var nombre := ruta.get_file()
		var paquete := load(ruta) as PackedScene
		if paquete == null:
			continue
		var raiz: Node = paquete.instantiate()
		for tele: Node in _teleporters(raiz):
			portales += 1
			var destino: String = str(tele.next_scene)
			var etiqueta := "%s/%s" % [nombre, tele.name]

			var paquete_destino := load(destino) as PackedScene
			_check("%s: next_scene resuelve" % etiqueta, paquete_destino != null, destino)
			if paquete_destino == null:
				continue

			var camino: NodePath = tele.spawn_point_path
			if camino.is_empty():
				_check("%s: sin spawn_point_path (usa default)" % etiqueta, true)
				continue
			var destino_raiz: Node = paquete_destino.instantiate()
			var punto := destino_raiz.get_node_or_null(camino)
			_check(
				"%s: spawn_point_path '%s' EXISTE en el destino" % [etiqueta, camino],
				punto != null,
				"destino=%s" % destino.get_file()
			)
			if punto != null:
				_check(
					"%s: el spawn está en el grupo spawn_point" % etiqueta,
					punto.is_in_group(&"spawn_point")
				)
			destino_raiz.free()
		raiz.free()
		await get_tree().process_frame

	_check("hay portales que revisar", portales >= 8, "portales=%d" % portales)
	print("--   portales revisados: %d" % portales)


func _teleporters(raiz: Node) -> Array[Node]:
	var salida: Array[Node] = []
	for nodo: Node in _todos(raiz):
		if "next_scene" in nodo and "spawn_point_path" in nodo:
			salida.append(nodo)
	return salida


func _todos(raiz: Node) -> Array[Node]:
	var salida: Array[Node] = [raiz]
	for hijo: Node in raiz.get_children():
		salida.append_array(_todos(hijo))
	return salida
