# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name BloqueEnMora
extends BloqueEmpujable

## Bloque-prenda: inamovible porque adentro duerme una promesa incumplida.
##
## En el sello se lee la tarea pendiente ([member tarea]). Cuando algo del propio
## dungeon cumple esa tarea y llama [method BloqueEmpujable.aliviar] (o emite la
## señal cableada en [member disparador]), el bloque brilla y recién entonces se
## puede empujar.

## Tarea pendiente escrita en el sello. Texto visible.
@export var tarea: String = "tarea pendiente":
	set(nueva):
		tarea = nueva
		_actualizar_texto()

## Nodo que avisa que la tarea se cumplió. Se conecta la señal [member senal_disparador].
@export var disparador: Node

## Nombre de la señal de [member disparador] que alivia el bloque.
@export var senal_disparador: StringName = &"pressed"

## Color del bloque mientras está en mora.
@export var color_mora: Color = Color(0.5, 0.46, 0.58)

## Color del bloque una vez aliviado.
@export var color_aliviado: Color = Color(1, 0.96, 0.82)

var _brillo: Tween


func _ready() -> void:
	# Un bloque en mora nace en mora salvo que el diseñador diga lo contrario.
	super._ready()
	_actualizar_texto()
	if Engine.is_editor_hint():
		return
	if disparador and disparador.has_signal(senal_disparador):
		disparador.connect(senal_disparador, _on_disparador)
	elif disparador:
		push_warning(
			"BloqueEnMora: '%s' no tiene la señal '%s'." % [disparador.name, senal_disparador]
		)


func aliviar() -> void:
	var estaba_en_mora := en_mora
	super.aliviar()
	if estaba_en_mora and not Engine.is_editor_hint():
		_brillar()


func _on_disparador(_a: Variant = null, _b: Variant = null) -> void:
	aliviar()


func _actualizar_texto() -> void:
	if not is_node_ready():
		return
	var etiqueta := get_node_or_null(^"%Sello")
	if etiqueta is Label:
		(etiqueta as Label).text = tarea
		(etiqueta as Label).visible = en_mora


func _actualizar_apariencia() -> void:
	if not is_node_ready():
		return
	var sprite := get_node_or_null(^"%Sprite")
	if sprite is CanvasItem:
		(sprite as CanvasItem).modulate = color_mora if en_mora else color_aliviado
	_actualizar_texto()


func _brillar() -> void:
	var sprite := get_node_or_null(^"%Sprite")
	if not sprite is CanvasItem:
		return
	if _brillo:
		_brillo.kill()
	_brillo = create_tween()
	_brillo.tween_property(sprite, "modulate", Color(1.6, 1.5, 1.1), 0.15)
	_brillo.tween_property(sprite, "modulate", color_aliviado, 0.5)
