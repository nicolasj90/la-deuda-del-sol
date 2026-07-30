# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node
## Restaurador de estado del acto: vive en cada mapa/dungeon del Acto 1.
##
## Al cargar partida, Encounters._ready() deja montada la party default (los
## cinco); este nodo reconstruye la party progresiva del acto desde las
## banderas guardadas apenas la escena entra al árbol. Es idempotente y barato
## (chequeo de bandera + resource_path), así que da igual cuántas veces corra.


func _ready() -> void:
	BanderasDeuda.restaurar_party_si_corresponde()
