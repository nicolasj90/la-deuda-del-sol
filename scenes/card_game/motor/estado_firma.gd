# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name EstadoFirma
extends RefCounted

## Todo lo que tiene un lado del duelo: su Aval, su Crédito, sus zonas y sus
## Promesas. Las zonas guardan [EstadoCarta] en orden; el orden del Estrado es la
## posición «izquierda a derecha» que usan las resoluciones deterministas
## (diseño § 3.2.3).

var lado: int = 0
var aval: int = Palabra.AVAL_INICIAL
## Crédito disponible este turno.
var credito: int = 0
## Techo de Crédito alcanzado: sube 1 por turno propio hasta 10 (§ 1).
var credito_max: int = 0

var mazo: Array[EstadoCarta] = []
var mano: Array[EstadoCarta] = []
var estrado: Array[EstadoCarta] = []
## Zona nueva de la revisión: Quebrantos que no cupieron en el Estrado (§ 3.2.2).
var mora: Array[EstadoCarta] = []
var empenadero: Array[EstadoCarta] = []
var descarte: Array[EstadoCarta] = []
## Cartas jugadas boca abajo que están viajando (§ 4.2).
var viaje: Array[EstadoCarta] = []

var promesas: Array[PromesaDePalabra] = []

## Contador de mora de mazo: sube 1 por cada robo fallido (§ 1.1).
var mora_de_mazo: int = 0
## Empeñar es una vez por turno (§ 3.3).
var empeno_usado: bool = false
## Denunciar es una vez por turno (§ 4.2).
var denuncia_usada: bool = false
## Turnos propios ya jugados.
var turnos_jugados: int = 0
## Fiadores jugados en el turno en curso (cláusula `jugar_otro_fiador`).
var fiadores_jugados_en_turno: int = 0
## Último Fiador aliado caído (Odila refrenda al último caído, § 5.5).
var ultimo_caido: EstadoCarta = null


static func crear(numero: int, aval_inicial: int) -> EstadoFirma:
	var f: EstadoFirma = EstadoFirma.new()
	f.lado = numero
	f.aval = aval_inicial
	return f


func zona(z: Palabra.Zona) -> Array[EstadoCarta]:
	match z:
		Palabra.Zona.MAZO:
			return mazo
		Palabra.Zona.MANO:
			return mano
		Palabra.Zona.ESTRADO:
			return estrado
		Palabra.Zona.MORA:
			return mora
		Palabra.Zona.EMPENADERO:
			return empenadero
		Palabra.Zona.DESCARTE:
			return descarte
		Palabra.Zona.VIAJE:
			return viaje
	return descarte


## Quebrantos del lado, en Estrado y en Mora: comparten la misma bolsa de 3
## (§ 3.2.1 y § 3.2.2).
func quebrantos() -> Array[EstadoCarta]:
	var salida: Array[EstadoCarta] = []
	for ec: EstadoCarta in estrado:
		if ec.id() == Palabra.T_QUEBRANTO:
			salida.append(ec)
	for ec: EstadoCarta in mora:
		if ec.id() == Palabra.T_QUEBRANTO:
			salida.append(ec)
	return salida


func estrado_lleno() -> bool:
	return estrado.size() >= Palabra.ESTRADO_MAX


func mano_llena() -> bool:
	return mano.size() >= Palabra.MANO_MAX


## Promesas pendientes ordenadas por antigüedad (§ 3.1.3).
func promesas_por_antiguedad() -> Array[PromesaDePalabra]:
	var copia: Array[PromesaDePalabra] = promesas.duplicate()
	copia.sort_custom(
		func(a: PromesaDePalabra, b: PromesaDePalabra) -> bool: return a.orden < b.orden
	)
	return copia


func promesa_de(uid: int, clausula: String) -> PromesaDePalabra:
	for p: PromesaDePalabra in promesas:
		if p.fiador_uid == uid and p.tipo == clausula:
			return p
	return null


func reiniciar_flags_de_turno() -> void:
	empeno_usado = false
	denuncia_usada = false
	fiadores_jugados_en_turno = 0
