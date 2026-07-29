# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name CapaObjetivo
extends Control

## Capa de elección de objetivo. **Es trabajo propio, no configuración**: en el
## addon no se puede soltar una carta sobre otra carta (§ 6.2.2). Los `DropZone`
## pertenecen a *contenedores* y `_card_can_be_added(cards)` recibe solo las
## cartas, sin objetivo: elegir a qué Fiador enemigo atacar o a quién buffear no
## se puede expresar con drop zones.
##
## Cómo funciona: mientras está activa se pone `can_be_interacted_with = false`
## en todas las cartas (lo hace la vista) y esta capa, que está por encima de
## todo, se come el input. Click izquierdo sobre un objetivo marcado lo elige;
## click derecho o Escape cancela.
##
## No conoce el motor: la vista le pasa qué nodos son objetivos legales y con qué
## uid del motor se corresponde cada uno.

signal elegido(uid: int)
signal cancelado

const COLOR_MARCO: Color = Color(1.0, 0.85, 0.25, 0.95)
const COLOR_RELLENO: Color = Color(1.0, 0.85, 0.25, 0.18)
const COLOR_VELO: Color = Color(0.0, 0.0, 0.0, 0.28)
const GROSOR: float = 3.0
const AIRE: float = 4.0

var activa: bool = false

var _objetivos: Array[Dictionary] = []
var _aviso: Label = null


func _ready() -> void:
	_aviso = get_node_or_null("Aviso") as Label
	set_process(false)
	_apagar()


## Pide un objetivo. [param objetivos] son diccionarios
## `{ "uid": int, "nodo": Control }`; `uid == -1` es la Firma rival.
func pedir(objetivos: Array[Dictionary], texto: String) -> void:
	_objetivos = objetivos.duplicate()
	activa = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _aviso != null:
		_aviso.text = texto
		_aviso.visible = true
	set_process(true)
	queue_redraw()


## Cierra la capa sin elegir nada (la usa la vista cuando el motor termina el
## duelo a mitad de una elección).
func cerrar() -> void:
	_apagar()


func objetivos() -> Array[Dictionary]:
	return _objetivos.duplicate()


func _apagar() -> void:
	activa = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objetivos = []
	set_process(false)
	if _aviso != null:
		_aviso.visible = false
	queue_redraw()


func _process(_delta: float) -> void:
	# Los naipes se mueven con tween: los marcos tienen que seguirlos.
	queue_redraw()


func _draw() -> void:
	if not activa:
		return
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_VELO, true)
	for objetivo: Dictionary in _objetivos:
		var r: Rect2 = _rect_de(objetivo)
		if r.size == Vector2.ZERO:
			continue
		draw_rect(r, COLOR_RELLENO, true)
		draw_rect(r, COLOR_MARCO, false, GROSOR)


func _gui_input(evento: InputEvent) -> void:
	if not activa:
		return
	var clic: InputEventMouseButton = evento as InputEventMouseButton
	if clic == null or not clic.pressed:
		return
	if clic.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		_apagar()
		cancelado.emit()
		return
	if clic.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	var donde: Vector2 = clic.position
	for objetivo: Dictionary in _objetivos:
		if _rect_de(objetivo).has_point(donde):
			var uid: int = int(objetivo.get("uid", -1))
			_apagar()
			elegido.emit(uid)
			return


func _unhandled_key_input(evento: InputEvent) -> void:
	if not activa:
		return
	var tecla: InputEventKey = evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.keycode != KEY_ESCAPE:
		return
	accept_event()
	_apagar()
	cancelado.emit()


func _rect_de(objetivo: Dictionary) -> Rect2:
	var nodo: Control = objetivo.get("nodo", null) as Control
	if nodo == null or not is_instance_valid(nodo) or not nodo.is_inside_tree():
		return Rect2()
	var global: Rect2 = nodo.get_global_rect()
	var local: Rect2 = Rect2(global.position - global_position, global.size)
	return local.grow(AIRE)
