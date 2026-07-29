# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name CatalogoDePalabra
extends RefCounted

## Catálogo de definiciones de carta: lee los [CartaDePalabra] del pipeline
## (`data/cartas/fuente/*.json` → `data/cartas/tres/*.tres`).
##
## **No usa [code]JsonCardFactory[/code]** (diseño § 6.2.5: sus dos `continue` no
## avanzan el índice y un dato malo cuelga Godot al arrancar sin error legible).
## Acá cada archivo se procesa una vez, los errores se reportan con `push_error`
## y el catálogo sigue: nunca hay loop.

const RUTA_TRES: String = "res://data/cartas/tres"
const RUTA_FUENTE: String = "res://data/cartas/fuente/cartas.json"

static var _cache: Dictionary = {}
static var _errores: Array[String] = []


## Devuelve el catálogo completo: id -> [CartaDePalabra]. Cachea.
static func cargar(forzar: bool = false) -> Dictionary:
	if not forzar and not _cache.is_empty():
		return _cache
	_cache = {}
	_errores = []
	var dir: DirAccess = DirAccess.open(RUTA_TRES)
	if dir == null:
		_errores.append("no se pudo abrir %s" % RUTA_TRES)
		push_error("CatalogoDePalabra: no se pudo abrir %s" % RUTA_TRES)
		return _cache
	var archivos: PackedStringArray = dir.get_files()
	# Un solo pase, sin `continue` que no avance: el bug del addon no se repite.
	for archivo: String in archivos:
		var nombre: String = archivo
		if nombre.ends_with(".remap"):
			nombre = nombre.trim_suffix(".remap")
		if not nombre.ends_with(".tres"):
			continue
		var ruta: String = "%s/%s" % [RUTA_TRES, nombre]
		var res: Resource = ResourceLoader.load(
			ruta, "CartaDePalabra", ResourceLoader.CACHE_MODE_REUSE
		)
		var carta: CartaDePalabra = res as CartaDePalabra
		if carta == null:
			_errores.append("%s: no es una CartaDePalabra" % ruta)
			push_error("CatalogoDePalabra: %s no es una CartaDePalabra" % ruta)
			continue
		var errores: Array[String] = carta.validar()
		if not errores.is_empty():
			for e: String in errores:
				_errores.append(e)
				push_error("CatalogoDePalabra: %s" % e)
			continue
		if _cache.has(carta.id):
			_errores.append("id duplicado: %s" % carta.id)
			push_error("CatalogoDePalabra: id duplicado %s" % carta.id)
			continue
		_cache[carta.id] = carta
	return _cache


static func obtener(id: String) -> CartaDePalabra:
	var todo: Dictionary = cargar()
	if not todo.has(id):
		push_error("CatalogoDePalabra: no existe la carta '%s'" % id)
		return null
	return todo[id] as CartaDePalabra


static func existe(id: String) -> bool:
	return cargar().has(id)


static func ids() -> Array[String]:
	var salida: Array[String] = []
	for k: String in cargar().keys():
		salida.append(k)
	salida.sort()
	return salida


## Errores del último [method cargar]. Vacío = set válido.
static func errores() -> Array[String]:
	cargar()
	return _errores.duplicate()


## Cartas que un mazo puede usar en una mesa dada (§ 4: una carta de módulo
## apagado no entra al mazo; los tokens y las bloqueadas tampoco).
static func armables(mesa: ConfigMesa) -> Array[String]:
	var salida: Array[String] = []
	for id: String in ids():
		var c: CartaDePalabra = obtener(id)
		if c == null or c.es_token or c.bloqueada:
			continue
		if not c.modulo.is_empty() and not mesa.tiene(c.modulo):
			continue
		salida.append(id)
	return salida
