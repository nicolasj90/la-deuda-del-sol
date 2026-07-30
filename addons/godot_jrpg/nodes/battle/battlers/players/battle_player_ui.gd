class_name BattlePlayerUI extends BattleBattlerUI

## LA DEUDA PATCH: upstream deja el Label con el texto de diseño
## ("BattlePlayer") y nunca lo pisa, así que en la batalla toda la party se
## llamaba igual.
@onready var name_label: Label = get_node("%Name")
@onready var hp_bar: Bar = get_node("%HPBar")
@onready var mp_bar: Bar = get_node("%MPBar")
@onready var current_hp_label: BarLabel = get_node("%CurrentHP")
@onready var current_mp_label: BarLabel = get_node("%CurrentMP")
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var engine: BattleEngine
var player: BattlerPlayer

func _init() -> void:
	focus_entered.connect(_on_focus_entered)

func setup(_engine: BattleEngine, _player: BattlerPlayer):
	engine = _engine
	player = _player
	if not is_node_ready(): await ready
	name_label.text = player.name
	hp_bar.setup(player.stats.hp.get_value(), player.current_hp, player.hp_changed)
	mp_bar.setup(player.stats.mp.get_value(), player.current_mp, player.mp_changed)
	current_hp_label.setup(player.current_hp, player.hp_changed)
	current_mp_label.setup(player.current_mp, player.mp_changed)

func flash() -> void:
	if not is_node_ready(): await ready
	animation_player.play("flash")

func stop_flash() -> void:
	animation_player.stop()

func die():
	pass

func _on_button_up():
	super()
	engine.battle_signals.player_selected.emit(player)

func _on_focus_entered():
	engine.battle_signals.player_changed.emit(player)
