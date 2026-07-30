# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node

## Prueba headless del pegamento entre los tres cores: colección, drops de
## combate, duelo lanzado desde un diálogo y persistencia en el save.
##
## Uso:
## [codeblock]
## godot --headless --path . res://scenes/card_game/integracion/tests/prueba_integracion.tscn
## [/codeblock]

const RUTA_DIALOGO: String = "res://scenes/card_game/integracion/ejemplo_duelo.dialogue"
const RUTA_ENCUENTRO_LOBOS: String = "res://resources/combate/encuentros/encuentro_lobos.tres"

var _fallos: Array[String] = []
var _chequeos: int = 0


func _ready() -> void:
	Engine.time_scale = 30.0
	await _correr()


func _correr() -> void:
	_probar_armador()
	_probar_coleccion()
	_probar_drops()
	_probar_drops_por_senal()
	_probar_persistencia()
	await _probar_duelo_ia_vs_ia()
	await _probar_duelo_desde_dialogo()
	_terminar()


# ---------------------------------------------------------------------------
# 1. Armador de mazos
# ---------------------------------------------------------------------------


func _probar_armador() -> void:
	var mesa: ConfigMesa = ConfigMesa.base()
	_igual(
		ArmadorDeMazos.normalizar({"gallina_lacrevieja": 2}).size(),
		2,
		"normalizar expande {id: copias}"
	)
	_igual(
		ArmadorDeMazos.por_arquetipo("garante", mesa).size(),
		ArmadorDeMazos.TAMANO,
		"por_arquetipo arma 30 cartas"
	)
	_ok(
		ArmadorDeMazos.es_legal(ArmadorDeMazos.por_arquetipo("interes", mesa), mesa, true),
		"el mazo por arquetipo es legal con las 30 exigidas"
	)
	_ok(
		not ArmadorDeMazos.es_legal(["gallina_lacrevieja", "gallina_lacrevieja", "gallina_lacrevieja"]),
		"tres copias de la misma carta es ilegal"
	)
	_ok(not ArmadorDeMazos.es_legal(["quebranto"]), "un token no entra a un mazo")
	_ok(not ArmadorDeMazos.es_legal(["nadia_la_impalabra"]), "una carta bloqueada no entra")
	_ok(not ArmadorDeMazos.es_legal(["no_existe_esta_carta"]), "una carta inventada no entra")
	_ok(
		not ArmadorDeMazos.es_legal(["primera_mentira_gratis"], ConfigMesa.base()),
		"una carta de módulo apagado no entra a la mesa base"
	)
	_ok(
		ArmadorDeMazos.es_legal(["primera_mentira_gratis"], ConfigMesa.el_fiado()),
		"esa misma carta sí entra en la mesa de El Fiado"
	)
	_igual(
		ArmadorDeMazos.arquetipo_de_perfil("senuelos"), "palabra_rota", "arquetipo del Cachuzo"
	)


# ---------------------------------------------------------------------------
# 2. Colección
# ---------------------------------------------------------------------------


func _probar_coleccion() -> void:
	Coleccion.vaciar()
	_igual(Coleccion.total(), 0, "antes de E03 la colección arranca vacía")
	_ok(not Coleccion.tiene_mazo(), "antes de E03 no hay mazo activo")

	_ok(Coleccion.agregar("gallina_lacrevieja"), "agregar una carta del set")
	_ok(Coleccion.agregar("gallina_lacrevieja"), "agregar la segunda copia")
	_igual(Coleccion.cuantas("gallina_lacrevieja"), 2, "dos Gallinas de Lacrevieja")
	_ok(Coleccion.tiene("gallina_lacrevieja", 2), "tiene(id, 2)")
	_ok(not Coleccion.tiene("gallina_lacrevieja", 3), "no tiene tres")
	_ok(not Coleccion.agregar("quebranto"), "un token no se colecciona")
	_ok(not Coleccion.agregar("nadia_la_impalabra"), "una carta bloqueada no se colecciona")
	_ok(not Coleccion.agregar("no_existe_esta_carta"), "una carta inventada no se colecciona")

	var entraron: Dictionary = Coleccion.agregar_varias(
		["colmillo_del_diezmo", "colmillo_del_diezmo", "lampara_de_palabra"]
	)
	_igual(int(entraron.get("colmillo_del_diezmo", 0)), 2, "agregar_varias suma copias")
	_igual(Coleccion.total(), 5, "total de copias")
	_igual(Coleccion.ids_poseidos().size(), 3, "tres cartas distintas")

	# El mazo activo tiene que ser un subconjunto de la colección.
	var errores: Array[String] = Coleccion.fijar_mazo(
		["gallina_lacrevieja", "gallina_lacrevieja", "gallina_lacrevieja"]
	)
	_ok(not errores.is_empty(), "el mazo no puede pedir más copias que las reglas")
	errores = Coleccion.fijar_mazo(["porteador_empenadero"])
	_ok(not errores.is_empty(), "el mazo no puede tener una carta que no se posee")
	errores = Coleccion.fijar_mazo(["gallina_lacrevieja", "colmillo_del_diezmo"])
	_ok(errores.is_empty(), "un mazo legal y poseído se fija: %s" % ", ".join(errores))
	_igual(Coleccion.mazo_actual().size(), 2, "el mazo activo quedó con dos cartas")

	# Quitar una carta recorta el mazo activo.
	_ok(Coleccion.quitar("colmillo_del_diezmo", 2), "quitar dos copias")
	_igual(Coleccion.mazo_actual().size(), 1, "el mazo se recorta al perder la carta")

	# El mazo inicial de E03 es idempotente y legal.
	Coleccion.vaciar()
	_ok(Coleccion.entregar_mazo_inicial(), "entregar el mazo inicial de E03")
	_ok(Coleccion.mazo_inicial_entregado(), "queda marcado como entregado")
	_ok(not Coleccion.entregar_mazo_inicial(), "entregarlo dos veces no duplica")
	_igual(
		Coleccion.mazo_actual().size(),
		ArmadorDeMazos.normalizar(Coleccion.MAZO_INICIAL).size(),
		"el mazo inicial queda como mazo activo"
	)
	_ok(
		ArmadorDeMazos.es_legal(Coleccion.mazo_actual()),
		"el mazo inicial es legal (copias, tokens, módulos)"
	)
	_ok(
		Coleccion.tiene("porteador_empenadero"),
		"el mazo inicial incluye el Porteador del Empeñadero (trazabilidad E17)"
	)
	_ok(
		not Coleccion.tiene("lampara_de_palabra"),
		"la Lámpara NO entra en E03: es de Rosaura, la propia llega en E09"
	)
	_ok(
		not Coleccion.tiene("colmillo_del_diezmo"),
		"el Colmillo del Diezmo no entra en E03: es el drop de los lobos"
	)


# ---------------------------------------------------------------------------
# 3. Drops de combate
# ---------------------------------------------------------------------------


func _probar_drops() -> void:
	_ok(DropsDeCartas.cargar_tablas(true) >= 4, "cargan las tablas de drops")
	_ok(
		DropsDeCartas.errores().is_empty(),
		"las tablas de drops están sanas: %s" % ", ".join(DropsDeCartas.errores())
	)
	_igual(DropsDeCartas.tablas_de("lobo_diezmo").size(), 1, "los lobos tienen una tabla")
	_igual(
		DropsDeCartas.tablas_de("Lobo del Diezmo").size(),
		1,
		"la tabla también matchea por nombre visible"
	)
	_igual(DropsDeCartas.tablas_de("bandido_ruta").size(), 0, "un enemigo sin familia no dropea")

	# Determinismo: misma semilla, mismo botín.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var a: Array[String] = DropsDeCartas.resolver(["lobo_diezmo", "lobo_diezmo"], rng)
	rng.seed = 12345
	var b: Array[String] = DropsDeCartas.resolver(["lobo_diezmo", "lobo_diezmo"], rng)
	_igual(a, b, "el drop es determinista con la misma semilla")
	for id: String in a:
		_igual(id, "colmillo_del_diezmo", "los lobos solo dropean el Colmillo del Diezmo")

	# Con muchas tiradas, el canal 1 entrega algo (chance 0.35 por lobo).
	rng.seed = 7
	var muchos: Array[String] = []
	for _i: int in 40:
		muchos.append("lobo_diezmo")
	_ok(
		not DropsDeCartas.resolver(muchos, rng).is_empty(),
		"40 lobos dejan por lo menos un Colmillo"
	)

	# Canal 2: la firma del jefe es garantizada y cae una sola vez.
	var jefe: Array[String] = DropsDeCartas.resolver(["tasador_decano"], rng)
	_igual(jefe, ["tasador_decano"] as Array[String], "el boss 1 garantiza su firma-carta")
	_igual(
		DropsDeCartas.resolver(["tasador_decano", "tasador_decano"], rng),
		["tasador_decano"] as Array[String],
		"la garantizada cae una vez por encuentro, no por enemigo"
	)

	# Las familias del guion.
	rng.seed = 99
	var quebrantos: Array[String] = DropsDeCartas.resolver(_repetir("quebranto_menor", 30), rng)
	_ok(not quebrantos.is_empty(), "los quebrantos dejan cartas de Letra chica")
	for id: String in quebrantos:
		var c: CartaDePalabra = CatalogoDePalabra.obtener(id)
		_igual(c.arquetipo, "letra_chica", "%s es Letra chica" % id)
	var tasadores: Array[String] = DropsDeCartas.resolver(_repetir("tasador_alguacil", 30), rng)
	_ok(not tasadores.is_empty(), "los tasadores dejan cartas de Interés")
	for id: String in tasadores:
		var c: CartaDePalabra = CatalogoDePalabra.obtener(id)
		_igual(c.arquetipo, "interes", "%s es de Interés" % id)

	# Los enemigos salen del BattleSettings del encuentro real.
	var settings: BattleSettings = load(RUTA_ENCUENTRO_LOBOS) as BattleSettings
	var claves: Array[String] = DropsDeCartas.enemigos_de(settings)
	_ok(not claves.is_empty(), "el encuentro de lobos declara enemigos")
	_ok(claves.has("lobo_diezmo"), "y se los reconoce por nombre de archivo")


## El camino real: DropsDeCartas escucha las señales del bridge de encuentros,
## entrega a la colección y escribe "cards" en el summary del encuentro.
func _probar_drops_por_senal() -> void:
	Coleccion.vaciar()
	DropsDeCartas.fijar_semilla(4242)
	DropsDeCartas.recordar_enemigos(_repetir("lobo_diezmo", 12) + ["tasador_decano"])
	var summary: Dictionary = {"money_gained": 12, "xp_gained": 30, "level_ups": []}
	var recibido: Array = []
	var espia := func(cartas: Array, _s: Dictionary) -> void: recibido.append_array(cartas)
	DropsDeCartas.cartas_dropeadas.connect(espia)
	Encounters.victory_rewards_applied.emit(summary)
	DropsDeCartas.cartas_dropeadas.disconnect(espia)

	_ok(summary.has("cards"), "el summary de victoria trae la entrada «cards»")
	_ok(summary.has("cards_nombres"), "y los nombres visibles para la UI")
	var cartas: Array = summary.get("cards", [])
	_ok(cartas.has("tasador_decano"), "la firma garantizada del jefe entró al botín")
	_igual(recibido, cartas, "la señal cartas_dropeadas lleva el mismo botín")
	var total: int = 0
	for id: Variant in cartas:
		total += 1
		_ok(Coleccion.tiene(String(id)), "«%s» entró a la colección" % id)
	_igual(Coleccion.total(), total, "la colección tiene exactamente lo dropeado")
	_ok(
		DropsDeCartas.enemigos_recordados().is_empty(),
		"los enemigos del encuentro se olvidan después de repartir"
	)


# ---------------------------------------------------------------------------
# 4. Persistencia dentro del save de Threadbare
# ---------------------------------------------------------------------------


func _probar_persistencia() -> void:
	Coleccion.vaciar()
	Coleccion.entregar_mazo_inicial()
	Coleccion.agregar("tasador_decano")
	var esperado_total: int = Coleccion.total()
	var esperado_mazo: Array[String] = Coleccion.mazo_actual()

	# La colección vive en GlobalState.facts, que es lo que se serializa.
	var facts: Dictionary = GameState.global.facts
	_ok(facts.has(Coleccion.CLAVE_CARTAS), "las cartas quedan en GlobalState.facts")
	_ok(facts.has(Coleccion.CLAVE_MAZO), "y el mazo activo también")

	# Un save/load de verdad: se escribe el SavedGame y se relee de disco.
	var ruta: String = "user://prueba_integracion_saved_game.tres"
	var guardado: SavedGame = SavedGame.new()
	guardado.global = GameState.global
	var e: Error = ResourceSaver.save(guardado, ruta)
	_igual(e, OK, "el SavedGame con la colección se guarda")
	Coleccion.vaciar()
	_igual(Coleccion.total(), 0, "la colección en memoria queda vacía")
	var leido: SavedGame = (
		ResourceLoader.load(ruta, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP) as SavedGame
	)
	_ok(leido != null, "el SavedGame se relee de disco")
	if leido != null:
		Coleccion.cargar_de(leido.global)
		_igual(Coleccion.total(), esperado_total, "la colección sobrevive al save/load")
		_igual(Coleccion.mazo_actual(), esperado_mazo, "y el mazo activo también")
		_ok(Coleccion.tiene("tasador_decano"), "la firma del jefe está después de cargar")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))


# ---------------------------------------------------------------------------
# 5. Duelo lanzado por DueloLauncher, resuelto IA contra IA
# ---------------------------------------------------------------------------


func _probar_duelo_ia_vs_ia() -> void:
	Coleccion.vaciar()
	Coleccion.entregar_mazo_inicial()
	var montado: Array = []
	var espia := func(motor: MotorDePalabra, vista: VistaDuelo) -> void:
		montado.append(motor)
		montado.append(vista)
	DueloLauncher.duelo_montado.connect(espia)
	var gano: bool = await DueloLauncher.duelo_auto(
		"garante",
		2026,
		{
			"pausar_mapa": false,
			"premio": {"gallina_lacrevieja": 1, "porteador_empenadero": 1},
			"mano_jugador":
			["gallina_lacrevieja", "gallina_lacrevieja", "peon_de_vina", "hornera_de_rosaura"],
			"anuncio_jugador":
			["gallina_lacrevieja", "gallina_lacrevieja", "peon_de_vina", "hornera_de_rosaura"],
		}
	)
	DueloLauncher.duelo_montado.disconnect(espia)

	_igual(montado.size(), 2, "se emitió duelo_montado con el motor y la vista")
	if montado.size() == 2:
		var motor: MotorDePalabra = montado[0] as MotorDePalabra
		_ok(motor != null and motor.estado.terminado, "el duelo cerró de verdad")
		_igual(
			motor.estado.firma(0).mano.size() + motor.estado.firma(0).descarte.size() > 0,
			true,
			"el lado del jugador jugó cartas"
		)
	_ok(DueloLauncher.ganador in [0, 1], "hay una Firma ganadora")
	_igual(DueloLauncher.gano, gano, "duelo() devuelve lo mismo que DueloLauncher.gano")
	_ok(not DueloLauncher.motivo.is_empty(), "el cierre tiene motivo: %s" % DueloLauncher.motivo)
	_ok(DueloLauncher.turnos > 0, "el duelo duró turnos")
	_ok(not DueloLauncher.en_curso, "el launcher quedó libre")
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(not _hay_mesa_montada(), "la capa del duelo se desmontó del árbol")
	if gano:
		_ok(
			Coleccion.cuantas("gallina_lacrevieja") > 2,
			"al ganar, el premio de cartas entró a la colección"
		)
		_igual(
			int(DueloLauncher.premio_entregado.get("gallina_lacrevieja", 0)),
			1,
			"premio_entregado dice qué se entregó"
		)
	else:
		_ok(DueloLauncher.premio_entregado.is_empty(), "al perder no se entrega premio")

	# La mano fijada por script es la regla no negociable del guion (§ 4f.1).
	var motor2: MotorDePalabra = MotorDePalabra.new(7)
	var mesa2: ConfigMesa = ConfigMesa.base()
	motor2.iniciar(
		mesa2,
		ArmadorDeMazos.por_arquetipo("neutral", mesa2),
		ArmadorDeMazos.por_arquetipo("garante", mesa2),
		0
	)
	DueloLauncher.fijar_mano_inicial(motor2, 0, ["gallina_lacrevieja", "lampara_de_palabra"])
	var en_mano: Array[String] = []
	for ec: EstadoCarta in motor2.estado.firma(0).mano:
		en_mano.append(ec.id())
	en_mano.sort()
	_igual(
		en_mano,
		["gallina_lacrevieja", "lampara_de_palabra"] as Array[String],
		"la mano fijada es exactamente la que anuncia el guion"
	)


# ---------------------------------------------------------------------------
# 6. Duelo lanzado desde un .dialogue (Dialogue Manager espera la corrutina)
# ---------------------------------------------------------------------------


func _probar_duelo_desde_dialogo() -> void:
	var recurso: DialogueResource = load(RUTA_DIALOGO) as DialogueResource
	_ok(recurso != null, "el .dialogue de referencia compila")
	if recurso == null:
		return
	Coleccion.vaciar()
	# El globo real lo monta DialogueManager y se lo pasa a las mutaciones como
	# «balloon»; acá va un doble para poder correr el `do balloon.hide()` que usa
	# el patrón de producción.
	var globo: Control = Control.new()
	globo.name = "GloboFalso"
	add_child(globo)
	var estados: Array = [{"balloon": globo}, self]
	# Se corre el título «demo_auto»: es el mismo camino que «start» (globo, duelo,
	# rama por resultado, premio) pero con la IA jugando los dos lados, porque acá
	# no hay nadie que arrastre cartas.
	var linea: DialogueLine = await DialogueManager.get_next_dialogue_line(
		recurso, "demo_auto", estados
	)
	var lineas: int = 0
	var vistas: PackedStringArray = []
	while linea != null and lineas < 20:
		lineas += 1
		vistas.append(linea.text)
		linea = await DialogueManager.get_next_dialogue_line(recurso, linea.next_id, estados)
	_ok(globo.visible, "el diálogo volvió a mostrar el globo después del duelo")
	_ok(lineas >= 3, "el diálogo corrió %d líneas" % lineas)
	_ok(DueloLauncher.turnos > 1, "el duelo se jugó desde el diálogo")
	_ok(DueloLauncher.ganador in [0, 1], "y cerró con una Firma ganadora")
	_ok(not DueloLauncher.motivo.is_empty(), "con motivo de cierre de verdad")
	_ok(not DueloLauncher.en_curso, "y quedó cerrado antes de la línea siguiente")
	var texto: String = "\n".join(vistas)
	_ok(
		texto.contains("El duelo cerró por [%s]" % DueloLauncher.motivo),
		"el diálogo puede leer el resultado del duelo: %s" % texto.replace("\n", " / ")
	)
	if DueloLauncher.gano:
		_ok(
			Coleccion.tiene("gallina_lacrevieja"),
			"al ganar desde el diálogo, el premio entró a la colección"
		)
		_ok(Coleccion.mazo_inicial_entregado(), "y la rama de victoria entregó el mazo inicial")


# ---------------------------------------------------------------------------
# Andamiaje
# ---------------------------------------------------------------------------


## ¿Quedó alguna mesa de duelo colgada del árbol?
func _hay_mesa_montada() -> bool:
	return _buscar_vista(get_tree().root) != null


func _buscar_vista(nodo: Node) -> VistaDuelo:
	if nodo is VistaDuelo:
		return nodo as VistaDuelo
	for hijo: Node in nodo.get_children():
		var encontrada: VistaDuelo = _buscar_vista(hijo)
		if encontrada != null:
			return encontrada
	return null


func _repetir(clave: String, cuantas: int) -> Array[String]:
	var salida: Array[String] = []
	for _i: int in cuantas:
		salida.append(clave)
	return salida


func _ok(condicion: bool, que: String) -> void:
	_chequeos += 1
	if not condicion:
		_fallos.append(que)


func _igual(a: Variant, b: Variant, que: String) -> void:
	_chequeos += 1
	if a != b:
		_fallos.append("%s (se esperaba %s y vino %s)" % [que, str(b), str(a)])


func _terminar() -> void:
	if _fallos.is_empty():
		print("OK — integración de los tres cores (%d chequeos)" % _chequeos)
		get_tree().quit(0)
		return
	for f: String in _fallos:
		printerr("FALLO: %s" % f)
	printerr("FALLÓ — %d de %d chequeos" % [_fallos.size(), _chequeos])
	get_tree().quit(1)
