# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name PuntoDeCarga
extends Node2D

## Los dos extremos del acarreo de la promesita de Rosaura (E02):
## la pila de atados del galpón y la boca del horno grande.
##
## El guion pide «acarrear la leña al horno — el peso de los atados se suma al de
## la prenda: caminar cargado es el minijuego». Acá está la mitad diegética: un
## punto en modo [constant Modo.TOMAR] entrega un atado, un punto en modo
## [constant Modo.DEJAR] lo recibe, y el viaje lo hace el jugador con las piernas.
## El castigo de peso mientras se camina cargado es de la capa de movimiento del
## jugador (pendiente de F1-esqueleto): este prop expone [method cargando] para
## que se enganche sin tocar la escena.
##
## Mismo patrón de interacción que [Aljibe] / [ParraSeca]: un [InteractArea] que
## se acciona con el botón de interacción de Threadbare.

## Emitida cuando el jugador levanta un atado del punto de origen.
signal tomado

## Emitida cada vez que se deja un atado en el punto de destino.
signal dejado(entregados: int, cupo: int)

## Emitida cuando el destino junta [member cupo] atados: la tarea está cumplida.
signal completo

enum Modo {
	## Punto de origen: entrega un atado por vez.
	TOMAR,
	## Punto de destino: recibe atados hasta llenar [member cupo].
	DEJAR,
}

## Qué papel juega este punto.
@export var modo: Modo = Modo.TOMAR:
	set(nuevo):
		modo = nuevo
		_actualizar_apariencia()

## El otro extremo del acarreo. El destino lo usa para saber si el jugador viene
## cargado; el origen, para no dar más atados de los que hacen falta.
@export var enlace: PuntoDeCarga

## Cuántos atados hacen falta (sólo lo mira el punto en modo
## [constant Modo.DEJAR]).
@export_range(1, 12, 1) var cupo: int = 3:
	set(nuevo):
		cupo = maxi(1, nuevo)
		_actualizar_apariencia()

## Rótulo del punto. Texto visible.
@export var etiqueta: String = "":
	set(nueva):
		etiqueta = nueva
		_actualizar_apariencia()

## Texto del indicador de interacción.
@export var accion: String = "Cargar":
	set(nueva):
		accion = nueva
		if is_node_ready():
			(get_node(^"%InteractArea") as InteractArea).action = accion

## ¿El jugador tiene un atado en brazos ahora mismo? Vive en el punto de origen.
var cargando: bool = false:
	set(nuevo):
		cargando = nuevo
		_actualizar_apariencia()
		if enlace != null and is_instance_valid(enlace):
			enlace._actualizar_apariencia()

## Atados ya entregados. Vive en el punto de destino.
var entregados: int = 0

@onready var interact_area: InteractArea = %InteractArea


func _ready() -> void:
	_actualizar_apariencia()
	interact_area.action = accion
	if Engine.is_editor_hint():
		return
	interact_area.interaction_started.connect(_on_interaction_started)
	# La cuenta de atados sólo se rotula con el jugador a tiro de mano: el «horno
	# grande de Rosaura — 0/3 atados» flotando siempre sobre el mapa era una etiqueta
	# de depuración, no información de juego. Lo que se lee de lejos es el atado.
	interact_area.observers_changed.connect(_on_observers_changed)
	_on_observers_changed()


## ¿La tarea ya está cumplida? La cuenta vive en el punto de destino.
func cumplido() -> bool:
	var destino: PuntoDeCarga = self if modo == Modo.DEJAR else enlace
	if destino == null or not is_instance_valid(destino):
		return false
	return destino.entregados >= destino.cupo


## Levanta un atado. Devuelve [code]true[/code] si el jugador quedó cargado.
func tomar() -> bool:
	if modo != Modo.TOMAR:
		return false
	if cargando or cumplido():
		return false
	cargando = true
	tomado.emit()
	return true


## Deja el atado que trae el jugador. Devuelve [code]true[/code] si entró uno.
func dejar() -> bool:
	if modo != Modo.DEJAR:
		return false
	if entregados >= cupo:
		return false
	var origen: PuntoDeCarga = enlace
	if origen == null or not is_instance_valid(origen) or not origen.cargando:
		return false
	origen.cargando = false
	entregados += 1
	_actualizar_apariencia()
	dejado.emit(entregados, cupo)
	if entregados >= cupo:
		completo.emit()
	return true


## Fija la cuenta de atados entregados (restaurar la partida, o el smoke).
func fijar_entregados(cuantos: int) -> void:
	entregados = clampi(cuantos, 0, cupo)
	_actualizar_apariencia()


## Lo que corresponda según el modo. Es lo que llama el botón de interacción.
func usar() -> bool:
	return tomar() if modo == Modo.TOMAR else dejar()


func _on_interaction_started(_jugador: Player, _desde_la_derecha: bool) -> void:
	usar()
	await get_tree().process_frame
	interact_area.end_interaction()


func _on_observers_changed() -> void:
	var estado := get_node_or_null(^"%Estado")
	if estado is CanvasItem:
		(estado as CanvasItem).visible = interact_area.is_being_observed


func _actualizar_apariencia() -> void:
	if not is_node_ready():
		return
	var estado := get_node_or_null(^"%Estado")
	if estado is Label:
		(estado as Label).text = _texto_de_estado()
	# En el origen el atado visible es el que falta llevarse; en el destino, la leña
	# ya entrada. Es el estado que se lee de lejos, sin rótulo.
	var hay_atado: bool = (
		(not cargando and not cumplido()) if modo == Modo.TOMAR else entregados > 0
	)
	for nombre: NodePath in [^"%Atado", ^"%AtadoCuerda"]:
		var bulto := get_node_or_null(nombre)
		if bulto is CanvasItem:
			(bulto as CanvasItem).visible = hay_atado


func _texto_de_estado() -> String:
	var nombre: String = etiqueta
	if nombre.is_empty():
		nombre = "pila de leña" if modo == Modo.TOMAR else "horno grande"
	if modo == Modo.TOMAR:
		if cumplido():
			return "%s — vacía: la leña ya está adentro" % nombre
		return "%s — con un atado en brazos" % nombre if cargando else "%s" % nombre
	if entregados >= cupo:
		return "%s — cargado (%d/%d atados)" % [nombre, entregados, cupo]
	return "%s — %d/%d atados" % [nombre, entregados, cupo]
