# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node
## Prueba headless del bloque del Vencimiento (E05 → E07).
##
## Verifica, sin UI y sin input:
## [br]— la [b]secuencia por banderas[/b]: E05 marca su bandera, E06 pide la de E05 y
##   marca la suya, E07 pide la de E06 y marca la última;
## [br]— el [b]tutorial de combate[/b] de E05 (Ciro solo contra dos alguaciles) es
##   ganable, y con cuánta vida sobra;
## [br]— las [b]dos fases del boss[/b] de E06: la fase 1 corre con Ferra del lado
##   enemigo y se gana [b]por interrupción[/b] (le voltean el atril), la party cambia
##   entre fases (Ciro solo → Ciro + Ferra) y la fase 2 se gana;
## [br]— la fase 1 también se gana [b]sin[/b] tocar el atril, por el tope de turnos
##   (segunda corrida del boss): nunca se puede quedar trabada contra Ferra;
## [br]— el [b]drop garantizado[/b] de la firma-carta «el Tasador Decano» entra a la
##   colección;
## [br]— E07 deja a Ferra en la party global y cura al grupo.
##
## Correr headless:
## [codeblock]
## DEUDA_TEST=1 ~/tools/godot/Godot_v4.7-stable_linux.x86_64 --headless --path . \
##     res://scenes/quests/story_quests/la_deuda_del_sol/vencimiento/tests/prueba_vencimiento.tscn
## [/codeblock]

const CASA: String = "res://scenes/quests/story_quests/la_deuda_del_sol/vencimiento/casa_de_ciro.tscn"
const PATIO: String = "res://scenes/quests/story_quests/la_deuda_del_sol/vencimiento/patio_notaria.tscn"
const CAMPAMENTO: String = "res://scenes/quests/story_quests/la_deuda_del_sol/vencimiento/componentes/campamento.tscn"

## Tope de turnos por combate (anti-cuelgue).
const TOPE_TURNOS: int = 40

var _fallos: Array[String] = []
var _motor: BattleEngine
var _senales: BattleSignals
var _arrancada: bool = false
var _ultima_seleccion: BattlePhase = null
var _turnos: int = 0
## Nombres que el "jugador" ataca primero, si están vivos.
var _prioridad: Array[String] = []
## Party de cada batalla montada, en orden.
var _parties_por_batalla: Array = []


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		Engine.time_scale = 20.0
	Encounters.battle_mounting.connect(_al_montar_batalla)
	Encounters.encounter_finished.connect(_al_terminar_encuentro)
	_correr.call_deferred()


func _correr() -> void:
	print("== [PruebaVencimiento] arranque limpio ==")
	BanderasDeuda.borrar()
	BanderasDeuda.arrancar_party_del_acto()
	var coleccion: Node = get_node_or_null(^"/root/Coleccion")
	if coleccion != null:
		coleccion.vaciar()
	DropsDeCartas.fijar_semilla(20260729)

	_afirmar(BanderasDeuda.nombres_de_party() == ["Ciro"], "la party arranca con Ciro solo, y arrancó con %s" % str(BanderasDeuda.nombres_de_party()))
	for bandera: String in BanderasDeuda.BANDERAS_DEL_BLOQUE:
		_afirmar(not BanderasDeuda.tiene(bandera), "la bandera %s tendría que estar limpia" % bandera)

	_probar_mapas()
	await _probar_e05()
	# Primero el peor caso del boss (el jugador ignora el atril), que es el que tiene
	# que ser ganable igual, y con la party y el nivel con los que se llega de E05.
	await _probar_boss_ignorando_el_atril()
	await _probar_e06()
	await _probar_e07()

	_cerrar()


# ---------------------------------------------------------------------------
# Enganche con los mapas del acto
# ---------------------------------------------------------------------------


## Los dos mapas que el bloque toca cargan y traen sus nodos nuevos.
func _probar_mapas() -> void:
	print("\n== [PruebaVencimiento] mapas del acto ==")
	var lacrevieja: Node = _instanciar("res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja.tscn")
	if lacrevieja != null:
		_afirmar(
			lacrevieja.get_node_or_null(^"OnTheGround/TriggerDeVencimiento") != null,
			"lacrevieja tiene el trigger de la casa de Ciro (entrada a E05)"
		)
		lacrevieja.free()
	var camino: Node = _instanciar("res://scenes/quests/story_quests/la_deuda_del_sol/camino_del_diezmo.tscn")
	if camino != null:
		_afirmar(
			camino.get_node_or_null(^"OnTheGround/Campamento") != null,
			"el camino del diezmo tiene el trigger de campamento (E07)"
		)
		_afirmar(
			camino.get_node_or_null(^"OnTheGround/SpawnCampamento") != null,
			"el camino del diezmo tiene el spawn al que llega la huida de E06"
		)
		camino.free()


func _instanciar(ruta: String) -> Node:
	var paquete: PackedScene = load(ruta) as PackedScene
	if paquete == null:
		_fallar("no se pudo cargar %s" % ruta)
		return null
	return paquete.instantiate()


# ---------------------------------------------------------------------------
# E05
# ---------------------------------------------------------------------------


func _probar_e05() -> void:
	print("\n== [PruebaVencimiento] E05: los tasadores ==")
	var escena: Node = await _montar(CASA, {"encadenar_a_e06": false})
	_prioridad = []
	var ciro: BattlerPlayer = _jugador("Ciro")
	var pv_antes: int = ciro.current_hp

	var completa: bool = await escena.correr()

	_afirmar(completa, "E05 tendría que terminar completa (el tutorial es ganable)")
	_afirmar(BanderasDeuda.tiene(BanderasDeuda.E05_TASADORES), "E05 tendría que marcar su bandera")
	_afirmar(
		BanderasDeuda.tiene(BanderasDeuda.E04_MAYORIA),
		"E05 asume E04 mientras la ceremonia no exista"
	)
	_afirmar(
		not BanderasDeuda.tiene(BanderasDeuda.E06_BOSS_DECANO),
		"E05 no tendría que marcar la bandera de E06"
	)
	_afirmar(_parties_por_batalla.size() == 1, "E05 tendría que correr un solo combate")
	if _parties_por_batalla.size() == 1:
		_afirmar(
			_parties_por_batalla[0] == ["Ciro"],
			"el tutorial es Ciro solo, y peleó %s" % str(_parties_por_batalla[0])
		)
	print(
		(
			"== [E05] PV de Ciro: %d antes / %d al terminar (curado en la fuga: máx %d) =="
			% [pv_antes, ciro.current_hp, ciro.stats.hp.get_value()]
		)
	)
	_desmontar(escena)


# ---------------------------------------------------------------------------
# E06 (boss 1, dos fases)
# ---------------------------------------------------------------------------


func _probar_e06() -> void:
	print("\n== [PruebaVencimiento] E06: boss del Tasador Decano, dos fases ==")
	_parties_por_batalla = []
	var escena: Node = await _montar(PATIO, {"encadenar_a_e07": false})
	# El "jugador" le pega al atril primero: es la forma de guion de cortar la
	# fase 1 (voltear el atril interrumpe la lectura).
	_prioridad = ["El atril del Decano"]
	var ciro: BattlerPlayer = _jugador("Ciro")

	var completa: bool = await escena.correr()

	_afirmar(completa, "E06 tendría que terminar completa (las dos fases son ganables)")
	_afirmar(
		escena.get("_fase1_interrumpida") == true,
		"la fase 1 se gana por interrupción, no matando al Decano"
	)
	_afirmar(_parties_por_batalla.size() == 2, "E06 son dos encuentros encadenados, corrieron %d" % _parties_por_batalla.size())
	if _parties_por_batalla.size() == 2:
		_afirmar(
			_parties_por_batalla[0] == ["Ciro"],
			"fase 1: Ciro solo (Ferra está del lado enemigo), y peleó %s" % str(_parties_por_batalla[0])
		)
		_afirmar(
			_parties_por_batalla[1] == ["Ciro", "Ferra"],
			"fase 2: Ferra en la party, y peleó %s" % str(_parties_por_batalla[1])
		)
	_afirmar(ciro.is_alive(), "Ciro tendría que salir vivo del boss")
	_afirmar(
		BanderasDeuda.tiene(BanderasDeuda.E06_BOSS_DECANO), "E06 tendría que marcar su bandera"
	)
	_afirmar(BanderasDeuda.tiene_ferra(), "después de E06 Ferra queda en la party viva")

	var coleccion: Node = get_node_or_null(^"/root/Coleccion")
	if coleccion != null:
		_afirmar(
			coleccion.tiene(BanderasDeuda.FIRMA_CARTA_DECANO),
			"la firma-carta «%s» tendría que caer garantizada" % BanderasDeuda.FIRMA_CARTA_DECANO
		)
		print("== [E06] colección después del boss: %s ==" % str(coleccion.ids_poseidos()))
	print(
		(
			"== [E06] PV al cerrar: %s =="
			% str(_pv_de_party())
		)
	)
	_desmontar(escena)


# ---------------------------------------------------------------------------
# E07
# ---------------------------------------------------------------------------


func _probar_e07() -> void:
	print("\n== [PruebaVencimiento] E07: el primer campamento ==")
	var ciro: BattlerPlayer = _jugador("Ciro")
	ciro.current_hp = maxi(1, int(ciro.stats.hp.get_value() / 4.0))
	var escena: Node = await _montar(CAMPAMENTO, {})

	# Se prueba por el trigger de verdad (pisar el claro), no llamando al director.
	var falso_jugador: Node2D = Node2D.new()
	falso_jugador.add_to_group("player")
	add_child(falso_jugador)

	# Antes del boss el claro no se enciende.
	BanderasDeuda.borrar([BanderasDeuda.E06_BOSS_DECANO])
	await escena._al_entrar(falso_jugador)
	_afirmar(
		not BanderasDeuda.tiene(BanderasDeuda.E07_CAMPAMENTO),
		"sin la bandera de E06 el campamento no tendría que dispararse"
	)
	BanderasDeuda.marcar(BanderasDeuda.E06_BOSS_DECANO)

	await escena._al_entrar(falso_jugador)
	var completa: bool = BanderasDeuda.tiene(BanderasDeuda.E07_CAMPAMENTO)
	falso_jugador.queue_free()

	_afirmar(completa, "E07 tendría que correr al pisar el claro con E06 cumplida")
	_afirmar(
		BanderasDeuda.tiene(BanderasDeuda.E07_CAMPAMENTO), "E07 tendría que marcar su bandera"
	)
	_afirmar(BanderasDeuda.tiene_ferra(), "Ferra queda en la party global después del campamento")
	_afirmar(
		ciro.current_hp == ciro.stats.hp.get_value(),
		"el campamento cura: Ciro quedó en %d/%d" % [ciro.current_hp, ciro.stats.hp.get_value()]
	)
	_afirmar(
		BanderasDeuda.nombres_de_party() == ["Ciro", "Ferra"],
		"party al cerrar el bloque: %s" % str(BanderasDeuda.nombres_de_party())
	)
	_desmontar(escena)


# ---------------------------------------------------------------------------
# El boss, otra vez, sin tocarle el atril
# ---------------------------------------------------------------------------


func _probar_boss_ignorando_el_atril() -> void:
	print("\n== [PruebaVencimiento] E06, peor caso: el jugador ignora el atril ==")
	_parties_por_batalla = []
	var escena: Node = await _montar(PATIO, {"encadenar_a_e07": false})
	# El "jugador" se obsesiona con el Decano, que es invulnerable a golpes: la fase 1
	# tiene que cortarse igual por el tope de turnos y ser ganable.
	_prioridad = ["el Tasador Decano"]
	var ciro: BattlerPlayer = _jugador("Ciro")

	var completa: bool = await escena.correr()

	_afirmar(completa, "la fase 1 tiene que ser ganable aunque el jugador ignore el atril")
	_afirmar(
		escena.get("_fase1_interrumpida") == true,
		"el corte por tope de turnos tendría que activarse"
	)
	_afirmar(ciro.is_alive(), "Ciro tendría que sobrevivir la fase 1 jugada de la peor manera")
	if _parties_por_batalla.size() > 0:
		_afirmar(
			_parties_por_batalla[0] == ["Ciro"],
			"fase 1 con Ciro solo, y peleó %s" % str(_parties_por_batalla[0])
		)
	_desmontar(escena)

	# Se vuelve al estado de "recién terminó E05" para probar el camino bueno.
	BanderasDeuda.borrar()
	BanderasDeuda.marcar(BanderasDeuda.E04_MAYORIA)
	BanderasDeuda.marcar(BanderasDeuda.E05_TASADORES)
	BanderasDeuda.arrancar_party_del_acto()
	BanderasDeuda.curar_party()


# ---------------------------------------------------------------------------
# Andamiaje
# ---------------------------------------------------------------------------


func _montar(ruta: String, propiedades: Dictionary) -> Node:
	var paquete: PackedScene = load(ruta) as PackedScene
	if paquete == null:
		_fallar("no se pudo cargar %s" % ruta)
		return null
	var escena: Node = paquete.instantiate()
	escena.set("autoarranque", false)
	for clave: String in propiedades.keys():
		escena.set(clave, propiedades[clave])
	get_tree().root.add_child(escena)
	get_tree().current_scene = escena
	await get_tree().physics_frame
	await get_tree().physics_frame
	return escena


func _desmontar(escena: Node) -> void:
	if escena == null:
		return
	get_tree().current_scene = self
	escena.queue_free()


func _jugador(nombre: String) -> BattlerPlayer:
	for jugador: BattlerPlayer in BanderasDeuda.party().players:
		if String(jugador.name) == nombre:
			return jugador
	_fallar("no está %s en la party viva" % nombre)
	return null


func _pv_de_party() -> Array[String]:
	var salida: Array[String] = []
	for jugador: BattlerPlayer in BanderasDeuda.party().players:
		salida.append("%s %d/%d" % [jugador.name, jugador.current_hp, jugador.stats.hp.get_value()])
	return salida


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
	print("== [Batalla] party %s vs %s ==" % [str(nombres), str(enemigos)])


func _al_terminar_encuentro(resultado: StringName, summary: Dictionary) -> void:
	print(
		(
			"== [Batalla] fin: %s en %d turnos | PV %s | plata +%d | xp +%d | cartas %s =="
			% [
				resultado,
				_turnos,
				str(_pv_de_party()),
				summary.get("money_gained", 0),
				summary.get("xp_gained", 0),
				str(summary.get("cards", [])),
			]
		)
	)
	_motor = null


## Sin visuals nadie emite damage_finished (lo emite la UI al terminar la animación):
## lo emitimos diferido para destrabar el await de BattleActionAttack.resolve().
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
			_fallar("la batalla no terminó en %d turnos" % TOPE_TURNOS)
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


func _afirmar(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("  ok — %s" % mensaje)
	else:
		_fallar(mensaje)


func _fallar(motivo: String) -> void:
	_fallos.append(motivo)
	push_error("[PruebaVencimiento] FALLÓ: %s" % motivo)


func _cerrar() -> void:
	if _fallos.is_empty():
		print("\n== PRUEBA_VENCIMIENTO: OK ==")
		get_tree().quit(0)
		return
	print("\n== PRUEBA_VENCIMIENTO: %d FALLO(S) ==" % _fallos.size())
	for fallo: String in _fallos:
		print("  - %s" % fallo)
	get_tree().quit(1)
