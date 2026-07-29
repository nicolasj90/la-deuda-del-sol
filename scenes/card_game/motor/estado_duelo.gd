# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name EstadoDuelo
extends RefCounted

## Estado completo de un duelo. Es un objeto de datos: no toma decisiones.
## La autoridad sobre las reglas es [MotorDePalabra].

var mesa: ConfigMesa = null
var firmas: Array[EstadoFirma] = []
## Turno global: cada turno de cada jugador cuenta 1 (tope 30, § 1.2).
var turno: int = 0
var activo: int = 0
var fase: Palabra.Fase = Palabra.Fase.SIN_INICIAR
var terminado: bool = false
## -1 mientras no hay resultado; si no, el lado ganador.
var ganador: int = -1
var motivo_fin: String = ""
## Todas las cartas del duelo por uid, en cualquier zona.
var por_uid: Dictionary = {}


static func crear(config: ConfigMesa) -> EstadoDuelo:
	var e: EstadoDuelo = EstadoDuelo.new()
	e.mesa = config
	e.firmas = [
		EstadoFirma.crear(0, config.aval_inicial),
		EstadoFirma.crear(1, config.aval_inicial),
	]
	return e


func firma(lado: int) -> EstadoFirma:
	return firmas[lado]


func rival_de(lado: int) -> int:
	return 1 - lado


func firma_activa() -> EstadoFirma:
	return firmas[activo]


func carta(uid: int) -> EstadoCarta:
	return por_uid.get(uid, null) as EstadoCarta


## Cuerpos que pueden ser atacados de un lado: solo el Estrado revelado. La Mora
## no es atacable (§ 3.2.2) y las cartas en viaje tampoco (§ 2, aclaración 2).
func atacables(lado: int) -> Array[EstadoCarta]:
	var salida: Array[EstadoCarta] = []
	for ec: EstadoCarta in firmas[lado].estrado:
		if not ec.boca_abajo:
			salida.append(ec)
	return salida


## Garantes vivos y revelados de un lado.
func garantes(lado: int) -> Array[EstadoCarta]:
	var salida: Array[EstadoCarta] = []
	for ec: EstadoCarta in atacables(lado):
		if ec.tiene(Palabra.KW_GARANTE):
			salida.append(ec)
	return salida


func como_texto() -> String:
	return (
		"turno=%d activo=%d aval=[%d,%d] credito=%d estrado=[%d,%d] mano=[%d,%d]"
		% [
			turno,
			activo,
			firmas[0].aval,
			firmas[1].aval,
			firmas[activo].credito,
			firmas[0].estrado.size(),
			firmas[1].estrado.size(),
			firmas[0].mano.size(),
			firmas[1].mano.size(),
		]
	)
