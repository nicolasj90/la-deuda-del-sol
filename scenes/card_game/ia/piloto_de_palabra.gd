# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name PilotoDePalabra
extends RefCounted

## Conductor de la IA: le pide el plan del turno a [IADePalabra] y lo **ejecuta**
## contra el motor real, jugada por jugada.
##
## Existe por dos razones:
## [br]— La IA es una función pura y no tiene memoria; sin piloto, cada jugada del
##   turno rival costaría un beam search entero. Acá el plan se calcula una vez y
##   se ejecuta; solo se replanifica si el motor real se desvía de la simulación
##   (algunas ops usan el rng del motor, que no es el de la simulación).
## [br]— Antes de ejecutar, cada jugada se vuelve a chequear con
##   [method MotorDePalabra.motivo_ilegal]: la autoridad sigue siendo el motor.
##
## No es un [Node] y no toca la vista: la vista puede llamarlo con un temporizador
## entre jugadas para que el turno rival se vea, o dejarlo correr headless.

## Tope de jugadas por turno. Cota anti-cuelgue: con cartas de coste 0 y robo
## encadenado el turno podría no cerrarse solo.
const JUGADAS_POR_TURNO_MAX: int = 40
## Tope de turnos que [method jugar_duelo] deja correr por si el motor no cerrara
## el duelo (el tope real es el del § 1.2, 30 turnos, y lo aplica el motor).
const TURNOS_MAX: int = 200


## Juega el turno completo del lado activo y lo cierra (PASAR).
##
## Devuelve [code]{ jugadas, planes, nodos }[/code]: las jugadas ejecutadas (sin
## contar el PASAR final), cuántas veces hubo que planificar y cuántos nodos costó.
static func jugar_turno(
	motor: MotorDePalabra,
	perfil: PerfilIA,
	rng: RandomNumberGenerator,
	anuncio: Array[String] = []
) -> Dictionary:
	var resultado: Dictionary = {"jugadas": [] as Array[JugadaDePalabra], "planes": 0, "nodos": 0}
	if motor == null or motor.estado == null or perfil == null:
		return resultado
	var lado: int = motor.estado.activo
	var ejecutadas: Array[JugadaDePalabra] = []
	var restantes: int = JUGADAS_POR_TURNO_MAX
	while restantes > 0 and _puede_seguir(motor, lado):
		var plan: Dictionary = IADePalabra.planificar(motor, perfil, rng, anuncio)
		resultado["planes"] = int(resultado["planes"]) + 1
		resultado["nodos"] = int(resultado["nodos"]) + int(plan["nodos"])
		var jugadas: Array = plan["jugadas"]
		if jugadas.is_empty():
			break
		var alguna: bool = false
		for j_v: Variant in jugadas:
			var j: JugadaDePalabra = j_v as JugadaDePalabra
			if restantes <= 0 or not _puede_seguir(motor, lado):
				break
			# El plan se armó sobre un clon: si el motor real no acepta la jugada,
			# la simulación se desvió y hay que replanificar.
			if not motor.motivo_ilegal(j).is_empty():
				break
			if not motor.ejecutar(j):
				break
			restantes -= 1
			ejecutadas.append(j)
			alguna = true
			if j.tipo == Palabra.TipoJugada.PASAR:
				break
		if not alguna:
			break
	if _puede_seguir(motor, lado):
		motor.ejecutar(JugadaDePalabra.pasar(lado))
	resultado["jugadas"] = ejecutadas
	return resultado


## Corre un duelo entero IA contra IA. Es la base del simulador de balance del
## § 9.1 y del humo de § 8.6.
##
## Devuelve [code]{ ganador, motivo, turnos, jugadas, planes, nodos }[/code].
static func jugar_duelo(
	motor: MotorDePalabra,
	perfil_0: PerfilIA,
	perfil_1: PerfilIA,
	rng: RandomNumberGenerator,
	anuncio_0: Array[String] = [],
	anuncio_1: Array[String] = []
) -> Dictionary:
	var resultado: Dictionary = {
		"ganador": -1, "motivo": "", "turnos": 0, "jugadas": 0, "planes": 0, "nodos": 0
	}
	if motor == null or motor.estado == null:
		return resultado
	var vueltas: int = TURNOS_MAX
	while not motor.estado.terminado and vueltas > 0:
		vueltas -= 1
		var lado: int = motor.estado.activo
		var perfil: PerfilIA = perfil_0 if lado == 0 else perfil_1
		# Lo que el rival anunció es lo que este lado puede creer o no (§ 7.2.6).
		var anuncio: Array[String] = anuncio_1 if lado == 0 else anuncio_0
		var turno: Dictionary = jugar_turno(motor, perfil, rng, anuncio)
		resultado["jugadas"] = int(resultado["jugadas"]) + (turno["jugadas"] as Array).size()
		resultado["planes"] = int(resultado["planes"]) + int(turno["planes"])
		resultado["nodos"] = int(resultado["nodos"]) + int(turno["nodos"])
		if motor.estado.activo == lado and not motor.estado.terminado:
			# El turno no avanzó: cortar antes de colgar (no debería pasar nunca).
			break
	resultado["ganador"] = motor.estado.ganador
	resultado["motivo"] = motor.estado.motivo_fin
	resultado["turnos"] = motor.estado.turno
	return resultado


static func _puede_seguir(motor: MotorDePalabra, lado: int) -> bool:
	var e: EstadoDuelo = motor.estado
	return not e.terminado and e.activo == lado and e.fase == Palabra.Fase.ACCIONES
