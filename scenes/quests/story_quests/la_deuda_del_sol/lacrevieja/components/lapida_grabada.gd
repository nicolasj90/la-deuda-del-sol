# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name LapidaGrabada
extends Node2D

## Una de las dos piedras nuevas de Cosme (promesita de E02): se lee en voz alta.
##
## La segunda tiene una errata —«Erminia» por «Herminia»— y detectarla es el
## cumplimiento de la promesa: «Prometo leer los nombres nuevos y darte fe de
## erratas». Cosme la talla después; la piedra queda [member enmendada].

## Emitida la primera vez que se lee la piedra.
signal leida_ahora(con_errata: bool)

## Emitida cuando Cosme talla la enmienda.
signal enmendada_ahora

## Lo que dice la piedra, tal como está grabada. Texto visible.
@export_multiline var inscripcion: String = "":
	set(nueva):
		inscripcion = nueva
		_actualizar_apariencia()

## La letra que falta, si falta alguna. Vacío = piedra en regla.
@export var errata: String = "":
	set(nueva):
		errata = nueva
		_actualizar_apariencia()

## ¿Ya se leyó en voz alta?
@export var leida: bool = false:
	set(nueva):
		leida = nueva
		_actualizar_apariencia()

## ¿Cosme ya talló la enmienda?
@export var enmendada: bool = false:
	set(nueva):
		enmendada = nueva
		_actualizar_apariencia()

## Texto del indicador de interacción.
@export var accion: String = "Leer en voz alta":
	set(nueva):
		accion = nueva
		if is_node_ready():
			(get_node(^"%InteractArea") as InteractArea).action = accion

@onready var interact_area: InteractArea = %InteractArea


func _ready() -> void:
	_actualizar_apariencia()
	interact_area.action = accion
	if Engine.is_editor_hint():
		return
	interact_area.interaction_started.connect(_on_interaction_started)


## ¿Esta piedra le está debiendo una letra a un finado?
func tiene_errata() -> bool:
	return not errata.is_empty()


## Lee la piedra en voz alta. Devuelve [code]true[/code] si era la primera vez.
func leer() -> bool:
	if leida:
		return false
	leida = true
	leida_ahora.emit(tiene_errata())
	return true


## Cosme saca gubia y martillo. Devuelve [code]true[/code] si cambió algo.
func enmendar() -> bool:
	if enmendada or not tiene_errata():
		return false
	enmendada = true
	enmendada_ahora.emit()
	return true


func _on_interaction_started(_jugador: Player, _desde_la_derecha: bool) -> void:
	leer()
	await get_tree().process_frame
	interact_area.end_interaction()


func _actualizar_apariencia() -> void:
	if not is_node_ready():
		return
	var grabado := get_node_or_null(^"%Grabado")
	if grabado is Label:
		(grabado as Label).text = inscripcion
	var estado := get_node_or_null(^"%Estado")
	if estado is Label:
		var texto: String = "piedra sin leer"
		if enmendada:
			texto = "hache tallada: en regla"
		elif leida and tiene_errata():
			texto = "le falta una letra: «%s»" % errata
		elif leida:
			texto = "leída, en regla y sin mora"
		(estado as Label).text = texto
	var sello := get_node_or_null(^"%Enmienda")
	if sello is CanvasItem:
		(sello as CanvasItem).visible = enmendada
