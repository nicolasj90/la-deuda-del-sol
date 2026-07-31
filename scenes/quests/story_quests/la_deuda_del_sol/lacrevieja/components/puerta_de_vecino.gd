# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name PuertaDeVecino
extends Node2D

## La puerta de una casa de Lacrevieja: se golpea y contesta.
##
## Ninguna casa del pueblo se puede atravesar (la pared y el tejado son sólidos en
## [code]tiles_pueblo.tres[/code]), pero un vano de puerta dibujado y mudo es una
## promesa que el mapa no cumple. Este nodo no pone física propia — la pone la
## pared de atrás — y sólo agrega el rótulo con el nombre de la casa y una línea
## corta al golpear: quién vive ahí y por qué hoy no atiende.
##
## Va SIEMPRE sobre la celda del vano, con el jugador pudiendo pararse en ella.
## Lo genera [code]tools/gen-mapa-lacrevieja.py[/code] junto con el resto del pueblo.

## Nombre de la casa, el que se lee al acercarse.
@export var etiqueta: String = "casa del pueblo":
	set(nueva):
		etiqueta = nueva
		_actualizar_rotulo()

## Lo que contesta la casa cuando Ciro golpea. Registro Valdepalabra, línea corta.
@export_multiline var aviso: String = "Cerrado. Hoy no atiende nadie: la fiesta es en la plaza.":
	set(nueva):
		aviso = nueva
		_actualizar_rotulo()

## Texto del indicador de interacción.
@export var accion: String = "Golpear":
	set(nueva):
		accion = nueva
		if is_node_ready():
			(get_node(^"%InteractArea") as InteractArea).action = accion

## ¿Ya golpeó Ciro esta puerta? Mientras sea [code]true[/code] el rótulo muestra el
## [member aviso] en vez del nombre de la casa.
var golpeada: bool = false

@onready var interact_area: InteractArea = %InteractArea


func _ready() -> void:
	_actualizar_rotulo()
	interact_area.action = accion
	if Engine.is_editor_hint():
		return
	interact_area.interaction_started.connect(_on_interaction_started)
	# El rótulo aparece sólo con el jugador a tiro: si no, once puertas encendidas a
	# la vez convierten el pueblo en una feria de letreros.
	interact_area.observers_changed.connect(_on_observers_changed)
	_on_observers_changed()


## Golpea la puerta. Devuelve [code]true[/code] la primera vez.
func golpear() -> bool:
	var primera: bool = not golpeada
	golpeada = true
	_actualizar_rotulo()
	return primera


func _on_interaction_started(_jugador: Player, _desde_la_derecha: bool) -> void:
	golpear()
	await get_tree().process_frame
	interact_area.end_interaction()


func _on_observers_changed() -> void:
	var rotulo := get_node_or_null(^"%Rotulo")
	if rotulo is CanvasItem:
		(rotulo as CanvasItem).visible = interact_area.is_being_observed
	if not interact_area.is_being_observed:
		# Al alejarse la casa vuelve a presentarse por su nombre.
		golpeada = false
		_actualizar_rotulo()


func _actualizar_rotulo() -> void:
	if not is_node_ready():
		return
	var rotulo := get_node_or_null(^"%Rotulo")
	if rotulo is Label:
		(rotulo as Label).text = aviso if golpeada else etiqueta
