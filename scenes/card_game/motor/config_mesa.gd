# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name ConfigMesa
extends Resource

## La mesa: qué módulos están encendidos y los ganchos de la Balanza (§ 4).
##
## El motor arranca con todos los módulos implementados y **apagados por bandera**.
## El Acto 1 usa [method base]; [code]balanza[/code] y [code]modo_rito[/code]
## quedan apagados y los multiplicadores en 1.0.

@export var empenar: bool = false
@export var al_fiado: bool = false
@export var balanza: bool = false
@export var modo_rito: bool = false

## Ganchos de la Balanza de la Palabra (Acto 2, § 4.1). En el Acto 1 valen 1.0:
## el efecto se resuelve una sola vez.
@export var amplificacion_de_palabra: float = 1.0
@export var amplificacion_letra_chica: float = 1.0

## Lado que desafió. En un empate por duelo incobrable, pierde el desafiante
## (§ 1.2); en los duelos de guion el desafiante es la IA.
@export var desafiante: int = 1
## Tope de turnos antes de declarar el duelo incobrable.
@export var tope_turnos: int = Palabra.TOPE_TURNOS
@export var aval_inicial: int = Palabra.AVAL_INICIAL
## Bono de entrega al revelar una carta jugada al fiado (§ 4.2). El diseño no fija
## un número: queda en 0 hasta que el balance lo defina.
@export var bono_entrega_ataque: int = 0
@export var bono_entrega_aguante: int = 0


## Mesa del Acto 1 base (E03 en adelante): solo Base + Promesas.
static func base() -> ConfigMesa:
	return ConfigMesa.new()


## Mesa de El Fiado (E17): empeñar + al fiado.
static func el_fiado() -> ConfigMesa:
	var m: ConfigMesa = ConfigMesa.new()
	m.empenar = true
	m.al_fiado = true
	return m


func tiene(modulo: String) -> bool:
	match modulo:
		Palabra.MOD_EMPENAR:
			return empenar
		Palabra.MOD_AL_FIADO:
			return al_fiado
		Palabra.MOD_BALANZA:
			return balanza
		Palabra.MOD_RITO:
			return modo_rito
	return false


## Repeticiones de un efecto según los multiplicadores de la Balanza. Con 1.0
## devuelve 1: el gancho está, apagado.
func repeticiones(trigger: String) -> int:
	var factor: float = 1.0
	if trigger == Palabra.TR_DE_PALABRA:
		factor = amplificacion_de_palabra
	elif trigger == Palabra.TR_LETRA_CHICA:
		factor = amplificacion_letra_chica
	return maxi(1, int(floor(factor)))
