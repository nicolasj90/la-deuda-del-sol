# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name CofreDeDungeon
extends Node2D

## Cofre de recompensa, versión placeholder.
##
## No toca el inventario ni la colección de cartas todavía (eso es de la fase de
## contenido): se abre por interacción, muestra en pantalla qué había adentro y
## emite [signal abierto]. Sirve para cerrar los dungeons del Acto 1 sin
## depender de recursos que aún no existen.

## Emitida al abrirse, con el texto de la recompensa.
signal abierto(recompensa: String)

## Qué hay adentro. Texto visible.
@export_multiline var recompensa: String = "cartas de dungeon":
	set(nueva):
		recompensa = nueva
		_actualizar_apariencia()

## Texto del indicador de interacción.
@export var accion: String = "Abrir":
	set(nueva):
		accion = nueva
		if is_node_ready():
			(get_node(^"%InteractArea") as InteractArea).action = accion

## Si es [code]true[/code], el cofre ya está abierto de entrada.
@export var ya_abierto: bool = false:
	set(nuevo):
		ya_abierto = nuevo
		_actualizar_apariencia()

## Color de la madera cerrada.
@export var color_cerrado: Color = Color(0.42, 0.28, 0.18)

## Color de la madera abierta.
@export var color_abierto: Color = Color(0.85, 0.71, 0.31)

@onready var interact_area: InteractArea = %InteractArea


func _ready() -> void:
	_actualizar_apariencia()
	interact_area.action = accion
	if Engine.is_editor_hint():
		return
	interact_area.interaction_started.connect(_on_interaction_started)


## Abre el cofre. Devuelve [code]false[/code] si ya estaba abierto.
func abrir() -> bool:
	if ya_abierto:
		return false
	ya_abierto = true
	abierto.emit(recompensa)
	return true


func _on_interaction_started(_jugador: Player, _desde_la_derecha: bool) -> void:
	abrir()
	await get_tree().process_frame
	interact_area.end_interaction()


func _actualizar_apariencia() -> void:
	if not is_node_ready():
		return

	var caja := get_node_or_null(^"%Caja")
	if caja is Polygon2D:
		(caja as Polygon2D).color = color_abierto if ya_abierto else color_cerrado

	var tapa := get_node_or_null(^"%Tapa")
	if tapa is Node2D:
		(tapa as Node2D).rotation = -0.6 if ya_abierto else 0.0

	var etiqueta := get_node_or_null(^"%Recompensa")
	if etiqueta is Label:
		(etiqueta as Label).text = recompensa
		(etiqueta as Label).visible = ya_abierto

	var interactuable := get_node_or_null(^"%InteractArea")
	if interactuable is InteractArea:
		(interactuable as InteractArea).disabled = ya_abierto
