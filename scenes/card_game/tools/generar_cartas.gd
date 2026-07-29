# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends SceneTree

## Pipeline de cartas: `data/cartas/fuente/cartas.json` → `data/cartas/tres/*.tres`.
##
## Es la mitad «data_src → .tres» de la convención del proyecto, y el motivo por
## el que no se usa `JsonCardFactory` (diseño § 6.2.5): acá el JSON se valida una
## sola vez, los errores se reportan y el proceso **sale con código != 0**; no hay
## forma de colgar Godot con un dato malo.
##
## Uso:
## [codeblock]
## godot --headless --path . -s res://scenes/card_game/tools/generar_cartas.gd
## [/codeblock]

const DESTINO: String = "res://data/cartas/tres"


func _initialize() -> void:
	var errores: Array[String] = generar()
	if errores.is_empty():
		print("OK — cartas generadas en %s" % DESTINO)
		quit(0)
		return
	for e: String in errores:
		printerr("ERROR de datos: %s" % e)
	printerr("FALLÓ — %d error(es) de datos" % errores.size())
	quit(1)


static func generar() -> Array[String]:
	var errores: Array[String] = []
	var texto: String = FileAccess.get_file_as_string(CatalogoDePalabra.RUTA_FUENTE)
	if texto.is_empty():
		errores.append("no se pudo leer %s" % CatalogoDePalabra.RUTA_FUENTE)
		return errores
	var crudo: Variant = JSON.parse_string(texto)
	if typeof(crudo) != TYPE_DICTIONARY:
		errores.append("%s no es un objeto JSON válido" % CatalogoDePalabra.RUTA_FUENTE)
		return errores
	var raiz: Dictionary = crudo
	var lista: Array = raiz.get("cartas", [])
	if lista.is_empty():
		errores.append("no hay cartas en la fuente")
		return errores
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(DESTINO)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINO))
	var vistos: Dictionary = {}
	for entrada_v: Variant in lista:
		if typeof(entrada_v) != TYPE_DICTIONARY:
			errores.append("entrada que no es objeto")
			continue
		var entrada: Dictionary = entrada_v
		var carta: CartaDePalabra = _desde_dict(entrada)
		var propios: Array[String] = carta.validar()
		if not propios.is_empty():
			for p: String in propios:
				errores.append(p)
			continue
		if vistos.has(carta.id):
			errores.append("id duplicado en la fuente: %s" % carta.id)
			continue
		vistos[carta.id] = true
		var ruta: String = "%s/%s.tres" % [DESTINO, carta.id]
		var err: int = ResourceSaver.save(carta, ruta)
		if err != OK:
			errores.append("no se pudo guardar %s (error %d)" % [ruta, err])
	# Coherencia entre cartas: toda carta invocada o transformada tiene que existir.
	for entrada_v2: Variant in lista:
		var entrada2: Dictionary = entrada_v2
		for referida: String in _referencias(entrada2):
			if not vistos.has(referida):
				errores.append(
					"%s referencia una carta inexistente: %s" % [entrada2.get("id", "?"), referida]
				)
	return errores


static func _referencias(entrada: Dictionary) -> Array[String]:
	var salida: Array[String] = []
	var fuentes: Array = []
	fuentes.append_array(entrada.get("efectos", []))
	for oferta_v: Variant in entrada.get("promesas", []):
		var oferta: Dictionary = oferta_v
		fuentes.append_array(oferta.get("bonus", []))
	for e_v: Variant in fuentes:
		if typeof(e_v) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = e_v
		var referida: String = String(e.get("carta", ""))
		if not referida.is_empty():
			salida.append(referida)
	return salida


static func _desde_dict(d: Dictionary) -> CartaDePalabra:
	var c: CartaDePalabra = CartaDePalabra.new()
	c.id = String(d.get("id", ""))
	c.nombre = String(d.get("nombre", ""))
	c.texto = String(d.get("texto", ""))
	c.lore = String(d.get("lore", ""))
	c.arquetipo = String(d.get("arquetipo", "neutral"))
	c.tipo = int(d.get("tipo", 0))
	c.coste_base = int(d.get("coste_base", 0))
	c.ataque_base = int(d.get("ataque_base", 0))
	c.aguante_base = int(d.get("aguante_base", 0))
	c.dano_base = int(d.get("dano_base", 0))
	c.es_token = bool(d.get("es_token", false))
	c.es_legendaria = bool(d.get("es_legendaria", false))
	c.puede_prometer = bool(d.get("puede_prometer", true))
	c.modulo = String(d.get("modulo", ""))
	c.bloqueada = bool(d.get("bloqueada", false))
	c.arte = String(d.get("arte", ""))
	var kws: Array[String] = []
	for kw_v: Variant in d.get("keywords", []):
		kws.append(String(kw_v))
	c.keywords = kws
	var objs: Array[String] = []
	for o_v: Variant in d.get("objetivos", []):
		objs.append(String(o_v))
	c.objetivos = objs
	var efs: Array[Dictionary] = []
	for e_v: Variant in d.get("efectos", []):
		efs.append(_normalizar(e_v) as Dictionary)
	c.efectos = efs
	var prs: Array[Dictionary] = []
	for p_v: Variant in d.get("promesas", []):
		prs.append(_normalizar(p_v) as Dictionary)
	c.promesas = prs
	c.bono_dinamico = _normalizar(d.get("bono_dinamico", {})) as Dictionary
	c.resource_name = c.id
	return c


## JSON devuelve todo número como float. Los pasa a int cuando son enteros, así
## los `.tres` quedan legibles y `int()` no sorprende a nadie.
static func _normalizar(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var d: Dictionary = v
			var salida: Dictionary = {}
			for k: Variant in d.keys():
				salida[String(k)] = _normalizar(d[k])
			return salida
		TYPE_ARRAY:
			var a: Array = v
			var lista: Array = []
			for x: Variant in a:
				lista.append(_normalizar(x))
			return lista
		TYPE_FLOAT:
			var f: float = v
			return int(f) if is_equal_approx(f, floor(f)) else f
	return v
