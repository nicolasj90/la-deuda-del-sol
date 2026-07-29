# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name PilotoRandom
extends RefCounted

## Piloto de pruebas: juega **al azar entre las jugadas legales**.
##
## No es la IA del juego (esa es la del § 7: beam de ancho 4, cota de 200 nodos y
## perfiles por rival). Es el bicho que necesita el humo de la vista: pega mil
## veces en todos los botones sin pensar, que es exactamente lo que rompe una UI.
##
## Igual que la IA de verdad, **le pide las jugadas legales al motor** (§ 7.2.1) y
## todo su azar entra por un [RandomNumberGenerator] inyectado, así que una semilla
## reproduce el duelo entero.

## Probabilidad de pasar aunque queden jugadas: sin esto un duelo al azar se
## estira siempre hasta el tope de turnos.
const CHANCE_DE_PASAR: float = 0.12


static func elegir(
	motor: MotorDePalabra, lado: int, rng: RandomNumberGenerator
) -> JugadaDePalabra:
	var legales: Array[JugadaDePalabra] = motor.jugadas_legales(lado)
	var utiles: Array[JugadaDePalabra] = []
	for j: JugadaDePalabra in legales:
		if j.tipo != Palabra.TipoJugada.PASAR:
			utiles.append(j)
	if utiles.is_empty() or rng.randf() < CHANCE_DE_PASAR:
		return JugadaDePalabra.pasar(lado)
	return utiles[rng.randi_range(0, utiles.size() - 1)]


## Mazo legal al azar para una mesa: 30 cartas, tope de copias por carta (2, o 1
## si es legendaria, § 1) y sin cartas de módulo apagado (§ 4).
static func mazo_al_azar(mesa: ConfigMesa, rng: RandomNumberGenerator) -> Array[String]:
	var disponibles: Array[String] = CatalogoDePalabra.armables(mesa)
	var salida: Array[String] = []
	var copias: Dictionary = {}
	var vueltas: int = 0
	while salida.size() < Palabra.MAZO_TAMANO and vueltas < 2000 and not disponibles.is_empty():
		vueltas += 1
		var id: String = disponibles[rng.randi_range(0, disponibles.size() - 1)]
		var def: CartaDePalabra = CatalogoDePalabra.obtener(id)
		if def == null:
			disponibles.erase(id)
			continue
		var puestas: int = int(copias.get(id, 0))
		if puestas >= def.max_copias():
			disponibles.erase(id)
			continue
		copias[id] = puestas + 1
		salida.append(id)
	return salida
