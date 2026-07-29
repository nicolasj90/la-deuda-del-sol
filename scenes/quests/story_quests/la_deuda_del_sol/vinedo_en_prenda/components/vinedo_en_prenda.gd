# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

## E13 — «El Viñedo en Prenda»: mini-dungeon 2 del Acto 1.
##
## Tutorial diegético del lenguaje de puzzles del juego: [b]cumplir alivia[/b].
## Dos [BloqueEnMora] cierran el sendero. Cada uno guarda una promesa incumplida
## de Vidal, viñatero difunto, y en el sello se lee la tarea:
## [br]— «regar la parra del cerco sur»: cargar agua en el [Aljibe] y volcarla en
## la [ParraSeca] (el balde pierde: hacen falta dos viajes).
## [br]— «devolver la tranquera al tercer poste»: empujar la tranquera caída
## hasta su marco ([PlacaPresion]).
## [br][br]
## Cumplida cada tarea, el bloque se alivia y recién entonces se puede empujar
## sobre su baldosa-sello. Con los dos sellos hundidos se abre la
## [PuertaSellada] del fondo. Y en el porche de la casa vacía, la lámpara de
## palabra prende — para nadie, y alumbra igual.
##
## El cableado tarea→bloque y sello→puerta está en la escena (exports
## [member BloqueEnMora.disparador] y [member PuertaSellada.fuentes]); este
## script sólo maneja los remates de ambiente y expone la API que usa el smoke
## headless de [code]scenes/dev/puzzles/smoke_dungeons.tscn[/code].

## Emitida cuando las dos tareas quedaron cumplidas (los dos bloques aliviados).
signal tareas_cumplidas

## Emitida cuando se abre la puerta del fondo.
signal dungeon_resuelto

@onready var aljibe: Aljibe = %Aljibe
@onready var parra: ParraSeca = %Parra
@onready var tranquera: BloqueEmpujable = %Tranquera
@onready var marco_tranquera: PlacaPresion = %MarcoTranquera
@onready var bloque_parra: BloqueEnMora = %BloqueParra
@onready var bloque_tranquera: BloqueEnMora = %BloqueTranquera
@onready var sello_parra: PlacaPresion = %SelloParra
@onready var sello_tranquera: PlacaPresion = %SelloTranquera
@onready var puerta_final: PuertaSellada = %PuertaFinal
@onready var cofre: CofreDeDungeon = %Cofre

@onready var _luz_lampara: CanvasItem = %LuzLampara
@onready var _estado: Label = %Estado


func _ready() -> void:
	_luz_lampara.visible = false
	bloque_parra.aliviado.connect(_on_bloque_aliviado)
	bloque_tranquera.aliviado.connect(_on_bloque_aliviado)
	puerta_final.progreso_cambiado.connect(_on_progreso_cambiado)
	puerta_final.opened.connect(_on_puerta_abierta)
	cofre.abierto.connect(_on_cofre_abierto)
	_actualizar_estado(0, puerta_final.requiere_n)


## Bloques que ya dejaron de estar en mora.
func bloques_aliviados() -> int:
	var cuenta := 0
	if not bloque_parra.en_mora:
		cuenta += 1
	if not bloque_tranquera.en_mora:
		cuenta += 1
	return cuenta


## ¿La lámpara de palabra del porche está encendida?
func lampara_encendida() -> bool:
	return _luz_lampara.visible


func _on_bloque_aliviado() -> void:
	if bloques_aliviados() < 2:
		return
	# «Alguien prometió y no llegó. Nosotros llegamos tarde. Y alcanzó igual.»
	_luz_lampara.visible = true
	tareas_cumplidas.emit()


func _on_progreso_cambiado(activas: int, requeridas: int) -> void:
	_actualizar_estado(activas, requeridas)


func _on_puerta_abierta() -> void:
	dungeon_resuelto.emit()


func _on_cofre_abierto(recompensa: String) -> void:
	_estado.text = "Cofre del galpón de Vidal: %s" % recompensa


func _actualizar_estado(activas: int, requeridas: int) -> void:
	if puerta_final.abierta:
		_estado.text = "El sendero está libre. La prenda del viñedo quedó saldada."
		return
	_estado.text = (
		"Bloques en mora aliviados: %d de 2 — baldosas-sello cubiertas: %d de %d"
		% [bloques_aliviados(), activas, requeridas]
	)
