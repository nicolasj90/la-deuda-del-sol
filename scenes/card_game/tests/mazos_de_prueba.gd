# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name MazosDePrueba
extends RefCounted

## Armador de mazos **para los tests de IA**: 30 cartas legales (§ 1: máximo 2
## copias, 1 si es legendaria) sesgadas al arquetipo de cada perfil.
##
## No es el armador del juego ni el mazo de guion de ningún rival: el § 5.10 lista
## los canales de obtención, no los 7 mazos carta por carta, y acá **no se
## inventa** ninguno. Es una fábrica determinista de posiciones para poder correr
## duelos IA contra IA (§ 9.1).

## Arquetipo con el que se arma el mazo de cada perfil (§ 7.3).
const ARQUETIPO_DE_PERFIL: Dictionary = {
	"casa": "neutral",
	"garante": "garante",
	"letra_chica": "letra_chica",
	"interes": "interes",
	"de_palabra": "de_palabra",
	"al_contado": "al_contado",
	"senuelos": "palabra_rota",
	"control": "palabra_rota",
}


## Mazo de 30 ids: primero el arquetipo pedido, después los neutrales, después lo
## que haya, siempre en orden alfabético (determinista).
static func por_arquetipo(arquetipo: String, mesa: ConfigMesa) -> Array[String]:
	var armables: Array[String] = CatalogoDePalabra.armables(mesa)
	var mazo: Array[String] = []
	for pase: String in [arquetipo, "neutral", ""]:
		for id: String in armables:
			if mazo.size() >= Palabra.MAZO_TAMANO:
				break
			var c: CartaDePalabra = CatalogoDePalabra.obtener(id)
			if c == null:
				continue
			if not pase.is_empty() and c.arquetipo != pase:
				continue
			var puestas: int = mazo.count(id)
			for _i: int in maxi(0, c.max_copias() - puestas):
				if mazo.size() < Palabra.MAZO_TAMANO:
					mazo.append(id)
	return mazo


static func del_perfil(perfil_id: String, mesa: ConfigMesa) -> Array[String]:
	var arquetipo: String = String(ARQUETIPO_DE_PERFIL.get(perfil_id, "neutral"))
	return por_arquetipo(arquetipo, mesa)
