# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name ReceptorDeFe
extends Area2D

## Estrado que se enciende cuando lo alcanza el haz de una [EstatuaTestigo].
##
## Vive en la capa física 11 (sin nombre en el proyecto: reservada acá para
## "receptores de fe") para que los [RayCast2D] de las estatuas la detecten sin
## chocar con las áreas de interacción.

## Emitida al encenderse.
signal encendido

## Emitida al apagarse.
signal apagado

## Emitida con cada cambio: formato uniforme para cablear una [PuertaSellada].
signal toggled(on: bool)

## Si es [code]true[/code], una vez iluminado no se apaga nunca más.
@export var permanente: bool = false

## Color cuando está iluminado.
@export var color_encendido: Color = Color(1, 0.93, 0.68)

## Color cuando está apagado.
@export var color_apagado: Color = Color(0.28, 0.24, 0.3)

## [code]true[/code] mientras al menos un haz lo alcance.
var iluminado: bool = false:
	set(nuevo):
		var cambio := nuevo != iluminado
		iluminado = nuevo
		_actualizar_apariencia()
		if not cambio or not is_node_ready() or Engine.is_editor_hint():
			return
		toggled.emit(iluminado)
		if iluminado:
			encendido.emit()
		else:
			apagado.emit()

var _fuentes: Dictionary = {}


func _ready() -> void:
	_actualizar_apariencia()


## Cuántos haces lo están alcanzando.
func cantidad_haces() -> int:
	return _fuentes.size()


## Una estatua declara que su haz llega hasta acá.
func iluminar(fuente: Node) -> void:
	if fuente == null:
		return
	_fuentes[fuente] = true
	iluminado = true


## Una estatua declara que su haz ya no llega.
func apagar(fuente: Node) -> void:
	_fuentes.erase(fuente)
	if permanente:
		return
	iluminado = not _fuentes.is_empty()


func _actualizar_apariencia() -> void:
	if not is_node_ready():
		return
	var brasa := get_node_or_null(^"%Brasa")
	if brasa is Polygon2D:
		(brasa as Polygon2D).color = color_encendido if iluminado else color_apagado
	var halo := get_node_or_null(^"%Halo")
	if halo is CanvasItem:
		(halo as CanvasItem).visible = iluminado
