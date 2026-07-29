# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name Palanca
extends Node2D

## Palanca de tinta: se acciona con el botón de interacción de Threadbare.
##
## Usa el mismo patrón que el [code]lever[/code] de Threadbare (un [InteractArea]
## que emite [signal InteractArea.interaction_started]), pero expone además
## [member un_solo_uso] para las palancas que sellan un mecanismo de una vez.

## Emitida cada vez que la palanca cambia de posición.
signal toggled(on: bool)

## Emitida al iniciar, para que los mecanismos conectados arranquen sincronizados.
signal initialized(on: bool)

## Posición actual de la palanca. Asignarla directamente NO emite [signal toggled];
## para eso está [method alternar].
@export var on: bool = false:
	set(nuevo):
		on = nuevo
		_actualizar_apariencia()

## Si es [code]true[/code], una vez accionada ya no vuelve atrás.
@export var un_solo_uso: bool = false

## Texto del indicador de interacción.
@export var accion: String = "Accionar":
	set(nuevo):
		accion = nuevo
		if is_node_ready():
			(get_node(^"%InteractArea") as InteractArea).action = accion

@onready var interact_area: InteractArea = %InteractArea


func _ready() -> void:
	_actualizar_apariencia()
	interact_area.action = accion
	if Engine.is_editor_hint():
		return
	interact_area.interaction_started.connect(_on_interaction_started)
	initialize_toggle_state.call_deferred()


## Reemite el estado inicial para los mecanismos conectados.
func initialize_toggle_state() -> void:
	initialized.emit(on)


## Cambia la posición de la palanca y avisa. Devuelve [code]true[/code] si cambió.
func alternar(nuevo: bool = not on) -> bool:
	if un_solo_uso and on:
		return false
	if nuevo == on:
		return false
	on = nuevo
	toggled.emit(on)
	return true


func _on_interaction_started(_jugador: Player, _desde_la_derecha: bool) -> void:
	alternar()
	await get_tree().process_frame
	interact_area.end_interaction()


func _actualizar_apariencia() -> void:
	if not is_node_ready():
		return
	var sprite := get_node_or_null(^"%SpritePalanca")
	if sprite is Sprite2D:
		(sprite as Sprite2D).frame = 1 if on else 0
