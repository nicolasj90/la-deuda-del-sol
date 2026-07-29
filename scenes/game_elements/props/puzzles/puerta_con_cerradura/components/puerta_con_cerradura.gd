# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name PuertaConCerradura
extends Node2D

## Puerta con cerradura: se abre al interactuar si hay una [Llave] del tipo
## correcto en el llavero de la escena, y por defecto la consume.

## Emitida cuando la puerta se abre.
signal opened

## Emitida cuando se intentó abrir sin llave.
signal intento_fallido

## Tipo de llave que acepta. Ver [member Llave.tipo].
@export var tipo_llave: StringName = &"lacre"

## Si es [code]true[/code], la llave se gasta al abrir.
@export var consume_llave: bool = true

## Texto del indicador de interacción.
@export var accion: String = "Abrir"

## Mensaje para carteles/diálogos cuando falta la llave.
@export var mensaje_sin_llave: String = "Cerrada. Falta la llave de lacre."

## Estado de la puerta.
@export var abierta: bool = false:
	set(nuevo):
		abierta = nuevo
		_actualizar_estado()

@onready var interact_area: InteractArea = %InteractArea


func _ready() -> void:
	_actualizar_estado()
	interact_area.action = accion
	if Engine.is_editor_hint():
		return
	interact_area.interaction_started.connect(_on_interaction_started)


## ¿Hay una llave servible a mano?
func tiene_llave() -> bool:
	return Llave.buscar_en_llavero(self, tipo_llave) != null


## Intenta abrir. Devuelve [code]true[/code] si la puerta quedó abierta.
func intentar_abrir() -> bool:
	if abierta:
		return true
	var llave := Llave.buscar_en_llavero(self, tipo_llave)
	if llave == null:
		intento_fallido.emit()
		return false
	if consume_llave:
		llave.consumir(self)
	abierta = true
	opened.emit()
	return true


func _on_interaction_started(_jugador: Player, _desde_la_derecha: bool) -> void:
	intentar_abrir()
	await get_tree().process_frame
	interact_area.end_interaction()


func _actualizar_estado() -> void:
	if not is_node_ready():
		return

	var cerrada_sprite := get_node_or_null(^"%PuertaCerrada")
	if cerrada_sprite is CanvasItem:
		(cerrada_sprite as CanvasItem).visible = not abierta
	var abierta_sprite := get_node_or_null(^"%PuertaAbierta")
	if abierta_sprite is CanvasItem:
		(abierta_sprite as CanvasItem).visible = abierta
	var cerradura := get_node_or_null(^"%Cerradura")
	if cerradura is CanvasItem:
		(cerradura as CanvasItem).visible = not abierta

	var colisionador := get_node_or_null(^"%ColisionadorCerrada")
	if colisionador is StaticBody2D:
		var cuerpo := colisionador as StaticBody2D
		cuerpo.set_collision_layer_value(Enums.CollisionLayers.WALLS, not abierta)
		cuerpo.set_collision_mask_value(Enums.CollisionLayers.PLAYERS, not abierta)
