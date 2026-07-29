# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name EncounterArea
extends Area2D
## Zona de encuentros: cuando el jugador la pisa puede dispararse una batalla
## del core integrado (addon godot_jrpg) vía el autoload [code]Encounters[/code].
##
## Patrón Threadbare (igual que Teleporter): instanciar en el mapa y agregarle
## un CollisionShape2D hijo. La batalla corre como overlay sobre el mapa, que
## queda pausado en su lugar: al ganar (o huir) se sigue jugando en la misma
## posición; al perder se vuelve a la escena hogar
## (threadbare/general/home_scene) con la party revivida a 1 HP.
##
## Nota de física: al pausarse el mapa (PROCESS_MODE_DISABLED) el área sale del
## espacio de física, emite un body_exited espurio, y al volver re-emite
## body_entered para el jugador que sigue parado adentro. Por eso el área queda
## desarmada después de cada batalla, ignora los body_exited que ocurren con la
## batalla en curso (el mapa pausado no permite salidas reales) y recién se
## rearma cuando el jugador SALE del área (body_exited) con el mapa vivo:
## para otra batalla hay que salir y volver a entrar.

## Se emite en el momento de disparar la batalla (antes del overlay).
signal encounter_triggered
## Se emite al volver de la batalla: &"victory" | &"defeat" | &"fled".
signal encounter_finished(result: StringName)

## Grupo enemigo de la zona: un BattleSettings con enemigos, fondo y música.
## Si su party está vacía, Encounters inyecta GameManager.party (la party viva).
@export var battle_settings: BattleSettings
## Probabilidad de que entrar al área dispare batalla (1.0 = siempre).
@export_range(0.0, 1.0, 0.05) var encounter_chance: float = 1.0
## Si es true, el área queda agotada después de la primera victoria.
@export var one_shot: bool = false

var _armed: bool = true
var _spent: bool = false
## True mientras la batalla de ESTA área corre: filtra el body_exited espurio
## que emite la pausa del mapa (sin esto, el área se rearmaba sola y encadenaba
## batallas con el jugador parado adentro).
var _in_battle: bool = false


func _ready() -> void:
	add_to_group(&"encounter_area")
	# DEFERRED: pausar el mapa (y sacar esta área del espacio de física)
	# no se puede hacer adentro del flush de señales de física.
	body_entered.connect(_on_body_entered, CONNECT_DEFERRED)
	body_exited.connect(_on_body_exited, CONNECT_DEFERRED)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not _armed or _spent:
		return
	if randf() > encounter_chance:
		return
	trigger_encounter()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	# Con la batalla corriendo el mapa está pausado: este body_exited es el
	# espurio de sacar el área del espacio de física, no una salida real.
	if _in_battle:
		return
	if not _spent:
		_armed = true


## Dispara la batalla de esta zona sin tirar el dado (para eventos y tests).
## Devuelve &"victory" | &"defeat" | &"fled", o &"ignored" si ya hay una
## batalla corriendo, el área está agotada o faltan settings.
func trigger_encounter() -> StringName:
	if _spent:
		return &"ignored"
	if battle_settings == null:
		push_warning("[EncounterArea] %s no tiene battle_settings asignado." % name)
		return &"ignored"
	_armed = false
	_in_battle = true
	encounter_triggered.emit()
	var result: StringName = await Encounters.start_encounter(battle_settings)
	_in_battle = false
	match result:
		&"ignored":
			_armed = true
		&"victory":
			if one_shot:
				_spent = true
		&"defeat":
			_return_home_defeated()
	encounter_finished.emit(result)
	return result


## Política de derrota de F2: el GameOver del addon está parcheado (destruía la
## escena actual), así que acá volvemos a la escena hogar con fade y revivimos
## la party a 1 HP para no encadenar derrotas instantáneas.
func _return_home_defeated() -> void:
	var party: Party = battle_settings.party if battle_settings.party else GameManager.party
	if party:
		for player: BattlerPlayer in party.players:
			player.current_hp = maxi(player.current_hp, 1)
	var home_scene: String = ThreadbareProjectSettings.get_setting(
		ThreadbareProjectSettings.HOME_SCENE
	)
	SceneSwitcher.change_to_file_with_transition(
		home_scene, ^"", Transition.Effect.FADE, Transition.Effect.FADE
	)
