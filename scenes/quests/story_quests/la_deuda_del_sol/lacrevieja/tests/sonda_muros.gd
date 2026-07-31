# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

## Sonda de muros de Lacrevieja: nadie atraviesa una casa, y todo lo que hay que
## visitar se alcanza caminando.
##
## Este smoke no habla con nadie: [b]camina[/b]. Monta [code]lacrevieja.tscn[/code]
## de verdad y usa el cuerpo del jugador (misma cápsula, misma máscara de colisión)
## para dos cosas:
## [br]— [b]empuje contra cada casa[/b]: por cada edificio del pueblo, y por cada
##   uno de sus cuatro lados, la sonda arranca en la celda de afuera y empuja cinco
##   celdas hacia adentro. El cuerpo de la casa (tejado + pared, todo menos el vano
##   de la puerta) tiene que quedar SIEMPRE fuera de su alcance. La regla del
##   usuario es dura: ninguna casa se puede atravesar.
## [br]— [b]inundación desde el spawn[/b]: BFS por física real (no por la tabla de
##   baldosas del generador) a media celda de paso, desde donde amanece Ciro. De
##   ahí salen las dos mitades del chequeo: que ningún interior de casa entre en la
##   zona alcanzable, y que los puntos de interés del guion sí entren.
##
## Correr:
## [codeblock]
## ~/tools/godot/Godot_v4.7-stable_linux.x86_64 --headless --path . \
##     res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/tests/sonda_muros.tscn
## [/codeblock]

const LACREVIEJA := preload("res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja.tscn")

const CELDA: float = 64.0
const W: int = 60
const H: int = 40

## Las casas del pueblo, copiadas de la tabla CASAS de
## [code]tools/gen-mapa-lacrevieja.py[/code]: x0, y0, ancho, alto, puertas, nombre.
## El cuerpo va de (x0, y0) a (x0+ancho-1, y0+alto-1); las columnas de [code]puertas[/code]
## en la última fila son el vano, y ahí sí se puede pisar.
const CASAS: Array = [
	[13, 8, 4, 3, [14], "casa de la vecina de la esquina"],
	[18, 8, 4, 3, [19], "casa vecina norte"],
	[25, 7, 7, 4, [28], "notaría del Fedatario"],
	[41, 7, 5, 4, [42, 43], "capilla del lacre"],
	[13, 15, 6, 4, [15], "panadería de Rosaura"],
	[44, 16, 4, 3, [45], "casa vecina del levante"],
	[15, 25, 5, 4, [17], "casa de Ciro"],
	[10, 26, 3, 3, [11], "galpón de la leña"],
	[26, 26, 4, 3, [27], "casa vecina del sur"],
	[33, 26, 4, 3, [34], "casa de las gallinas"],
	[44, 26, 4, 3, [45], "casa vecina del sudeste"],
]

## Celda donde amanece Ciro (SPAWN del generador).
const SPAWN := Vector2i(18, 30)

## Lo que el guion pide poder visitar a pie, en celdas. Son celdas de PARARSE, no
## celdas de objeto: un prop con cuerpo (la pila de leña, un cartel) o un vecino
## plantado ocupan la suya, así que acá van las de al lado.
const DESTINOS: Dictionary = {
	"calle frente a la casa de Ciro": Vector2i(17, 29),
	"vano de la casa de Ciro": Vector2i(17, 28),
	"patio de la leña de los Albar": Vector2i(14, 28),
	"puerta del galpón": Vector2i(11, 28),
	"horno grande de Rosaura": Vector2i(12, 19),
	"puerta de la panadería": Vector2i(15, 19),
	"cantero norte de macetas": Vector2i(28, 17),
	"estrado de la ceremonia": Vector2i(34, 17),
	"mesas de la fiesta": Vector2i(30, 23),
	"puerta de la notaría": Vector2i(28, 11),
	"patio de la notaría (E06)": Vector2i(33, 10),
	"puerta de la capilla": Vector2i(43, 11),
	"atrio del cementerio": Vector2i(52, 11),
	"cementerio de Cosme": Vector2i(52, 6),
	"viñedo del oeste": Vector2i(4, 20),
	"huerta del sur": Vector2i(30, 31),
	"salida este a Villarrúbrica": Vector2i(58, 20),
}

var _total: int = 0
var _fallos: int = 0
var _mapa: MapaLacrevieja
var _sonda: CharacterBody2D
var _alcanzable: Dictionary = {}


func _ready() -> void:
	print("== SONDA DE MUROS: Lacrevieja ==")
	await _montar()
	_p1_empujar_contra_las_casas()
	_p2_inundacion_desde_el_spawn()
	_p3_todo_lo_interactuable_esta_a_tiro()
	print("== RESUMEN: %d chequeos, %d fallos ==" % [_total, _fallos])
	print("SONDA OK" if _fallos == 0 else "SONDA FALLÓ")
	get_tree().quit(1 if _fallos > 0 else 0)


func _check(nombre: String, ok: bool, detalle: String = "") -> void:
	_total += 1
	if ok:
		print("PASS - %s" % nombre)
		return
	_fallos += 1
	print("FAIL - %s%s" % [nombre, "" if detalle.is_empty() else " (%s)" % detalle])


func _montar() -> void:
	_mapa = LACREVIEJA.instantiate() as MapaLacrevieja
	_mapa.autoarrancar_prologo = false
	_mapa.dialogo_sin_globo = true
	add_child(_mapa)
	for _i in 6:
		await get_tree().physics_frame
	# La sonda ES el jugador: mismo cuerpo, misma cápsula, misma máscara. Se le
	# apaga el andar por teclado para moverlo a mano con move_and_collide().
	_sonda = _mapa.get_node(^"OnTheGround/Player") as CharacterBody2D
	_sonda.set_physics_process(false)
	var andar: Node = _sonda.get_node_or_null(^"InputWalkBehavior")
	if andar != null:
		andar.set_physics_process(false)
		andar.set_process(false)
	for _i in 2:
		await get_tree().physics_frame


func _centro(x: int, y: int) -> Vector2:
	return Vector2((float(x) + 0.5) * CELDA, (float(y) + 0.5) * CELDA)


func _celda_de(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CELDA)), int(floor(p.y / CELDA)))


# --- P1: empujar contra cada casa por sus cuatro lados ---------------------


## Las celdas macizas de una casa: todo el cuerpo menos el vano de la puerta.
func _cuerpo(casa: Array) -> Dictionary:
	var x0: int = casa[0]
	var y0: int = casa[1]
	var ancho: int = casa[2]
	var alto: int = casa[3]
	var puertas: Array = casa[4]
	var celdas: Dictionary = {}
	for j in alto:
		for i in ancho:
			var x: int = x0 + i
			var y: int = y0 + j
			if j == alto - 1 and puertas.has(x):
				continue  # el vano: ahí sí se puede parar
			celdas[Vector2i(x, y)] = true
	return celdas


## Empuja la sonda desde [param desde] en la dirección [param dir] durante
## [param celdas] celdas, y devuelve la celda más profunda que llegó a pisar.
func _empujar(desde: Vector2, dir: Vector2, celdas: float) -> Array[Vector2i]:
	_sonda.global_position = desde
	var pisadas: Array[Vector2i] = [_celda_de(desde)]
	var pasos: int = int(celdas * CELDA / 4.0)
	for _i in pasos:
		_sonda.move_and_collide(dir * 4.0)
		var c: Vector2i = _celda_de(_sonda.global_position)
		if not pisadas.has(c):
			pisadas.append(c)
	return pisadas


func _p1_empujar_contra_las_casas() -> void:
	print("-- P1 empuje: cuatro lados por casa, cinco celdas de envión")
	for casa: Array in CASAS:
		var x0: int = casa[0]
		var y0: int = casa[1]
		var ancho: int = casa[2]
		var alto: int = casa[3]
		var nombre: String = casa[5]
		var cuerpo: Dictionary = _cuerpo(casa)
		var coladas: Array[String] = []
		var carriles: int = 0
		# Norte y sur: un carril por columna. Este y oeste: uno por fila.
		var carriles_def: Array = []
		for i in ancho:
			carriles_def.append([_centro(x0 + i, y0 - 1), Vector2.DOWN, "norte"])
			carriles_def.append([_centro(x0 + i, y0 + alto), Vector2.UP, "sur"])
		for j in alto:
			carriles_def.append([_centro(x0 - 1, y0 + j), Vector2.RIGHT, "oeste"])
			carriles_def.append([_centro(x0 + ancho, y0 + j), Vector2.LEFT, "este"])
		for carril: Array in carriles_def:
			carriles += 1
			for c: Vector2i in _empujar(carril[0], carril[1], 5.0):
				if cuerpo.has(c):
					var falla := "%s→%s en %s" % [carril[2], c, nombre]
					if not coladas.has(falla):
						coladas.append(falla)
		_check(
			"P1 %s: %d carriles y ninguno la atraviesa" % [nombre, carriles],
			coladas.is_empty(),
			", ".join(coladas)
		)
		# La regla del usuario tiene dos mitades: la casa no se atraviesa, y el vano
		# que se le dibujó adelante contesta algo. Un vano mudo no vale.
		var con_puerta: bool = false
		var puertas: Node = _mapa.get_node_or_null(^"OnTheGround/Puertas")
		for px: int in casa[4] as Array:
			var centro: Vector2 = _centro(px, y0 + alto - 1)
			for puerta: Node in (puertas.get_children() if puertas != null else []):
				if (puerta as Node2D).global_position.distance_to(centro) < CELDA:
					con_puerta = true
		_check("P1 %s: el vano contesta al golpearlo" % nombre, con_puerta)


# --- P2: inundación por física real desde el spawn -------------------------


## Paso de la grilla de inundación: media celda. La grilla se ancla en múltiplos de
## [constant PASO] justo para que el centro de cada celda ([code]2c+1[/code]) sea un
## nodo: un vano de puerta de una sola celda deja 11 px de juego a cada lado de la
## cápsula del jugador, y si la grilla cayera en los cuartos de celda ese vano se
## leería como cerrado aunque se pase.
const PASO: float = CELDA / 2.0


func _nodo_de_celda(c: Vector2i) -> Vector2i:
	return Vector2i(c.x * 2 + 1, c.y * 2 + 1)


## BFS a media celda de paso usando [method CharacterBody2D.test_move]: sólo se
## anota un nodo si la sonda puede recorrer de verdad el tramo que lleva hasta él.
func _p2_inundacion_desde_el_spawn() -> void:
	print("-- P2 inundación por física desde el spawn de Ciro")
	var origen: Vector2i = _nodo_de_celda(SPAWN)
	var cola: Array[Vector2i] = [origen]
	_alcanzable = {origen: true}
	var t := Transform2D.IDENTITY
	while not cola.is_empty():
		var n: Vector2i = cola.pop_back()
		var p := Vector2(float(n.x) * PASO, float(n.y) * PASO)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var m: Vector2i = n + d
			if m.x < 0 or m.y < 0 or m.x > W * 2 or m.y > H * 2 or _alcanzable.has(m):
				continue
			t.origin = p
			if _sonda.test_move(t, Vector2(d) * PASO):
				continue
			_alcanzable[m] = true
			cola.append(m)
	print("   nodos alcanzables (media celda): %d" % _alcanzable.size())

	# a) ningún interior de casa entra en la zona caminable.
	for casa: Array in CASAS:
		var dentro: Array[String] = []
		for c: Vector2i in _cuerpo(casa).keys():
			if _alcanzable.has(_nodo_de_celda(c)):
				dentro.append(str(c))
		_check(
			"P2 el interior de «%s» queda fuera del paso" % casa[5],
			dentro.is_empty(),
			", ".join(dentro)
		)

	# b) todo lo que el guion pide visitar se alcanza a pie.
	for nombre: String in DESTINOS:
		var c: Vector2i = DESTINOS[nombre]
		_check("P2 se llega caminando a: %s" % nombre, _alcanzable.has(_nodo_de_celda(c)), str(c))

	# c) el pueblo está cerrado: las cuatro esquinas del mapa no se pisan.
	for c: Vector2i in [Vector2i(0, 0), Vector2i(W - 1, 0), Vector2i(0, H - 1), Vector2i(W - 1, H - 1)]:
		_check("P2 el borde no tiene fuga en %s" % c, not _alcanzable.has(_nodo_de_celda(c)))


# --- P3: nada interactuable queda encerrado ---------------------------------


## El chequeo que de verdad importa para jugar E01–E05: cada [code]InteractArea[/code]
## del pueblo — vecinos, lámparas, macetas, lápidas, la pila de leña, el horno —
## tiene que tener al menos un lugar donde pararse, dentro de la zona caminable, a
## tiro del botón de interacción. Un prop encerrado detrás de una pared pasa todos
## los smokes (que lo llaman por código) y es imposible de usar jugando.
## Lo que el jugador «ve» para interactuar es su [CharacterSight]: un rectángulo de
## 110x80 adelantado 47 px. O sea que alcanza bastante más lejos que el radio del
## [InteractArea]; acá se le suma ese brazo, y además se pide LÍNEA LIMPIA (nada de
## la capa de paredes en el medio) para que un prop tapiado no pase por cercanía.
const BRAZO: float = 70.0


func _p3_todo_lo_interactuable_esta_a_tiro() -> void:
	print("-- P3 alcance: cada objeto interactuable tiene dónde pararse")
	var puestos: Array[Vector2] = []
	for n: Vector2i in _alcanzable:
		puestos.append(Vector2(float(n.x) * PASO, float(n.y) * PASO))
	var espacio := _sonda.get_world_2d().direct_space_state
	var encontrados: int = 0
	for area: Node in _mapa.find_children("InteractArea", "Area2D", true, false):
		var duenio: Node = area.get_parent()
		if not (duenio is Node2D) or not (duenio as Node2D).is_visible_in_tree():
			continue
		var radio: float = _radio_de(area as Area2D)
		if radio <= 0.0:
			continue
		encontrados += 1
		var centro: Vector2 = (area as Node2D).global_position
		var propios: Array[RID] = [_sonda.get_rid()]
		for cuerpo: Node in duenio.find_children("*", "PhysicsBody2D", true, false):
			propios.append((cuerpo as PhysicsBody2D).get_rid())
		if duenio is PhysicsBody2D:
			propios.append((duenio as PhysicsBody2D).get_rid())
		var mejor: float = INF
		var a_tiro: bool = false
		for p: Vector2 in puestos:
			var d: float = p.distance_to(centro)
			if d > radio + BRAZO:
				continue
			mejor = minf(mejor, d)
			var rayo := PhysicsRayQueryParameters2D.create(p, centro, 16, propios)
			var choque: Dictionary = espacio.intersect_ray(rayo)
			# Vale que lo único «en el medio» sea la baldosa del propio objeto: el
			# horno grande de Rosaura, por ejemplo, está empotrado en su pared de
			# ladrillo y se atiende desde la calle, por la boca.
			if choque.is_empty() or (choque["position"] as Vector2).distance_to(centro) <= CELDA / 2.0:
				a_tiro = true
				break
		_check(
			"P3 «%s» tiene dónde pararse a tiro" % duenio.name,
			a_tiro,
			(
				"nada caminable a menos de %.0f px (alcance %.0f + brazo %.0f)"
				% [radio + BRAZO, radio, BRAZO]
				if mejor == INF
				else "lo más cerca que se llega es %.0f px y hay pared en el medio" % mejor
			)
		)
	_check("P3 el pueblo tiene cosas para interactuar", encontrados >= 15, "n=%d" % encontrados)


func _radio_de(area: Area2D) -> float:
	for hijo: Node in area.get_children():
		if not (hijo is CollisionShape2D):
			continue
		var forma: Shape2D = (hijo as CollisionShape2D).shape
		if forma is CircleShape2D:
			return (forma as CircleShape2D).radius
		if forma is RectangleShape2D:
			return minf((forma as RectangleShape2D).size.x, (forma as RectangleShape2D).size.y) / 2.0
	return 0.0
