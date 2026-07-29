# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
class_name JugadorFalso
extends CharacterBody2D

## Doble de prueba del jugador para los smokes de puzzles.
##
## Expone la misma superficie que [BloqueEmpujable] consulta del [Player] real:
## un [code]input_walk_behavior[/code] con [code]input_vector[/code] (la intención
## de movimiento, que no se anula al chocar contra una pared) y [code]velocity[/code].
## Está en el grupo [code]player[/code], igual que el jugador de Threadbare.

## Intención de movimiento, en píxeles/segundo.
var input_vector: Vector2 = Vector2.ZERO

## Duck typing: el bloque pide [code]cuerpo.input_walk_behavior.input_vector[/code].
var input_walk_behavior: Node:
	get:
		return self


func _ready() -> void:
	add_to_group(&"player")


## Arma un doble listo para usar, con collider y capa de jugador.
static func crear(en_posicion: Vector2 = Vector2.ZERO) -> JugadorFalso:
	var jugador := JugadorFalso.new()
	jugador.name = "JugadorFalso"
	jugador.collision_layer = 1
	jugador.collision_mask = 16
	jugador.global_position = en_posicion
	var forma := CollisionShape2D.new()
	var capsula := CapsuleShape2D.new()
	capsula.height = 42.0
	capsula.radius = 10.0
	forma.shape = capsula
	forma.rotation = -PI / 2.0
	jugador.add_child(forma)
	return jugador
