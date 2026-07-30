# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name EntradaDeDrop
extends Resource

## Una línea de una [TablaDeDrops]: qué carta puede caer y con qué probabilidad.
##
## La tirada es [b]por enemigo derrotado[/b] de la familia: si en el encuentro
## había tres lobos, la entrada tira tres veces.

## Id de la carta en el set (`data/cartas/`).
@export var carta_id: String = ""

## Probabilidad por enemigo derrotado. 1.0 = siempre.
@export_range(0.0, 1.0, 0.01) var chance: float = 0.25

## Cuántas copias entrega cuando sale.
@export var cantidad: int = 1


func validar() -> Array[String]:
	var errores: Array[String] = []
	if carta_id.strip_edges().is_empty():
		errores.append("entrada de drop sin carta_id")
	elif not CatalogoDePalabra.existe(carta_id):
		errores.append("entrada de drop con carta desconocida: %s" % carta_id)
	if chance < 0.0 or chance > 1.0:
		errores.append("%s: chance fuera de 0..1 (%f)" % [carta_id, chance])
	if cantidad <= 0:
		errores.append("%s: cantidad %d" % [carta_id, cantidad])
	return errores
