# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name FabricaDePalabra
extends CardFactory

## Fábrica de naipes de «De Palabra»: instancia [NaipeDePalabra] desde los
## [CartaDePalabra] del pipeline (`data/cartas/fuente/*.json` → `data/cartas/tres/*.tres`).
##
## **Reemplaza a `JsonCardFactory`, que no se usa** (diseño § 6.2.5). Los motivos,
## verificados en el código del addon:
##
## 1. `preload_card_data()` tiene un **loop infinito**: sus dos `continue` no
##    avanzan `file_name`, así que un JSON malformado o un PNG faltante **cuelga
##    Godot al arrancar**, sin error legible. Acá el recorrido es un `for` sobre un
##    Array: no hay forma de no avanzar, y todo dato malo sale por `push_error`.
## 2. `card_info` se comparte **por referencia** entre todas las copias de una
##    carta y queda cacheado para todo el proceso: escribir estado de runtime ahí
##    corrompe las dos Gallinas del mazo a la vez y arrastra la corrupción entre
##    duelos. Acá cada naipe recibe su propio `duplicate(true)` y, por defecto,
##    **de solo lectura**: el estado mutable vive en el motor ([EstadoCarta]).
## 3. `_create_card_node` instancia el nodo **y después** pregunta si el
##    contenedor lo acepta; si no, `queue_free()` en silencio (§ 6.2.7). Acá el
##    destino se decide **antes** de instanciar: nunca se crea un nodo para
##    tirarlo, y el rechazo es ruidoso.
##
## La fábrica no conoce el motor: traduce definiciones a nodos. Los números vivos
## los pinta la vista con [method NaipeDePalabra.pintar_numeros].

## Escena del naipe (tiene que extender [Card]). Por defecto,
## `naipe_de_palabra.tscn`.
@export var escena_naipe: PackedScene
## Dorso común. Mientras no haya arte queda en null y el naipe muestra su marco.
@export var imagen_dorso: Texture2D
## Cara por defecto para las cartas sin arte propio (§ 9.4: faltan las 42 caras).
@export var imagen_placeholder: Texture2D
## Deja [member Card.card_info] de solo lectura, para que un intento de guardar
## estado de runtime ahí falle fuerte en vez de corromper las copias (§ 6.2.4).
@export var card_info_de_solo_lectura: bool = true

var _errores: Array[String] = []


## Carga el catálogo entero una sola vez. Un solo pase, sin `continue` que no
## avance, y los errores se acumulan en [method errores] además de `push_error`.
func preload_card_data() -> void:
	preloaded_cards.clear()
	_errores.clear()
	if escena_naipe == null:
		_fallar("no hay escena_naipe asignada: la fábrica no puede instanciar nada")
		return
	for e: String in CatalogoDePalabra.errores():
		_fallar("el set de cartas no valida: %s" % e)
	var catalogo: Dictionary = CatalogoDePalabra.cargar()
	for id: String in CatalogoDePalabra.ids():
		var def: CartaDePalabra = catalogo[id] as CartaDePalabra
		if def == null:
			_fallar("'%s' no es una CartaDePalabra" % id)
			continue
		preloaded_cards[id] = {
			"def": def,
			"info": _info_de(def),
			"textura": _textura_de(def),
		}


## Crea el naipe de [param card_name] y lo mete en [param target].
## Devuelve null (sin instanciar nada) si la carta no existe o si el contenedor no
## puede recibirla: el destino es decisión del motor, no de la fábrica.
func create_card(card_name: String, target: CardContainer) -> Card:
	var entrada: Dictionary = _entrada_de(card_name)
	if entrada.is_empty():
		return null
	if target != null and not _contenedor_listo(target):
		_fallar(
			(
				"el contenedor de '%s' todavía no está listo (sin nodo Cards): "
				+ "instanciá los contenedores antes de repartir"
			)
			% card_name
		)
		return null
	if target != null and not hay_lugar(target):
		# § 6.2.7: el motor decide el destino ANTES. Si llegamos acá, la vista y el
		# motor están desincronizados; se avisa y no se destruye nada en silencio.
		_fallar("'%s' no entra en el contenedor destino (lleno)" % card_name)
		return null
	var naipe: NaipeDePalabra = crear_suelto(card_name)
	if naipe == null:
		return null
	if target != null:
		_colocar(naipe, target)
	return naipe


## Crea un naipe **sin contenedor**: sirve para la capa de objetivos, la
## previsualización de la colección y el armador de mazos.
func crear_suelto(id: String) -> NaipeDePalabra:
	var entrada: Dictionary = _entrada_de(id)
	if entrada.is_empty():
		return null
	var nodo: Node = escena_naipe.instantiate()
	var naipe: NaipeDePalabra = nodo as NaipeDePalabra
	if naipe == null:
		_fallar("escena_naipe no instancia un NaipeDePalabra")
		nodo.queue_free()
		return null
	if card_size != Vector2.ZERO:
		naipe.card_size = card_size
	# Una copia propia por naipe, no la referencia del molde (§ 6.2.4).
	var info: Dictionary = (entrada["info"] as Dictionary).duplicate(true)
	if card_info_de_solo_lectura:
		info.make_read_only()
	naipe.card_info = info
	naipe.mostrar_definicion(entrada["def"] as CartaDePalabra)
	naipe.poner_caras(entrada["textura"] as Texture2D, imagen_dorso)
	naipe.name = "Naipe_%s" % id
	return naipe


## Definición inmutable de una carta, o null si no está en el set.
func definicion(id: String) -> CartaDePalabra:
	var entrada: Dictionary = preloaded_cards.get(id, {})
	return entrada.get("def", null) as CartaDePalabra


## Ids de las caras que todavía no tienen arte propio (§ 9.4). La vista las dibuja
## con [member imagen_placeholder].
func caras_faltantes() -> Array[String]:
	var salida: Array[String] = []
	for id: String in CatalogoDePalabra.ids():
		var def: CartaDePalabra = CatalogoDePalabra.obtener(id)
		if def == null:
			continue
		if def.arte.strip_edges().is_empty() or not ResourceLoader.exists(def.arte):
			salida.append(id)
	return salida


## Errores acumulados desde la última precarga. Vacío = fábrica sana.
func errores() -> Array[String]:
	return _errores.duplicate()


## ¿Le queda lugar al contenedor para [param n] cartas más? Se pregunta **antes**
## de instanciar. `Hand` es el único contenedor del framework con tope propio.
func hay_lugar(target: CardContainer, n: int = 1) -> bool:
	if target == null:
		return false
	var tope: Variant = target.get("max_hand_size")
	if tope == null:
		return true
	return target.get_card_count() + n <= int(tope)


# --- Interno ---


func _entrada_de(id: String) -> Dictionary:
	if preloaded_cards.has(id):
		return preloaded_cards[id]
	# Carga tardía: útil para tokens que aparecen a mitad de duelo si alguien no
	# precargó. Un solo intento, nunca un reintento en bucle.
	var def: CartaDePalabra = null
	if CatalogoDePalabra.existe(id):
		def = CatalogoDePalabra.obtener(id)
	if def == null:
		_fallar("no existe la carta '%s' en el set" % id)
		return {}
	if escena_naipe == null:
		_fallar("no hay escena_naipe asignada: la fábrica no puede instanciar nada")
		return {}
	preloaded_cards[id] = {
		"def": def,
		"info": _info_de(def),
		"textura": _textura_de(def),
	}
	return preloaded_cards[id]


## Molde de solo lectura de `card_info`: **datos**, nunca estado de runtime.
func _info_de(def: CartaDePalabra) -> Dictionary:
	var info: Dictionary = {
		"id": def.id,
		"name": def.id,  # el framework espera la clave "name"
		"nombre": def.nombre,
		"texto": def.texto,
		"lore": def.lore,
		"arquetipo": def.arquetipo,
		"tipo": int(def.tipo),
		"coste_base": def.coste_base,
		"ataque_base": def.ataque_base,
		"aguante_base": def.aguante_base,
		"dano_base": def.dano_base,
		"keywords": def.keywords.duplicate(),
		"es_token": def.es_token,
		"es_legendaria": def.es_legendaria,
		"modulo": def.modulo,
		"bloqueada": def.bloqueada,
	}
	return info


func _textura_de(def: CartaDePalabra) -> Texture2D:
	if def.arte.strip_edges().is_empty():
		return imagen_placeholder
	if not ResourceLoader.exists(def.arte):
		_fallar("'%s' apunta a un arte que no existe: %s" % [def.id, def.arte])
		return imagen_placeholder
	var tex: Texture2D = ResourceLoader.load(def.arte) as Texture2D
	if tex == null:
		_fallar("'%s': %s no es una textura" % [def.id, def.arte])
		return imagen_placeholder
	return tex


func _contenedor_listo(target: CardContainer) -> bool:
	if not target.is_inside_tree():
		return false
	return target.cards_node != null


func _colocar(naipe: NaipeDePalabra, target: CardContainer) -> void:
	target.cards_node.add_child(naipe)
	target.add_card(naipe)


func _fallar(mensaje: String) -> void:
	_errores.append(mensaje)
	push_error("FabricaDePalabra: %s" % mensaje)
