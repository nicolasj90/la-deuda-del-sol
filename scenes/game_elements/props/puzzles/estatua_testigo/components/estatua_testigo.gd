# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name EstatuaTestigo
extends Node2D

## Estatua de fedatario: se rota por interacción y proyecta su fe pública como un
## haz de luz de lacre.
##
## El haz es un [RayCast2D] dibujado con un [Line2D]. Se corta contra cualquier
## obstáculo de [member mascara_haz] (paredes y bloques incluidos) y, cuando
## termina sobre un [ReceptorDeFe], emite [signal haz_llega_a].
##
## Rota en cuatro direcciones y el orden importa: es el idioma del dungeon (la
## Cerradura de Testigos). No hace falta subrayar por qué.

## Direcciones posibles de la mirada, en orden horario.
enum Direccion { ARRIBA, DERECHA, ABAJO, IZQUIERDA }

const _ANGULOS: Dictionary[int, float] = {
	Direccion.ARRIBA: -PI / 2.0,
	Direccion.DERECHA: 0.0,
	Direccion.ABAJO: PI / 2.0,
	Direccion.IZQUIERDA: PI,
}

## Emitida cada vez que la estatua queda mirando a otro lado.
signal rotada(direccion: Direccion)

## Emitida cuando el haz empieza a tocar un [ReceptorDeFe].
signal haz_llega_a(objetivo: Node)

## Emitida cuando el haz deja de tocar el receptor que tocaba.
signal haz_perdido(objetivo: Node)

## Hacia dónde mira la estatua.
@export var direccion: Direccion = Direccion.ABAJO:
	set(nuevo):
		direccion = nuevo
		_actualizar_pivote()

## Largo máximo del haz, en píxeles.
@export_range(64.0, 4096.0, 8.0, "suffix:px") var alcance: float = 512.0

## Si es [code]false[/code], la estatua no proyecta nada (estatua "sin fe").
@export var activa: bool = true:
	set(nuevo):
		activa = nuevo
		if is_node_ready():
			_actualizar_haz()

## Capas que cortan el haz, más la capa de los receptores (11).
@export_flags_2d_physics var mascara_haz: int = 1040

## Color del lacre del haz.
@export var color_haz: Color = Color(1, 0.85, 0.55, 0.75)

## Texto del indicador de interacción.
@export var accion: String = "Rotar"

## Receptor que el haz está tocando ahora mismo, o [code]null[/code].
var objetivo_actual: Node = null

@onready var interact_area: InteractArea = %InteractArea
@onready var _pivote: Node2D = %Pivote
@onready var _rayo: RayCast2D = %Rayo
@onready var _haz: Line2D = %Haz


func _ready() -> void:
	_actualizar_pivote()
	interact_area.action = accion
	_haz.default_color = color_haz

	if Engine.is_editor_hint():
		set_physics_process(false)
		return

	_rayo.collision_mask = mascara_haz
	var base := get_node_or_null(^"%Base")
	if base is CollisionObject2D:
		_rayo.add_exception(base as CollisionObject2D)
	interact_area.interaction_started.connect(_on_interaction_started)
	_actualizar_haz()


func _physics_process(_delta: float) -> void:
	_actualizar_haz()


## Rota la estatua [param pasos] cuartos de vuelta en sentido horario.
func rotar(pasos: int = 1) -> void:
	var siguiente: int = ((int(direccion) + pasos) % 4 + 4) % 4
	direccion = siguiente as Direccion
	rotada.emit(direccion)
	if not Engine.is_editor_hint():
		_actualizar_haz()


## Vector unitario de la dirección actual.
func vector_direccion() -> Vector2:
	return Vector2.RIGHT.rotated(_ANGULOS[direccion])


## Recalcula el haz ahora mismo (útil en tests: no espera al próximo tick).
func actualizar_haz_ahora() -> void:
	_actualizar_haz()


func _actualizar_pivote() -> void:
	if not is_node_ready():
		return
	(get_node(^"%Pivote") as Node2D).rotation = _ANGULOS[direccion]
	var mirada := get_node_or_null(^"%Mirada")
	if mirada is Node2D:
		(mirada as Node2D).rotation = _ANGULOS[direccion]


func _actualizar_haz() -> void:
	if not is_node_ready():
		return

	if not activa:
		_haz.visible = false
		_rayo.enabled = false
		_cambiar_objetivo(null)
		return

	_haz.visible = true
	_rayo.enabled = true
	_rayo.target_position = Vector2(alcance, 0)
	_rayo.force_raycast_update()

	var largo := alcance
	var golpeado: Node = null
	if _rayo.is_colliding():
		largo = _pivote.to_local(_rayo.get_collision_point()).x
		golpeado = _rayo.get_collider() as Node

	_haz.points = PackedVector2Array([Vector2.ZERO, Vector2(maxf(0.0, largo), 0)])
	_cambiar_objetivo(golpeado if golpeado is ReceptorDeFe else null)


func _cambiar_objetivo(nuevo: Node) -> void:
	if nuevo == objetivo_actual:
		return

	var anterior := objetivo_actual
	objetivo_actual = nuevo

	if anterior is ReceptorDeFe:
		(anterior as ReceptorDeFe).apagar(self)
		haz_perdido.emit(anterior)
	if nuevo is ReceptorDeFe:
		(nuevo as ReceptorDeFe).iluminar(self)
		haz_llega_a.emit(nuevo)


func _on_interaction_started(_jugador: Player, _desde_la_derecha: bool) -> void:
	rotar()
	await get_tree().process_frame
	interact_area.end_interaction()
