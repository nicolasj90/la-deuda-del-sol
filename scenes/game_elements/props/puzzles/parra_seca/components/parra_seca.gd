# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name ParraSeca
extends Node2D

## Parra en mora: la tarea pendiente de un [BloqueEnMora] hecha objeto del mundo.
##
## Se riega con el agua de un [Aljibe] (o de cualquier nodo con
## [code]vaciar()[/code] y [code]tiene_agua()[/code]). El balde pierde, así que
## hace falta más de un viaje: [member baldes_necesarios]. Cuando se completa,
## emite [signal regada] — que es la señal que se cablea al
## [member BloqueEnMora.disparador] para que el bloque se alivie.

## Emitida cuando la parra queda regada (tarea cumplida).
signal regada

## Emitida con cada balde volcado.
signal progreso(baldes: int, necesarios: int)

## Emitida al intentar regar con el balde vacío.
signal intento_sin_agua

## Tarea, tal como se lee en el sello del bloque. Texto visible.
@export var tarea: String = "regar la parra del cerco sur":
	set(nueva):
		tarea = nueva
		_actualizar_apariencia()

## Fuente de agua: normalmente el [Aljibe] del propio dungeon.
@export var fuente_de_agua: Node

## Cuántos baldes hacen falta (el balde pierde: por eso más de uno).
@export_range(1, 8, 1) var baldes_necesarios: int = 2:
	set(nuevos):
		baldes_necesarios = maxi(1, nuevos)
		_actualizar_apariencia()

## Texto del indicador de interacción.
@export var accion: String = "Regar":
	set(nueva):
		accion = nueva
		if is_node_ready():
			(get_node(^"%InteractArea") as InteractArea).action = accion

## Qué se muestra si se intenta regar sin agua. Texto visible.
@export var mensaje_sin_agua: String = "El balde está seco. Hay un aljibe en el patio."

## Color de la parra seca.
@export var color_seca: Color = Color(0.45, 0.4, 0.3)

## Color de la parra viva.
@export var color_viva: Color = Color(0.35, 0.6, 0.32)

## Baldes volcados hasta ahora.
var baldes: int = 0

## [code]true[/code] cuando la tarea ya está cumplida.
var viva: bool = false

var _aviso: Tween

@onready var interact_area: InteractArea = %InteractArea


func _ready() -> void:
	_actualizar_apariencia()
	interact_area.action = accion
	if Engine.is_editor_hint():
		return
	interact_area.interaction_started.connect(_on_interaction_started)


## Vuelca un balde. Devuelve [code]true[/code] si el agua llegó a la tierra.
func regar() -> bool:
	if viva:
		return false

	if fuente_de_agua == null or not fuente_de_agua.has_method(&"vaciar"):
		push_warning("ParraSeca: no tiene fuente_de_agua con vaciar().")
		intento_sin_agua.emit()
		_mostrar_aviso(mensaje_sin_agua)
		return false

	if not fuente_de_agua.call(&"vaciar"):
		intento_sin_agua.emit()
		_mostrar_aviso(mensaje_sin_agua)
		return false

	baldes += 1
	progreso.emit(baldes, baldes_necesarios)
	_actualizar_apariencia()

	if baldes >= baldes_necesarios:
		viva = true
		_actualizar_apariencia()
		regada.emit()
	return true


## ¿Queda agua disponible en la fuente?
func hay_agua_disponible() -> bool:
	if fuente_de_agua == null or not fuente_de_agua.has_method(&"tiene_agua"):
		return false
	return bool(fuente_de_agua.call(&"tiene_agua"))


func _on_interaction_started(_jugador: Player, _desde_la_derecha: bool) -> void:
	regar()
	await get_tree().process_frame
	interact_area.end_interaction()


func _mostrar_aviso(texto: String) -> void:
	var aviso := get_node_or_null(^"%Aviso")
	if not aviso is Label:
		return
	var etiqueta := aviso as Label
	etiqueta.text = texto
	etiqueta.modulate = Color.WHITE
	etiqueta.visible = true
	if Engine.is_editor_hint():
		return
	if _aviso:
		_aviso.kill()
	_aviso = create_tween()
	_aviso.tween_interval(2.0)
	_aviso.tween_property(etiqueta, "modulate", Color.TRANSPARENT, 0.5)
	_aviso.tween_callback(func() -> void: etiqueta.visible = false)


func _actualizar_apariencia() -> void:
	if not is_node_ready():
		return

	var hojas := get_node_or_null(^"%Hojas")
	if hojas is Polygon2D:
		(hojas as Polygon2D).color = color_viva if viva else color_seca

	var estado := get_node_or_null(^"%Estado")
	if estado is Label:
		(estado as Label).text = (
			"parra regada"
			if viva
			else "%s (%d/%d baldes)" % [tarea, baldes, baldes_necesarios]
		)
