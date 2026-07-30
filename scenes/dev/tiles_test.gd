# SPDX-FileCopyrightText: The Threadbare Authors
#
# SPDX-License-Identifier: MPL-2.0

## Diagnóstico de la escena de prueba de [code]tiles_pueblo.tres[/code].
##
## Imprime cuántas celdas pintó cada [TileMapLayer] y verifica que las baldosas
## que deben frenar al jugador (paredes, techos, agua, cercos, árboles) tengan
## polígono de física, y que las caminables (pasto, camino, plaza, puertas) no.
## Con [code]--tiles-check[/code] en la línea de comandos cierra al terminar.
extends Node2D

const CAPA_PAREDES := 16
const CAPA_PISO_NO_CAMINABLE := 512

## Celdas que tienen que frenar al jugador (paredes 16 o piso-no-caminable 512).
@export var celdas_solidas: Array[Vector2i] = [
	Vector2i(4, 2),  # techo casa A
	Vector2i(4, 4),  # pared casa A
	Vector2i(10, 4),  # pared casa B
	Vector2i(2, 5),  # tronco de árbol
	Vector2i(3, 11),  # cerco horizontal
	Vector2i(16, 12),  # pozo
	Vector2i(26, 13),  # agua de la laguna
	Vector2i(18, 12),  # horno
	Vector2i(21, 13),  # lápida
]

## Celdas que tienen que ser caminables.
@export var celdas_caminables: Array[Vector2i] = [
	Vector2i(0, 0),  # pasto
	Vector2i(8, 8),  # camino de tierra
	Vector2i(5, 5),  # puerta casa A
	Vector2i(11, 5),  # puerta casa B
	Vector2i(4, 13),  # portillo del cerco
	Vector2i(16, 15),  # plaza
	Vector2i(1, 16),  # cantero de flores
]


func _ready() -> void:
	var capas: Node2D = $TileMapLayers
	var total: int = 0
	for capa: Node in capas.get_children():
		var tml := capa as TileMapLayer
		if tml == null:
			continue
		var n: int = tml.get_used_cells().size()
		total += n
		print("[tiles_test] capa %s: %d celdas" % [tml.name, n])
	print("[tiles_test] total de celdas pintadas: %d" % total)

	var fallas: PackedStringArray = []
	for celda: Vector2i in celdas_solidas:
		if _mascara_en(capas, celda) == 0:
			fallas.append("%s debería colisionar y no colisiona" % celda)
	for celda: Vector2i in celdas_caminables:
		var mascara: int = _mascara_en(capas, celda)
		if mascara != 0:
			fallas.append("%s debería ser caminable (máscara %d)" % [celda, mascara])

	if fallas.is_empty():
		print("[tiles_test] OK: colisiones y caminables como se esperaba")
	else:
		for falla: String in fallas:
			push_error("[tiles_test] %s" % falla)

	if "--tiles-check" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		get_tree().quit(0 if fallas.is_empty() else 1)


## Devuelve la unión de capas de colisión que aportan las baldosas en [param celda].
func _mascara_en(capas: Node2D, celda: Vector2i) -> int:
	var mascara: int = 0
	for capa: Node in capas.get_children():
		var tml := capa as TileMapLayer
		if tml == null:
			continue
		var datos: TileData = tml.get_cell_tile_data(celda)
		if datos == null:
			continue
		var conjunto: TileSet = tml.tile_set
		for i: int in conjunto.get_physics_layers_count():
			if datos.get_collision_polygons_count(i) > 0:
				mascara |= conjunto.get_physics_layer_collision_layer(i)
	return mascara
