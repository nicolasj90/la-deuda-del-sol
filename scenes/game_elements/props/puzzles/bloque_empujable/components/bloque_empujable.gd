# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
@tool
class_name BloqueEmpujable
extends AnimatableBody2D

## Bloque que se desliza UNA celda por empuje sostenido del jugador.
##
## El movimiento del jugador en Threadbare es libre (no por casillas), así que
## este bloque no se empuja "por paso" como en un sokoban clásico: se empuja por
## [b]contacto sostenido[/b]. Mientras el jugador se apoya contra una cara del
## bloque durante [member retardo_empuje] segundos, el bloque se desliza una
## celda con snap a grilla y un tween (patrón TetraForce).
##
## Con [member capa_grilla] asignada, la grilla es la del tileset y las celdas de
## todos los bloques son comparables entre sí. Sin ella, cada bloque ancla su
## grilla en su [b]propia[/b] posición inicial: [method celda_actual] devuelve
## entonces un desplazamiento relativo a donde nació ese bloque, así que
## [b]no se pueden comparar celdas de dos bloques distintos[/b] (para eso,
## asignales la misma [member capa_grilla]). El bloqueo contra paredes y contra
## otros bloques no depende de esto: se resuelve por física con un [ShapeCast2D].
##
## Se bloquea contra paredes y contra otros bloques mediante un [ShapeCast2D]
## que sondea la celda destino antes de moverse.

## Emitida cuando el bloque terminó de deslizarse una celda.
signal moved(desde: Vector2, hacia: Vector2)

## Emitida cuando se intentó empujar y la celda destino estaba ocupada.
signal empuje_bloqueado(direccion: Vector2i)

## Emitida cuando un bloque en mora deja de estar en mora (ver [method aliviar]).
signal aliviado

const _EJES: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]

## Lado de la celda, en píxeles. Se ignora si [member capa_grilla] está asignada.
@export var tamano_celda: int = 64

## Si se asigna, el bloque se alinea a esta capa al iniciar, usa su tamaño de
## celda y sólo puede deslizarse a celdas que tengan un tile pintado.
@export var capa_grilla: TileMapLayer

## Segundos de contacto sostenido antes de que el bloque cede.
@export_range(0.0, 2.0, 0.05, "suffix:s") var retardo_empuje: float = 0.3

## Duración del deslizamiento de una celda.
@export_range(0.05, 1.0, 0.01, "suffix:s") var duracion_deslizamiento: float = 0.18

## Tolerancia (en píxeles) de desalineación entre jugador y bloque para que el
## empuje cuente. Evita empujar "de costado" al pasar caminando.
@export var tolerancia_alineacion: float = 26.0

## Capas físicas que impiden el deslizamiento (paredes, otros bloques, NPCs).
@export_flags_2d_physics var mascara_obstaculos: int = 530

## Si es [code]true[/code], el bloque está en mora: no se mueve hasta que se lo
## alivie con [method aliviar]. Ver [BloqueEnMora].
@export var en_mora: bool = false:
	set(nuevo):
		en_mora = nuevo
		_actualizar_apariencia()

## Si es [code]true[/code], el bloque no puede volver a moverse nunca más.
@export var fijado: bool = false

var _origen_grilla: Vector2
var _tamano_efectivo: float = 64.0
var _tween: Tween
var _empuje_acumulado: float = 0.0
var _direccion_empuje: Vector2i = Vector2i.ZERO
var _cuerpos: Array[Node2D] = []

@onready var _detector: ShapeCast2D = %Detector
@onready var _area_empuje: Area2D = %AreaEmpuje
@onready var _forma_detector: RectangleShape2D = _detector.shape as RectangleShape2D


## [code]true[/code] mientras el bloque se está deslizando.
var deslizandose: bool:
	get:
		return _tween != null and _tween.is_running()


func _ready() -> void:
	_tamano_efectivo = float(tamano_celda)
	if capa_grilla and capa_grilla.tile_set:
		_tamano_efectivo = float(capa_grilla.tile_set.tile_size.x)

	if Engine.is_editor_hint():
		return

	_detector.add_exception(self)
	_detector.collision_mask = mascara_obstaculos
	if _forma_detector:
		# Un poco más chica que la celda para no rozar obstáculos vecinos.
		var lado: float = maxf(8.0, _tamano_efectivo - 16.0)
		_forma_detector.size = Vector2(lado, lado)

	if capa_grilla:
		var celda := celda_actual()
		global_position = celda_a_global(celda)
	_origen_grilla = global_position

	_area_empuje.body_entered.connect(_on_area_empuje_body_entered)
	_area_empuje.body_exited.connect(_on_area_empuje_body_exited)
	_actualizar_apariencia()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _cuerpos.is_empty() or deslizandose or fijado or en_mora:
		_empuje_acumulado = 0.0
		_direccion_empuje = Vector2i.ZERO
		return

	var direccion := _direccion_de_empuje()
	if direccion == Vector2i.ZERO:
		_empuje_acumulado = 0.0
		_direccion_empuje = Vector2i.ZERO
		return

	if direccion != _direccion_empuje:
		_direccion_empuje = direccion
		_empuje_acumulado = 0.0

	_empuje_acumulado += delta
	if _empuje_acumulado >= retardo_empuje:
		_empuje_acumulado = 0.0
		intentar_empujar(direccion)


## Cuántos empujadores están apoyados contra el bloque.
func cuerpos_en_contacto() -> int:
	return _cuerpos.size()


## Dirección que el bloque considera "empuje válido" en este instante, o
## [constant Vector2i.ZERO]. Expuesta para depurar y para los smokes.
func direccion_de_empuje_actual() -> Vector2i:
	return _direccion_de_empuje()


## Celda de grilla que ocupa el bloque ahora mismo.
func celda_actual() -> Vector2i:
	if capa_grilla:
		return capa_grilla.local_to_map(capa_grilla.to_local(global_position))
	var relativo := global_position - _origen_grilla
	return Vector2i(roundi(relativo.x / _tamano_efectivo), roundi(relativo.y / _tamano_efectivo))


## Posición global del centro de una celda.
func celda_a_global(celda: Vector2i) -> Vector2:
	if capa_grilla:
		return capa_grilla.to_global(capa_grilla.map_to_local(celda))
	return _origen_grilla + Vector2(celda) * _tamano_efectivo


## [code]true[/code] si la celda vecina en [param direccion] está libre.
func puede_moverse(direccion: Vector2i) -> bool:
	if fijado or en_mora or deslizandose:
		return false
	if direccion == Vector2i.ZERO:
		return false

	if capa_grilla:
		var destino := celda_actual() + direccion
		if capa_grilla.get_cell_source_id(destino) == -1:
			return false

	_detector.target_position = Vector2(direccion) * _tamano_efectivo
	_detector.force_shapecast_update()
	return not _detector.is_colliding()


## Intenta deslizar el bloque una celda. Devuelve [code]true[/code] si arrancó
## el deslizamiento; en caso contrario emite [signal empuje_bloqueado].
func intentar_empujar(direccion: Vector2i) -> bool:
	if not puede_moverse(direccion):
		empuje_bloqueado.emit(direccion)
		_sacudir()
		return false

	var desde := global_position
	var hacia := celda_a_global(celda_actual() + direccion)

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "global_position", hacia, duracion_deslizamiento)
	_tween.tween_callback(
		func() -> void:
			# Snap final duro: el tween puede dejar decimales.
			global_position = hacia
			moved.emit(desde, hacia)
	)
	return true


## Levanta la mora: el bloque brilla y se vuelve empujable.
## Pensado para conectarse a la señal de una tarea cumplida.
func aliviar() -> void:
	if not en_mora:
		return
	en_mora = false
	aliviado.emit()


## Vuelve a poner el bloque en mora.
func poner_en_mora() -> void:
	en_mora = true


func _direccion_de_empuje() -> Vector2i:
	for cuerpo: Node2D in _cuerpos:
		if not is_instance_valid(cuerpo):
			continue
		var intencion := _intencion_de(cuerpo)
		if intencion.length_squared() < 1.0:
			continue

		var hacia_bloque := global_position - cuerpo.global_position
		var eje := _eje_dominante(intencion)
		if eje == Vector2i.ZERO:
			continue
		# El jugador tiene que estar del lado opuesto al que empuja...
		if hacia_bloque.dot(Vector2(eje)) <= 0.0:
			continue
		# ...y razonablemente alineado con la fila/columna del bloque.
		var perpendicular := absf(hacia_bloque.x if eje.x == 0 else hacia_bloque.y)
		if perpendicular > tolerancia_alineacion:
			continue
		return eje
	return Vector2i.ZERO


## Vector de intención del cuerpo: primero el input del jugador (que no se anula
## al chocar contra una pared), y si no hay, su velocidad.
func _intencion_de(cuerpo: Node2D) -> Vector2:
	if "input_walk_behavior" in cuerpo:
		var comportamiento: Variant = cuerpo.input_walk_behavior
		if comportamiento != null and "input_vector" in comportamiento:
			var intencion: Vector2 = comportamiento.input_vector
			if intencion.length_squared() > 1.0:
				return intencion
	if "velocity" in cuerpo:
		return cuerpo.velocity
	return Vector2.ZERO


func _eje_dominante(vector: Vector2) -> Vector2i:
	if is_zero_approx(vector.x) and is_zero_approx(vector.y):
		return Vector2i.ZERO
	if absf(vector.x) > absf(vector.y):
		return Vector2i(signi(roundi(signf(vector.x))), 0)
	return Vector2i(0, signi(roundi(signf(vector.y))))


func _es_empujador(cuerpo: Node2D) -> bool:
	return cuerpo.is_in_group(&"player")


func _on_area_empuje_body_entered(cuerpo: Node2D) -> void:
	if _es_empujador(cuerpo) and not _cuerpos.has(cuerpo):
		_cuerpos.append(cuerpo)


func _on_area_empuje_body_exited(cuerpo: Node2D) -> void:
	_cuerpos.erase(cuerpo)
	if _cuerpos.is_empty():
		_empuje_acumulado = 0.0
		_direccion_empuje = Vector2i.ZERO


func _sacudir() -> void:
	var sacudidor := get_node_or_null(^"%Sacudidor")
	if sacudidor and sacudidor.has_method(&"shake"):
		sacudidor.shake()


## Gancho para las subclases: actualizar el aspecto según [member en_mora].
func _actualizar_apariencia() -> void:
	if not is_node_ready():
		return
	var sprite := get_node_or_null(^"%Sprite")
	if sprite is CanvasItem:
		(sprite as CanvasItem).modulate = (
			Color(0.55, 0.5, 0.62) if en_mora else Color.WHITE
		)


func _get_configuration_warnings() -> PackedStringArray:
	var avisos: PackedStringArray = []
	if tamano_celda <= 0:
		avisos.append("tamano_celda debe ser mayor que cero.")
	if capa_grilla and not capa_grilla.tile_set:
		avisos.append("capa_grilla no tiene TileSet.")
	return avisos
