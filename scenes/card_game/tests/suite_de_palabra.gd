# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name SuiteDePalabra
extends RefCounted

## Base mínima de tests headless para el motor de «De Palabra» (diseño § 8).
##
## Sin dependencias externas: los duelos son la parte del juego con más estado
## oculto y los tests tienen que correr con `--headless -s`, sin escena y sin
## addons. Cada suite declara sus casos en [method casos] en el orden del diseño.

var nombre: String = "suite"

var _fallos: Array[String] = []
var _termino: bool = false


## Nombres de los métodos `test_*` de la suite, en el orden del documento.
func casos() -> Array[String]:
	return []


## Corre un caso y devuelve sus fallos (vacío = PASS).
##
## Todo caso **tiene que** terminar llamando a [method fin]. Sin ese centinela un
## error de runtime a mitad del test (un índice fuera de rango, por ejemplo) aborta
## la función sin registrar nada y el caso se reportaría como PASS.
func correr(caso: String) -> Array[String]:
	_fallos = []
	_termino = false
	if not has_method(caso):
		_fallos.append("el caso '%s' no está implementado" % caso)
		return _fallos
	callv(caso, [])
	if not _termino:
		_fallos.append("el caso se cortó antes de terminar (¿error de runtime?)")
	return _fallos.duplicate()


## Centinela de fin de caso. Última línea de todo test.
func fin() -> void:
	_termino = true


# --- Afirmaciones ---


func af(condicion: bool, mensaje: String) -> void:
	if not condicion:
		_fallos.append(mensaje)


func af_eq(actual: Variant, esperado: Variant, mensaje: String) -> void:
	if actual != esperado:
		_fallos.append("%s — esperaba %s, hubo %s" % [mensaje, str(esperado), str(actual)])


func af_no_eq(actual: Variant, prohibido: Variant, mensaje: String) -> void:
	if actual == prohibido:
		_fallos.append("%s — no debía ser %s" % [mensaje, str(prohibido)])


# --- Armado de duelos ---


## Mazo de [param n] copias del mismo id. Los tests no arman mazos legales: arman
## posiciones.
func mazo(n: int, id: String = "peon_de_vina") -> Array[String]:
	var salida: Array[String] = []
	for _i: int in n:
		salida.append(id)
	return salida


## Duelo nuevo, sin mezclar (determinismo) y con semilla fija.
func duelo(
	mesa: ConfigMesa = null, primero: int = 0, semilla: int = 7, id_mazo: String = "peon_de_vina"
) -> MotorDePalabra:
	var m: MotorDePalabra = MotorDePalabra.new(semilla)
	var config: ConfigMesa = ConfigMesa.base() if mesa == null else mesa
	m.iniciar(config, mazo(30, id_mazo), mazo(30, id_mazo), primero, false)
	return m


## Termina el turno en curso y avanza hasta el próximo turno de [param lado].
func siguiente_turno_de(m: MotorDePalabra, lado: int) -> void:
	m.terminar_turno()
	m.depurar_avanzar_a_turno_de(lado)


## Cuántas cartas con ese id hay en una zona de un lado.
func contar(m: MotorDePalabra, lado: int, z: Palabra.Zona, id: String) -> int:
	var n: int = 0
	for ec: EstadoCarta in m.estado.firma(lado).zona(z):
		if ec.id() == id:
			n += 1
	return n


func buscar_en_mano(m: MotorDePalabra, lado: int, id: String) -> EstadoCarta:
	for ec: EstadoCarta in m.estado.firma(lado).mano:
		if ec.id() == id:
			return ec
	return null


## Deja la mano de [param lado] con exactamente estas cartas.
func mano_exacta(m: MotorDePalabra, lado: int, ids: Array[String]) -> Array[int]:
	m.depurar_vaciar_mano(lado)
	var uids: Array[int] = []
	for id: String in ids:
		uids.append(m.depurar_poner_en_mano(lado, id))
	return uids
