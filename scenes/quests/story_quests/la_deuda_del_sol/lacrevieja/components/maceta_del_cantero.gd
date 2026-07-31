# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name MacetaDelCantero
extends Node2D

## Una de las seis macetas del cantero norte (promesita de la Maestra, E02).
##
## La sexta está [member rota]: rajada al medio y sin planta. Se riega igual —
## «Está en el cantero norte. Estaba en los términos» — y eso es todo el chiste
## de la escena hecho regla: el término dijo «todas».

## Emitida cuando esta maceta queda regada.
signal regada_ahora

## ¿Está rota y vacía? (la sexta del cantero).
@export var rota: bool = false:
	set(nueva):
		rota = nueva
		_actualizar_apariencia()

## ¿Ya está regada?
@export var regada: bool = false:
	set(nueva):
		regada = nueva
		_actualizar_apariencia()

## Texto del indicador de interacción.
@export var accion: String = "Regar":
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
	# El rótulo sólo aparece cuando el jugador tiene la maceta a tiro de mano. Antes
	# estaba siempre encendido y el anillo norte de la plaza era una fila de carteles
	# «maceta — seca» pisándose entre sí.
	interact_area.observers_changed.connect(_on_observers_changed)
	_on_observers_changed()


## Vuelca la regadera. Devuelve [code]true[/code] si esta maceta pasó a regada.
func regar() -> bool:
	if regada:
		return false
	regada = true
	regada_ahora.emit()
	return true


func _on_interaction_started(_jugador: Player, _desde_la_derecha: bool) -> void:
	regar()
	await get_tree().process_frame
	interact_area.end_interaction()


func _on_observers_changed() -> void:
	var estado := get_node_or_null(^"%Estado")
	if estado is CanvasItem:
		(estado as CanvasItem).visible = interact_area.is_being_observed


func _actualizar_apariencia() -> void:
	if not is_node_ready():
		return
	var planta := get_node_or_null(^"%Planta")
	if planta is Polygon2D:
		var hojas := planta as Polygon2D
		hojas.visible = not rota
		hojas.color = Color(0.36, 0.62, 0.33) if regada else Color(0.5, 0.52, 0.3)
	var tallo := get_node_or_null(^"%Tallo")
	if tallo is Polygon2D:
		var caña := tallo as Polygon2D
		caña.visible = not rota
		caña.color = Color(0.3, 0.55, 0.28) if regada else Color(0.45, 0.45, 0.28)
	# La maceta cumplida saca flor: es el estado que E02 tiene que mostrar SIN texto.
	for nombre: NodePath in [^"%Flor", ^"%FlorCentro"]:
		var petalos := get_node_or_null(nombre)
		if petalos is CanvasItem:
			(petalos as CanvasItem).visible = regada and not rota
	var rajadura := get_node_or_null(^"%Rajadura")
	if rajadura is CanvasItem:
		(rajadura as CanvasItem).visible = rota
	var agua := get_node_or_null(^"%Agua")
	if agua is CanvasItem:
		(agua as CanvasItem).visible = regada
	var estado := get_node_or_null(^"%Estado")
	if estado is Label:
		var texto: String = "maceta rota" if rota else "maceta"
		(estado as Label).text = "%s — regada" % texto if regada else "%s — seca" % texto
