# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name EstradoDePalabra
extends CardContainer

## El Estrado de una Firma: **7 lugares fijos** (diseño § 1), izquierda a derecha.
##
## El orden importa: las resoluciones deterministas del motor (Letra chica en
## cascada, AoE) van en orden de posición (§ 3.2.3), así que la vista dibuja ese
## mismo orden con [method ordenar_por].
##
## Tres cosas que este contenedor **no** hace, a propósito:
##
## 1. **No decide legalidad.** `_card_can_be_added` es afordancia visual nada más
##    (§ 0): el que dice sí o no es el motor, a través de [member validador].
## 2. **No mueve la carta al soltarla.** Soltar es una *intención*: emite
##    [signal soltaron_naipe] y devuelve el naipe a su lugar. Recién cuando el
##    motor confirma (evento `carta_entro_al_estrado`) la vista lo trae acá. Así
##    no hay que deshacer nada si el jugador cancela el objetivo o la Promesa.
## 3. **No escribe historial.** `move_cards` fuerza `with_history = false`
##    (§ 6.2.6: el historial del addon crece sin cota y `undo()` es público, o sea
##    que se podría «des-jugar» una carta).

## Se emite cuando el jugador suelta un naipe encima: es un pedido, no un hecho.
signal soltaron_naipe(naipe: Card, contenedor: CardContainer)
## Se emite al apretar un naipe del Estrado (elegir atacante, ver la carta).
signal apretaron_naipe(naipe: Card, contenedor: CardContainer)

## Cuántos lugares tiene el Estrado. Es el tope del diseño, no un adorno.
@export var capacidad: int = Palabra.ESTRADO_MAX
## Distancia entre lugares. La vista la calcula del tamaño de carta + aire.
@export var paso: Vector2 = Vector2(90, 0)

## `motivo_ilegal`-como-callable: recibe el naipe y devuelve "" si el motor lo
## aceptaría. Vacío = el contenedor no acepta nada soltado.
var validador: Callable = Callable()


## Posición de un lugar del Estrado, en coordenadas globales.
func posicion_de_lugar(indice: int) -> Vector2:
	return global_position + paso * indice


## Reordena los naipes para que sigan el orden del motor (izquierda a derecha).
func ordenar_por(uids: Array[int]) -> void:
	_prune_freed_cards()
	var orden: Dictionary = {}
	for i: int in uids.size():
		orden[uids[i]] = i
	var previo: Array[Card] = _held_cards.duplicate()
	_held_cards.sort_custom(
		func(a: Card, b: Card) -> bool:
			return int(orden.get(_uid_de(a), 99)) < int(orden.get(_uid_de(b), 99))
	)
	if _held_cards != previo:
		update_card_ui()


func _card_can_be_added(cards: Array) -> bool:
	if cards.size() != 1:
		return false
	var naipe: Card = cards[0] as Card
	if naipe == null:
		return false
	if _held_cards.has(naipe):
		# Reordenar dentro del Estrado no es una jugada: el orden lo fija el motor.
		return false
	if get_card_count() >= capacidad:
		return false
	if not validador.is_valid():
		return false
	return String(validador.call(naipe)).is_empty()


## Soltar un naipe es una intención. No se mueve nada: gana el motor (§ 0).
func move_cards(cards: Array, _index: int = -1, _with_history: bool = true) -> bool:
	if cards.size() != 1:
		return false
	var naipe: Card = cards[0] as Card
	if naipe == null or _held_cards.has(naipe):
		return false
	naipe.return_card()
	soltaron_naipe.emit(naipe, self)
	return true


func _update_target_positions() -> void:
	for i: int in _held_cards.size():
		_held_cards[i].move(posicion_de_lugar(i), 0.0)


func _update_target_z_index() -> void:
	for i: int in _held_cards.size():
		_held_cards[i].stored_z_index = i


## La vista maneja cara/dorso (una carta al fiado viaja boca abajo) y la
## interacción (la capa de objetivos apaga todo): este contenedor no los pisa.
func _update_card_states() -> void:
	pass


func get_target_pose_for(card: Card) -> Dictionary:
	var i: int = _held_cards.find(card)
	if i == -1:
		return {}
	return {"position": posicion_de_lugar(i), "rotation": 0.0}


func on_card_pressed(card: Card) -> void:
	apretaron_naipe.emit(card, self)


func _uid_de(naipe: Card) -> int:
	var np: NaipeDePalabra = naipe as NaipeDePalabra
	return np.uid_motor if np != null else -1
