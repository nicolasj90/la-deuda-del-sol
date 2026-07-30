# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends Node

## Atajo de verificación del camino **diegético** de E03.
##
## Da por hechos E01 (prólogo visto) y E02 (las tres promesitas cumplidas, las tres
## lámparas prendidas) y monta el mapa de Lacrevieja de verdad. Desde ahí se camina
## hasta Rosaura y se le habla: el duelo **sale del diálogo**, de
## [code]do Lacrevieja.duelo_con_rosaura()[/code] en
## [code]rosaura.dialogue[/code]. Lo único que se saltea es cumplir las promesitas.
##
## El mapa se instancia como hijo (no por [code]SceneSwitcher[/code]) para que esta
## escena siga viva con su [SondaDeMesa]: el launcher pausa la escena actual
## mientras la mesa está montada, y la sonda corre en
## [constant Node.PROCESS_MODE_ALWAYS]. Instanciarlo como hijo es además lo que
## hace el smoke de la zona, así que es un camino probado (y de paso el prólogo no
## se dispara solo, que pide ser la escena actual).
##
## En web: [code]index.html#res://scenes/dev/e03_dev.tscn[/code].

const MAPA: String = "res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja.tscn"


func _ready() -> void:
	await get_tree().process_frame
	if GameState == null or GameState.global == null:
		push_error("[E03_DEV] no hay GameState: no se pueden poner las banderas.")
		return
	var hechos: Dictionary = GameState.global.facts
	hechos[MapaLacrevieja.HECHO_PROLOGO] = true
	for cual: String in MapaLacrevieja.PROMESAS:
		hechos[MapaLacrevieja.HECHO_PROMESA % cual] = true
		hechos[MapaLacrevieja.HECHO_CUMPLIDA % cual] = true
	var escena: PackedScene = load(MAPA) as PackedScene
	var mapa: MapaLacrevieja = escena.instantiate() as MapaLacrevieja
	add_child(mapa)
	await get_tree().process_frame
	_plantar_al_jugador_frente_a(mapa, "Rosaura")
	print(
		(
			"== E03_DEV: mapa montado; lámparas=%d plaza_lista=%s =="
			% [mapa.lamparas_encendidas(), mapa.plaza_lista()]
		)
	)


## Deja a Ciro al lado del vecino, mirando para el norte. El camino desde la casa
## de los Albar hasta la plaza es largo y con paredes: caminarlo no es lo que se
## está verificando acá (el gesto que importa es apretar «interactuar» y que el
## duelo salga del diálogo).
func _plantar_al_jugador_frente_a(mapa: Node, vecino: String) -> void:
	var npc: Node2D = mapa.get_node_or_null(NodePath("%%%s" % vecino)) as Node2D
	var jugador: Node2D = mapa.get_node_or_null(^"OnTheGround/Player") as Node2D
	if npc == null or jugador == null:
		push_error("[E03_DEV] no encontré a %s o al jugador en el mapa." % vecino)
		return
	jugador.global_position = npc.global_position + Vector2(0, 40)
	print("== E03_DEV: Ciro al lado de %s, en %s ==" % [vecino, jugador.global_position])
