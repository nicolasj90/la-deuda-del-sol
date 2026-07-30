# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node
## Banco de pruebas de la [b]derrota jugada[/b]: monta el mapa real
## ([code]camino_del_diezmo[/code]), deja la party en las últimas y dispara el
## [EncounterArea] real, para poder [b]perder la batalla con el teclado[/b]
## (eligiendo Defender, sin atacar) y auditar en pantalla la vuelta a la escena
## hogar con la party revivida a 1 PV.
##
## Por qué existe: con la party del acto entera (490 PV) y los enemigos del
## Camino (28 PV de daño por turno, y menos todavía si la party se defiende) una
## derrota honesta tarda decenas de turnos. Acá lo único que se siembra es el
## estado de PV con el que la party [b]llega[/b] al encuentro
## ([constant PV_INICIALES], «venían de arrastrarse»); la batalla, la derrota, el
## [method EncounterArea._return_home_defeated] y la vuelta al pueblo son el
## código real, jugados a mano.
##
## Este nodo NO juega: no encola acciones ni aprieta botones. Solo monta, siembra
## y después verifica (imprime el veredicto en la consola).
##
## Correr en el build web:
## [codeblock]
## http://localhost:8931/#res://scenes/dev/derrota_jugada.tscn
## [/codeblock]

const CAMINO_UID: String = "uid://bcaminodiezmo"

## PV con los que la party entra al encuentro (1 = a la primera cachetada cae).
const PV_INICIALES: int = 1

var _mapa: Node
var _resultado: StringName = &""


func _ready() -> void:
	_correr.call_deferred()


func _correr() -> void:
	# Igual que encounter_test.gd: el mapa pasa a ser current_scene y este nodo
	# queda de hermano en root (Encounters pausa current_scene, no al driver).
	# Sembrar GameState.scene evita que las luces y los spawn points del mapa
	# revienten en su _ready() contra un GameState.scene nulo.
	GameState.set_scene(ResourceUID.ensure_path(CAMINO_UID))
	_mapa = (load(CAMINO_UID) as PackedScene).instantiate()
	get_tree().root.add_child(_mapa)
	get_tree().current_scene = _mapa
	await get_tree().physics_frame
	await get_tree().physics_frame

	var areas: Array[Node] = get_tree().get_nodes_in_group(&"encounter_area")
	if areas.is_empty():
		push_error("[DerrotaJugada] no hay EncounterArea en el mapa.")
		return
	var area: EncounterArea = areas[0] as EncounterArea

	var party: Party = GameManager.party
	if party == null:
		push_error("[DerrotaJugada] no hay party viva.")
		return
	for jugador: BattlerPlayer in party.players:
		jugador.current_hp = PV_INICIALES
	print(
		(
			"== [DerrotaJugada] party en %d PV: %s | disparando %s =="
			% [
				PV_INICIALES,
				", ".join(party.players.map(func(j: BattlerPlayer) -> String: return j.name)),
				area.name,
			]
		)
	)
	print("== [DerrotaJugada] JUGAR: Pelear -> cada jugador -> Defender (NO atacar) ==")

	_resultado = await area.trigger_encounter()
	print("== [DerrotaJugada] resultado del encuentro: %s ==" % _resultado)
	if _resultado != &"defeat":
		push_error("[DerrotaJugada] se esperaba defeat y salió %s" % _resultado)
		return
	await _verificar_vuelta_al_pueblo()


func _verificar_vuelta_al_pueblo() -> void:
	var hogar: String = ResourceUID.ensure_path(
		ThreadbareProjectSettings.get_setting(ThreadbareProjectSettings.HOME_SCENE)
	)
	var llego: bool = false
	for i: int in 1800:
		await get_tree().process_frame
		var actual: Node = get_tree().current_scene
		if actual != null and actual != _mapa and actual.scene_file_path == hogar:
			llego = true
			break
	if not llego:
		push_error("[DerrotaJugada] tras la derrota no se llegó a la escena hogar (%s)" % hogar)
		return
	var pv: Array[String] = []
	for jugador: BattlerPlayer in GameManager.party.players:
		pv.append("%s %d PV" % [jugador.name, jugador.current_hp])
		if jugador.current_hp < 1:
			push_error("[DerrotaJugada] %s volvió muerto de la derrota." % jugador.name)
			return
	print("== [DerrotaJugada] OK: vuelta al pueblo (%s) | %s ==" % [hogar, ", ".join(pv)])
