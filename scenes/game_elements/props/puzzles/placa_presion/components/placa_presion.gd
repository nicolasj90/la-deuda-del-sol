# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name PlacaPresion
extends Area2D

## Baldosa-sello que se hunde cuando la pisa el jugador o la cubre un bloque.
##
## Se conecta a una [PuertaSellada] (o a cualquier cosa) por [signal pressed] y
## [signal released]. Si [member permanente] es [code]true[/code], una vez
## hundida no vuelve a levantarse: el sello quedó estampado.

## Emitida cuando la placa pasa de libre a ocupada.
signal pressed

## Emitida cuando la placa pasa de ocupada a libre.
signal released

## ¿El peso del jugador alcanza para hundirla?
@export var acepta_jugador: bool = true

## ¿La cubre un [BloqueEmpujable]?
@export var acepta_bloque: bool = true

## Si es [code]true[/code], la placa queda hundida para siempre.
@export var permanente: bool = false

## Color del lacre cuando está hundida.
@export var color_hundida: Color = Color(0.85, 0.71, 0.31)

## Color cuando está libre.
@export var color_libre: Color = Color(0.35, 0.16, 0.16)

## [code]true[/code] mientras haya algo válido encima.
var occupied: bool = false:
	set(nuevo):
		occupied = nuevo
		_actualizar_apariencia()

var _ocupantes: Array[Node2D] = []


func _ready() -> void:
	_actualizar_apariencia()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Cantidad de cuerpos válidos apoyados sobre la placa.
func cantidad_ocupantes() -> int:
	return _ocupantes.size()


## ¿Este cuerpo tiene peso a los ojos de la placa?
func acepta(cuerpo: Node2D) -> bool:
	if cuerpo is BloqueEmpujable:
		return acepta_bloque
	if cuerpo.is_in_group(&"player"):
		return acepta_jugador
	return false


func _on_body_entered(cuerpo: Node2D) -> void:
	if not acepta(cuerpo) or _ocupantes.has(cuerpo):
		return
	_ocupantes.append(cuerpo)
	if _ocupantes.size() == 1 and not occupied:
		occupied = true
		pressed.emit()


func _on_body_exited(cuerpo: Node2D) -> void:
	if not _ocupantes.has(cuerpo):
		return
	_ocupantes.erase(cuerpo)
	if not _ocupantes.is_empty() or permanente or not occupied:
		return
	occupied = false
	released.emit()


func _actualizar_apariencia() -> void:
	if not is_node_ready():
		return
	var sello := get_node_or_null(^"%Sello")
	if sello is CanvasItem:
		(sello as CanvasItem).modulate = color_hundida if occupied else color_libre
	var hundida := get_node_or_null(^"%Hundida")
	if hundida is CanvasItem:
		(hundida as CanvasItem).visible = occupied
