# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name ManoDePalabra
extends Hand

## La mano de una Firma: el abanico de [Hand] del addon, con tres correcciones.
##
## 1. **Sin historial** (§ 6.2.6): `move_cards` fuerza `with_history = false`, o
##    `card_manager.undo()` podría des-jugar una carta.
## 2. **No recibe cartas de afuera por drag**: las cartas entran a la mano solo
##    porque el motor lo dice (robo, rescate, Fe de Erratas). Arrastrar de la mano
##    a la mano **sí** vale: es reordenar, y es cosmético.
## 3. **No pisa cara/dorso ni interacción**: los maneja la vista, que sabe qué es
##    información oculta (mano rival, carta al fiado) y cuándo hay que apagar todo
##    (capa de objetivos, § 6.2.2).

## Se emite al apretar un naipe de esta mano: la vista lo selecciona.
signal apretaron_naipe(naipe: Card)


func _card_can_be_added(cards: Array) -> bool:
	for c: Variant in cards:
		if not _held_cards.has(c):
			return false
	return true


func move_cards(cards: Array, index: int = -1, _with_history: bool = true) -> bool:
	return super.move_cards(cards, index, false)


func _update_card_states() -> void:
	pass


func on_card_pressed(card: Card) -> void:
	apretaron_naipe.emit(card)
