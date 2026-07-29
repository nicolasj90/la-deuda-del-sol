# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

## E09 — «El Archivo Bajo»: dungeon 1 del Acto 1, en los sótanos de la Notaría
## del Alba.
##
## Cerradura de Testigos, versión introductoria: UNA [EstatuaTestigo] (el Primer
## Rúbrica) y DOS estanterías rodantes ([BloqueEmpujable]) que tapan la línea de
## vista hasta el estrado ([ReceptorDeFe]). Hay que girar el interruptor de tinta
## hasta que la estatua mire al levante y correr los anaqueles para que el haz de
## fe pública cruce el sótano y caiga limpio sobre el estrado. Cuando llega, se
## abre la puerta del archivo profundo.
##
## Las indicaciones de Odila («Al levante primero... Después la letra... Al
## final, el estrado») son las de la escaleta: son la siembra de la Cerradura de
## Testigos del Acto 3 y son texto inamovible. No tocar.
##
## El cableado estrado→puerta está en la escena ([member PuertaSellada.fuentes]);
## este script sólo maneja los remates de ambiente y expone la API que usa el
## smoke headless de [code]scenes/dev/puzzles/smoke_dungeons.tscn[/code].

## Emitida cuando el haz llega por primera vez al estrado.
signal fe_publica_convergio

## Emitida cuando se abre la puerta del archivo profundo.
signal dungeon_resuelto

@onready var primer_rubrica: EstatuaTestigo = %PrimerRubrica
@onready var estanteria_primera: BloqueEmpujable = %EstanteriaPrimera
@onready var estanteria_segunda: BloqueEmpujable = %EstanteriaSegunda
@onready var estrado: ReceptorDeFe = %Estrado
@onready var puerta_final: PuertaSellada = %PuertaFinal
@onready var acta_mayor: CofreDeDungeon = %ActaMayor

@onready var _no_consta: Label = %NoConsta
@onready var _estado: Label = %Estado


func _ready() -> void:
	_no_consta.visible = false
	primer_rubrica.rotada.connect(_on_estatua_rotada)
	primer_rubrica.haz_llega_a.connect(_on_haz_llega_a)
	estrado.encendido.connect(_on_estrado_encendido)
	puerta_final.opened.connect(_on_puerta_abierta)
	acta_mayor.abierto.connect(_on_acta_abierta)
	_actualizar_estado()


## ¿El haz de la estatua está cayendo sobre el estrado?
func haz_en_el_estrado() -> bool:
	return primer_rubrica.objetivo_actual == estrado


func _on_estatua_rotada(_direccion: EstatuaTestigo.Direccion) -> void:
	_actualizar_estado()


func _on_haz_llega_a(objetivo: Node) -> void:
	if objetivo == estrado:
		fe_publica_convergio.emit()
	_actualizar_estado()


func _on_estrado_encendido() -> void:
	# «Cuando esa mirada dé limpia en el estrado, el archivo atiende.»
	_no_consta.visible = true
	_actualizar_estado()


func _on_puerta_abierta() -> void:
	dungeon_resuelto.emit()
	_actualizar_estado()


func _on_acta_abierta(recompensa: String) -> void:
	_estado.text = "Resguardo del Archivo Bajo: %s" % recompensa


func _actualizar_estado() -> void:
	if puerta_final.abierta:
		_estado.text = "El archivo atendió. La vía oficial tiene un final: acaba de conocerlo."
		return
	var mirada := ""
	match primer_rubrica.direccion:
		EstatuaTestigo.Direccion.ARRIBA:
			mirada = "al norte"
		EstatuaTestigo.Direccion.DERECHA:
			mirada = "al levante"
		EstatuaTestigo.Direccion.ABAJO:
			mirada = "al piso"
		EstatuaTestigo.Direccion.IZQUIERDA:
			mirada = "al poniente"
	_estado.text = (
		"El Primer Rúbrica mira %s. Los anaqueles tapan la mirada: %s"
		% [mirada, "no" if haz_en_el_estrado() else "sí"]
	)
