# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name DialogoDePalabra
extends Control

## Diálogo de confirmación con opciones armadas en runtime.
##
## Lo usan las dos decisiones del duelo que **no** son un objetivo en la mesa:
##
## - **la Promesa** al jugar una carta (§ 3): cláusula + plazo, o «sin Promesa».
##   Es un diálogo y no un gesto porque una Promesa es un compromiso con plazo:
##   si se pudiera firmar sin querer, el arquetipo de palabra rota sería una
##   trampa en vez de una decisión.
## - **el tipo declarado** al denunciar una carta en viaje (§ 4.2).
##
## No conoce el motor ni las reglas: recibe textos y valores, devuelve el valor
## elegido. Las opciones se recalculan cada vez que se abre; no se cachea nada.

signal elegido(valor: Variant)
signal cancelado

var _titulo: Label = null
var _detalle: Label = null
var _opciones: VBoxContainer = null
var _cancelar: Button = null

var _valores: Array = []


func _ready() -> void:
	_titulo = get_node_or_null("Panel/Caja/Titulo") as Label
	_detalle = get_node_or_null("Panel/Caja/Detalle") as Label
	_opciones = get_node_or_null("Panel/Caja/Scroll/Opciones") as VBoxContainer
	_cancelar = get_node_or_null("Panel/Caja/Cancelar") as Button
	if _cancelar != null:
		_cancelar.pressed.connect(_al_cancelar)
	cerrar()


## Abre el diálogo. [param opciones] son diccionarios
## `{ "texto": String, "valor": Variant }`.
func preguntar(titulo: String, detalle: String, opciones: Array[Dictionary]) -> void:
	if _opciones == null:
		push_error("DialogoDePalabra: la escena no tiene Panel/Caja/Scroll/Opciones")
		return
	for hijo: Node in _opciones.get_children():
		hijo.queue_free()
	_valores = []
	if _titulo != null:
		_titulo.text = titulo
	if _detalle != null:
		_detalle.text = detalle
		_detalle.visible = not detalle.is_empty()
	for i: int in opciones.size():
		var opcion: Dictionary = opciones[i]
		var boton: Button = Button.new()
		boton.text = String(opcion.get("texto", "?"))
		boton.tooltip_text = String(opcion.get("ayuda", ""))
		boton.pressed.connect(_al_elegir.bind(i))
		_opciones.add_child(boton)
		_valores.append(opcion.get("valor", null))
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not opciones.is_empty():
		var primero: Button = _opciones.get_child(0) as Button
		if primero != null:
			primero.grab_focus()


func abierto() -> bool:
	return visible


func cerrar() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _al_elegir(indice: int) -> void:
	if indice < 0 or indice >= _valores.size():
		return
	var valor: Variant = _valores[indice]
	cerrar()
	elegido.emit(valor)


func _al_cancelar() -> void:
	cerrar()
	cancelado.emit()


func _unhandled_key_input(evento: InputEvent) -> void:
	if not visible:
		return
	var tecla: InputEventKey = evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.keycode != KEY_ESCAPE:
		return
	accept_event()
	_al_cancelar()
