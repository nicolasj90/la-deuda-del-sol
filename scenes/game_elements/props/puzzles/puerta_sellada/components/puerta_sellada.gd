# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name PuertaSellada
extends Toggleable

## Puerta que se abre cuando [member requiere_n] fuentes están activas a la vez.
##
## Las fuentes se declaran en [member fuentes] y pueden ser [PlacaPresion]
## ([signal PlacaPresion.pressed] / [signal PlacaPresion.released]), [Palanca] o
## [ReceptorDeFe] (señal [code]toggled(on)[/code]) — o cualquier nodo con esas
## señales. El conteo es por fuente distinta, así que una fuente que grite dos
## veces no cuenta doble.
##
## Hereda de [Toggleable] para poder engancharse también a los mecanismos de
## Threadbare; en ese caso [method set_toggled] fuerza el estado y saltea el
## contador (no mezclar las dos formas de cableado en la misma puerta).

## Emitida cuando la puerta se abre.
signal opened

## Emitida cuando la puerta se cierra.
signal closed

## Emitida con cada cambio del contador: útil para carteles o HUD.
signal progreso_cambiado(activas: int, requeridas: int)

## Cuántas fuentes activas hacen falta.
@export_range(0, 16, 1, "or_greater") var requiere_n: int = 1:
	set(nuevo):
		requiere_n = maxi(0, nuevo)
		if is_node_ready() and not Engine.is_editor_hint():
			_recontar()

## Placas, palancas o receptores que alimentan el contador.
@export var fuentes: Array[Node] = []

## Si es [code]true[/code], la puerta se cierra al cumplirse la condición.
@export var invertir: bool = false

## Si es [code]true[/code], una vez abierta no vuelve a cerrarse.
@export var permanente: bool = false

## Estado visible de la puerta.
@export var abierta: bool = false:
	set(nuevo):
		var cambio := nuevo != abierta
		abierta = nuevo
		_actualizar_estado()
		if cambio and is_node_ready() and not Engine.is_editor_hint():
			if abierta:
				opened.emit()
			else:
				closed.emit()

var _activas: Dictionary = {}


func _ready() -> void:
	_actualizar_estado()
	if Engine.is_editor_hint():
		return
	_conectar_fuentes()
	_sembrar_estado_inicial.call_deferred()


## Cuántas fuentes están activas ahora mismo.
## Descarta las que ya se liberaron, para no contar fantasmas.
func activas() -> int:
	_purgar_fuentes_muertas()
	return _activas.size()


## Registra (o desregistra) una fuente y recalcula el estado de la puerta.
func set_activacion(fuente: Object, activa: bool) -> void:
	if fuente == null:
		return
	if activa:
		_activas[fuente] = true
	else:
		_activas.erase(fuente)
	_recontar()


## Fuerza el estado, salteando el contador (compatibilidad con [Toggleable]).
func set_toggled(value: bool) -> void:
	abierta = value


func abrir() -> void:
	abierta = true


func cerrar() -> void:
	abierta = false


## Saca del contador las fuentes que fueron liberadas (queue_free): una fuente
## que ya no existe no puede seguir sosteniendo una puerta abierta.
func _purgar_fuentes_muertas() -> void:
	for fuente: Variant in _activas.keys():
		if fuente == null or not is_instance_valid(fuente):
			_activas.erase(fuente)


func _recontar() -> void:
	_purgar_fuentes_muertas()
	var cumplida := _activas.size() >= requiere_n
	var deberia_estar_abierta := not cumplida if invertir else cumplida
	progreso_cambiado.emit(_activas.size(), requiere_n)
	if permanente and abierta:
		return
	if deberia_estar_abierta != abierta:
		abierta = deberia_estar_abierta


func _conectar_fuentes() -> void:
	for fuente: Node in fuentes:
		if fuente == null:
			continue
		if fuente.has_signal(&"toggled"):
			fuente.connect(&"toggled", _on_fuente_toggled.bind(fuente))
		elif fuente.has_signal(&"pressed") and fuente.has_signal(&"released"):
			fuente.connect(&"pressed", set_activacion.bind(fuente, true))
			fuente.connect(&"released", set_activacion.bind(fuente, false))
		else:
			push_warning(
				"PuertaSellada: la fuente '%s' no tiene señales toggled ni pressed/released."
				% fuente.name
			)


func _sembrar_estado_inicial() -> void:
	for fuente: Node in fuentes:
		if fuente == null:
			continue
		if "occupied" in fuente:
			set_activacion(fuente, fuente.occupied)
		elif "on" in fuente:
			set_activacion(fuente, fuente.on)
		elif "iluminado" in fuente:
			set_activacion(fuente, fuente.iluminado)
	_recontar()


func _on_fuente_toggled(activa: bool, fuente: Node) -> void:
	set_activacion(fuente, activa)


func _actualizar_estado() -> void:
	if not is_node_ready():
		return

	var cerrada_sprite := get_node_or_null(^"%PuertaCerrada")
	if cerrada_sprite is CanvasItem:
		(cerrada_sprite as CanvasItem).visible = not abierta
	var abierta_sprite := get_node_or_null(^"%PuertaAbierta")
	if abierta_sprite is CanvasItem:
		(abierta_sprite as CanvasItem).visible = abierta

	var colisionador := get_node_or_null(^"%ColisionadorCerrada")
	if colisionador is StaticBody2D:
		var cuerpo := colisionador as StaticBody2D
		cuerpo.set_collision_layer_value(Enums.CollisionLayers.WALLS, not abierta)
		cuerpo.set_collision_mask_value(Enums.CollisionLayers.PLAYERS, not abierta)
