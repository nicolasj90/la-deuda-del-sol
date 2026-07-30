# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name EscenaGuionada
extends Node2D
## Base de las escenas de guion de «La Deuda del Sol»: corre diálogos de Dialogue
## Manager y encuentros del core JRPG en secuencia, desde un solo director.
##
## Por qué un director y no un [Cinematic] + [EncounterArea] por pisada:
## [br]— las escenas del Vencimiento son diálogo → combate → diálogo → cambio de
##   escena, y el combate tiene que dispararse [b]por evento[/b] (el Decano diciendo
##   «Alguaciles.»), no porque el jugador pise un área;
## [br]— si el combate se pierde, [EncounterArea] manda a la escena hogar y el
##   diálogo tiene que cortarse ahí mismo, lo que desde un [code].dialogue[/code] es
##   frágil (el nodo de estado se libera en medio de la conversación).
##
## [b]Modo headless[/b] ([code]DEUDA_TEST=1[/code] o servidor de display headless): en
## vez de montar el globo y esperar input, el diálogo se recorre línea por línea con
## [method DialogueManager.get_next_dialogue_line]. Eso deja verificado que el
## [code].dialogue[/code] parsea y que sus mutaciones ([code]do ...[/code]) corren,
## sin trabarse esperando un botón que en un test nunca llega.

## Se emite cuando el director terminó de correr la escena. [param completa] es
## [code]false[/code] si se cortó (derrota en un combate obligatorio, por ejemplo).
signal escena_terminada(completa: bool)

## Tope de líneas al recorrer un diálogo en modo headless (anti-cuelgue).
const TOPE_LINEAS: int = 400

## Nombre visible de la escena en los logs.
@export var titulo_de_escena: String = ""

## Motor de la batalla en curso, o [code]null[/code].
var motor: BattleEngine = null

## Barks del combate en curso: [code]turno -> Array[/code] de líneas.
var _barks_por_turno: Dictionary = {}
var _turno_de_barks: int = 0


## ¿Hay que correr sin globo ni input?
static func modo_headless() -> bool:
	if OS.get_environment("DEUDA_TEST") == "1":
		return true
	return DisplayServer.get_name() == "headless"


## Corre un diálogo entero y devuelve cuando terminó. [param ruta] es el
## [code].dialogue[/code]; [param titulo] el [code]~ titulo[/code] de arranque.
func correr_dialogo(ruta: String, titulo: String = "") -> void:
	var recurso: Resource = load(ruta)
	if recurso == null:
		push_error("[%s] no se pudo cargar el diálogo %s" % [_quien(), ruta])
		return
	if modo_headless():
		await _correr_dialogo_headless(recurso, titulo)
		return
	DialogueManager.show_dialogue_balloon(recurso, titulo, [self])
	await DialogueManager.dialogue_ended


## Dispara un encuentro por evento (no por pisada) y devuelve el resultado del
## bridge: [code]&"victory"[/code], [code]&"defeat"[/code], [code]&"fled"[/code] o
## [code]&"ignored"[/code].
##
## [param barks] son las líneas de guion que se cantan sobre la mesa, por turno:
## [code]{1: ["Decano: ¡Tasación en caliente!"], 2: [...]}[/code].
func pelear(area: EncounterArea, barks: Dictionary = {}) -> StringName:
	if area == null:
		push_error("[%s] no hay EncounterArea para disparar el combate." % _quien())
		return &"ignored"
	_barks_por_turno = barks
	_turno_de_barks = 0
	Encounters.battle_mounting.connect(_al_montar_batalla_interno, CONNECT_ONE_SHOT)
	var resultado: StringName = await area.trigger_encounter()
	if Encounters.battle_mounting.is_connected(_al_montar_batalla_interno):
		Encounters.battle_mounting.disconnect(_al_montar_batalla_interno)
	_soltar_senales()
	print("[%s] encuentro %s: %s" % [_quien(), area.name, resultado])
	return resultado


## Canta una línea sobre la mesa de batalla (mensajero del combate) y la deja en el
## log. Es la forma de meter los barks del guion sin tocar el addon.
func decir(linea: String) -> void:
	print("[%s] (bark) %s" % [_quien(), linea])
	if motor == null or motor.battle_signals == null:
		return
	motor.battle_signals.toggle_messenger_emitted.emit(true)
	motor.battle_signals.message_emitted.emit(linea)


## Gancho para las subclases: la batalla ya está configurada y por montarse.
func _al_montar_batalla(_engine: BattleEngine) -> void:
	pass


## Gancho para las subclases: arrancó la resolución del turno [param turno].
func _al_empezar_turno(_turno: int, _engine: BattleEngine) -> void:
	pass


## Gancho para las subclases: la batalla terminó y hay que soltar lo que se enganchó
## a [param senales] (que es un Resource compartido y de vida larga: lo que se conecta
## acá sobrevive a la batalla si no se desconecta).
func _al_soltar_senales(_senales: BattleSignals) -> void:
	pass


func _al_montar_batalla_interno(engine: BattleEngine) -> void:
	motor = engine
	if not engine.battle_signals.status_refreshed.is_connected(_al_refrescar_estado):
		engine.battle_signals.status_refreshed.connect(_al_refrescar_estado)
	_al_montar_batalla(engine)


func _soltar_senales() -> void:
	if motor != null and motor.battle_signals != null:
		var senales: BattleSignals = motor.battle_signals
		if senales.status_refreshed.is_connected(_al_refrescar_estado):
			senales.status_refreshed.disconnect(_al_refrescar_estado)
		_al_soltar_senales(senales)
	motor = null


func _al_refrescar_estado(engine: BattleEngine) -> void:
	# status_refreshed se emite dos veces por turno (resolución y upkeep): el turno
	# ya cantado no se repite.
	if engine == null or engine.current_turn == _turno_de_barks:
		return
	_turno_de_barks = engine.current_turn
	for linea: Variant in _barks_por_turno.get(engine.current_turn, []):
		decir(String(linea))
	_al_empezar_turno(engine.current_turn, engine)


func _quien() -> String:
	return titulo_de_escena if not titulo_de_escena.is_empty() else String(name)


func _correr_dialogo_headless(recurso: Resource, titulo: String) -> void:
	var linea: DialogueLine = await DialogueManager.get_next_dialogue_line(recurso, titulo, [self])
	var leidas: int = 0
	while linea != null and leidas < TOPE_LINEAS:
		if linea.character.is_empty():
			print("[%s] %s" % [_quien(), linea.text])
		else:
			print("[%s] %s: %s" % [_quien(), linea.character, linea.text])
		leidas += 1
		linea = await DialogueManager.get_next_dialogue_line(recurso, linea.next_id, [self])
	if leidas >= TOPE_LINEAS:
		push_error("[%s] el diálogo %s pasó las %d líneas: ¿bucle?" % [_quien(), titulo, TOPE_LINEAS])
