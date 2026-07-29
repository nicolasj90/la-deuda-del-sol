# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name PruebaSetDeCartas
extends SuiteDePalabra

## Contrato del set de cartas con el diseño y con el guion (diseño § 8.5).
##
## Tres cosas:
## 1. Las **42 caras** del § 5 están, con los números y los textos del documento,
##    y el validador del pipeline **termina siempre** (el bug del loop infinito de
##    `JsonCardFactory`, § 6.2.5, no se puede repetir acá).
## 2. Las **manos anunciadas** de Ciro (INDICE § 4f.1) son servibles con lo que los
##    canales del § 5.10 entregaron **antes** de esa escena. Es la regla no
##    negociable «Ciro no puede mentir ni por desincronización».
## 3. Toda carta coleccionable tiene canal, o está en la lista documentada de
##    huecos (§ 5.10 deja dos cartas sin entregar: el test lo cuida como regresión).

const RUTA_CANALES: String = "res://data/cartas/fuente/canales.json"

## Presupuesto de tiempo del validador del set completo. No es un test de
## performance: es el centinela anti-cuelgue (§ 6.2.5).
const MS_MAX_VALIDAR: int = 5000

## Cartas por arquetipo, tal como las agrupa el § 5.
const POR_ARQUETIPO: Dictionary = {
	"neutral": 6,  # § 5.1
	"garante": 5,  # § 5.2
	"letra_chica": 6,  # § 5.3
	"interes": 5,  # § 5.4
	"de_palabra": 5,  # § 5.5
	"al_contado": 4,  # § 5.6
	"palabra_rota": 4,  # § 5.7
	"postgame": 1,  # § 5.8
	"token": 6,  # § 5.9
}

## Las 42 caras del § 5, transcriptas del documento.
## [code][arquetipo, tipo, coste, ataque, aguante, dano, keywords, banderas][/code]
## Tipo: 0 Fiador · 1 Soporte · 2 Cláusula. Banderas: `token`, `leg`, `bloqueada`,
## `sin_promesas`, `mod:<módulo>`.
const TABLA: Dictionary = {
	# § 5.1 Neutrales
	"gallina_lacrevieja": ["neutral", 0, 1, 1, 1, 0, "", ""],
	"peon_de_vina": ["neutral", 0, 2, 2, 2, 0, "", ""],
	"mula_de_reparto": ["neutral", 0, 3, 3, 3, 0, "", ""],
	"colmillo_del_diezmo": ["neutral", 0, 2, 3, 2, 0, "", ""],
	"lampara_de_palabra": ["neutral", 1, 2, 0, 3, 0, "", ""],
	"fe_de_erratas": ["neutral", 2, 2, 0, 0, 0, "", ""],
	# § 5.2 Garante — Rosaura
	"tranquera_cerrada": ["garante", 1, 1, 0, 4, 0, "garante", ""],
	"hornera_de_rosaura": ["garante", 0, 2, 1, 4, 0, "garante", ""],
	"sereno_del_archivo": ["garante", 0, 3, 2, 4, 0, "garante|sello", ""],
	"porteador_empenadero": ["garante", 0, 4, 2, 5, 0, "garante", ""],
	"de_mi_mesa_nadie": ["garante", 2, 3, 0, 0, 0, "", ""],
	# § 5.3 Letra chica — Cosme / Salu
	"deudo_del_difunto": ["letra_chica", 0, 1, 1, 1, 0, "letra_chica", ""],
	"clausula_al_dorso": ["letra_chica", 2, 2, 0, 0, 0, "", ""],
	"sepulturero_cosme": ["letra_chica", 0, 3, 2, 2, 0, "letra_chica", ""],
	"contrato_que_drena": ["letra_chica", 1, 3, 0, 2, 0, "letra_chica", ""],
	"testamento_apurado": ["letra_chica", 2, 4, 0, 0, 0, "", ""],
	"quebranto_del_peaje": ["letra_chica", 0, 5, 4, 4, 0, "letra_chica", ""],
	# § 5.4 Interés — prestamista / Bravante
	"cobrador_de_la_camara": ["interes", 0, 2, 2, 1, 0, "interes", ""],
	"pagare_a_la_vista": ["interes", 2, 1, 0, 0, 2, "interes", ""],
	"lo_suyo_madura": ["interes", 2, 2, 0, 0, 0, "", ""],
	"bravante_el_corredor": ["interes", 0, 5, 4, 4, 0, "", ""],
	"tasador_decano": ["interes", 0, 6, 5, 5, 0, "de_palabra", ""],
	# § 5.5 De palabra — archivista
	"maestra_jardinera": ["de_palabra", 0, 2, 1, 3, 0, "de_palabra", ""],
	"tasadora_ciega": ["de_palabra", 0, 3, 2, 2, 0, "de_palabra", ""],
	"archivista_jubilada": ["de_palabra", 0, 4, 3, 3, 0, "de_palabra", ""],
	"pregon_de_ventanilla": ["de_palabra", 2, 4, 0, 0, 0, "", ""],
	"odila_la_forastera": ["de_palabra", 0, 4, 2, 4, 0, "de_palabra|letra_chica", "leg"],
	# § 5.6 Al contado — Tallador / Cachuzo
	"changuito_del_muelle": ["al_contado", 0, 1, 2, 1, 0, "al_contado", ""],
	"tallador_de_la_puerta": ["al_contado", 0, 3, 3, 2, 0, "al_contado", ""],
	"cobradoras_gemelas":
	["al_contado", 0, 5, 3, 3, 0, "al_contado|de_palabra|letra_chica", "leg"],
	"primera_mentira_gratis": ["al_contado", 2, 2, 0, 0, 0, "", "mod:al_fiado"],
	# § 5.7 Palabra rota / Quebrantos
	"lloron_del_puerto": ["palabra_rota", 0, 2, 2, 2, 0, "", ""],
	"palabra_rota": ["palabra_rota", 2, 3, 0, 0, 0, "", ""],
	"fiel_el_que_espera": ["palabra_rota", 0, 4, 3, 3, 0, "", "leg"],
	"el_amanecer": ["palabra_rota", 2, 10, 0, 0, 0, "", "leg"],
	# § 5.8 Bloqueada en el Acto 1
	"nadia_la_impalabra": ["postgame", 0, 9, 7, 7, 0, "de_palabra", "leg bloqueada sin_promesas"],
	# § 5.9 Tokens
	"gallina_cumplidora": ["token", 0, 1, 2, 3, 0, "sello", "token"],
	"deudo": ["token", 0, 1, 1, 1, 0, "", "token"],
	"quebranto": ["token", 0, 0, 2, 2, 0, "", "token sin_promesas"],
	"copia_espejo": ["token", 0, 5, 3, 3, 0, "al_contado|letra_chica", "token"],
	"la_forastera": ["token", 0, 4, 4, 2, 0, "al_contado", "token"],
	"la_vuelta": ["token", 2, 0, 0, 0, 0, "", "token"],
}

## Las diez de muestra de la biblia: son las únicas que llevan lore, y lo llevan
## palabra por palabra (§ 10, «lo que decidí NO tocar»).
const CON_LORE: Array[String] = [
	"gallina_lacrevieja",
	"cobrador_de_la_camara",
	"tasadora_ciega",
	"lampara_de_palabra",
	"porteador_empenadero",
	"palabra_rota",
	"fiel_el_que_espera",
	"odila_la_forastera",
	"nadia_la_impalabra",
	"el_amanecer",
]


func _init() -> void:
	nombre = "set de cartas y contrato con el guion (§ 8.5)"


func casos() -> Array[String]:
	return [
		"test_set_de_cartas_valida_sin_colgar",
		"test_manos_anunciadas_son_servibles",
		"test_cada_carta_tiene_al_menos_un_canal_de_obtencion",
	]


# --- § 8.5.45 ---


func test_set_de_cartas_valida_sin_colgar() -> void:
	# Recarga forzada y con reloj: si el validador entrara en loop, no habría FAIL
	# sino cuelgue — por eso el presupuesto de tiempo es parte del test.
	var t0: int = Time.get_ticks_msec()
	var catalogo: Dictionary = CatalogoDePalabra.cargar(true)
	var errores: Array[String] = CatalogoDePalabra.errores()
	var ms: int = Time.get_ticks_msec() - t0
	af(ms < MS_MAX_VALIDAR, "el set valida en menos de %d ms (tardó %d)" % [MS_MAX_VALIDAR, ms])
	for e: String in errores:
		af(false, "el set no valida: %s" % e)
	af_eq(catalogo.size(), TABLA.size(), "las 42 caras del § 5 están en el catálogo")

	# Ni una carta de más, ni una de menos, y cada una con los números del § 5.
	var ids: Array[String] = CatalogoDePalabra.ids()
	for id: String in ids:
		af(TABLA.has(id), "'%s' está en el catálogo pero no en el § 5" % id)
	var esperados: Array = TABLA.keys()
	esperados.sort()
	for id_v: Variant in esperados:
		var id: String = id_v
		var c: CartaDePalabra = catalogo.get(id) as CartaDePalabra
		if c == null:
			af(false, "falta la carta '%s' del § 5" % id)
			continue
		_comparar_con_tabla(c, TABLA[id] as Array)

	# Arquetipos: los conteos de las secciones § 5.1 a § 5.9.
	var conteo: Dictionary = {}
	for id: String in ids:
		var c2: CartaDePalabra = catalogo[id] as CartaDePalabra
		conteo[c2.arquetipo] = int(conteo.get(c2.arquetipo, 0)) + 1
	var claves: Array = POR_ARQUETIPO.keys()
	claves.sort()
	for k_v: Variant in claves:
		var k: String = k_v
		af_eq(int(conteo.get(k, 0)), int(POR_ARQUETIPO[k]), "cartas del arquetipo '%s'" % k)

	# Nombre y texto: nombre siempre; texto salvo los vanilla del § 5.
	for id: String in ids:
		var c3: CartaDePalabra = catalogo[id] as CartaDePalabra
		af(not c3.nombre.strip_edges().is_empty(), "%s: nombre vacío" % id)
		af_eq(c3.resource_name, id, "%s: resource_name distinto del id" % id)
	af_eq(
		catalogo["peon_de_vina"].texto,
		"",
		"Peón de Viña es vanilla: el § 5.1 no le da texto de reglas"
	)
	af(
		String(catalogo["el_amanecer"].texto).contains("Cumplí todas tus Promesas pendientes"),
		"El Amanecer conserva el texto del § 5.7"
	)

	# Lore: solo las diez de muestra de la biblia, y ninguna más (no se inventa canon).
	for id: String in ids:
		var c4: CartaDePalabra = catalogo[id] as CartaDePalabra
		if CON_LORE.has(id):
			af(not c4.lore.strip_edges().is_empty(), "%s es de la biblia y le falta el lore" % id)
		else:
			af_eq(c4.lore, "", "%s tiene lore inventado (la biblia no habla de ella)" % id)

	# Coherencia interna: toda carta invocada, transformada o referida existe.
	for id: String in ids:
		var c5: CartaDePalabra = catalogo[id] as CartaDePalabra
		for referida: String in _referencias(c5):
			af(catalogo.has(referida), "%s referencia una carta inexistente: %s" % [id, referida])

	# El validador **termina siempre**, incluso con datos basura: es el punto del
	# § 6.2.5 (los dos `continue` del addon no avanzan el índice y cuelgan Godot).
	var basura: Array[CartaDePalabra] = [
		CartaDePalabra.new(),  # todo vacío
		_carta_mala("sin_aguante", Palabra.Tipo.FIADOR, 1, 0),
		_carta_mala("clausula_con_stats", Palabra.Tipo.CLAUSULA, 0, 3),
		_carta_kw_mala("kw_inventada"),
		_carta_promesa_mala("plazo_de_9", 9),
	]
	var t1: int = Time.get_ticks_msec()
	for mala: CartaDePalabra in basura:
		af(not mala.validar().is_empty(), "el validador tiene que rechazar '%s'" % mala.id)
	af(
		Time.get_ticks_msec() - t1 < MS_MAX_VALIDAR,
		"validar datos basura termina rápido y no cuelga"
	)
	fin()


# --- § 8.5.46 ---


func test_manos_anunciadas_son_servibles() -> void:
	var datos: Dictionary = _canales()
	if datos.is_empty():
		af(false, "no se pudo leer %s" % RUTA_CANALES)
		fin()
		return
	var canales: Array = datos.get("canales", [])
	var manos: Array = datos.get("manos_anunciadas", [])
	af(not canales.is_empty(), "hay canales de obtención cargados (§ 5.10)")
	af_eq(manos.size(), 5, "las cinco manos anunciadas de Ciro (§ 4f.1 del INDICE)")

	for id: String in _ids_de_canales(datos):
		af(CatalogoDePalabra.existe(id), "el calendario de canales nombra '%s', que no existe" % id)

	for mano_v: Variant in manos:
		var mano: Dictionary = mano_v
		var escena: String = String(mano.get("escena", "?"))
		var orden: int = int(mano.get("orden", 0))
		var vias: Array = mano.get("vias", [])
		var anunciada: Dictionary = mano.get("cartas", {})
		# Solo cuentan los canales **anteriores o de la misma escena** y
		# **obligatorios**: Ciro no puede anunciar algo que dependa de un opcional.
		var disponible: Dictionary = {}
		for canal_v: Variant in canales:
			var canal: Dictionary = canal_v
			if int(canal.get("orden", 0)) > orden:
				continue
			if not bool(canal.get("obligatorio", false)):
				continue
			if not vias.has(String(canal.get("via", ""))):
				continue
			var entregadas: Dictionary = canal.get("cartas", {})
			for id_v: Variant in entregadas.keys():
				var id: String = id_v
				disponible[id] = int(disponible.get(id, 0)) + int(entregadas[id])
		var total: int = 0
		var ids_mano: Array = anunciada.keys()
		ids_mano.sort()
		for id_v2: Variant in ids_mano:
			var id2: String = id_v2
			var copias: int = int(anunciada[id2])
			total += copias
			var c: CartaDePalabra = null
			if CatalogoDePalabra.existe(id2):
				c = CatalogoDePalabra.obtener(id2)
			if c == null:
				af(false, "%s anuncia '%s', que no está en el set" % [escena, id2])
				continue
			af(
				copias <= c.max_copias(),
				(
					"%s anuncia %d copias de %s y el mazo admite %d"
					% [escena, copias, id2, c.max_copias()]
				)
			)
			af(
				int(disponible.get(id2, 0)) >= copias,
				(
					"%s anuncia %d %s y los canales obligatorios previos entregaron %d"
					% [escena, copias, id2, int(disponible.get(id2, 0))]
				)
			)
		af(
			total <= Palabra.MANO_INICIAL_SEGUNDO,
			(
				"la mano anunciada de %s (%d cartas) tiene que caber en una mano inicial legal (%d)"
				% [escena, total, Palabra.MANO_INICIAL_SEGUNDO]
			)
		)
	fin()


# --- § 8.5.48 ---


func test_cada_carta_tiene_al_menos_un_canal_de_obtencion() -> void:
	var datos: Dictionary = _canales()
	if datos.is_empty():
		af(false, "no se pudo leer %s" % RUTA_CANALES)
		fin()
		return
	var documentados: Dictionary = datos.get("sin_canal_conocido", {})
	var en_coleccion: Dictionary = {}
	for canal_v: Variant in datos.get("canales", []):
		var canal: Dictionary = canal_v
		if String(canal.get("via", "")) != "coleccion":
			continue
		var repetible: bool = bool(canal.get("repetible", false))
		var entregadas: Dictionary = canal.get("cartas", {})
		for id_v: Variant in entregadas.keys():
			var id: String = id_v
			if repetible:
				# Un drop por probabilidad no tiene tope contable: alcanza con que exista.
				en_coleccion[id] = maxi(int(en_coleccion.get(id, 0)), 1)
			else:
				en_coleccion[id] = int(en_coleccion.get(id, 0)) + int(entregadas[id])

	for id: String in CatalogoDePalabra.ids():
		var c: CartaDePalabra = CatalogoDePalabra.obtener(id)
		if c == null or c.es_token:
			continue
		var tiene_canal: bool = en_coleccion.has(id)
		if not tiene_canal:
			af(
				documentados.has(id),
				(
					"'%s' no tiene canal de obtención y el hueco no está documentado en %s"
					% [id, RUTA_CANALES]
				)
			)
		else:
			af(
				not documentados.has(id),
				"'%s' ya tiene canal: sacalo de sin_canal_conocido en %s" % [id, RUTA_CANALES]
			)
			af(
				int(en_coleccion[id]) <= c.max_copias(),
				(
					"los canales entregan %d copias de %s y el mazo admite %d"
					% [int(en_coleccion[id]), id, c.max_copias()]
				)
			)
	for id_v: Variant in documentados.keys():
		var id2: String = id_v
		af(CatalogoDePalabra.existe(id2), "sin_canal_conocido nombra '%s', que no existe" % id2)
	fin()


# --- Auxiliares ---


func _comparar_con_tabla(c: CartaDePalabra, fila: Array) -> void:
	var id: String = c.id
	af_eq(c.arquetipo, String(fila[0]), "%s: arquetipo" % id)
	af_eq(int(c.tipo), int(fila[1]), "%s: tipo" % id)
	af_eq(c.coste_base, int(fila[2]), "%s: coste base" % id)
	af_eq(c.ataque_base, int(fila[3]), "%s: ataque base" % id)
	af_eq(c.aguante_base, int(fila[4]), "%s: aguante base" % id)
	af_eq(c.dano_base, int(fila[5]), "%s: daño base" % id)
	var kws: Array[String] = c.keywords.duplicate()
	kws.sort()
	var esperadas: Array[String] = []
	for kw: String in String(fila[6]).split("|", false):
		esperadas.append(kw)
	esperadas.sort()
	af_eq("|".join(kws), "|".join(esperadas), "%s: keywords" % id)
	var banderas: PackedStringArray = String(fila[7]).split(" ", false)
	af_eq(c.es_token, banderas.has("token"), "%s: es_token" % id)
	af_eq(c.es_legendaria, banderas.has("leg"), "%s: es_legendaria" % id)
	af_eq(c.bloqueada, banderas.has("bloqueada"), "%s: bloqueada" % id)
	af_eq(c.puede_prometer, not banderas.has("sin_promesas"), "%s: puede_prometer" % id)
	var modulo: String = ""
	for b: String in banderas:
		if b.begins_with("mod:"):
			modulo = b.trim_prefix("mod:")
	af_eq(c.modulo, modulo, "%s: módulo" % id)
	af_eq(c.max_copias(), 1 if c.es_legendaria else 2, "%s: copias por mazo (§ 1)" % id)


func _referencias(c: CartaDePalabra) -> Array[String]:
	var salida: Array[String] = []
	var fuentes: Array[Dictionary] = []
	fuentes.append_array(c.efectos)
	for oferta: Dictionary in c.promesas:
		for bonus_v: Variant in oferta.get("bonus", []):
			if typeof(bonus_v) == TYPE_DICTIONARY:
				fuentes.append(bonus_v)
	for e: Dictionary in fuentes:
		var referida: String = String(e.get("carta", ""))
		if not referida.is_empty():
			salida.append(referida)
		for id_v: Variant in e.get("ids", []):
			salida.append(String(id_v))
	return salida


func _carta_mala(id: String, tipo: Palabra.Tipo, ataque: int, aguante: int) -> CartaDePalabra:
	var c: CartaDePalabra = CartaDePalabra.new()
	c.id = id
	c.nombre = id
	c.tipo = tipo
	c.ataque_base = ataque
	c.aguante_base = aguante
	return c


func _carta_kw_mala(id: String) -> CartaDePalabra:
	var c: CartaDePalabra = _carta_mala(id, Palabra.Tipo.FIADOR, 1, 1)
	c.keywords = ["keyword_que_no_existe"]
	return c


func _carta_promesa_mala(id: String, plazo: int) -> CartaDePalabra:
	var c: CartaDePalabra = _carta_mala(id, Palabra.Tipo.FIADOR, 1, 1)
	c.promesas = [{"tipo": Palabra.CL_NO_ATACAR, "plazo": plazo}]
	return c


func _canales() -> Dictionary:
	var texto: String = FileAccess.get_file_as_string(RUTA_CANALES)
	if texto.is_empty():
		return {}
	var crudo: Variant = JSON.parse_string(texto)
	if typeof(crudo) != TYPE_DICTIONARY:
		return {}
	return crudo


func _ids_de_canales(datos: Dictionary) -> Array[String]:
	var salida: Array[String] = []
	var fuentes: Array = []
	fuentes.append_array(datos.get("canales", []))
	fuentes.append_array(datos.get("manos_anunciadas", []))
	for entrada_v: Variant in fuentes:
		var entrada: Dictionary = entrada_v
		var cartas: Dictionary = entrada.get("cartas", {})
		for id_v: Variant in cartas.keys():
			var id: String = id_v
			if not salida.has(id):
				salida.append(id)
	salida.sort()
	return salida
