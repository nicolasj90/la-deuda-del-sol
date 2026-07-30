# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name NaipeDePalabra
extends Card

## La carta **visual** de «De Palabra»: un [Card] del framework con labels vivos.
##
## Se llama [code]NaipeDePalabra[/code] y no `CartaDePalabra` porque ese nombre
## global ya es el del [Resource] de datos del motor (dos `class_name` iguales
## rompen el proyecto).
##
## Por qué labels y no un PNG por carta (diseño § 6.2.3): la cara que da el
## framework es un solo [Texture2D] sin números, y el **Interés** cambia coste y
## ataque en vivo (+1 por turno en mano), igual que los +1/+1. Con caras
## pre-rendereadas el arquetipo de Bravante es indibujable.
##
## Este nodo es **tonto a propósito**: no conoce el motor ni pregunta nada. La
## vista le pasa los números ya calculados con [method pintar_numeros] cada vez
## que el motor emite un evento. Nunca guarda estado de runtime en
## [member Card.card_info] (§ 6.2.4: es un Dictionary compartido y cacheado).

## Estructura que el script espera de `naipe_de_palabra.tscn`. Es un contrato:
## si la vista rediseña la cara, tiene que conservar estos nombres de nodo (los
## `@export` de tipo Node **no** se resuelven en escenas de texto, así que las
## referencias se buscan por ruta en [method _resolver_nodos]).
const RUTA_FRENTE: String = "FrontFace"
const RUTA_DORSO: String = "BackFace"
const RUTA_NOMBRE: String = "FrontFace/Nombre"
const RUTA_COSTE: String = "FrontFace/Coste"
const RUTA_ATAQUE: String = "FrontFace/Ataque"
const RUTA_AGUANTE: String = "FrontFace/Aguante"
const RUTA_TIPO: String = "FrontFace/Tipo"
const RUTA_TEXTO: String = "FrontFace/Texto"
const RUTA_LORE: String = "FrontFace/Lore"

## Tamaño en el que está dibujada la cara en `naipe_de_palabra.tscn`. En la mesa
## las cartas van más chicas (siete lugares de Estrado + mano + pilas no entran de
## otra forma en 1280×720), así que el naipe **escala su cara entera** en vez de
## reacomodar labels: [method Card._update_card_size] del addon solo estira los
## dos [TextureRect] y dejaría los números y el texto en su tamaño de diseño,
## desbordando la carta.
const DISENO: Vector2 = Vector2(150, 210)

## Marco de la cara visible. Es el **placeholder** mientras no haya arte: si
## [member Card.front_image] es null, esto es todo lo que se ve además del texto.
var marco_frente: Control = null
var marco_dorso: Control = null
var etiqueta_nombre: Label = null
var etiqueta_coste: Label = null
var etiqueta_ataque: Label = null
var etiqueta_aguante: Label = null
var etiqueta_tipo: Label = null
var etiqueta_texto: Label = null
var etiqueta_lore: Label = null

## Id de la definición ([member CartaDePalabra.id]). Es la clave con el catálogo.
var carta_id: String = ""
## `uid` de la instancia en el motor, o -1 si el naipe no representa una carta de
## un duelo en curso (previsualización, colección, armador de mazos).
var uid_motor: int = -1

var _def: CartaDePalabra = null


func _ready() -> void:
	_resolver_nodos()
	super._ready()
	if front_face_texture != null and back_face_texture != null:
		set_faces(front_image, back_image)
	if _def != null:
		_pintar()
	_actualizar_marcos()
	# El setter de `card_size` puede haber corrido antes de que existieran los
	# nodos (la fábrica arma el naipe suelto): se reaplica con el árbol listo.
	_update_card_size(card_size)


## Toda la cara escala junta. Se sobreescribe entero a propósito: el original
## estira los [TextureRect] al tamaño nuevo, y acá los TextureRect viven **dentro**
## de la cara escalada, así que estirarlos los escalaría dos veces.
func _update_card_size(new_size: Vector2) -> void:
	if new_size.x <= 0.0 or new_size.y <= 0.0:
		return
	check_and_set_textures()
	if front_face_texture != null:
		front_face_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		front_face_texture.size = DISENO
	if back_face_texture != null:
		back_face_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back_face_texture.size = DISENO
	custom_minimum_size = new_size
	size = new_size
	pivot_offset = new_size / 2.0
	var factor: Vector2 = Vector2(new_size.x / DISENO.x, new_size.y / DISENO.y)
	for marco: Control in [marco_frente, marco_dorso]:
		if marco != null:
			marco.position = Vector2.ZERO
			marco.scale = factor


## Caras de la carta. Aguanta que la llamen **antes** de entrar al árbol (la
## fábrica arma el naipe suelto y lo coloca después): en ese caso las guarda y las
## aplica en [method _ready].
func poner_caras(frente: Texture2D, dorso: Texture2D) -> void:
	front_image = frente
	back_image = dorso
	if front_face_texture != null and back_face_texture != null:
		set_faces(frente, dorso)


func _resolver_nodos() -> void:
	marco_frente = get_node_or_null(RUTA_FRENTE) as Control
	marco_dorso = get_node_or_null(RUTA_DORSO) as Control
	etiqueta_nombre = get_node_or_null(RUTA_NOMBRE) as Label
	etiqueta_coste = get_node_or_null(RUTA_COSTE) as Label
	etiqueta_ataque = get_node_or_null(RUTA_ATAQUE) as Label
	etiqueta_aguante = get_node_or_null(RUTA_AGUANTE) as Label
	etiqueta_tipo = get_node_or_null(RUTA_TIPO) as Label
	etiqueta_texto = get_node_or_null(RUTA_TEXTO) as Label
	etiqueta_lore = get_node_or_null(RUTA_LORE) as Label
	if etiqueta_nombre == null or etiqueta_coste == null:
		push_error(
			"NaipeDePalabra: la escena no tiene los labels de %s y %s" % [RUTA_NOMBRE, RUTA_COSTE]
		)


## Carga la definición inmutable. Solo texto fijo: los números los pinta
## [method pintar_numeros], porque el coste y el ataque **cambian en vivo**.
func mostrar_definicion(def: CartaDePalabra) -> void:
	_def = def
	carta_id = def.id if def != null else ""
	card_name = carta_id
	if etiqueta_nombre != null:
		_pintar()


func definicion() -> CartaDePalabra:
	return _def


## Números del turno, calculados por el motor ([code]motor.coste()[/code],
## [code]motor.ataque()[/code], [code]motor.aguante()[/code],
## [code]motor.dano_de_clausula()[/code]). Pasar -1 en un campo lo oculta.
func pintar_numeros(coste: int, ataque: int, aguante: int, dano: int = -1) -> void:
	if etiqueta_coste != null:
		etiqueta_coste.text = str(maxi(coste, 0))
		etiqueta_coste.visible = coste >= 0
	var es_clausula: bool = _def != null and _def.tipo == Palabra.Tipo.CLAUSULA
	if etiqueta_ataque != null:
		var valor: int = dano if es_clausula else ataque
		etiqueta_ataque.text = str(maxi(valor, 0))
		etiqueta_ataque.visible = valor >= 0
	if etiqueta_aguante != null:
		etiqueta_aguante.text = str(maxi(aguante, 0))
		etiqueta_aguante.visible = aguante >= 0 and not es_clausula


## Corta un arrastre o un hover en curso y devuelve el naipe a su lugar.
##
## La vista apaga todas las cartas cuando abre una decisión (capa de objetivos o
## diálogo, § 6.2.2), y el addon deja de escuchar el mouse en cuanto
## [member DraggableObject.can_be_interacted_with] es false: si el naipe estaba
## agarrado, el «mouse up» ya no llega nunca y la carta queda pegada al cursor
## para siempre. Eso pasaba en el camino de atacar, que se abre **apretando** un
## Fiador del Estrado (el botón todavía está apretado cuando se abre la capa).
func soltar_ya() -> void:
	if current_state != DraggableState.HOLDING and current_state != DraggableState.HOVERING:
		return
	var contenedor: CardContainer = card_container
	change_state(DraggableState.IDLE)
	# El contenedor se guarda los naipes agarrados para resolverlos en el «mouse
	# up»; si no se lo saca de esa lista, el próximo soltar de cualquier carta lo
	# arrastraría de prepo a la zona donde esté el mouse.
	if contenedor != null:
		contenedor._holding_cards.erase(self)
	return_card()


## [Card] lleva los contadores de hover y de arrastre en variables **estáticas**
## (`Card.hovering_card_count` / `holding_card_count`) y los baja en el `_exit_state`
## del addon. Un naipe que se libera en medio de un hover nunca los baja, y desde
## ahí [method Card._can_start_hovering] devuelve false para siempre: la mesa
## entera deja de responder al mouse, y también la mesa del duelo siguiente
## (E03 son dos duelos). La vista libera naipes cuando el motor lo dice —una carta
## que vuelve al mazo, el cierre del duelo—, así que se corrige acá.
## Se hace a mano y no con [method DraggableObject.change_state] porque el salir
## de HOVERING crea un tween de vuelta, y un nodo que está saliendo del árbol no
## puede crear tweens.
func _exit_tree() -> void:
	if current_state == DraggableState.HOVERING:
		hovering_card_count -= 1
	elif current_state == DraggableState.HOLDING:
		holding_card_count -= 1
	else:
		return
	current_state = DraggableState.IDLE
	if hover_tween != null and hover_tween.is_valid():
		hover_tween.kill()
		hover_tween = null
	scale = original_scale
	rotation = original_hover_rotation
	z_index = stored_z_index


## Afordancia visual del § 1.3: una carta que no puede producir ningún efecto
## legal se muestra apagada, con el motivo al hover. **La legalidad la decide el
## motor**, no este nodo.
func marcar_jugable(jugable: bool, motivo: String = "") -> void:
	modulate = Color(1, 1, 1, 1) if jugable else Color(0.55, 0.55, 0.55, 1)
	tooltip_text = motivo if not jugable else ""


func _pintar() -> void:
	if _def == null:
		return
	if etiqueta_nombre != null:
		etiqueta_nombre.text = _def.nombre
	if etiqueta_tipo != null:
		var partes: PackedStringArray = [Palabra.nombre_tipo(_def.tipo)]
		if _def.es_legendaria:
			partes.append("legendaria")
		if _def.es_token:
			partes.append("token")
		etiqueta_tipo.text = " · ".join(partes)
	if etiqueta_texto != null:
		etiqueta_texto.text = _def.texto
		etiqueta_texto.visible = not _def.texto.is_empty()
	if etiqueta_lore != null:
		etiqueta_lore.text = _def.lore
		etiqueta_lore.visible = not _def.lore.is_empty()
	pintar_numeros(_def.coste_base, _def.ataque_base, _def.aguante_base, _def.dano_base)


## El framework solo prende y apaga los dos [TextureRect]; los labels y el marco
## viven en otros nodos y hay que esconderlos también, o una carta boca abajo
## (módulo «al fiado») mostraría su nombre. Se llama desde el setter de
## `show_front`, que corre **antes** de `_ready`: de ahí los guardas de null.
func _update_face_visibility() -> void:
	super._update_face_visibility()
	_actualizar_marcos()


func _actualizar_marcos() -> void:
	if marco_frente != null:
		marco_frente.visible = _show_front
	if marco_dorso != null:
		marco_dorso.visible = not _show_front
