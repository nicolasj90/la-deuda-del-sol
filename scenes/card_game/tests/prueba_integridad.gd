# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name PruebaIntegridad
extends SuiteDePalabra

## Duelos completos jugados al azar (con semilla) sobre una mesa con todos los
## módulos encendidos, para ejercitar **las 42 cartas** y todos los ops.
##
## No está en la lista del § 8, pero cubre lo que los casos puntuales no pueden:
## que ninguna carta reviente al resolverse y que los topes del diseño se cumplan
## en cada paso, no solo en la posición armada a mano.


func _init() -> void:
	nombre = "integridad (fuzz con semilla)"


func casos() -> Array[String]:
	return [
		"test_toda_jugada_legal_se_puede_ejecutar",
		"test_los_topes_se_respetan_en_todo_el_duelo",
	]


## Mazo con todas las cartas coleccionables, repetidas hasta llegar a [param n].
func _mazo_variado(n: int) -> Array[String]:
	var ids: Array[String] = []
	for id: String in CatalogoDePalabra.ids():
		var c: CartaDePalabra = CatalogoDePalabra.obtener(id)
		if c != null and not c.es_token:
			ids.append(id)
	var salida: Array[String] = []
	for i: int in n:
		salida.append(ids[i % ids.size()])
	return salida


func _mesa_todo_encendido() -> ConfigMesa:
	var mesa: ConfigMesa = ConfigMesa.new()
	mesa.empenar = true
	mesa.al_fiado = true
	return mesa


## Juega un duelo entero eligiendo jugadas legales al azar. Devuelve el motor y
## acumula los fallos de invariante que encuentre.
func _correr_duelo(semilla: int, pasos_max: int, chequear_topes: bool) -> MotorDePalabra:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = semilla
	var m: MotorDePalabra = MotorDePalabra.new(semilla)
	m.iniciar(_mesa_todo_encendido(), _mazo_variado(30), _mazo_variado(30), semilla % 2, true)
	var pasos: int = 0
	while not m.estado.terminado and pasos < pasos_max:
		pasos += 1
		var legales: Array[JugadaDePalabra] = m.jugadas_legales()
		if legales.is_empty():
			af(false, "semilla %d: no quedó ni la jugada de pasar" % semilla)
			return m
		var j: JugadaDePalabra = legales[rng.randi_range(0, legales.size() - 1)]
		var motivo: String = m.motivo_ilegal(j)
		if not motivo.is_empty():
			af(false, "semilla %d: jugada enumerada pero ilegal (%s)" % [semilla, motivo])
			return m
		if not m.ejecutar(j):
			af(false, "semilla %d: el motor rechazó una jugada que enumeró" % semilla)
			return m
		if chequear_topes and not _topes_ok(m, semilla, pasos):
			return m
	return m


func _topes_ok(m: MotorDePalabra, semilla: int, paso: int) -> bool:
	var pre: String = "semilla %d paso %d" % [semilla, paso]
	for lado: int in [0, 1]:
		var f: EstadoFirma = m.estado.firma(lado)
		if f.estrado.size() > Palabra.ESTRADO_MAX:
			af(false, "%s: el Estrado pasó de 7 (%d)" % [pre, f.estrado.size()])
			return false
		if f.mano.size() > Palabra.MANO_MAX:
			af(false, "%s: la mano pasó de 10 (%d)" % [pre, f.mano.size()])
			return false
		if f.mora.size() > Palabra.QUEBRANTOS_MAX:
			af(false, "%s: la Mora pasó de 3 (%d)" % [pre, f.mora.size()])
			return false
		if f.quebrantos().size() > Palabra.QUEBRANTOS_MAX:
			af(false, "%s: más de 3 Quebrantos (%d)" % [pre, f.quebrantos().size()])
			return false
		if f.promesas.size() > Palabra.PROMESAS_MAX:
			af(false, "%s: más de 3 Promesas pendientes (%d)" % [pre, f.promesas.size()])
			return false
		if f.credito > Palabra.CREDITO_TOPE:
			af(false, "%s: el Crédito pasó de 10 (%d)" % [pre, f.credito])
			return false
		for p: PromesaDePalabra in f.promesas:
			if p.plazo_restante > Palabra.PLAZO_MAX:
				af(false, "%s: un plazo pasó de 3 (%d)" % [pre, p.plazo_restante])
				return false
	return true


func test_toda_jugada_legal_se_puede_ejecutar() -> void:
	var terminados: int = 0
	for semilla: int in [1, 2, 3, 7, 13, 31, 44, 68, 91, 512]:
		var m: MotorDePalabra = _correr_duelo(semilla, 400, false)
		af_eq(
			m.eventos_de(EventoDuelo.JUGADA_RECHAZADA).size(),
			0,
			"semilla %d: el motor no rechazó ninguna jugada que había enumerado" % semilla
		)
		if m.estado.terminado:
			terminados += 1
	af_eq(terminados, 10, "los diez duelos terminan solos (nadie queda colgado)")
	fin()


func test_los_topes_se_respetan_en_todo_el_duelo() -> void:
	for semilla: int in [11, 23, 42, 99, 123, 777, 2026, 4, 5, 6, 8, 9, 10, 17, 55, 101]:
		var m: MotorDePalabra = _correr_duelo(semilla, 400, true)
		af(m.estado.terminado, "semilla %d: el duelo termina" % semilla)
		af_no_eq(m.estado.ganador, -1, "semilla %d: hay un ganador" % semilla)
	fin()
