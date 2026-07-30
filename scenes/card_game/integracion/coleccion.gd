# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node

## Autoload [b]Coleccion[/b]: las cartas de «De Palabra» que el jugador posee y su
## mazo activo.
##
## Es el pegamento entre los tres cores: los duelos leen de acá el mazo del
## jugador, los combates escriben acá los drops ([code]DropsDeCartas[/code]) y las
## escenas de guion entregan premios llamando a [method agregar] desde un
## [code].dialogue[/code].
##
## [b]Qué guarda[/b]: un [code]id -> copias[/code] de cartas poseídas (ids del set
## de [code]data/cartas/[/code]) y una lista de ids como mazo activo. El mazo
## siempre es un subconjunto de lo poseído: [method fijar_mazo] rechaza cartas que
## no estén en la colección.
##
## [b]Persistencia[/b]: entra en el save existente de Threadbare, en
## [member GlobalState.facts] (el diccionario de hechos globales que ya se
## serializa en [code]user://saved_game.tres[/code]), bajo las claves
## [constant CLAVE_CARTAS], [constant CLAVE_MAZO] y
## [constant CLAVE_MAZO_INICIAL]. Cada mutación llama a
## [method GameState.save], igual que hace [method GameState.set_scene].
## [br]Si el [GlobalState] cambia de objeto —«Nueva partida» sin cerrar el juego llama
## a [method GameState.clear]— la colección lo detecta y se relee sola
## ([method _sincronizar]): la partida nueva nunca arranca con las cartas de la vieja.
##
## [b]Antes de E03 la colección está vacía[/b]: el duelo tutorial de Rosaura se
## juega con el mazo prestado de la casa (que NO entra a la colección, ver la
## continuidad de E03 en el guion). El primer mazo propio lo entrega
## [method entregar_mazo_inicial] cuando Rosaura lo regala.
##
## Uso desde un [code].dialogue[/code]:
## [codeblock]
## do Coleccion.agregar("gallina_lacrevieja")
## do Coleccion.entregar_mazo_inicial()
## if Coleccion.tiene("el_amanecer"):
##     Salu: Eso que tenés en la mano no lo tiene nadie.
## [/codeblock]

## Se emite cuando entran cartas nuevas. [param entregas] es [code]id -> copias[/code].
signal cartas_agregadas(entregas: Dictionary)

## Se emite cuando cambia el mazo activo.
signal mazo_cambiado(mazo: Array)

## Claves con las que la colección vive en [member GlobalState.facts].
const CLAVE_CARTAS: String = "coleccion_cartas"
const CLAVE_MAZO: String = "coleccion_mazo"
const CLAVE_MAZO_INICIAL: String = "coleccion_mazo_inicial_entregado"

## El primer mazo propio: el que Rosaura le empuja por la mesa en E03 («Tu primer
## mazo propio»), atado con piolín de panadería.
##
## [b]De dónde sale esta lista[/b]: el guion (E03) y el § 5.10 del diseño garantizan
## que el mazo incluye un «Porteador del Empeñadero» (trazabilidad de E17) pero
## [b]no lo enumeran carta por carta[/b]. Esta constante adopta el candidato que
## [code]data/cartas/fuente/canales.json[/code] señala en su nota
## [code]_sin_canal[/code] («el candidato natural es el mazo propio que Rosaura
## regala en E03») y se queda solo con cartas rurales de Lacrevieja y del
## arquetipo Garante de Rosaura. Deliberadamente [b]no[/b] incluye:
## [br]— [code]lampara_de_palabra[/code]: la que Ciro anuncia en E03 es de Rosaura;
##   la propia llega en el cofre de E09 (continuidad explícita del guion, «sin
##   duplicado fantasma»).
## [br]— [code]colmillo_del_diezmo[/code], [code]mula_de_reparto[/code],
##   [code]fe_de_erratas[/code] y todo lo que ya tiene canal propio más adelante
##   (E11, E13, E20…): entregarlo acá le sacaría sentido a ese canal.
##
## Son 14 cartas, no 30: con la colección de E03 no se puede llegar a 30 sin
## inventar canales que el guion no tiene. Queda como decisión de sala; para
## subirlo alcanza con editar esta constante (o pasarla por
## [method ArmadorDeMazos.completar]).
const MAZO_INICIAL: Dictionary = {
	"gallina_lacrevieja": 2,
	"peon_de_vina": 2,
	"hornera_de_rosaura": 2,
	"tranquera_cerrada": 2,
	"porteador_empenadero": 2,
	"sereno_del_archivo": 2,
	"de_mi_mesa_nadie": 2,
}

## El mazo prestado de la casa de Rosaura (E03), el «de enseñar»: se juega con él
## el duelo tutorial y [b]no entra a la colección[/b] — la Lámpara que Ciro anuncia
## en E03 es de esta mesa, no suya (la propia llega en E09).
##
## Son las cartas que [code]data/cartas/fuente/canales.json[/code] traza por la vía
## [code]mazo_de_la_casa[/code]. Es un mazo prestado, así que completarlo hasta 30
## con [method ArmadorDeMazos.completar] no ensucia ningún canal:
## [codeblock]
## var mazo := ArmadorDeMazos.completar(Coleccion.MAZO_DE_LA_CASA, ConfigMesa.base(), "garante")
## await DueloLauncher.duelo("garante", {"mazo_jugador": mazo, ...})
## [/codeblock]
const MAZO_DE_LA_CASA: Dictionary = {
	"gallina_lacrevieja": 2,
	"peon_de_vina": 1,
	"lampara_de_palabra": 1,
	"porteador_empenadero": 1,
	"tranquera_cerrada": 1,
	"hornera_de_rosaura": 1,
}

## id -> copias.
var _cartas: Dictionary = {}
## Mazo activo: ids, con repetición.
var _mazo: Array[String] = []
## Reemplazo de [member GlobalState.facts] cuando no hay estado de juego (jugar
## una escena sola desde el editor): la colección funciona igual, sin persistir.
var _facts_sueltos: Dictionary = {}
## El [member GameState.global] que había la última vez que se leyó del estado vivo.
## Si pasa a ser otro objeto —«Nueva partida» llama a [method GameState.clear], que
## reemplaza el estado entero— hay que releer, o la partida nueva arranca con las
## cartas de la vieja.
var _global_vivo: GlobalState = null
## [code]true[/code] cuando la colección se cargó a mano de un [GlobalState] que no
## es el del juego ([method cargar_de] desde un test): ahí no se resincroniza sola.
var _desacoplado: bool = false


func _ready() -> void:
	cargar()


# ---------------------------------------------------------------------------
# Cartas poseídas
# ---------------------------------------------------------------------------


## Suma copias de una carta a la colección. Devuelve [code]false[/code] si el id no
## existe en el set, o si es un token / una carta bloqueada (nunca se poseen).
func agregar(id: String, cantidad: int = 1) -> bool:
	_sincronizar()
	if cantidad <= 0:
		return false
	if not _es_coleccionable(id):
		return false
	_cartas[id] = cuantas(id) + cantidad
	guardar()
	cartas_agregadas.emit({id: cantidad})
	return true


## Suma varias cartas de una vez. Acepta un [Array] de ids (con repetición) o un
## [Dictionary] [code]id -> copias[/code]. Devuelve lo que realmente entró.
func agregar_varias(entregas: Variant) -> Dictionary:
	_sincronizar()
	var pedido: Dictionary = ArmadorDeMazos.cuenta(entregas)
	var entraron: Dictionary = {}
	for id: String in pedido.keys():
		var cantidad: int = int(pedido[id])
		if cantidad <= 0 or not _es_coleccionable(id):
			continue
		_cartas[id] = cuantas(id) + cantidad
		entraron[id] = cantidad
	if entraron.is_empty():
		return entraron
	guardar()
	cartas_agregadas.emit(entraron)
	return entraron


## Saca copias de la colección (empeñar de verdad, vender, castigos de guion).
## Si el mazo activo se queda con cartas que ya no se poseen, se recorta.
func quitar(id: String, cantidad: int = 1) -> bool:
	_sincronizar()
	if cantidad <= 0 or not tiene(id, cantidad):
		return false
	var quedan: int = cuantas(id) - cantidad
	if quedan <= 0:
		_cartas.erase(id)
	else:
		_cartas[id] = quedan
	_recortar_mazo()
	guardar()
	return true


## ¿Tiene al menos [param cantidad] copias de esa carta?
func tiene(id: String, cantidad: int = 1) -> bool:
	return cuantas(id) >= cantidad


func cuantas(id: String) -> int:
	_sincronizar()
	return int(_cartas.get(id, 0))


## Ids poseídos, en orden alfabético (determinista, para UI y tests).
func ids_poseidos() -> Array[String]:
	_sincronizar()
	var salida: Array[String] = []
	for id: Variant in _cartas.keys():
		salida.append(String(id))
	salida.sort()
	return salida


## Total de cartas (contando copias).
func total() -> int:
	_sincronizar()
	var suma: int = 0
	for id: Variant in _cartas.keys():
		suma += int(_cartas[id])
	return suma


## Cuántas cartas distintas del set tiene, sobre el total coleccionable.
## Para el resumen del acto (E28).
func resumen() -> Dictionary:
	_sincronizar()
	return {
		"distintas": _cartas.size(),
		"copias": total(),
		"mazo": _mazo.size(),
		"mazo_inicial_entregado": mazo_inicial_entregado(),
	}


# ---------------------------------------------------------------------------
# Mazo activo
# ---------------------------------------------------------------------------


## Copia del mazo activo. Vacío = todavía no tiene mazo (antes de E03).
func mazo_actual() -> Array[String]:
	_sincronizar()
	return _mazo.duplicate()


func tiene_mazo() -> bool:
	_sincronizar()
	return not _mazo.is_empty()


## Fija el mazo activo. Devuelve la lista de errores (vacía = quedó fijado):
## las reglas de mazo de [ArmadorDeMazos] más «no podés poner cartas que no tenés».
## No exige las 30 cartas: al principio del Acto 1 la colección no alcanza.
func fijar_mazo(ids: Variant, mesa: ConfigMesa = null) -> Array[String]:
	_sincronizar()
	var lista: Array[String] = ArmadorDeMazos.normalizar(ids)
	var errores: Array[String] = ArmadorDeMazos.errores_de_mazo(lista, mesa, false)
	var pedido: Dictionary = ArmadorDeMazos.cuenta(lista)
	for id: String in pedido.keys():
		var copias: int = int(pedido[id])
		if not tiene(id, copias):
			errores.append(
				"«%s»: el mazo pide %d y en la colección hay %d" % [id, copias, cuantas(id)]
			)
	if not errores.is_empty():
		return errores
	_mazo = lista
	guardar()
	mazo_cambiado.emit(mazo_actual())
	return errores


## Entrega el primer mazo propio (regalo de Rosaura en E03): mete
## [constant MAZO_INICIAL] en la colección y lo deja como mazo activo.
## Es idempotente: llamarla dos veces no duplica cartas.
func entregar_mazo_inicial() -> bool:
	if mazo_inicial_entregado():
		return false
	agregar_varias(MAZO_INICIAL)
	_marcar_mazo_inicial()
	var errores: Array[String] = fijar_mazo(MAZO_INICIAL)
	for e: String in errores:
		push_error("[Coleccion] mazo inicial ilegal: %s" % e)
	return errores.is_empty()


func mazo_inicial_entregado() -> bool:
	_sincronizar()
	return bool(_facts().get(CLAVE_MAZO_INICIAL, false))


# ---------------------------------------------------------------------------
# Persistencia (dentro del save de Threadbare: GlobalState.facts)
# ---------------------------------------------------------------------------


## Vuelca la colección al estado global y guarda el juego.
func guardar() -> void:
	var facts: Dictionary = _facts()
	facts[CLAVE_CARTAS] = _cartas.duplicate()
	var plano: Array = []
	for id: String in _mazo:
		plano.append(id)
	facts[CLAVE_MAZO] = plano
	if GameState != null:
		GameState.save()


## Relee la colección del estado global (después de cargar una partida).
func cargar() -> void:
	var vivo: GlobalState = GameState.global if GameState != null else null
	cargar_de(vivo)
	_global_vivo = vivo
	_desacoplado = false


## Relee la colección de un [GlobalState] cualquiera. Lo usan los tests para
## verificar un save/load real sin depender del autoload. Cargar de un estado que no
## es el del juego deja la colección [b]desacoplada[/b]: deja de resincronizarse sola
## hasta el próximo [method cargar].
func cargar_de(global: GlobalState) -> void:
	_cartas = {}
	_mazo = []
	if GameState != null and global != GameState.global:
		_desacoplado = true
	if global == null:
		return
	var guardadas: Variant = global.facts.get(CLAVE_CARTAS, null)
	if guardadas is Dictionary:
		for clave: Variant in (guardadas as Dictionary).keys():
			var id: String = String(clave)
			var copias: int = int((guardadas as Dictionary)[clave])
			if copias > 0 and _es_coleccionable(id):
				_cartas[id] = copias
	_mazo = ArmadorDeMazos.normalizar(global.facts.get(CLAVE_MAZO, null))
	_recortar_mazo()


## Borra la colección (partida nueva).
func vaciar() -> void:
	# Vaciar es el reset de partida nueva: vuelve a acoplar la colección al estado
	# vivo, aunque venga de un [method cargar_de] suelto.
	_global_vivo = GameState.global if GameState != null else null
	_desacoplado = false
	_cartas = {}
	_mazo = []
	_facts().erase(CLAVE_MAZO_INICIAL)
	guardar()
	mazo_cambiado.emit(mazo_actual())


# ---------------------------------------------------------------------------
# Internos
# ---------------------------------------------------------------------------


## Los hechos globales del save, o un diccionario suelto si todavía no hay estado
## (el juego corriendo desde el editor sobre una escena sola).
##
## No llama a [method _sincronizar]: lo usa [method guardar] justo después de mutar,
## y ahí releer sería pisar el cambio recién hecho.
func _facts() -> Dictionary:
	if GameState == null or GameState.global == null:
		return _facts_sueltos
	return GameState.global.facts


## Si el estado global cambió de objeto (partida nueva por [method GameState.clear],
## o una partida cargada), relee la colección de ahí. Sin esto, «Nueva partida» sin
## cerrar el juego arranca con las cartas de la partida anterior: el diccionario en
## memoria sobrevive al [GlobalState] que lo respaldaba y el primer
## [method agregar] lo vuelca al save nuevo.
func _sincronizar() -> void:
	if GameState == null or _desacoplado:
		return
	if GameState.global == _global_vivo:
		return
	cargar()


func _marcar_mazo_inicial() -> void:
	_facts()[CLAVE_MAZO_INICIAL] = true
	if GameState != null:
		GameState.save()


## Una carta se puede poseer si existe en el set y no es un token ni está
## bloqueada (los tokens los crea el motor en la mesa; las bloqueadas son de
## postgame).
func _es_coleccionable(id: String) -> bool:
	var c: CartaDePalabra = CatalogoDePalabra.obtener(id)
	if c == null:
		push_warning("[Coleccion] «%s» no existe en el set de cartas." % id)
		return false
	if c.es_token:
		push_warning("[Coleccion] «%s» es un token: no se colecciona." % id)
		return false
	if c.bloqueada:
		push_warning("[Coleccion] «%s» está bloqueada en el Acto 1." % id)
		return false
	return true


## Saca del mazo activo lo que ya no esté en la colección.
func _recortar_mazo() -> void:
	var usadas: Dictionary = {}
	var limpio: Array[String] = []
	for id: String in _mazo:
		var puestas: int = int(usadas.get(id, 0))
		if puestas >= cuantas(id):
			continue
		usadas[id] = puestas + 1
		limpio.append(id)
	_mazo = limpio
