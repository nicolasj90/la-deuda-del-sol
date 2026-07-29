# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends SceneTree

## Prueba de humo de [FabricaDePalabra]: arma un [CardManager] + una [Pile] de
## verdad y reparte las 42 caras del set.
##
## No vive en `runner_motor.gd` a propósito: ese runner es 100 % sin escena
## (diseño § 8) y esto necesita árbol de nodos y `addons/card-framework`.
##
## Uso:
## [codeblock]
## godot --headless --path . -s res://scenes/card_game/tools/humo_fabrica.gd
## [/codeblock]

const ESCENA_FABRICA: String = "res://scenes/card_game/vista/fabrica_de_palabra.tscn"

var _fallos: Array[String] = []
var _corrido: bool = false


## El árbol recién existe en el primer frame: `_initialize()` corre antes de que
## `root` acepte hijos, y `CardManager` necesita estar en el árbol para instanciar
## su fábrica.
func _process(_delta: float) -> bool:
	if _corrido:
		return true
	_corrido = true
	_correr()
	return true


func _correr() -> void:
	var gestor: CardManager = CardManager.new()
	gestor.name = "CardManager"
	gestor.card_factory_scene = load(ESCENA_FABRICA)
	root.add_child(gestor)

	var pila: Pile = Pile.new()
	pila.name = "Mazo"
	gestor.add_child(pila)

	var fabrica: FabricaDePalabra = gestor.card_factory as FabricaDePalabra
	if fabrica == null:
		_fallar("el CardManager no instanció una FabricaDePalabra")
		_terminar()
		return
	for e: String in fabrica.errores():
		_fallar("precarga: %s" % e)
	var mano: Hand = Hand.new()
	mano.name = "Mano"
	mano.max_hand_size = 2
	gestor.add_child(mano)

	_probar_las_42(fabrica, pila)
	_probar_carta_inexistente(fabrica, pila)
	_probar_mano_llena(fabrica, mano)
	_probar_info_no_compartida(fabrica)
	_terminar()


## § 6.2.7: la mano llena **no** destruye nada en silencio. El destino se decide
## antes de instanciar el nodo.
func _probar_mano_llena(fabrica: FabricaDePalabra, mano: Hand) -> void:
	for i: int in 2:
		if fabrica.create_card("peon_de_vina", mano) == null:
			_fallar("la mano tendría que aceptar la carta %d de 2" % (i + 1))
	if mano.get_card_count() != 2:
		_fallar("la mano quedó con %d cartas de 2" % mano.get_card_count())
	var hijos_antes: int = mano.cards_node.get_child_count()
	if fabrica.create_card("peon_de_vina", mano) != null:
		_fallar("la mano llena aceptó una tercera carta")
	if mano.cards_node.get_child_count() != hijos_antes:
		_fallar("la mano llena creó un nodo para tirarlo (§ 6.2.7)")
	print("-- mano llena (tope %d): rechazo sin crear nodos" % mano.max_hand_size)


func _probar_las_42(fabrica: FabricaDePalabra, pila: Pile) -> void:
	var creadas: int = 0
	for id: String in CatalogoDePalabra.ids():
		var naipe: Card = fabrica.create_card(id, pila)
		if naipe == null:
			_fallar("no se pudo crear '%s'" % id)
			continue
		creadas += 1
		var np: NaipeDePalabra = naipe as NaipeDePalabra
		if np == null:
			_fallar("'%s' no es un NaipeDePalabra" % id)
			continue
		if np.carta_id != id:
			_fallar("'%s' quedó con carta_id '%s'" % [id, np.carta_id])
		if np.etiqueta_nombre == null or np.etiqueta_nombre.text.is_empty():
			_fallar("'%s': la etiqueta de nombre quedó vacía" % id)
		# Los números tienen que poder cambiar en vivo (§ 6.2.3: Interés).
		np.pintar_numeros(9, 8, 7, 8)
		if np.etiqueta_coste.text != "9" or np.etiqueta_ataque.text != "8":
			_fallar("'%s': los labels no siguen a pintar_numeros" % id)
	if creadas != CatalogoDePalabra.ids().size():
		_fallar("se crearon %d naipes de %d" % [creadas, CatalogoDePalabra.ids().size()])
	if pila.get_card_count() != creadas:
		_fallar("la pila tiene %d cartas y se crearon %d" % [pila.get_card_count(), creadas])
	print("-- %d naipes creados y colocados en la pila" % creadas)


func _probar_carta_inexistente(fabrica: FabricaDePalabra, pila: Pile) -> void:
	var antes: int = pila.get_card_count()
	# Tiene que devolver null sin crear nodos y sin colgarse (§ 6.2.5).
	var naipe: Card = fabrica.create_card("carta_que_no_existe", pila)
	if naipe != null:
		_fallar("creó un naipe para una carta inexistente")
	if pila.get_card_count() != antes:
		_fallar("una carta inexistente cambió el contenido de la pila")
	print("-- carta inexistente: rechazada sin crear nodos")


func _probar_info_no_compartida(fabrica: FabricaDePalabra) -> void:
	var a: NaipeDePalabra = fabrica.crear_suelto("gallina_lacrevieja")
	var b: NaipeDePalabra = fabrica.crear_suelto("gallina_lacrevieja")
	if a == null or b == null:
		_fallar("no se pudieron crear dos copias sueltas de la Gallina")
		return
	# `is_same` compara la referencia: las dos Gallinas del mazo no pueden
	# compartir el mismo Dictionary (§ 6.2.4).
	if is_same(a.card_info, b.card_info):
		_fallar("las dos copias comparten la misma instancia de card_info (§ 6.2.4)")
	if not a.card_info.is_read_only():
		_fallar("card_info tendría que ser de solo lectura")
	a.queue_free()
	b.queue_free()
	print("-- card_info: una copia por naipe, de solo lectura")


func _fallar(mensaje: String) -> void:
	_fallos.append(mensaje)


func _terminar() -> void:
	if _fallos.is_empty():
		print("OK — humo de FabricaDePalabra")
		quit(0)
		return
	for f: String in _fallos:
		printerr("FALLO: %s" % f)
	printerr("FALLÓ — %d problema(s)" % _fallos.size())
	quit(1)
