# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name ArmadorDeMazos
extends RefCounted

## Armador y validador de mazos **del juego** (no de los tests).
##
## [MazosDePrueba] existe para correr duelos IA contra IA y dice de sí mismo que
## no es el armador del juego; esta clase sí lo es: la usan [Coleccion] (para
## validar el mazo activo del jugador) y [code]DueloLauncher[/code] (para armar el
## mazo de un rival cuando la escena solo declara un arquetipo).
##
## Reglas que aplica (diseño § 1 y § 4):
## [br]— 30 cartas por mazo (se puede pedir que no lo exija: los mazos del
##   principio del Acto 1 todavía no llegan a 30, ver [constant Coleccion.MAZO_INICIAL]).
## [br]— máximo 2 copias por carta, 1 si es legendaria.
## [br]— nada de tokens ni de cartas bloqueadas.
## [br]— una carta de módulo apagado no entra al mazo de esa mesa.
##
## Todo es estático y determinista: mismo pedido, mismo mazo.

## Tamaño reglamentario de mazo (§ 1).
const TAMANO: int = Palabra.MAZO_TAMANO

## Arquetipo con el que se arma el mazo de cada rival-personalidad cuando la
## escena no lo enumera carta por carta (§ 7.3 del diseño: los perfiles de IA del
## Acto 1). Misma tabla que usa el simulador de balance, acá para el juego.
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


static func arquetipo_de_perfil(perfil_id: String) -> String:
	return String(ARQUETIPO_DE_PERFIL.get(perfil_id, "neutral"))


## Pasa cualquier lista de ids (Array, PackedStringArray, lo que venga de un
## .dialogue) a un [code]Array[String][/code] limpio.
static func normalizar(ids: Variant) -> Array[String]:
	var salida: Array[String] = []
	if ids == null:
		return salida
	if ids is String:
		if not String(ids).is_empty():
			salida.append(String(ids))
		return salida
	if ids is Dictionary:
		# {id: copias} — el orden es el de la Dictionary, que en GDScript es estable.
		for clave: Variant in (ids as Dictionary).keys():
			var cuantas: int = int((ids as Dictionary)[clave])
			for _i: int in maxi(0, cuantas):
				salida.append(String(clave))
		return salida
	if ids is PackedStringArray:
		for id: String in ids as PackedStringArray:
			salida.append(id)
		return salida
	if ids is Array:
		for v: Variant in ids as Array:
			salida.append(String(v))
	return salida


## id -> cuántas copias hay en la lista.
static func cuenta(ids: Variant) -> Dictionary:
	var salida: Dictionary = {}
	for id: String in normalizar(ids):
		salida[id] = int(salida.get(id, 0)) + 1
	return salida


## Errores que hacen ilegal el mazo, o vacío si está bien.
## [param exigir_tamano] chequea además las 30 cartas del § 1.
static func errores_de_mazo(
	ids: Variant, mesa: ConfigMesa = null, exigir_tamano: bool = false
) -> Array[String]:
	if mesa == null:
		mesa = ConfigMesa.base()
	var lista: Array[String] = normalizar(ids)
	var errores: Array[String] = []
	if exigir_tamano and lista.size() != TAMANO:
		errores.append("el mazo tiene %d cartas y el reglamento pide %d" % [lista.size(), TAMANO])
	var por_id: Dictionary = cuenta(lista)
	for id: String in por_id.keys():
		var copias: int = int(por_id[id])
		var c: CartaDePalabra = CatalogoDePalabra.obtener(id)
		if c == null:
			errores.append("«%s» no existe en el set" % id)
			continue
		if c.es_token:
			errores.append("«%s» es un token: no entra a ningún mazo" % id)
			continue
		if c.bloqueada:
			errores.append("«%s» está bloqueada en el Acto 1" % id)
			continue
		if not c.modulo.is_empty() and not mesa.tiene(c.modulo):
			errores.append("«%s» necesita el módulo «%s», apagado en esta mesa" % [id, c.modulo])
		if copias > c.max_copias():
			errores.append(
				"«%s»: %d copias y el máximo es %d" % [id, copias, c.max_copias()]
			)
	return errores


static func es_legal(ids: Variant, mesa: ConfigMesa = null, exigir_tamano: bool = false) -> bool:
	return errores_de_mazo(ids, mesa, exigir_tamano).is_empty()


## Mazo de [constant TAMANO] ids sesgado a un arquetipo: primero el arquetipo
## pedido, después los neutrales, después lo que haya, siempre en orden
## alfabético. Sirve para los rivales que la escena declara solo por arquetipo
## («el prestamista de Villarrúbrica juega puro Interés»).
static func por_arquetipo(arquetipo: String, mesa: ConfigMesa = null) -> Array[String]:
	if mesa == null:
		mesa = ConfigMesa.base()
	return completar([] as Array[String], mesa, arquetipo)


## Completa una lista de ids hasta [constant TAMANO] con cartas legales, sin
## romper el máximo de copias y sin tocar lo que ya estaba. Determinista.
static func completar(
	ids: Variant, mesa: ConfigMesa = null, arquetipo: String = "neutral"
) -> Array[String]:
	if mesa == null:
		mesa = ConfigMesa.base()
	var mazo: Array[String] = normalizar(ids)
	var armables: Array[String] = CatalogoDePalabra.armables(mesa)
	armables.sort()
	for pase: String in [arquetipo, "neutral", ""]:
		for id: String in armables:
			if mazo.size() >= TAMANO:
				return mazo
			var c: CartaDePalabra = CatalogoDePalabra.obtener(id)
			if c == null:
				continue
			if not pase.is_empty() and c.arquetipo != pase:
				continue
			for _i: int in maxi(0, c.max_copias() - mazo.count(id)):
				if mazo.size() < TAMANO:
					mazo.append(id)
	return mazo
