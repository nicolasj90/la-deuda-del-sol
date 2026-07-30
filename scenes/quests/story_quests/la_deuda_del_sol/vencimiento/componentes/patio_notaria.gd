# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends EscenaGuionada
## E06 — «Contrato roto, contrato nulo»: director del boss 1, en dos fases.
##
## [b]Fase 1[/b] ([code]e06_decano_fase1.tres[/code]): Ciro solo contra el Decano
## leyendo desde el atril, dos alguaciles de refresco y [b]Ferra del lado enemigo[/b]
## (pega flojo, jamás remata, y canta sus barks). El atril es el objeto destruible
## de la fase: voltearlo interrumpe la lectura. La fase [b]no se gana matando al
## Decano[/b] — se gana interrumpiéndolo, así que el director corta el combate
## cuando cae el atril o cuando se llega a [constant TURNO_TOPE_FASE1] (tope de
## seguridad, para que la fase sea ganable siempre y nunca dependa de si el jugador
## le pega al mueble correcto).
##
## La interrupción se hace por el camino normal del motor: se les baja a 0 los PV a
## los enemigos que quedan en pie («diligencia frustrada»), y el
## [BattlePhaseResolveActions] resuelve las muertes y declara victoria como en
## cualquier combate. No se toca una línea del addon.
##
## [b]Fase 2[/b] ([code]e06_decano_fase2.tres[/code]): Ferra ya está en la party
## (cambio de bando en caliente) y el Decano pelea sin atril. Al ganar cae la
## firma-carta garantizada «el Tasador Decano» — la resuelve
## [code]DropsDeCartas[/code] con la tabla
## [code]resources/combate/drops/jefe_tasador_decano.tres[/code], que matchea el
## archivo [code]tasador_decano.tres[/code] (por eso la fase 1 usa otro archivo,
## [code]tasador_decano_lector.tres[/code]: para que la firma caiga una sola vez, y
## al final).
##
## Ciro entra a la fase 2 con los PV que le quedaron de la fase 1 y Ferra entra
## entera: eso es el punto de la escena («Vos pegá, que aguanto yo»), así que acá
## [b]no[/b] se cura entre fases.

const DIALOGO: String = "res://scenes/quests/story_quests/la_deuda_del_sol/vencimiento/componentes/e06_contrato_roto.dialogue"
const ESCENA_CAMINO: String = "res://scenes/quests/story_quests/la_deuda_del_sol/camino_del_diezmo.tscn"
const SPAWN_CAMPAMENTO: NodePath = ^"OnTheGround/SpawnCampamento"

## Turno en el que el Decano corta la lectura por su cuenta si el jugador todavía no
## le volteó el atril. El corte cae [b]antes[/b] de que se resuelvan las acciones de
## ese turno, así que la fase expone a Ciro a dos turnos de golpes como máximo: es lo
## que la vuelve ganable siempre, incluso jugando de la peor manera posible (pegarle
## al Decano, que es invulnerable a golpes).
const TURNO_TOPE_FASE1: int = 3

## Barks de la fase 1, TEXTUALES del guion.
const BARKS_FASE1: Dictionary = {
	1: ["Decano: ¡Tasación en caliente! ¡Todo lo del embargado pesa doble hasta nueva foja!"],
	2:
	[
		"Ciro: Empeño palabra: ¡prometo no retroceder este turno!",
		"Ferra: Nada personal, pibe. Todavía.",
	],
	3: ["Ferra: Voy. Estoy yendo. Mirá cómo voy."],
}

## Barks de la fase 2, TEXTUALES del guion.
const BARKS_FASE2: Dictionary = {
	1: ["Ferra: ¡Eh! ¡Los grises! ¡Acá! ¡El que le pegue al pibe cobra a término, COMO YO!"],
	2: ["Decano: Consta que la ex escolta emplea agravios de índole... contable."],
	3:
	[
		"Decano: \"Considerando primero: que el peso de la prueba recae en—\"",
		"Ferra: Considerando nada.",
		"Decano: ¡ESO ERA UN INSTRUMENTO PÚBLICO!",
	],
}

## Nombre del atril tal como lo trae su Enemy (así se lo reconoce al caer).
const NOMBRE_ATRIL: String = "El atril del Decano"

@export var area_fase1: EncounterArea
@export var area_fase2: EncounterArea

@export var autoarranque: bool = true

## Pasar al camino (campamento de E07) al terminar. Los tests lo apagan.
@export var encadenar_a_e07: bool = true

var _fase: int = 0
var _fase1_interrumpida: bool = false
var _corriendo: bool = false


func _ready() -> void:
	if autoarranque:
		correr.call_deferred()


## Corre E06 entera (las dos fases). Devuelve [code]false[/code] si se perdió.
func correr() -> bool:
	if _corriendo:
		return false
	_corriendo = true

	if not BanderasDeuda.tiene(BanderasDeuda.E05_TASADORES):
		push_warning("[E06] la bandera de E05 no está puesta: el boss llega antes de tiempo.")

	BanderasDeuda.arrancar_party_del_acto()

	await correr_dialogo(DIALOGO, "e06_patio")

	# --- Fase 1: Ferra del lado enemigo ---
	_fase = 1
	_fase1_interrumpida = false
	var r1: StringName = await pelear(area_fase1, BARKS_FASE1)
	if r1 != &"victory":
		return _cortar()

	# --- Cambio de bando en caliente ---
	await correr_dialogo(DIALOGO, "e06_interrupcion")
	BanderasDeuda.sumar_ferra()
	print("[E06] party de la fase 2: %s" % ", ".join(BanderasDeuda.nombres_de_party()))

	# --- Fase 2: Ferra de Garante ---
	_fase = 2
	var r2: StringName = await pelear(area_fase2, BARKS_FASE2)
	if r2 != &"victory":
		return _cortar()

	await correr_dialogo(DIALOGO, "e06_cierre")

	BanderasDeuda.marcar(BanderasDeuda.E06_BOSS_DECANO)
	_registrar_firma_carta()
	_fase = 0
	_corriendo = false
	escena_terminada.emit(true)

	if encadenar_a_e07:
		SceneSwitcher.change_to_file_with_transition(
			ESCENA_CAMINO, SPAWN_CAMPAMENTO, Transition.Effect.FADE, Transition.Effect.FADE
		)
	return true


func _cortar() -> bool:
	_fase = 0
	_corriendo = false
	escena_terminada.emit(false)
	return false


func _al_montar_batalla(engine: BattleEngine) -> void:
	if _fase == 1 and not engine.battle_signals.battler_died.is_connected(_al_morir_en_fase1):
		engine.battle_signals.battler_died.connect(_al_morir_en_fase1)


func _al_soltar_senales(senales: BattleSignals) -> void:
	if senales.battler_died.is_connected(_al_morir_en_fase1):
		senales.battler_died.disconnect(_al_morir_en_fase1)


func _al_empezar_turno(turno: int, _engine: BattleEngine) -> void:
	if _fase == 1 and turno >= TURNO_TOPE_FASE1:
		_interrumpir_fase1("se acabó la paciencia del Decano (turno %d)" % turno)


func _al_morir_en_fase1(battler: Battler) -> void:
	if battler != null and String(battler.name).begins_with(NOMBRE_ATRIL):
		_interrumpir_fase1("le voltearon el atril")


## Frustra la diligencia: los que quedan en pie se retiran y el motor declara
## victoria por su camino de siempre.
func _interrumpir_fase1(motivo: String) -> void:
	if _fase1_interrumpida or motor == null:
		return
	_fase1_interrumpida = true
	print("[E06] fase 1 interrumpida: %s" % motivo)
	decir("Decano: Suficiente registro. Escolta: proceda al remate de la garantía.")
	for enemigo: Enemy in motor.enemies:
		if enemigo.is_alive():
			enemigo.current_hp = 0


func _registrar_firma_carta() -> void:
	var coleccion: Node = get_node_or_null(^"/root/Coleccion")
	if coleccion == null:
		return
	var carta: String = BanderasDeuda.FIRMA_CARTA_DECANO
	if coleccion.tiene(carta):
		print("[E06] firma-carta «%s» en la colección (x%d)." % [carta, coleccion.cuantas(carta)])
	else:
		push_warning("[E06] el boss cayó y la firma-carta «%s» no entró a la colección." % carta)
