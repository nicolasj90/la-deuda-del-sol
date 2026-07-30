# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name LamparaDePalabra
extends Node2D

## Lámpara de palabra: el alumbrado público de Valdepalabra (E02).
##
## No se prende con fuego ni con aceite: se prende con [b]palabra cumplida[/b]. La
## enciende el mapa cuando una promesita se disuelve ([method encender]); una vez
## encendida no se apaga (E13 deja la del porche «encendida permanente»).
##
## Es un prop de placeholder gráfico —polígonos, como el resto del Acto 1— pensado
## para que arte lo reemplace sin tocar la lógica: lo único que mira el juego es
## [member encendida].

## Emitida cuando la lámpara pasa de fría a encendida.
signal encendio

## ¿Está encendida ahora mismo?
@export var encendida: bool = false:
	set(nueva):
		encendida = nueva
		_actualizar_apariencia()

## Rótulo del poste. Texto visible.
@export var etiqueta: String = "lámpara de palabra":
	set(nueva):
		etiqueta = nueva
		_actualizar_apariencia()

## Si es [code]false[/code], no se dibuja el rótulo (plaza ya aprendida).
@export var mostrar_etiqueta: bool = true:
	set(nueva):
		mostrar_etiqueta = nueva
		_actualizar_apariencia()


func _ready() -> void:
	_actualizar_apariencia()


## Enciende la lámpara. Devuelve [code]true[/code] si cambió algo (nunca se apaga).
func encender() -> bool:
	if encendida:
		return false
	encendida = true
	encendio.emit()
	return true


func _actualizar_apariencia() -> void:
	if not is_node_ready():
		return
	var luz := get_node_or_null(^"%Luz")
	if luz is CanvasItem:
		(luz as CanvasItem).visible = encendida
	var halo := get_node_or_null(^"%Halo")
	if halo is CanvasItem:
		(halo as CanvasItem).visible = encendida
	var farol := get_node_or_null(^"%Farol")
	if farol is Polygon2D:
		(farol as Polygon2D).color = (
			Color(1.0, 0.88, 0.55) if encendida else Color(0.26, 0.24, 0.24)
		)
	var estado := get_node_or_null(^"%Estado")
	if estado is Label:
		var etiqueta_nodo := estado as Label
		etiqueta_nodo.visible = mostrar_etiqueta
		etiqueta_nodo.text = (
			"%s — encendida" % etiqueta if encendida else "%s — fría" % etiqueta
		)
