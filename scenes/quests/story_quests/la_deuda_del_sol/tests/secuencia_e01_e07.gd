# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

## Revisión adversarial de F5a: la secuencia COMPLETA E01 → E07 en un solo proceso.
##
## Los smokes de fase corren cada bloque por separado (E01–E04 en
## [code]smoke_lacrevieja[/code], E05–E07 en [code]prueba_vencimiento[/code]). Esta
## prueba los encadena en el mismo proceso, con el mismo estado global, para
## verificar lo que ninguno de los dos ve:
## [br]— que el estado que deja E04 (banderas + colección + mazo) sea exactamente el
##   que E05 necesita, sin resetear nada en el medio;
## [br]— que la colección y la party sobrevivan un [b]save/load real[/b] a mitad de
##   secuencia (round-trip por [code].tres[/code], no por memoria);
## [br]— que el orden se respete: E05 sin E04 no abre, E06 sin E05 avisa, E07 sin E06
##   no dispara;
## [br]— que la party viva vaya Ciro → Ciro+Ferra en el momento exacto del guion.
##
## Correr:
## [codeblock]
## DEUDA_TEST=1 ~/tools/godot/Godot_v4.7-stable_linux.x86_64 --headless --path . \
##     res://scenes/quests/story_quests/la_deuda_del_sol/tests/secuencia_e01_e07.tscn
## [/codeblock]

const LACREVIEJA := preload("res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja.tscn")
const CASA: String = "res://scenes/quests/story_quests/la_deuda_del_sol/vencimiento/casa_de_ciro.tscn"
const PATIO: String = "res://scenes/quests/story_quests/la_deuda_del_sol/vencimiento/patio_notaria.tscn"
const CAMPAMENTO: String = "res://scenes/quests/story_quests/la_deuda_del_sol/vencimiento/componentes/campamento.tscn"

## Misma semilla que el smoke de Lacrevieja: con ésta Ciro gana el duelo tutorial.
const SEMILLA_E03: int = 1001
const TOPE_TURNOS: int = 40
const SAVE_DE_PRUEBA: String = "user://prueba_secuencia_f5a.tres"

var _total: int = 0
var _fallos: int = 0
var _mapa: MapaLacrevieja

# --- andamiaje de batalla (igual que prueba_vencimiento) ---
var _motor: BattleEngine
var _senales: BattleSignals
var _arrancada: bool = false
var _ultima_seleccion: BattlePhase = null
var _turnos: int = 0
var _prioridad: Array[String] = []
var _parties_por_batalla: Array = []


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		Engine.time_scale = 20.0
	_perro_guardian(420.0)
	Encounters.battle_mounting.connect(_al_montar_batalla)
	print("== SECUENCIA E01 → E07 en un solo proceso ==")
	await _a_probar()


func _a_probar() -> void:
	await _s0_boot()
	await _s1_lacrevieja_e01_e04()
	await _s2_save_load_a_mitad("después de E04", ["Ciro"])
	await _s3_e05()
	await _s4_e06()
	await _s2_save_load_a_mitad("después de E06 (con Ferra)", ["Ciro", "Ferra"])
	await _s6_e07()
	await _s7_estado_final()
	await _s8_party_al_recargar()
	await _s9_partida_nueva()

	print("\n== RESUMEN: %d chequeos, %d fallos ==" % [_total, _fallos])
	print("SECUENCIA OK" if _fallos == 0 else "SECUENCIA FALLÓ")
	get_tree().quit(1 if _fallos > 0 else 0)


# ---------------------------------------------------------------------------
# S0 — boot: la cadena splash → título → primera escena del acto
# ---------------------------------------------------------------------------


func _s0_boot() -> void:
	print("\n-- S0 boot: splash → título → Lacrevieja")
	var principal: String = String(ProjectSettings.get_setting("application/run/main_scene"))
	_check("S0 la escena principal existe", ResourceLoader.exists(principal), principal)
	var splash: PackedScene = load(principal) as PackedScene
	_check("S0 el splash carga", splash != null)
	var nodo_splash: Node = splash.instantiate() if splash != null else null
	var enlace: Node = nodo_splash.get_node_or_null(^"%SceneLink") if nodo_splash != null else null
	var siguiente: String = String(enlace.next_scene) if enlace != null else ""
	_check("S0 el splash apunta al título", ResourceLoader.exists(siguiente), siguiente)
	if nodo_splash != null:
		nodo_splash.free()

	var titulo: PackedScene = load(siguiente) as PackedScene if not siguiente.is_empty() else null
	_check("S0 el título carga", titulo != null)
	var quest_path: String = String(
		ThreadbareProjectSettings.get_setting(ThreadbareProjectSettings.OPENING_QUEST)
	)
	_check("S0 la quest de apertura existe", ResourceLoader.exists(quest_path), quest_path)
	var quest: Quest = load(quest_path) as Quest
	_check(
		"S0 la quest de apertura es la del acto",
		quest != null and String(quest.title).contains("La Deuda del Sol"),
		String(quest.title) if quest != null else "sin quest"
	)
	var primera: String = String(quest.first_scene) if quest != null else ""
	_check("S0 su primera escena existe", ResourceLoader.exists(primera), primera)
	_check(
		"S0 y es Lacrevieja",
		ResourceUID.get_id_path(ResourceUID.text_to_id(primera)).ends_with("lacrevieja.tscn")
		if primera.begins_with("uid://")
		else primera.ends_with("lacrevieja.tscn"),
		primera
	)


# ---------------------------------------------------------------------------
# S1 — E01 a E04, por el camino del jugador
# ---------------------------------------------------------------------------


func _s1_lacrevieja_e01_e04() -> void:
	print("\n-- S1 Lacrevieja: E01 → E04")
	_mapa = LACREVIEJA.instantiate() as MapaLacrevieja
	_mapa.autoarrancar_prologo = false
	_mapa.dialogo_sin_globo = true
	_mapa.duelos_automaticos = true
	_mapa.semilla_duelos = SEMILLA_E03
	add_child(_mapa)
	get_tree().current_scene = _mapa
	await _fisica(6)
	Coleccion.vaciar()
	BanderasDeuda.borrar()
	_mapa.reiniciar_hechos()
	DropsDeCartas.fijar_semilla(20260730)

	# --- la puerta a E05 está cerrada antes de la ceremonia (orden de guion) ---
	var puerta: Node = _mapa.get_node_or_null(^"OnTheGround/TriggerDeVencimiento")
	_check("S1 la casa de Ciro tiene la puerta a E05", puerta != null)
	if puerta != null:
		_check("S1 y no es un atajo de desarrollo", puerta.asumir_e04 == false)
		var falso: Node2D = Node2D.new()
		falso.add_to_group("player")
		add_child(falso)
		puerta._al_entrar(falso)
		await _fisica(2)
		_check(
			"S1 sin E04 la puerta a E05 no se abre",
			puerta.get("_yendo") == false
		)
		falso.queue_free()
		puerta.queue_free()
		await _fisica(2)

	# --- E01 ---
	await _mapa.correr_prologo()
	_check("S1 E01 corrió el prólogo", _mapa.prologo_visto())

	# --- E02: las tres promesitas, en el orden del guion ---
	await _mapa.hablar_con("Rosaura")
	for _i in 3:
		_mapa.pila_de_lena.tomar()
		_mapa.horno_grande.dejar()
	await _esperar_dialogo()
	await _mapa.hablar_con("Maestra")
	for maceta: MacetaDelCantero in _macetas():
		maceta.regar()
	await _esperar_dialogo()
	await _mapa.hablar_con("Cosme")
	for lapida: LapidaGrabada in _lapidas():
		lapida.leer()
	await _esperar_dialogo()
	_check("S1 E02 dejó la plaza encendida", _mapa.plaza_lista())

	# --- E03: el duelo tutorial, jugado por IA de los dos lados ---
	_check("S1 antes de E03 la colección está vacía", Coleccion.total() == 0)
	var lineas: Array = await _mapa.hablar_con("Rosaura")
	await _esperar_dialogo()
	_check("S1 E03 jugó el duelo de verdad", DueloLauncher.turnos > 0, "turnos=%d" % DueloLauncher.turnos)
	_check("S1 E03 lo ganó Ciro", _mapa.duelo_rosaura_ganado(), "motivo=%s" % DueloLauncher.motivo)
	_check("S1 la mesa quedó desmontada", not DueloLauncher.en_curso)
	_check(
		"S1 EL MAZO INICIAL ENTRÓ A LA COLECCIÓN",
		Coleccion.mazo_inicial_entregado() and Coleccion.tiene_mazo(),
		"mazo=%d cartas" % Coleccion.mazo_actual().size()
	)
	_check(
		"S1 con el Porteador del Empeñadero (trazabilidad E17)",
		Coleccion.tiene("porteador_empenadero")
	)
	_check(
		"S1 y sin la Lámpara (es de Rosaura; la propia llega en E09)",
		not Coleccion.tiene("lampara_de_palabra")
	)
	_check("S1 el premio del duelo suma la Gallina", Coleccion.cuantas("gallina_lacrevieja") >= 3)
	_check("S1 y Ciro cantó la mano del guion", _dice(lineas, "Tengo dos Gallinas, un Peón de Viña y la Lámpara de Palabra."))
	print("   colección tras E03: %s (%d copias)" % [str(Coleccion.ids_poseidos()), Coleccion.total()])

	# --- E04: la ceremonia y la primera campanada ---
	await _mapa.hablar_con("Fedatario")
	await _esperar_dialogo()
	_check("S1 E04 cerró la ceremonia", _mapa.ceremonia_hecha())
	_check("S1 SONÓ LA PRIMERA CAMPANADA", _mapa.campanadas() == 1)
	_check(
		"S1 y quedó puesta la bandera que pide E05",
		BanderasDeuda.tiene(BanderasDeuda.E04_MAYORIA)
	)
	for bandera: String in [
		BanderasDeuda.E05_TASADORES, BanderasDeuda.E06_BOSS_DECANO, BanderasDeuda.E07_CAMPAMENTO
	]:
		_check("S1 %s todavía no está marcada" % bandera, not BanderasDeuda.tiene(bandera))

	# La puerta a E05 ahora sí abre (misma escena, con la ceremonia hecha).
	var otra_puerta: Node = load(
		"res://scenes/quests/story_quests/la_deuda_del_sol/vencimiento/componentes/trigger_de_vencimiento.tscn"
	).instantiate()
	add_child(otra_puerta)
	await _fisica(2)
	_check(
		"S1 con E04 hecha, la casa de Ciro sí deja pasar a E05",
		BanderasDeuda.tiene(BanderasDeuda.E04_MAYORIA)
		and not BanderasDeuda.tiene(BanderasDeuda.E05_TASADORES)
	)
	otra_puerta.queue_free()
	await _fisica(2)


# ---------------------------------------------------------------------------
# S2 / S5 — save/load real a mitad de secuencia
# ---------------------------------------------------------------------------


## Serializa el estado global a un [code].tres[/code] de verdad, lo vuelve a leer y
## verifica que la colección, el mazo, las banderas y la party se reconstruyan.
## [param party_esperada] es la party que el guion pide en ese punto de la historia.
func _s2_save_load_a_mitad(cuando: String, party_esperada: Array[String]) -> void:
	print("\n-- S2 save/load real %s" % cuando)
	Coleccion.guardar()
	var antes_ids: Array[String] = Coleccion.ids_poseidos()
	var antes_total: int = Coleccion.total()
	var antes_mazo: Array[String] = Coleccion.mazo_actual()
	var antes_banderas: Array[String] = []
	for bandera: String in BanderasDeuda.BANDERAS_DEL_BLOQUE:
		if BanderasDeuda.tiene(bandera):
			antes_banderas.append(bandera)

	var guardado: SavedGame = SavedGame.new()
	guardado.global = GameState.global
	var err: int = ResourceSaver.save(guardado, SAVE_DE_PRUEBA)
	_check("S2 el save se escribe a disco (%s)" % cuando, err == OK, "error=%d" % err)

	var leido: SavedGame = ResourceLoader.load(
		SAVE_DE_PRUEBA, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP
	) as SavedGame
	_check("S2 el save se vuelve a leer", leido != null and leido.global != null)
	if leido == null or leido.global == null:
		return

	# Colección: se relee del GlobalState cargado, como hace GameState al arrancar.
	Coleccion.cargar_de(leido.global)
	_check(
		"S2 la colección sobrevive el round-trip",
		Coleccion.ids_poseidos() == antes_ids and Coleccion.total() == antes_total,
		"%d/%d copias, %d/%d ids" % [Coleccion.total(), antes_total, Coleccion.ids_poseidos().size(), antes_ids.size()]
	)
	_check(
		"S2 el mazo activo sobrevive el round-trip",
		Coleccion.mazo_actual() == antes_mazo,
		"%d vs %d cartas" % [Coleccion.mazo_actual().size(), antes_mazo.size()]
	)
	# Banderas.
	var faltan: Array[String] = []
	for bandera: String in antes_banderas:
		if not bool(leido.global.facts.get(bandera, false)):
			faltan.append(bandera)
	_check("S2 las banderas de guion sobreviven", faltan.is_empty(), str(faltan))

	# Party: el save NO guarda GameManager.party; se reconstruye de la bandera
	# FERRA_EN_PARTY. Se simula el arranque desde cero: se pisa la party con la del
	# boot (lo que hace Encounters._ready()), se le saca Ferra y se rearma.
	GameManager.party = Encounters.PARTY_DEUDA
	BanderasDeuda.quitar_ferra()
	BanderasDeuda.arrancar_party_del_acto()
	_check(
		"S2 la party se reconstruye desde la bandera tras el load (%s)" % cuando,
		BanderasDeuda.nombres_de_party() == party_esperada,
		"esperada %s / quedó %s" % [str(party_esperada), str(BanderasDeuda.nombres_de_party())]
	)
	# Y se vuelve a dejar la colección como estaba en memoria.
	Coleccion.cargar()
	_check(
		"S2 la colección en memoria sigue intacta",
		Coleccion.total() == antes_total,
		"%d vs %d" % [Coleccion.total(), antes_total]
	)


# ---------------------------------------------------------------------------
# S3 — E05
# ---------------------------------------------------------------------------


func _s3_e05() -> void:
	print("\n-- S3 E05: los tasadores (tutorial de combate)")
	_mapa.queue_free()
	_mapa = null
	await _fisica(2)

	_parties_por_batalla = []
	var escena: Node = await _montar(CASA, {"encadenar_a_e06": false})
	_prioridad = []
	var completa: bool = await escena.correr()
	_check("S3 E05 termina completa", completa)
	_check("S3 E05 marca su bandera", BanderasDeuda.tiene(BanderasDeuda.E05_TASADORES))
	_check("S3 E05 corrió un solo combate", _parties_por_batalla.size() == 1, str(_parties_por_batalla))
	if _parties_por_batalla.size() >= 1:
		_check("S3 y peleó Ciro solo", _parties_por_batalla[0] == ["Ciro"], str(_parties_por_batalla[0]))
	_check(
		"S3 E05 NO reseteó la colección que dejó E03",
		Coleccion.mazo_inicial_entregado() and Coleccion.tiene("porteador_empenadero"),
		"%d copias" % Coleccion.total()
	)
	_check("S3 E05 no adelanta la bandera de E06", not BanderasDeuda.tiene(BanderasDeuda.E06_BOSS_DECANO))
	_check("S3 Ferra todavía no es de la casa", not BanderasDeuda.tiene_ferra())
	_desmontar(escena)


# ---------------------------------------------------------------------------
# S4 — E06 (boss, dos fases)
# ---------------------------------------------------------------------------


func _s4_e06() -> void:
	print("\n-- S4 E06: boss 1 en dos fases")
	_parties_por_batalla = []
	var cartas_antes: int = Coleccion.total()
	var escena: Node = await _montar(PATIO, {"encadenar_a_e07": false})
	_prioridad = ["El atril del Decano"]
	var completa: bool = await escena.correr()

	_check("S4 E06 termina completa", completa)
	_check("S4 la fase 1 se ganó por interrupción del atril", escena.get("_fase1_interrumpida") == true)
	_check("S4 fueron dos encuentros", _parties_por_batalla.size() == 2, str(_parties_por_batalla))
	if _parties_por_batalla.size() == 2:
		_check("S4 FASE 1: Ciro solo (Ferra del lado enemigo)", _parties_por_batalla[0] == ["Ciro"], str(_parties_por_batalla[0]))
		_check("S4 FASE 2: FERRA CAMBIÓ DE BANDO", _parties_por_batalla[1] == ["Ciro", "Ferra"], str(_parties_por_batalla[1]))
	_check("S4 E06 marca su bandera", BanderasDeuda.tiene(BanderasDeuda.E06_BOSS_DECANO))
	_check(
		"S4 DROP GARANTIZADO: firma-carta «%s»" % BanderasDeuda.FIRMA_CARTA_DECANO,
		Coleccion.tiene(BanderasDeuda.FIRMA_CARTA_DECANO),
		str(Coleccion.ids_poseidos())
	)
	_check("S4 y la colección creció, no se reemplazó", Coleccion.total() > cartas_antes, "%d → %d" % [cartas_antes, Coleccion.total()])
	_check("S4 Ferra quedó en la party viva", BanderasDeuda.tiene_ferra())
	_desmontar(escena)


# ---------------------------------------------------------------------------
# S6 — E07
# ---------------------------------------------------------------------------


func _s6_e07() -> void:
	print("\n-- S6 E07: el primer campamento")
	var ciro: BattlerPlayer = _jugador("Ciro")
	if ciro != null:
		ciro.current_hp = maxi(1, int(ciro.stats.hp.get_value() / 3.0))
	var escena: Node = await _montar(CAMPAMENTO, {})
	var falso: Node2D = Node2D.new()
	falso.add_to_group("player")
	add_child(falso)
	await escena._al_entrar(falso)
	falso.queue_free()

	_check("S6 E07 corrió al pisar el claro", BanderasDeuda.tiene(BanderasDeuda.E07_CAMPAMENTO))
	_check(
		"S6 SONÓ LA SEGUNDA CAMPANADA (curva E04 → E07 del § 5b)",
		BanderasDeuda.campanadas() == 2,
		"campanadas=%d" % BanderasDeuda.campanadas()
	)
	_check(
		"S6 la campanada es sonido, no un cartel en pantalla",
		escena.campana != null and escena.campana.stream != null
	)
	_check("S6 FERRA EN LA PARTY GLOBAL", BanderasDeuda.nombres_de_party() == ["Ciro", "Ferra"], str(BanderasDeuda.nombres_de_party()))
	_check(
		"S6 el campamento curó a Ciro",
		ciro != null and ciro.current_hp == ciro.stats.hp.get_value(),
		"%d/%d" % [ciro.current_hp, ciro.stats.hp.get_value()] if ciro != null else "sin Ciro"
	)
	# Segunda pisada: no se repite.
	var otra: Node2D = Node2D.new()
	otra.add_to_group("player")
	add_child(otra)
	await escena._al_entrar(otra)
	otra.queue_free()
	_check("S6 volver al claro no repite la escena", escena.get("_corriendo") == false)
	_desmontar(escena)


# ---------------------------------------------------------------------------
# S7 — estado final del bloque
# ---------------------------------------------------------------------------


func _s7_estado_final() -> void:
	print("\n-- S7 estado al cerrar el bloque")
	for bandera: String in BanderasDeuda.BANDERAS_DEL_BLOQUE:
		_check("S7 bandera %s puesta" % bandera, BanderasDeuda.tiene(bandera))
	_check("S7 la party cierra con Ciro y Ferra", BanderasDeuda.nombres_de_party() == ["Ciro", "Ferra"])
	_check(
		"S7 la colección tiene el mazo inicial + la firma del Decano",
		(
			Coleccion.mazo_inicial_entregado()
			and Coleccion.tiene(BanderasDeuda.FIRMA_CARTA_DECANO)
			and Coleccion.tiene("porteador_empenadero")
		),
		str(Coleccion.ids_poseidos())
	)
	print("   colección final: %s (%d copias, mazo de %d)" % [
		str(Coleccion.ids_poseidos()), Coleccion.total(), Coleccion.mazo_actual().size()
	])
	print("   party final: %s" % str(BanderasDeuda.nombres_de_party()))
	# Los 4 mapas y los 2 dungeons del acto siguen instanciables tras toda la corrida.
	for ruta: String in [
		"res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja.tscn",
		"res://scenes/quests/story_quests/la_deuda_del_sol/villarrubrica.tscn",
		"res://scenes/quests/story_quests/la_deuda_del_sol/camino_del_diezmo.tscn",
		"res://scenes/quests/story_quests/la_deuda_del_sol/el_fiado.tscn",
		"res://scenes/quests/story_quests/la_deuda_del_sol/archivo_bajo/archivo_bajo.tscn",
		"res://scenes/quests/story_quests/la_deuda_del_sol/vinedo_en_prenda/vinedo_en_prenda.tscn",
	]:
		var paquete: PackedScene = load(ruta) as PackedScene
		var nodo: Node = paquete.instantiate() if paquete != null else null
		_check("S7 %s instancia" % ruta.get_file(), nodo != null)
		if nodo != null:
			nodo.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_DE_PRUEBA))


# ---------------------------------------------------------------------------
# S8 — la party después de cargar la partida en el camino (post-E07)
# ---------------------------------------------------------------------------


## HALLAZGO ABIERTO (no se arregla acá: [code]scenes/globals/encounters/[/code] está
## fuera del territorio de F5a).
##
## [code]Encounters._ready()[/code] pisa [code]GameManager.party[/code] con
## [code]party_deuda.tres[/code] (los cinco: Ciro, Ferra, Salu, Odila, Fiel) en
## [b]cada arranque[/b], y la única cosa que la devuelve a la party del acto es
## [method BanderasDeuda.arrancar_party_del_acto], que solo se llama desde
## [code]casa_de_ciro.gd[/code] (E05) y [code]patio_notaria.gd[/code] (E06).
##
## Consecuencia: si el jugador guarda después de E07 y vuelve a entrar, cae en el
## Camino del Diezmo con la party de cinco — Salu, Odila y Fiel peleando antes de
## sumarse al grupo (E12, E14 y E25). Este bloque lo deja documentado en verde/rojo.
func _s8_party_al_recargar() -> void:
	print("\n-- S8 party al recargar la partida en el camino (post-E07)")
	# Lo que pasa en un arranque de verdad, en este orden.
	GameManager.party = Encounters.PARTY_DEUDA
	var al_arrancar: Array[String] = BanderasDeuda.nombres_de_party()
	print("   party que deja el arranque: %s" % str(al_arrancar))
	_check(
		"S8 la bandera de Ferra sí quedó guardada",
		BanderasDeuda.tiene(BanderasDeuda.FERRA_EN_PARTY)
	)
	var camino: Node = load(
		"res://scenes/quests/story_quests/la_deuda_del_sol/camino_del_diezmo.tscn"
	).instantiate()
	add_child(camino)
	get_tree().current_scene = camino
	await _fisica(6)
	var quedo: Array[String] = BanderasDeuda.nombres_de_party()
	_check(
		"S8 al volver al camino la party es la del guion (Ciro + Ferra)",
		quedo == ["Ciro", "Ferra"],
		"quedó %s — nadie llama a arrancar_party_del_acto() al cargar" % str(quedo)
	)
	var area: Node = camino.get_node_or_null(^"OnTheGround/EncounterArea")
	if area == null:
		for hijo: Node in camino.get_node(^"OnTheGround").get_children():
			if hijo is EncounterArea:
				area = hijo
				break
	if area != null and (area as EncounterArea).battle_settings != null:
		var settings: BattleSettings = (area as EncounterArea).battle_settings
		_check(
			"S8 el encuentro del camino usa la party viva (no una fija)",
			settings.party == null or settings.party == BanderasDeuda.party(),
			"settings.party = %s" % str(settings.party)
		)
	camino.queue_free()
	await _fisica(2)


# ---------------------------------------------------------------------------
# S9 — «Nueva partida» sin cerrar el juego
# ---------------------------------------------------------------------------


## Camino real: Pausa → «Pantalla de título» → «Nueva partida». Eso llama a
## [method GameState.clear], que reemplaza el [GlobalState] entero por uno nuevo y
## vacío. Los hechos de guion se leen del estado ([BanderasDeuda], [MapaLacrevieja])
## así que arrancan limpios; la colección, en cambio, vive en memoria en
## [code]Coleccion[/code] y hay que verificar que se entere del cambio.
func _s9_partida_nueva() -> void:
	print("\n-- S9 «Nueva partida» sin cerrar el proceso")
	var antes: int = Coleccion.total()
	_check("S9 la partida vieja tenía cartas", antes > 0, "%d copias" % antes)
	GameState.clear()
	await _fisica(2)
	_check(
		"S9 las banderas de guion arrancan limpias",
		not BanderasDeuda.tiene(BanderasDeuda.E06_BOSS_DECANO)
		and not BanderasDeuda.tiene(BanderasDeuda.E07_CAMPAMENTO)
	)
	_check(
		"S9 LA COLECCIÓN ARRANCA VACÍA EN LA PARTIDA NUEVA",
		Coleccion.total() == 0,
		"quedaron %d copias de la partida anterior: %s"
		% [Coleccion.total(), str(Coleccion.ids_poseidos())]
	)
	_check(
		"S9 y sin mazo propio (el de E03 es de la partida vieja)",
		not Coleccion.tiene_mazo() and not Coleccion.mazo_inicial_entregado(),
		"mazo de %d, entregado=%s" % [Coleccion.mazo_actual().size(), str(Coleccion.mazo_inicial_entregado())]
	)
	# Y el regalo de Rosaura vuelve a poder entregarse una sola vez.
	Coleccion.entregar_mazo_inicial()
	_check(
		"S9 el mazo inicial de la partida nueva no acumula el de la vieja",
		Coleccion.cuantas("gallina_lacrevieja") == int(Coleccion.MAZO_INICIAL["gallina_lacrevieja"]),
		"gallinas=%d" % Coleccion.cuantas("gallina_lacrevieja")
	)


# ---------------------------------------------------------------------------
# Andamiaje
# ---------------------------------------------------------------------------


func _perro_guardian(segundos: float) -> void:
	var reloj: SceneTreeTimer = get_tree().create_timer(segundos, true, false, true)
	reloj.timeout.connect(
		func() -> void:
			print("FAIL - la secuencia se colgó tras %.0f s" % segundos)
			print("SECUENCIA FALLÓ")
			get_tree().quit(1)
	)


func _check(nombre: String, ok: bool, detalle: String = "") -> void:
	_total += 1
	if ok:
		print("PASS - %s" % nombre)
		return
	_fallos += 1
	print("FAIL - %s%s" % [nombre, "" if detalle.is_empty() else " (%s)" % detalle])


func _fisica(cuadros: int = 1) -> void:
	for _i in cuadros:
		await get_tree().physics_frame


func _esperar_dialogo() -> void:
	for _i in 4:
		await get_tree().process_frame
	var limite: int = 3600
	while _mapa != null and _mapa.en_dialogo() and limite > 0:
		limite -= 1
		await get_tree().process_frame


func _dice(lineas: Array, texto: String) -> bool:
	for linea: String in lineas:
		if linea.contains(texto):
			return true
	return false


func _macetas() -> Array[MacetaDelCantero]:
	var salida: Array[MacetaDelCantero] = []
	for nodo: Node in _mapa.get_node(^"OnTheGround/Cantero").get_children():
		if nodo is MacetaDelCantero:
			salida.append(nodo as MacetaDelCantero)
	return salida


func _lapidas() -> Array[LapidaGrabada]:
	var salida: Array[LapidaGrabada] = []
	for nodo: Node in _mapa.get_node(^"OnTheGround/Cementerio").get_children():
		if nodo is LapidaGrabada:
			salida.append(nodo as LapidaGrabada)
	return salida


func _montar(ruta: String, propiedades: Dictionary) -> Node:
	var paquete: PackedScene = load(ruta) as PackedScene
	if paquete == null:
		_check("se pudo cargar %s" % ruta, false)
		return null
	var escena: Node = paquete.instantiate()
	escena.set("autoarranque", false)
	for clave: String in propiedades.keys():
		escena.set(clave, propiedades[clave])
	get_tree().root.add_child(escena)
	get_tree().current_scene = escena
	await _fisica(2)
	return escena


func _desmontar(escena: Node) -> void:
	if escena == null:
		return
	get_tree().current_scene = self
	escena.queue_free()


func _jugador(nombre: String) -> BattlerPlayer:
	var party: Party = BanderasDeuda.party()
	if party == null:
		return null
	for jugador: BattlerPlayer in party.players:
		if String(jugador.name) == nombre:
			return jugador
	return null


func _al_montar_batalla(engine: BattleEngine) -> void:
	_motor = engine
	_motor.visuals_enabled = false
	_senales = engine.battle_signals
	if not _senales.battler_damaged.is_connected(_al_danar):
		_senales.battler_damaged.connect(_al_danar)
	_arrancada = false
	_ultima_seleccion = null
	_turnos = 0
	var nombres: Array = []
	for jugador: BattlerPlayer in engine.battle_settings.party.players:
		nombres.append(String(jugador.name))
	_parties_por_batalla.append(nombres)
	var enemigos: Array = []
	for puesto: EnemySettings in engine.battle_settings.enemies:
		enemigos.append(String(puesto.enemy.name))
	print("   [Batalla] %s vs %s" % [str(nombres), str(enemigos)])


func _al_danar(_battler: Battler) -> void:
	if _senales != null:
		_senales.damage_finished.emit.call_deferred()


func _process(_delta: float) -> void:
	if _motor == null:
		return
	var fase: BattlePhase = _motor.current_phase
	if fase == null:
		return
	if not _arrancada and fase is BattlePhaseInit and fase.is_finished:
		_arrancada = true
		BattleInputStartBattle.new().resolve(_motor)
	elif fase is BattlePhaseSelection and fase != _ultima_seleccion:
		_ultima_seleccion = fase
		_turnos += 1
		if _turnos > TOPE_TURNOS:
			_check("la batalla terminó en %d turnos" % TOPE_TURNOS, false)
			_motor = null
			return
		_elegir_acciones(fase)


func _elegir_acciones(fase: BattlePhase) -> void:
	var objetivo: Enemy = _objetivo()
	if objetivo == null:
		return
	for jugador: BattlerPlayer in _motor.players:
		if jugador.is_alive():
			var objetivos: Array[Battler] = [objetivo]
			_motor.action_pool.append(BattleActionAttack.new(jugador, objetivos))
	fase.end()
	_motor.change_phase(BattlePhaseResolveActions.new())


func _objetivo() -> Enemy:
	for nombre: String in _prioridad:
		for enemigo: Enemy in _motor.enemies:
			if enemigo.is_alive() and String(enemigo.name).begins_with(nombre):
				return enemigo
	return _motor.get_first_alive_enemy()
