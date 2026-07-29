# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name JugadaDePalabra
extends RefCounted

## Una jugada legal. El motor las enumera ([method MotorDePalabra.jugadas_legales])
## y las ejecuta ([method MotorDePalabra.ejecutar]).
##
## La IA nunca reimplementa la legalidad: pide esta lista (diseño § 7.2.1).

var tipo: Palabra.TipoJugada = Palabra.TipoJugada.PASAR
var lado: int = 0
## Carta propia involucrada (la que se juega, ataca, se empeña o se rescata).
var carta_uid: int = -1
## Objetivo elegido: uid de carta, o -1 si el objetivo es la Firma rival / nada.
var objetivo_uid: int = -1
## Cláusula de Promesa optativa: "" = sin Promesa.
var promesa_tipo: String = ""
var promesa_plazo: int = 0
## Jugarla boca abajo (módulo al fiado).
var al_fiado: bool = false
## Tipo declarado al denunciar una carta en viaje.
var tipo_declarado: Palabra.Tipo = Palabra.Tipo.FIADOR


static func pasar(lado: int) -> JugadaDePalabra:
	var j: JugadaDePalabra = JugadaDePalabra.new()
	j.tipo = Palabra.TipoJugada.PASAR
	j.lado = lado
	return j


static func jugar(
	lado: int, carta_uid: int, objetivo_uid: int = -1, promesa: String = "", plazo: int = 0
) -> JugadaDePalabra:
	var j: JugadaDePalabra = JugadaDePalabra.new()
	j.tipo = Palabra.TipoJugada.JUGAR
	j.lado = lado
	j.carta_uid = carta_uid
	j.objetivo_uid = objetivo_uid
	j.promesa_tipo = promesa
	j.promesa_plazo = plazo
	return j


static func atacar(lado: int, carta_uid: int, objetivo_uid: int) -> JugadaDePalabra:
	var j: JugadaDePalabra = JugadaDePalabra.new()
	j.tipo = Palabra.TipoJugada.ATACAR
	j.lado = lado
	j.carta_uid = carta_uid
	j.objetivo_uid = objetivo_uid
	return j


static func empenar(lado: int, carta_uid: int) -> JugadaDePalabra:
	var j: JugadaDePalabra = JugadaDePalabra.new()
	j.tipo = Palabra.TipoJugada.EMPENAR
	j.lado = lado
	j.carta_uid = carta_uid
	return j


static func rescatar(lado: int, carta_uid: int) -> JugadaDePalabra:
	var j: JugadaDePalabra = JugadaDePalabra.new()
	j.tipo = Palabra.TipoJugada.RESCATAR
	j.lado = lado
	j.carta_uid = carta_uid
	return j


static func denunciar(lado: int, carta_uid: int, tipo_declarado: Palabra.Tipo) -> JugadaDePalabra:
	var j: JugadaDePalabra = JugadaDePalabra.new()
	j.tipo = Palabra.TipoJugada.DENUNCIAR
	j.lado = lado
	j.carta_uid = carta_uid
	j.tipo_declarado = tipo_declarado
	return j


func como_texto() -> String:
	return (
		"[%s lado=%d carta=%d obj=%d promesa=%s/%d al_fiado=%s]"
		% [
			Palabra.TipoJugada.keys()[tipo],
			lado,
			carta_uid,
			objetivo_uid,
			promesa_tipo if not promesa_tipo.is_empty() else "-",
			promesa_plazo,
			str(al_fiado),
		]
	)
