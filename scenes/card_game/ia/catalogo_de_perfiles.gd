# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name CatalogoDePerfiles
extends RefCounted

## Catálogo de [PerfilIA]: lee los `.tres` que dejó el pipeline
## (`data/perfiles_ia/fuente/perfiles.json` → `data/perfiles_ia/tres/*.tres`).
##
## Mismo patrón anti-cuelgue que [CatalogoDePalabra] (diseño § 6.2.5): un solo
## pase por archivo, `push_error` legible y el catálogo sigue. Nada de
## `JsonCardFactory`.

const RUTA_TRES: String = "res://data/perfiles_ia/tres"
const RUTA_FUENTE: String = "res://data/perfiles_ia/fuente/perfiles.json"

## Los perfiles que el Acto 1 necesita (§ 7.3 + el mazo de la casa de E03).
const PERFILES_ACTO1: Array[String] = [
	"casa",
	"garante",
	"letra_chica",
	"interes",
	"de_palabra",
	"al_contado",
	"senuelos",
	"control",
]

static var _cache: Dictionary = {}
static var _errores: Array[String] = []


## id -> [PerfilIA]. Cachea.
static func cargar(forzar: bool = false) -> Dictionary:
	if not forzar and not _cache.is_empty():
		return _cache
	_cache = {}
	_errores = []
	var dir: DirAccess = DirAccess.open(RUTA_TRES)
	if dir == null:
		_errores.append("no se pudo abrir %s" % RUTA_TRES)
		push_error("CatalogoDePerfiles: no se pudo abrir %s" % RUTA_TRES)
		return _cache
	for archivo: String in dir.get_files():
		var nombre: String = archivo
		if nombre.ends_with(".remap"):
			nombre = nombre.trim_suffix(".remap")
		if not nombre.ends_with(".tres"):
			continue
		var ruta: String = "%s/%s" % [RUTA_TRES, nombre]
		# SIN type_hint a propósito: en un build exportado los .tres se convierten
		# a .res binarios y el loader no reconoce el nombre de una clase custom de
		# GDScript, así que pedirle "PerfilIA" hace fallar el load con
		# «No loader found for resource ... (expected type: PerfilIA)».
		# El tipo se valida abajo con el cast.
		var res: Resource = ResourceLoader.load(ruta, "", ResourceLoader.CACHE_MODE_REUSE)
		var perfil: PerfilIA = res as PerfilIA
		if perfil == null:
			_errores.append("%s: no es un PerfilIA" % ruta)
			push_error("CatalogoDePerfiles: %s no es un PerfilIA" % ruta)
			continue
		var errores: Array[String] = perfil.validar()
		if not errores.is_empty():
			for e: String in errores:
				_errores.append(e)
				push_error("CatalogoDePerfiles: %s" % e)
			continue
		if _cache.has(perfil.id):
			_errores.append("id de perfil duplicado: %s" % perfil.id)
			push_error("CatalogoDePerfiles: id duplicado %s" % perfil.id)
			continue
		_cache[perfil.id] = perfil
	return _cache


static func obtener(id: String) -> PerfilIA:
	var todo: Dictionary = cargar()
	if not todo.has(id):
		push_error("CatalogoDePerfiles: no existe el perfil '%s'" % id)
		return null
	return todo[id] as PerfilIA


static func existe(id: String) -> bool:
	return cargar().has(id)


static func ids() -> Array[String]:
	var salida: Array[String] = []
	for k: String in cargar().keys():
		salida.append(k)
	salida.sort()
	return salida


## Errores del último [method cargar]. Vacío = perfiles válidos.
static func errores() -> Array[String]:
	cargar()
	return _errores.duplicate()


## Copia del perfil con un campo cambiado, sin tocar el recurso del catálogo.
## Sirve para el guion (un rival con el mismo motor y un sesgo distinto) y para los
## tests del defecto de Salu.
static func variante(id: String, campo: String, valor: Variant) -> PerfilIA:
	var base: PerfilIA = obtener(id)
	if base == null:
		return null
	var copia: PerfilIA = base.duplicate(true) as PerfilIA
	copia.set(campo, valor)
	return copia
