# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name Aljibe
extends Node2D

## Aljibe con balde: fuente de agua de los puzzles de "cumplir alivia".
##
## Se acciona con el botón de interacción de Threadbare (mismo patrón que
## [Palanca]). Cada interacción llena el balde; el que consume el agua es otro
## prop —típicamente una [ParraSeca]— llamando [method vaciar].
##
## El balde pierde: por eso [ParraSeca] pide más de un viaje. La cuenta de viajes
## vive en la parra, no acá; el aljibe sólo sabe si el balde está lleno.

## Emitida cuando el balde queda lleno.
signal balde_cargado

## Emitida cuando alguien consumió el agua del balde.
signal balde_vaciado

## Emitida al intentar cargar un balde que ya estaba lleno.
signal balde_ya_estaba_lleno

## Texto del indicador de interacción.
@export var accion: String = "Sacar agua":
	set(nueva):
		accion = nueva
		if is_node_ready():
			(get_node(^"%InteractArea") as InteractArea).action = accion

## ¿El balde tiene agua ahora mismo?
@export var balde_lleno: bool = false:
	set(nuevo):
		balde_lleno = nuevo
		_actualizar_apariencia()

## Rótulo del brocal. Texto visible.
@export var etiqueta: String = "Aljibe de Vidal":
	set(nueva):
		etiqueta = nueva
		_actualizar_apariencia()

@onready var interact_area: InteractArea = %InteractArea


func _ready() -> void:
	_actualizar_apariencia()
	interact_area.action = accion
	if Engine.is_editor_hint():
		return
	interact_area.interaction_started.connect(_on_interaction_started)


## Llena el balde. Devuelve [code]true[/code] si cambió algo.
func cargar() -> bool:
	if balde_lleno:
		balde_ya_estaba_lleno.emit()
		return false
	balde_lleno = true
	balde_cargado.emit()
	return true


## Consume el agua del balde. Devuelve [code]false[/code] si estaba vacío.
func vaciar() -> bool:
	if not balde_lleno:
		return false
	balde_lleno = false
	balde_vaciado.emit()
	return true


## ¿Hay agua para regar?
func tiene_agua() -> bool:
	return balde_lleno


func _on_interaction_started(_jugador: Player, _desde_la_derecha: bool) -> void:
	cargar()
	await get_tree().process_frame
	interact_area.end_interaction()


func _actualizar_apariencia() -> void:
	if not is_node_ready():
		return
	var agua := get_node_or_null(^"%Agua")
	if agua is CanvasItem:
		(agua as CanvasItem).visible = balde_lleno
	var estado := get_node_or_null(^"%Estado")
	if estado is Label:
		(estado as Label).text = (
			"%s — balde lleno" % etiqueta if balde_lleno else "%s — balde vacío" % etiqueta
		)
