# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name TablaDeDrops
extends Resource

## Tabla de drops de cartas de una familia de enemigos: qué cartas de «De Palabra»
## deja el combate por turnos cuando se gana.
##
## Los archivos viven en [code]res://resources/combate/drops/[/code] y los carga
## solo el autoload [code]DropsDeCartas[/code]. Una tabla por familia del guion
## (lobos → Colmillo del Diezmo; quebrantos → Letra chica; tasadores → Interés) y
## una tabla por jefe, con su firma-carta en [member garantizadas].
##
## Cómo se resuelve un encuentro ganado:
## [br]— [member garantizadas] cae [b]una vez[/b] si en el encuentro había al menos
##   un enemigo de la familia (el canal 2 del guion: las firmas de jefe).
## [br]— cada [EntradaDeDrop] tira [b]una vez por enemigo[/b] de la familia
##   (el canal 1: fiadores baratos por familia).

## Nombre de la familia, para logs y para el orden de resolución (alfabético).
@export var familia: String = ""

## A qué enemigos aplica. Se compara contra el nombre de archivo del
## [code].tres[/code] del enemigo ([code]lobo_diezmo[/code]) y contra su
## [member Battler.name] ([code]Lobo del Diezmo[/code]): cualquiera de los dos
## sirve, así una tabla no se rompe si el enemigo se renombra.
@export var enemigos: Array[String] = []

## Cartas que caen siempre (una vez por encuentro ganado). Canal 2: firmas de jefe.
@export var garantizadas: Array[String] = []

## Drops por probabilidad, una tirada por enemigo derrotado de la familia.
@export var entradas: Array[EntradaDeDrop] = []


## ¿Esta tabla aplica a ese enemigo? [param claves] son las claves del enemigo
## (nombre de archivo y nombre visible).
func aplica_a(claves: Array) -> bool:
	for clave: Variant in claves:
		if enemigos.has(String(clave)):
			return true
	return false


func validar() -> Array[String]:
	var errores: Array[String] = []
	if familia.strip_edges().is_empty():
		errores.append("%s: tabla sin familia" % resource_path)
	if enemigos.is_empty():
		errores.append("%s: tabla sin enemigos" % familia)
	for id: String in garantizadas:
		if not CatalogoDePalabra.existe(id):
			errores.append("%s: carta garantizada desconocida: %s" % [familia, id])
	for e: EntradaDeDrop in entradas:
		if e == null:
			errores.append("%s: entrada nula" % familia)
			continue
		for err: String in e.validar():
			errores.append("%s: %s" % [familia, err])
	return errores
