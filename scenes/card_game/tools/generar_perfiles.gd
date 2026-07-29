# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends SceneTree

## Pipeline de perfiles de IA: `data/perfiles_ia/fuente/perfiles.json` →
## `data/perfiles_ia/tres/*.tres` (diseño § 7.1: `PerfilIA` es un `Resource`).
##
## Mismo contrato que `generar_cartas.gd`: el JSON se valida una sola vez, los
## errores se imprimen y el proceso sale con código != 0. No hay forma de colgar
## Godot con un dato malo.
##
## Uso:
## [codeblock]
## godot --headless --path . -s res://scenes/card_game/tools/generar_perfiles.gd
## [/codeblock]

const DESTINO: String = "res://data/perfiles_ia/tres"


func _initialize() -> void:
	var errores: Array[String] = generar()
	if errores.is_empty():
		print("OK — perfiles generados en %s" % DESTINO)
		quit(0)
		return
	for e: String in errores:
		printerr("ERROR de datos: %s" % e)
	printerr("FALLÓ — %d error(es) de datos" % errores.size())
	quit(1)


static func generar() -> Array[String]:
	var errores: Array[String] = []
	var texto: String = FileAccess.get_file_as_string(CatalogoDePerfiles.RUTA_FUENTE)
	if texto.is_empty():
		errores.append("no se pudo leer %s" % CatalogoDePerfiles.RUTA_FUENTE)
		return errores
	var crudo: Variant = JSON.parse_string(texto)
	if typeof(crudo) != TYPE_DICTIONARY:
		errores.append("%s no es un objeto JSON válido" % CatalogoDePerfiles.RUTA_FUENTE)
		return errores
	var raiz: Dictionary = crudo
	var lista: Array = raiz.get("perfiles", [])
	if lista.is_empty():
		errores.append("no hay perfiles en la fuente")
		return errores
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(DESTINO)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINO))
	var vistos: Dictionary = {}
	for entrada_v: Variant in lista:
		if typeof(entrada_v) != TYPE_DICTIONARY:
			errores.append("entrada de perfil que no es objeto")
			continue
		var perfil: PerfilIA = _desde_dict(entrada_v as Dictionary)
		var propios: Array[String] = perfil.validar()
		if not propios.is_empty():
			errores.append_array(propios)
			continue
		if vistos.has(perfil.id):
			errores.append("id de perfil duplicado en la fuente: %s" % perfil.id)
			continue
		vistos[perfil.id] = true
		var err: int = ResourceSaver.save(perfil, "%s/%s.tres" % [DESTINO, perfil.id])
		if err != OK:
			errores.append("no se pudo guardar el perfil %s (error %d)" % [perfil.id, err])
	# Las cartas que nombra un guion de tutorial tienen que existir en el set.
	for entrada_v2: Variant in lista:
		var entrada2: Dictionary = entrada_v2
		for paso_v: Variant in entrada2.get("guion_forzado", []):
			var paso: Dictionary = paso_v
			var carta: String = String(paso.get("carta", ""))
			if carta.is_empty():
				continue
			if not CatalogoDePalabra.existe(carta):
				errores.append(
					(
						"%s: el guion nombra una carta inexistente: %s"
						% [entrada2.get("id", "?"), carta]
					)
				)
	for id: String in CatalogoDePerfiles.PERFILES_ACTO1:
		if not vistos.has(id):
			errores.append("falta el perfil '%s' que pide el § 7.3" % id)
	return errores


static func _desde_dict(d: Dictionary) -> PerfilIA:
	var p: PerfilIA = PerfilIA.new()
	p.id = String(d.get("id", ""))
	p.nombre = String(d.get("nombre", ""))
	p.peso_tempo = float(d.get("peso_tempo", 1.0))
	p.peso_cara = float(d.get("peso_cara", 1.0))
	p.peso_tabla = float(d.get("peso_tabla", 1.0))
	p.peso_mano = float(d.get("peso_mano", 1.0))
	p.sesgo_promesa = float(d.get("sesgo_promesa", 0.5))
	p.sesgo_desconfianza = float(d.get("sesgo_desconfianza", 0.0))
	p.umbral_trade = float(d.get("umbral_trade", 0.3))
	p.prob_senuelo = float(d.get("prob_senuelo", 0.0))
	var curva: Array[int] = []
	for c_v: Variant in d.get("curva_preferida", []):
		curva.append(int(c_v))
	p.curva_preferida = curva
	var kws: Array[String] = []
	for k_v: Variant in d.get("keywords_prioritarias", []):
		kws.append(String(k_v))
	p.keywords_prioritarias = kws
	var guion: Array[Dictionary] = []
	for paso_v: Variant in d.get("guion_forzado", []):
		if typeof(paso_v) != TYPE_DICTIONARY:
			continue
		var paso: Dictionary = paso_v
		var limpio: Dictionary = {}
		for k: Variant in paso.keys():
			var clave: String = String(k)
			var valor: Variant = paso[k]
			limpio[clave] = int(valor) if typeof(valor) == TYPE_FLOAT else valor
		guion.append(limpio)
	p.guion_forzado = guion
	p.resource_name = p.id
	return p
