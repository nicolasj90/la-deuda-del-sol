# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name Llave
extends Area2D

## Llave de lacre: pickup por contacto que queda en un llavero local.
##
## No usa autoloads ni el inventario del juego: al recogerse, la llave se agrega
## al grupo [constant GRUPO_RECOGIDAS], y cualquier [PuertaConCerradura] del
## mismo árbol la encuentra por [member tipo]. El nodo sobrevive (oculto) hasta
## que una cerradura lo consume, así el llavero es puro estado de escena.

## Grupo donde viven las llaves ya recogidas.
const GRUPO_RECOGIDAS: StringName = &"llaves_recogidas"

## Emitida al recogerla.
signal recogida(llave: Llave)

## Emitida cuando una cerradura la gasta.
signal consumida_por(cerradura: Node)

## Qué cerraduras abre. Tiene que coincidir con [member PuertaConCerradura.tipo_llave].
@export var tipo: StringName = &"lacre"

## Nombre visible de la llave, para carteles y diálogos.
@export var etiqueta: String = "Llave de lacre"

## Color del lacre de esta llave.
@export var color: Color = Color(0.85, 0.71, 0.31):
	set(nuevo):
		color = nuevo
		_actualizar_apariencia()

## [code]true[/code] si ya está en el llavero.
var recolectada: bool = false

## [code]true[/code] si una cerradura ya la gastó.
var consumida: bool = false


func _ready() -> void:
	_actualizar_apariencia()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)


## Mete la llave en el llavero. Devuelve [code]true[/code] si la recogió recién.
func recoger() -> bool:
	if recolectada:
		return false
	recolectada = true
	add_to_group(GRUPO_RECOGIDAS)
	monitoring = false
	visible = false
	recogida.emit(self)
	return true


## La gasta una cerradura. Devuelve [code]true[/code] si estaba disponible.
func consumir(cerradura: Node = null) -> bool:
	if not recolectada or consumida:
		return false
	consumida = true
	remove_from_group(GRUPO_RECOGIDAS)
	consumida_por.emit(cerradura)
	return true


## ¿Sirve para abrir una cerradura de este tipo?
func sirve_para(tipo_buscado: StringName) -> bool:
	return recolectada and not consumida and tipo == tipo_buscado


## Busca en el llavero de la escena una llave disponible del tipo pedido.
static func buscar_en_llavero(nodo: Node, tipo_buscado: StringName) -> Llave:
	if nodo == null or not nodo.is_inside_tree():
		return null
	for candidata: Node in nodo.get_tree().get_nodes_in_group(GRUPO_RECOGIDAS):
		if candidata is Llave and (candidata as Llave).sirve_para(tipo_buscado):
			return candidata as Llave
	return null


func _on_body_entered(cuerpo: Node2D) -> void:
	if cuerpo.is_in_group(&"player"):
		recoger()


func _actualizar_apariencia() -> void:
	if not is_node_ready():
		return
	var cuerpo := get_node_or_null(^"%CuerpoLlave")
	if cuerpo is Polygon2D:
		(cuerpo as Polygon2D).color = color
