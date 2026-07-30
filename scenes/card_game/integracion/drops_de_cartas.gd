# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node

## Autoload [b]DropsDeCartas[/b]: el puente combate → cartas.
##
## Escucha las dos señales que el bridge de encuentros ya expone y no le toca una
## línea:
## [br]— [signal Encounters.battle_mounting]: se anota qué enemigos trae el
##   encuentro (el summary de victoria no los lleva).
## [br]— [signal Encounters.victory_rewards_applied]: resuelve las
##   [TablaDeDrops] de esos enemigos, entrega las cartas a [code]Coleccion[/code]
##   y agrega la entrada [code]"cards"[/code] al summary [b]antes[/b] de que
##   [signal Encounters.encounter_finished] lo reparta (el Dictionary es el mismo
##   objeto, así que la pantalla de victoria puede mostrar el botín de cartas
##   junto a XP, plata y loot).
##
## Las tablas son datos: [code]res://resources/combate/drops/*.tres[/code], una por
## familia del guion. Agregar una familia nueva es agregar un [code].tres[/code];
## este autoload no se toca.
##
## El azar pasa siempre por [member rng], con semilla fijable
## ([method fijar_semilla]) para que los tests sean deterministas.

## Se emite cuando un combate ganado dejó cartas. [param cartas] son ids con
## repetición; [param summary] es el mismo Dictionary del encuentro.
signal cartas_dropeadas(cartas: Array, summary: Dictionary)

const RUTA_TABLAS: String = "res://resources/combate/drops"

## Clave que este autoload agrega al summary del encuentro.
const CLAVE_SUMMARY: String = "cards"
## Misma lista, con los nombres visibles de las cartas (para la UI de victoria).
const CLAVE_SUMMARY_NOMBRES: String = "cards_nombres"

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _tablas: Array[TablaDeDrops] = []
var _errores: Array[String] = []
## Enemigos del encuentro en curso (claves de enemigo), anotados al montar la
## batalla porque el summary de victoria no los trae.
var _enemigos: Array[String] = []


func _ready() -> void:
	rng.randomize()
	cargar_tablas()
	var encuentros: Node = get_node_or_null(^"/root/Encounters")
	if encuentros == null:
		push_warning("[DropsDeCartas] no está el autoload Encounters: sin drops de combate.")
		return
	encuentros.battle_mounting.connect(_al_montar_batalla)
	encuentros.victory_rewards_applied.connect(_al_aplicar_recompensas)
	# Si el combate se pierde o se huye no hay drops, pero la lista de enemigos
	# tiene que quedar limpia igual: nadie hereda el botín del encuentro anterior.
	encuentros.encounter_finished.connect(_al_terminar_encuentro)


# ---------------------------------------------------------------------------
# Tablas
# ---------------------------------------------------------------------------


## Relee [constant RUTA_TABLAS]. Devuelve cuántas tablas quedaron cargadas.
## Mismo patrón anti-cuelgue que los catálogos del core de cartas: un
## [method @GlobalScope.push_error] legible por archivo y el resto sigue.
func cargar_tablas(forzar: bool = false) -> int:
	if not forzar and not _tablas.is_empty():
		return _tablas.size()
	_tablas = []
	_errores = []
	var dir: DirAccess = DirAccess.open(RUTA_TABLAS)
	if dir == null:
		_errores.append("no se pudo abrir %s" % RUTA_TABLAS)
		push_warning("[DropsDeCartas] no se pudo abrir %s" % RUTA_TABLAS)
		return 0
	var archivos: PackedStringArray = dir.get_files()
	var nombres: Array[String] = []
	for archivo: String in archivos:
		var nombre: String = archivo.trim_suffix(".remap")
		if nombre.ends_with(".tres") and not nombres.has(nombre):
			nombres.append(nombre)
	nombres.sort()
	for nombre: String in nombres:
		var ruta: String = "%s/%s" % [RUTA_TABLAS, nombre]
		var res: Resource = ResourceLoader.load(ruta, "TablaDeDrops", ResourceLoader.CACHE_MODE_REUSE)
		var tabla: TablaDeDrops = res as TablaDeDrops
		if tabla == null:
			_errores.append("%s: no es una TablaDeDrops" % ruta)
			push_error("[DropsDeCartas] %s no es una TablaDeDrops" % ruta)
			continue
		var errores: Array[String] = tabla.validar()
		if not errores.is_empty():
			for e: String in errores:
				_errores.append(e)
				push_error("[DropsDeCartas] %s" % e)
			continue
		_tablas.append(tabla)
	return _tablas.size()


func tablas() -> Array[TablaDeDrops]:
	cargar_tablas()
	return _tablas.duplicate()


func errores() -> Array[String]:
	cargar_tablas()
	return _errores.duplicate()


## Tablas que aplican a un enemigo dado (por nombre de archivo o nombre visible).
func tablas_de(enemigo: Variant) -> Array[TablaDeDrops]:
	cargar_tablas()
	var claves: Array = enemigo if enemigo is Array else [String(enemigo)]
	var salida: Array[TablaDeDrops] = []
	for t: TablaDeDrops in _tablas:
		if t.aplica_a(claves):
			salida.append(t)
	return salida


# ---------------------------------------------------------------------------
# Resolución
# ---------------------------------------------------------------------------


## Resuelve el botín de cartas de un encuentro ganado, [b]sin[/b] entregarlo.
## [param enemigos] son claves de enemigo (nombres de archivo o nombres visibles),
## una por enemigo del encuentro (los repetidos cuentan: tres lobos = tres tiradas).
## Devuelve ids de carta con repetición.
func resolver(enemigos: Variant, rng_local: RandomNumberGenerator = null) -> Array[String]:
	cargar_tablas()
	var dado: RandomNumberGenerator = rng_local if rng_local != null else rng
	var claves: Array[String] = ArmadorDeMazos.normalizar(enemigos)
	var salida: Array[String] = []
	for t: TablaDeDrops in _tablas:
		var cuantos: int = 0
		for clave: String in claves:
			if t.aplica_a([clave]):
				cuantos += 1
		if cuantos == 0:
			continue
		for id: String in t.garantizadas:
			salida.append(id)
		for e: EntradaDeDrop in t.entradas:
			if e == null:
				continue
			for _i: int in cuantos:
				if dado.randf() <= e.chance:
					for _c: int in maxi(1, e.cantidad):
						salida.append(e.carta_id)
	return salida


## Resuelve, entrega a [code]Coleccion[/code] y escribe la entrada
## [constant CLAVE_SUMMARY] en el summary del encuentro. Devuelve las cartas.
func aplicar(enemigos: Variant, summary: Dictionary = {}) -> Array[String]:
	var cartas: Array[String] = resolver(enemigos)
	var plano: Array = []
	var nombres: Array = []
	for id: String in cartas:
		plano.append(id)
		var c: CartaDePalabra = CatalogoDePalabra.obtener(id)
		nombres.append(c.nombre if c != null else id)
	summary[CLAVE_SUMMARY] = plano
	summary[CLAVE_SUMMARY_NOMBRES] = nombres
	if cartas.is_empty():
		return cartas
	var coleccion: Node = get_node_or_null(^"/root/Coleccion")
	if coleccion != null:
		coleccion.agregar_varias(cartas)
	cartas_dropeadas.emit(plano, summary)
	return cartas


## Semilla del azar de drops (los tests la fijan para poder afirmar qué cae).
func fijar_semilla(semilla: int) -> void:
	rng.seed = semilla


## Claves de un enemigo del addon: nombre de archivo del [code].tres[/code] y
## nombre visible. Cualquiera de las dos matchea una [TablaDeDrops].
func claves_de_enemigo(enemigo: Resource) -> Array[String]:
	var claves: Array[String] = []
	if enemigo == null:
		return claves
	if not enemigo.resource_path.is_empty():
		claves.append(enemigo.resource_path.get_file().trim_suffix(".remap").get_basename())
	var visible: String = String(enemigo.get(&"name")) if enemigo.get(&"name") != null else ""
	if not visible.is_empty() and not claves.has(visible):
		claves.append(visible)
	return claves


## Una clave por enemigo del encuentro (repetidos incluidos): lo que espera
## [method resolver].
func enemigos_de(settings: BattleSettings) -> Array[String]:
	var salida: Array[String] = []
	if settings == null:
		return salida
	for puesto: EnemySettings in settings.enemies:
		if puesto == null or puesto.enemy == null:
			continue
		var claves: Array[String] = claves_de_enemigo(puesto.enemy)
		if not claves.is_empty():
			salida.append(claves[0])
	return salida


## Anota a mano los enemigos del próximo encuentro ganado. La usa el camino
## normal (al montar la batalla) y los tests, que no montan una batalla de verdad.
func recordar_enemigos(enemigos: Variant) -> void:
	_enemigos = ArmadorDeMazos.normalizar(enemigos)


func enemigos_recordados() -> Array[String]:
	return _enemigos.duplicate()


# ---------------------------------------------------------------------------
# Enganche con el bridge de encuentros
# ---------------------------------------------------------------------------


func _al_montar_batalla(engine: BattleEngine) -> void:
	if engine == null:
		return
	recordar_enemigos(enemigos_de(engine.battle_settings))


func _al_aplicar_recompensas(summary: Dictionary) -> void:
	aplicar(_enemigos, summary)
	_enemigos = []


func _al_terminar_encuentro(_resultado: StringName, _summary: Dictionary) -> void:
	_enemigos = []
