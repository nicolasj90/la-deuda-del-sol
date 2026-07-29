# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name PilaDePalabra
extends Pile

## Pila de una zona de duelo: Mazo, Descarte, **Empeñadero** (§ 3.3), Mora
## (§ 3.2.2) y las cartas en viaje del módulo al fiado (§ 4.2).
##
## Igual que el resto de los contenedores propios: sin historial (§ 6.2.6), la
## legalidad la decide el motor por [member validador], soltar es una intención
## (no mueve nada) y no pisa cara/dorso ni interacción.
##
## El Empeñadero **existe con drop zone habilitada desde el turno 1** y se cierra
## por [method _card_can_be_added] consultando la mesa: `enable_drop_zone` solo se
## lee en `_ready` y no se puede reactivar en runtime (§ 6.2.9).

## Se emite cuando el jugador suelta un naipe encima (empeñar).
signal soltaron_naipe(naipe: Card, contenedor: CardContainer)
## Se emite al apretar un naipe de la pila (rescatar del Empeñadero rival,
## denunciar una carta en viaje).
signal apretaron_naipe(naipe: Card, contenedor: CardContainer)

## "" si el motor aceptaría lo que se está soltando. Vacío = no se acepta nada.
var validador: Callable = Callable()


func _card_can_be_added(cards: Array) -> bool:
	if cards.size() != 1:
		return false
	var naipe: Card = cards[0] as Card
	if naipe == null or _held_cards.has(naipe):
		return false
	if not validador.is_valid():
		return false
	return String(validador.call(naipe)).is_empty()


func move_cards(cards: Array, _index: int = -1, _with_history: bool = true) -> bool:
	if cards.size() != 1:
		return false
	var naipe: Card = cards[0] as Card
	if naipe == null or _held_cards.has(naipe):
		return false
	naipe.return_card()
	soltaron_naipe.emit(naipe, self)
	return true


func _update_card_states() -> void:
	pass


func on_card_pressed(card: Card) -> void:
	apretaron_naipe.emit(card, self)
