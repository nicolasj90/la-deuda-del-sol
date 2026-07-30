# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name BanderasDeuda
extends RefCounted
## Banderas de guion y party viva de «La Deuda del Sol» (Acto 1).
##
## [b]Banderas[/b]: viven en [member GlobalState.facts], el mismo diccionario que ya
## se serializa en [code]user://saved_game.tres[/code] (igual que hace
## [code]Coleccion[/code] con las cartas). Una bandera por escena del guion:
## marcarla es «esta escena ya pasó», y las escenas siguientes la piden como
## requisito. Todo es estático: no hace falta un autoload nuevo.
##
## [b]Party viva[/b]: el Acto 1 empieza con Ciro solo (E05: «Ciro solo contra dos
## alguaciles») y Ferra se suma en caliente en la fase 2 del boss 1 (E06). Eso se
## hace sobre [constant RUTA_PARTY_ACTO1], que es el Resource que va a
## [code]GameManager.party[/code]: los [BattleSettings] de las escenas dejan su
## campo [code]party[/code] vacío, así el bridge de encuentros les inyecta la party
## viva del momento (ver [code]Encounters.start_encounter[/code]).
##
## Uso desde código o desde un [code].dialogue[/code]:
## [codeblock]
## do BanderasDeuda.marcar(BanderasDeuda.E06_BOSS_DECANO)
## if BanderasDeuda.tiene(BanderasDeuda.E05_TASADORES):
##     Ferra: Contrato roto...
## [/codeblock]

## Ceremonia de la Mayoría de Palabra (E04). La pone la escena de la ceremonia;
## E05 la pide como requisito.
const E04_MAYORIA: String = "deuda_e04_mayoria"
## Notificación de embargo y tutorial de combate (E05).
const E05_TASADORES: String = "deuda_e05_tasadores"
## Boss 1, las dos fases, en el patio de la notaría (E06).
const E06_BOSS_DECANO: String = "deuda_e06_boss_decano"
## Primer campamento, farol humano y segunda campanada (E07).
const E07_CAMPAMENTO: String = "deuda_e07_campamento"
## Ferra ya es de la casa: está en la party viva.
const FERRA_EN_PARTY: String = "deuda_ferra_en_party"

## Todas las banderas del bloque, en orden de guion (las usa el test de secuencia).
const BANDERAS_DEL_BLOQUE: Array[String] = [
	E04_MAYORIA,
	E05_TASADORES,
	E06_BOSS_DECANO,
	E07_CAMPAMENTO,
	FERRA_EN_PARTY,
]

## Contador de campanadas de la prenda, compartido por todas las escenas del acto.
## Es la misma clave que usa [code]MapaLacrevieja[/code] (que dispara la primera en
## E04): la curva del § 5b del INDICE —E04 → E07 → E15 → E19 → E27— tiene que poder
## leerse de un solo lugar, porque el resumen del acto (E28) la reporta.
const CAMPANADAS: String = "ldds_campanadas"

const RUTA_PARTY_ACTO1: String = "res://resources/combate/party_acto1.tres"
const RUTA_CIRO: String = "res://resources/combate/personajes/ciro.tres"
const RUTA_FERRA: String = "res://resources/combate/personajes/ferra.tres"

## Firma-carta garantizada del boss 1 (canal 2 de la colección). El drop lo
## resuelve [code]DropsDeCartas[/code] con
## [code]resources/combate/drops/jefe_tasador_decano.tres[/code]; esta constante es
## para que las escenas y los tests puedan verificarlo.
const FIRMA_CARTA_DECANO: String = "tasador_decano"

# ---------------------------------------------------------------------------
# Banderas
# ---------------------------------------------------------------------------


## Marca una bandera y guarda la partida (si corresponde).
static func marcar(bandera: String) -> void:
	var estado: Node = _game_state()
	if estado == null or estado.global == null:
		push_warning("[BanderasDeuda] sin estado de juego: «%s» no se pudo marcar." % bandera)
		return
	estado.global.facts[bandera] = true
	estado.save()


## ¿Está marcada?
static func tiene(bandera: String) -> bool:
	return bool(facts().get(bandera, false))


## Borra banderas (partida nueva, o tests que corren la secuencia de cero).
static func borrar(banderas: Array[String] = BANDERAS_DEL_BLOQUE) -> void:
	var estado: Node = _game_state()
	if estado == null or estado.global == null:
		return
	for bandera: String in banderas:
		estado.global.facts.erase(bandera)
	estado.save()


## Cuántas campanadas de la prenda sonaron en la partida.
static func campanadas() -> int:
	return int(facts().get(CAMPANADAS, 0))


## Registra una campanada más y devuelve cuál es (1 = la de E04, 2 = la de E07...).
## El SFX y el shake los pone cada escena: acá vive solo la cuenta de la curva.
static func sonar_campanada() -> int:
	var numero: int = campanadas() + 1
	var estado: Node = _game_state()
	if estado == null or estado.global == null:
		push_warning("[BanderasDeuda] sin estado de juego: la campanada %d no se contó." % numero)
		return numero
	estado.global.facts[CAMPANADAS] = numero
	estado.save()
	return numero


## El diccionario de hechos globales del save, o uno vacío si todavía no hay estado
## de juego (jugar una escena sola desde el editor).
static func facts() -> Dictionary:
	var estado: Node = _game_state()
	if estado == null or estado.global == null:
		return {}
	return estado.global.facts


# ---------------------------------------------------------------------------
# Party viva
# ---------------------------------------------------------------------------


## Deja la party del Acto 1 como party viva ([code]GameManager.party[/code]) y la
## pone en el estado que corresponde a las banderas: Ciro solo, y Ferra solamente
## si ya se sumó. Devuelve la party.
static func arrancar_party_del_acto() -> Party:
	var party: Party = load(RUTA_PARTY_ACTO1) as Party
	if party == null:
		push_error("[BanderasDeuda] no se pudo cargar %s" % RUTA_PARTY_ACTO1)
		return null
	var manager: Node = _game_manager()
	if manager != null:
		manager.party = party
	if tiene(FERRA_EN_PARTY):
		sumar_ferra()
	else:
		quitar_ferra()
	return party


## La party viva del momento.
static func party() -> Party:
	var manager: Node = _game_manager()
	if manager == null:
		return null
	return manager.party as Party


## Si el acto ya arrancó (E05) pero la party viva no es la del acto (pasa al
## cargar partida: Encounters._ready() monta party_deuda en cada arranque),
## la reconstruye desde las banderas. Punto único de restauración post-load.
static func restaurar_party_si_corresponde() -> Party:
	if not tiene(E05_TASADORES):
		return party()
	var actual: Party = party()
	if actual != null and actual.resource_path == RUTA_PARTY_ACTO1:
		return actual
	return arrancar_party_del_acto()


## Suma a Ferra a la party viva (fase 2 del boss 1; queda confirmado en E07).
## Es idempotente y la deja con los PV llenos: entra de refresco, no herida.
static func sumar_ferra() -> bool:
	var actual: Party = party()
	if actual == null:
		return false
	# Guarda anti-footgun: nunca mutar un Resource de party ajeno al acto
	# (mutar party_deuda borra/duplica a Ferra en el canon de los cinco para
	# todo el proceso). Si el acto arrancó, normalizamos y seguimos.
	if actual.resource_path != RUTA_PARTY_ACTO1:
		if not tiene(E05_TASADORES):
			return false
		actual = arrancar_party_del_acto()
		if actual == null:
			return false
		if tiene_ferra():
			# arrancar ya la sumó por la bandera guardada: nada que hacer.
			return false
	var ferra: BattlerPlayer = load(RUTA_FERRA) as BattlerPlayer
	if ferra == null:
		push_error("[BanderasDeuda] no se pudo cargar %s" % RUTA_FERRA)
		return false
	ferra.current_hp = ferra.stats.hp.get_value()
	ferra.current_mp = ferra.stats.mp.get_value()
	ferra.status.clear()
	ferra.trait_aggregator.refresh()
	if actual.players.has(ferra):
		return false
	actual.players.append(ferra)
	marcar(FERRA_EN_PARTY)
	return true


## Saca a Ferra de la party viva (antes de E06 todavía es de la Cámara; también lo
## usan los tests para correr la secuencia de cero).
static func quitar_ferra() -> bool:
	var actual: Party = party()
	if actual == null:
		return false
	# Misma guarda anti-footgun que sumar_ferra(): no mutar party_deuda.
	if actual.resource_path != RUTA_PARTY_ACTO1:
		return false
	var ferra: BattlerPlayer = load(RUTA_FERRA) as BattlerPlayer
	if ferra == null or not actual.players.has(ferra):
		return false
	actual.players.erase(ferra)
	return true


static func tiene_ferra() -> bool:
	var actual: Party = party()
	if actual == null:
		return false
	for jugador: BattlerPlayer in actual.players:
		if jugador != null and jugador.name == "Ferra":
			return true
	return false


## Nombres de la party viva, para logs y tests.
static func nombres_de_party() -> Array[String]:
	var nombres: Array[String] = []
	var actual: Party = party()
	if actual == null:
		return nombres
	for jugador: BattlerPlayer in actual.players:
		if jugador != null:
			nombres.append(String(jugador.name))
	return nombres


## Cura a toda la party viva (PV, PM y estados).
##
## [b]Decisión de producción[/b]: E05 y E06 son dos combates seguidos, de noche y sin
## posada en el medio (el campamento —y la curación diegética— llega recién en E07).
## Se cura en el tramo de fuga entre la casa y la notaría, que en el guion es una
## corrida por todo el pueblo, para que las dos peleas se puedan balancear desde
## PV llenos. La fase 2 del boss NO cura: Ciro entra golpeado y Ferra entera, que
## es justamente el punto de la escena.
static func curar_party() -> void:
	var actual: Party = party()
	if actual == null:
		return
	for jugador: BattlerPlayer in actual.players:
		if jugador == null:
			continue
		jugador.status.clear()
		jugador.trait_aggregator.refresh()
		jugador.current_hp = jugador.stats.hp.get_value()
		jugador.current_mp = jugador.stats.mp.get_value()


# ---------------------------------------------------------------------------
# Internos
# ---------------------------------------------------------------------------


static func _raiz() -> Node:
	var bucle: MainLoop = Engine.get_main_loop()
	if bucle is SceneTree:
		return (bucle as SceneTree).root
	return null


static func _game_state() -> Node:
	var raiz: Node = _raiz()
	return raiz.get_node_or_null(^"/root/GameState") if raiz != null else null


static func _game_manager() -> Node:
	var raiz: Node = _raiz()
	return raiz.get_node_or_null(^"/root/GameManager") if raiz != null else null
