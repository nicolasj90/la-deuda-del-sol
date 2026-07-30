# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
extends Node2D

## Smoke headless de la zona tutorial: E01 → E04 en Lacrevieja.
##
## Monta [code]lacrevieja.tscn[/code] de verdad y recorre la secuencia entera por
## el camino del jugador: los diálogos de los NPC (los mismos [code].dialogue[/code]
## y los mismos títulos que abre el botón de interacción), las tres tareas de las
## promesitas con sus [InteractArea], el duelo tutorial de «De Palabra» resuelto
## por IA y la ceremonia con la primera campanada. Verifica además que el texto
## que sale sea el del guion, palabra por palabra.
##
## Correr:
## [codeblock]
## scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/tests/smoke_lacrevieja.sh
## # o bien
## ~/tools/godot/Godot_v4.7-stable_linux.x86_64 --headless --path . \
##     res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/tests/smoke_lacrevieja.tscn
## [/codeblock]

const LACREVIEJA := preload("res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja.tscn")

## Semilla con la que el lado de Ciro gana el duelo tutorial jugado por IA (E03 es
## el duelo que el guion da por ganado). Verificada a mano con la sonda de
## semillas: gana por aval en 17 turnos.
const SEMILLA_E03: int = 1001

var _total: int = 0
var _fallos: int = 0
var _mapa: MapaLacrevieja


func _ready() -> void:
	print("== SMOKE Lacrevieja: E01 → E04 ==")
	_armar_perro_guardian()
	await _montar()
	await _p0_poblacion()
	await _p1_prologo()
	await _p2_promesitas()
	await _p3_duelos()
	await _p4_ceremonia()
	await _p5_volver_a_la_zona()
	await _p6_tarea_antes_de_prometer()

	print("== RESUMEN: %d chequeos, %d fallos ==" % [_total, _fallos])
	print("SMOKE OK" if _fallos == 0 else "SMOKE FALLÓ")
	get_tree().quit(1 if _fallos > 0 else 0)


# --- Infraestructura -------------------------------------------------------


func _armar_perro_guardian(segundos: float = 240.0) -> void:
	var reloj := get_tree().create_timer(segundos, true, false, true)
	reloj.timeout.connect(
		func() -> void:
			print("FAIL - el smoke se colgó tras %.0f s" % segundos)
			print("SMOKE FALLÓ")
			get_tree().quit(1)
	)


func _check(nombre: String, ok: bool, detalle: String = "") -> void:
	_total += 1
	if ok:
		print("PASS - %s" % nombre)
		return
	_fallos += 1
	print("FAIL - %s%s" % [nombre, "" if detalle.is_empty() else " (%s)" % detalle])


func _fisica(cuadros: int = 1) -> void:
	for _i in cuadros:
		await get_tree().physics_frame


## Espera a que no quede ningún diálogo de la zona corriendo. Los primeros cuadros
## son a propósito: el remate de una promesita que se cumple sola espera a que
## cierre el diálogo en curso, así que arranca uno o dos cuadros más tarde.
func _esperar_dialogo() -> void:
	for _i in 4:
		await get_tree().process_frame
	var limite: int = 3600
	while _mapa.en_dialogo() and limite > 0:
		limite -= 1
		await get_tree().process_frame


## ¿Alguna de las líneas que salieron contiene este texto?
func _dice(lineas: Array, texto: String) -> bool:
	for linea: String in lineas:
		if linea.contains(texto):
			return true
	return false


func _texto(lineas: Array) -> String:
	return " / ".join(lineas)


func _montar() -> void:
	_mapa = LACREVIEJA.instantiate() as MapaLacrevieja
	_mapa.autoarrancar_prologo = false
	_mapa.dialogo_sin_globo = true
	_mapa.duelos_automaticos = true
	_mapa.semilla_duelos = SEMILLA_E03
	add_child(_mapa)
	await _fisica(6)
	# La puerta a E05 (bloque del Vencimiento) queda afuera de este smoke: acá se
	# verifica E01–E04 y nada más.
	var puerta_e05: Node = _mapa.get_node_or_null(^"OnTheGround/TriggerDeVencimiento")
	if puerta_e05 != null:
		puerta_e05.queue_free()
	await _fisica(2)
	Coleccion.vaciar()
	_mapa.reiniciar_hechos()


# --- P0: la plaza está poblada --------------------------------------------


func _p0_poblacion() -> void:
	print("-- P0 población: NPCs, lámparas, tareas")
	for nombre: String in [
		"Rosaura",
		"Maestra",
		"Cosme",
		"Fedatario",
		"VecinaDeLaEsquina",
		"VecinoDeLasMesas",
		"VecinoDeLasGallinas",
	]:
		var npc: Node = _mapa.get_node_or_null(NodePath("%%%s" % nombre))
		_check("P0 %s está en la plaza" % nombre, npc != null)
		if npc == null:
			continue
		var charla: Node = npc.get_node_or_null(^"TalkBehavior")
		_check("P0 %s tiene TalkBehavior con diálogo" % nombre, charla != null and charla.dialogue != null)
		_check(
			"P0 %s puede llamar a Lacrevieja desde su diálogo" % nombre,
			charla != null and _mapa in charla.extra_context
		)
		_check("P0 %s tiene nombre de vecino" % nombre, npc.npc_name != "")

	_check("P0 hay tres lámparas de palabra", _mapa.lamparas.size() == 3)
	_check("P0 las tres amanecieron frías", _mapa.lamparas_encendidas() == 0)
	_check("P0 la plaza todavía no está lista", not _mapa.plaza_lista())
	_check("P0 la leña está en el galpón", _mapa.horno_grande.entregados == 0)
	_check("P0 el horno pide tres atados", _mapa.horno_grande.cupo == 3)
	_check("P0 hay seis macetas en el cantero norte", _macetas().size() == 6)
	var rotas: int = 0
	for maceta: MacetaDelCantero in _macetas():
		if maceta.rota:
			rotas += 1
	_check("P0 una de las seis está rota y vacía", rotas == 1, "rotas=%d" % rotas)
	_check("P0 hay dos piedras nuevas", _lapidas().size() == 2)
	var con_errata: int = 0
	for lapida: LapidaGrabada in _lapidas():
		if lapida.tiene_errata():
			con_errata += 1
	_check("P0 una de las dos le debe una letra a la finada", con_errata == 1)
	_check(
		"P0 la errata es la hache de Herminia",
		_lapidas()[1].inscripcion.contains("Erminia del Soto") and _lapidas()[1].errata == "H"
	)
	_check("P0 la campana de la prenda tiene sonido cargado", _mapa.campana.stream != null)


# --- P1: E01 «El peso de siempre» -----------------------------------------


func _p1_prologo() -> void:
	print("-- P1 E01: sueño-prólogo y despertar")
	await _mapa.correr_dialogo(_mapa.dialogo_prologo, "sueno")
	var sueno: Array = _mapa.ultimas_lineas.duplicate()
	_check("P1 el sueño da líneas", sueno.size() >= 10, "n=%d" % sueno.size())
	_check("P1 la madre dice el orden", _dice(sueno, "Primero el peso. Después el porqué."))
	_check("P1 «Pesa.» del chico de seis", _dice(sueno, "Pesa."))
	_check("P1 «vos derechito»", _dice(sueno, "Pase lo que pase, vos derechito."))
	_check(
		"P1 los términos quedan fuera de foco (siembra E27)",
		_dice(sueno, "fuera de foco")
	)

	await _mapa.correr_dialogo(_mapa.dialogo_prologo, "despertar")
	var despertar: Array = _mapa.ultimas_lineas.duplicate()
	_check("P1 la libreta se lee al despertar", _dice(despertar, "Barrer la vereda."))
	_check("P1 «En mora: una campana.»", _dice(despertar, "una campana."))
	_check(
		"P1 el alba no lo alivia (siembra enterrada)",
		_dice(despertar, "igual de cargado que se acostó")
	)
	_check("P1 «Lo mío por lo menos viene con manija.»", _dice(despertar, "viene con manija"))

	# Y ahora la secuencia completa, como al entrar por primera vez.
	_mapa.reiniciar_hechos()
	_check("P1 el prólogo arranca sin ver", not _mapa.prologo_visto())
	await _mapa.correr_prologo()
	_check("P1 el prólogo quedó visto", _mapa.prologo_visto())
	var apertura: Array = _mapa.ultimas_lineas.duplicate()
	_check("P1 la apertura es la de Rosaura", _dice(apertura, "¡Ahí está! El hombre del día."))
	_check(
		"P1 la Ley del Empeño queda explicada",
		_dice(apertura, "tres vecinos, tres promesitas, tres lámparas")
	)
	_check(
		"P1 el gag de literalidad de Ciro",
		_dice(apertura, "cumplir después en orden de vencimiento")
	)
	_check("P1 el velo del fundido volvió a transparente", _negro().color.a == 0.0)
	# Idempotencia: volver a entrar no repite la cinemática.
	_mapa.ultimas_lineas.clear()
	await _mapa.correr_prologo()
	_check("P1 el prólogo no se repite", _mapa.ultimas_lineas.is_empty())


# --- P2: E02 «Tres promesitas» --------------------------------------------


func _p2_promesitas() -> void:
	print("-- P2 E02: tres promesitas, tres lámparas")

	# Promesita 1 — Rosaura: la leña del horno grande.
	var lineas: Array = await _mapa.hablar_con("Rosaura")
	_check("P2 Rosaura pide la leña", _dice(lineas, "la leña del horno grande sigue en el galpón"))
	_check("P2 Ciro promete entrar la leña", _dice(lineas, "Prometo entrar la leña antes del mediodía."))
	_check("P2 nació la promesita de Rosaura", _mapa.promesa_hecha_ya("rosaura"))
	_check("P2 todavía no está cumplida", not _mapa.promesa_cumplida_ya("rosaura"))

	# Primer atado por el camino real: el botón de interacción.
	_mapa.pila_de_lena.interact_area.start_interaction(null, false)
	await _fisica(3)
	_check("P2 el jugador carga un atado por interacción", _mapa.pila_de_lena.cargando)
	_check("P2 con el atado en brazos no se puede cargar otro", not _mapa.pila_de_lena.tomar())
	_mapa.horno_grande.interact_area.start_interaction(null, false)
	await _fisica(3)
	_check("P2 el primer atado entró al horno", _mapa.horno_grande.entregados == 1)
	_check("P2 y las manos quedaron libres", not _mapa.pila_de_lena.cargando)
	_check("P2 en el horno no se deja lo que no se trae", not _mapa.horno_grande.dejar())
	_check("P2 con un atado la lámpara sigue fría", _mapa.lamparas_encendidas() == 0)

	# Los otros dos viajes.
	for _i in 2:
		_check("P2 viaje de leña: cargar", _mapa.pila_de_lena.tomar())
		_check("P2 viaje de leña: descargar", _mapa.horno_grande.dejar())
	await _esperar_dialogo()
	_check("P2 los tres atados están adentro", _mapa.horno_grande.entregados == 3)
	_check("P2 la promesita de Rosaura se cumplió", _mapa.promesa_cumplida_ya("rosaura"))
	_check("P2 se encendió la primera lámpara", _mapa.lamparas_encendidas() == 1)
	var cumplida_rosaura: Array = _mapa.ultimas_lineas.duplicate()
	_check(
		"P2 «una palabra volviendo a casa»",
		_dice(cumplida_rosaura, "una palabra volviendo a casa"),
		_texto(cumplida_rosaura)
	)
	_check(
		"P2 la acotación dice qué lámpara prendió",
		_dice(cumplida_rosaura, "la primera lámpara se enciende sola")
	)
	_check("P2 la pila del galpón quedó vacía", not _mapa.pila_de_lena.tomar())

	# Promesita 2 — la Maestra: las macetas del cantero norte.
	lineas = await _mapa.hablar_con("Maestra")
	_check("P2 la Maestra pide el cantero", _dice(lineas, "Las macetas del cantero norte, Ciro."))
	_check("P2 Ciro dice «todas»", _dice(lineas, "Prometo regar todas las macetas del cantero norte."))
	_check("P2 y no se desdice", _dice(lineas, "Dije \"todas\". Ya está sellado."))
	_check("P2 nació la promesita de la Maestra", _mapa.promesa_hecha_ya("maestra"))

	var macetas: Array[MacetaDelCantero] = _macetas()
	macetas[0].interact_area.start_interaction(null, false)
	await _fisica(3)
	_check("P2 la maceta se riega por interacción", macetas[0].regada)
	_check("P2 regar dos veces no cuenta", not macetas[0].regar())
	for i: int in range(1, 5):
		_check("P2 maceta %d regada" % (i + 1), macetas[i].regar())
	_check("P2 con cinco de seis la promesita sigue viva", not _mapa.promesa_cumplida_ya("maestra"))
	_check("P2 la sexta está rota y se riega igual", macetas[5].rota and macetas[5].regar())
	await _esperar_dialogo()
	_check("P2 la promesita de la Maestra se cumplió", _mapa.promesa_cumplida_ya("maestra"))
	_check("P2 se encendió la segunda lámpara", _mapa.lamparas_encendidas() == 2)
	var cumplida_maestra: Array = _mapa.ultimas_lineas.duplicate()
	_check(
		"P2 «Estaba en los términos»",
		_dice(cumplida_maestra, "Está en el cantero norte. Estaba en los términos."),
		_texto(cumplida_maestra)
	)
	_check(
		"P2 «Adónde va el agua no es problema de los términos»",
		_dice(cumplida_maestra, "Adónde va el agua no es problema de los términos.")
	)
	_check("P2 la acotación dice «Segunda lámpara»", _dice(cumplida_maestra, "Segunda lámpara encendida."))

	# Promesita 3 — Cosme: leer las dos piedras y dar fe de erratas.
	lineas = await _mapa.hablar_con("Cosme")
	_check("P2 Cosme tiene dos piedras y la vista vieja", _dice(lineas, "Tengo dos piedras nuevas y la vista vieja."))
	_check("P2 Ciro promete fe de erratas", _dice(lineas, "Prometo leer los nombres nuevos y darte fe de erratas."))
	_check("P2 «Lo bueno pasa al final, pibe.»", _dice(lineas, "Lo bueno pasa al final, pibe."))
	_check("P2 nació la promesita de Cosme", _mapa.promesa_hecha_ya("cosme"))

	var lapidas: Array[LapidaGrabada] = _lapidas()
	lapidas[0].interact_area.start_interaction(null, false)
	await _fisica(3)
	_check("P2 la primera piedra se lee por interacción", lapidas[0].leida)
	_check("P2 con una sola piedra la promesita sigue viva", not _mapa.promesa_cumplida_ya("cosme"))
	_check("P2 la segunda piedra se lee", lapidas[1].leer())
	await _esperar_dialogo()
	_check("P2 la promesita de Cosme se cumplió", _mapa.promesa_cumplida_ya("cosme"))
	_check("P2 Cosme talló la hache", lapidas[1].enmendada)
	_check("P2 la piedra en regla no se enmienda", not lapidas[0].enmendada)
	_check("P2 se encendió la tercera lámpara", _mapa.lamparas_encendidas() == 3)
	var cumplida_cosme: Array = _mapa.ultimas_lineas.duplicate()
	_check(
		"P2 «Herminia va con hache»",
		_dice(cumplida_cosme, "Herminia va con hache."),
		_texto(cumplida_cosme)
	)
	_check(
		"P2 «Es de las que no suenan. Se deben más fácil.»",
		_dice(cumplida_cosme, "Se deben más fácil.")
	)
	_check("P2 la acotación dice «tercera lámpara»", _dice(cumplida_cosme, "la tercera lámpara se enciende sola"))

	_check("P2 LA PLAZA QUEDÓ ENCENDIDA", _mapa.plaza_lista())
	_check("P2 todavía no se puede refrendar la Mayoría", not _mapa.listo_para_ceremonia())

	# El fedatario todavía no refrenda: falta el mediodía en el horno (E03).
	lineas = await _mapa.hablar_con("Fedatario")
	_check("P2 el fedatario hace esperar hasta el atardecer", _dice(lineas, "Todavía no, Ciro."), _texto(lineas))
	_check("P2 y no sonó ninguna campanada antes de la ceremonia", _mapa.campanadas() == 0)

	# Y los vecinos de color contestan según el estado de la plaza.
	lineas = await _mapa.hablar_con("VecinoDeLasMesas")
	_check("P2 el vecino de las mesas ve las lámparas prendidas", _dice(lineas, "a pleno sol"), _texto(lineas))
	lineas = await _mapa.hablar_con("VecinoDeLasGallinas")
	_check("P2 el vecino de las gallinas habla de gallinas", _dice(lineas, "gallinas"), _texto(lineas))


# --- P3: E03 duelos de «De Palabra» ---------------------------------------


func _p3_duelos() -> void:
	print("-- P3 E03: duelo tutorial de Rosaura y duelo opcional de Cosme")
	_check("P3 la colección arranca vacía (antes de E03)", Coleccion.total() == 0)
	_check("P3 y sin mazo propio", not Coleccion.tiene_mazo())
	var mazo_casa: Array[String] = _mapa.mazo_de_la_casa()
	_check("P3 el mazo prestado de la casa es reglamentario", mazo_casa.size() == 30)
	_check(
		"P3 y trae la Lámpara que Ciro anuncia (es de Rosaura, no suya)",
		mazo_casa.has("lampara_de_palabra")
	)
	_check(
		"P3 la mano cantada es la del guion (dos Gallinas, Peón, Lámpara)",
		(
			_mapa.MANO_DE_CIRO_E03.count("gallina_lacrevieja") == 2
			and _mapa.MANO_DE_CIRO_E03.has("peon_de_vina")
			and _mapa.MANO_DE_CIRO_E03.has("lampara_de_palabra")
			and _mapa.MANO_DE_CIRO_E03.size() == 4
		),
		str(_mapa.MANO_DE_CIRO_E03)
	)

	var lineas: Array = await _mapa.hablar_con("Rosaura")
	await _esperar_dialogo()
	_check("P3 el cierre de E02 lo dice Rosaura", _dice(lineas, "sabe quién cumple"), _texto(lineas))
	_check("P3 «Un juego. Del que no pesa.»", _dice(lineas, "Un juego. Del que no pesa."))
	_check("P3 el lacre muerto queda explicado", _dice(lineas, "Lacre muerto, exacto."))
	_check("P3 Ciro canta la mano en voz alta", _dice(lineas, "Tengo dos Gallinas, un Peón de Viña y la Lámpara de Palabra."))
	_check("P3 «un tramposo finísimo»", _dice(lineas, "un tramposo finísimo."))
	_check("P3 el duelo se jugó de verdad", DueloLauncher.turnos > 0, "turnos=%d" % DueloLauncher.turnos)
	_check("P3 y cerró con una Firma ganadora", DueloLauncher.ganador in [0, 1])
	_check("P3 con motivo de cierre", not DueloLauncher.motivo.is_empty(), DueloLauncher.motivo)
	_check("P3 la mesa se desmontó", not DueloLauncher.en_curso)
	_check("P3 CIRO LE GANÓ A ROSAURA", _mapa.duelo_rosaura_ganado())
	_check("P3 «¡CUMPLIÓ!»", _dice(lineas, "¡CUMPLIÓ!"))
	_check("P3 «Estoy orgullosa, que es peor.»", _dice(lineas, "Estoy orgullosa, que es peor."))
	_check("P3 Rosaura regala el mazo propio", Coleccion.mazo_inicial_entregado())
	_check("P3 y el mazo activo quedó fijado", Coleccion.tiene_mazo())
	_check(
		"P3 el mazo inicial trae el Porteador del Empeñadero (trazabilidad E17)",
		Coleccion.tiene("porteador_empenadero")
	)
	_check("P3 la Gallina va de regalo", Coleccion.cuantas("gallina_lacrevieja") >= 3)
	_check(
		"P3 la Lámpara NO entra a la colección (llega en el cofre de E09)",
		not Coleccion.tiene("lampara_de_palabra")
	)
	_check("P3 ahora sí se puede refrendar la Mayoría", _mapa.listo_para_ceremonia())

	# Duelo opcional de Cosme.
	_mapa.semilla_duelos = 0
	lineas = await _mapa.hablar_con("Cosme")
	await _esperar_dialogo()
	_check("P3 Cosme enseña lo contrario", _dice(lineas, "Letra chica, le dicen."), _texto(lineas))
	_check("P3 el duelo opcional se jugó", _mapa.duelo_cosme_jugado())
	_check("P3 «Lindo funeral de partida.»", _dice(lineas, "Lindo funeral de partida."))
	for id: String in ["sepulturero_cosme", "deudo_del_difunto", "testamento_apurado"]:
		_check("P3 Cosme regala «%s»" % id, Coleccion.tiene(id))
	_check("P3 una copia de cada carta de difunto", Coleccion.cuantas("sepulturero_cosme") == 1)
	# Volver a hablarle no vuelve a sentarlo a la mesa ni a repartir el premio.
	lineas = await _mapa.hablar_con("Cosme")
	await _esperar_dialogo()
	_check("P3 el duelo opcional no se repite", Coleccion.cuantas("sepulturero_cosme") == 1)
	_check(
		"P3 y Cosme queda con su línea repetible",
		_dice(lineas, "Aprovechala liviana mientras dure."),
		_texto(lineas)
	)


# --- P4: E04 «Mayoría de palabra» -----------------------------------------


func _p4_ceremonia() -> void:
	print("-- P4 E04: la ceremonia y la PRIMERA CAMPANADA")
	_check("P4 la ceremonia no pasó todavía", not _mapa.ceremonia_hecha())
	_check("P4 no sonó ninguna campanada", _mapa.campanadas() == 0)

	var lineas: Array = await _mapa.hablar_con("Fedatario")
	await _esperar_dialogo()
	_check("P4 el fedatario refrenda la Mayoría", _dice(lineas, "alcanza la Mayoría de Palabra."), _texto(lineas))
	_check(
		"P4 la fórmula del juramento va textual",
		_dice(lineas, "Doy mi palabra de dar mi palabra a sabiendas")
	)
	_check("P4 Ciro corrige la gramática del pueblo", _dice(lineas, "Son dos sujetos. El cielo y el vecindario."))
	_check("P4 «Vale la enmienda.»", _dice(lineas, "Vale la enmienda."))
	_check("P4 SONÓ LA PRIMERA CAMPANADA", _mapa.campanadas() == 1)
	_check(
		"P4 el fedatario disimula («el bronce del estrado»)",
		_dice(lineas, "El bronce del estrado. Resuena cuando refrenda.")
	)
	_check("P4 y Ciro lo desmiente", _dice(lineas, "El estrado es de madera."))
	_check("P4 la prenda quedó tibia", _dice(lineas, "Está tibio. Nunca antes estuvo tibio."))
	_check("P4 la pregunta del acto", _dice(lineas, "¿Quién escucha cuando yo prometo?"))
	_check("P4 la ceremonia quedó cerrada", _mapa.ceremonia_hecha())
	_check(
		"P4 y con ella la bandera de guion que pide E05",
		BanderasDeuda.tiene(BanderasDeuda.E04_MAYORIA)
	)
	_check("P4 la campanada no se repite al volver a hablarle", await _repetir_fedatario())


func _repetir_fedatario() -> bool:
	var lineas: Array = await _mapa.hablar_con("Fedatario")
	await _esperar_dialogo()
	return _mapa.campanadas() == 1 and _dice(lineas, "Andá con los tuyos, que la fiesta es tuya.")


# --- P5: volver a la zona con la partida como quedó ------------------------


func _p5_volver_a_la_zona() -> void:
	print("-- P5 volver a Lacrevieja: la plaza quedó como la dejamos")
	var otra: MapaLacrevieja = LACREVIEJA.instantiate() as MapaLacrevieja
	otra.name = "LacreviejaDeVuelta"
	otra.autoarrancar_prologo = false
	otra.dialogo_sin_globo = true
	add_child(otra)
	await _fisica(6)
	var puerta_e05: Node = otra.get_node_or_null(^"OnTheGround/TriggerDeVencimiento")
	if puerta_e05 != null:
		puerta_e05.queue_free()
	await _fisica(2)
	_check("P5 las tres lámparas siguen encendidas", otra.lamparas_encendidas() == 3)
	_check("P5 la leña sigue adentro", otra.horno_grande.entregados == 3)
	_check("P5 las macetas siguen regadas", otra.get_node(^"OnTheGround/Cantero/Maceta6").regada)
	_check("P5 la hache sigue tallada", otra.get_node(^"OnTheGround/Cementerio/Lapida2").enmendada)
	_check("P5 el prólogo no vuelve a correr", otra.prologo_visto())
	_check("P5 la ceremonia sigue hecha", otra.ceremonia_hecha())
	otra.queue_free()
	await _fisica(2)


# --- P6: el jugador riega antes de prometer --------------------------------


## Las macetas no piden permiso: se pueden regar antes de hablar con la Maestra.
## En ese caso la promesita nace y se disuelve en el mismo gesto, y el remate de la
## escena tiene que salir igual (y después del diálogo de la promesa, no encima).
func _p6_tarea_antes_de_prometer() -> void:
	print("-- P6 orden invertido: cumplir la tarea antes de empeñar la palabra")
	# Esta sección arranca la zona de cero: va última a propósito.
	_mapa.queue_free()
	await _fisica(2)
	_mapa = LACREVIEJA.instantiate() as MapaLacrevieja
	_mapa.name = "LacreviejaDeCero"
	_mapa.autoarrancar_prologo = false
	_mapa.dialogo_sin_globo = true
	add_child(_mapa)
	await _fisica(6)
	var puerta_e05: Node = _mapa.get_node_or_null(^"OnTheGround/TriggerDeVencimiento")
	if puerta_e05 != null:
		puerta_e05.queue_free()
	await _fisica(2)
	_mapa.reiniciar_hechos()
	_check("P6 la plaza volvió a amanecer fría", _mapa.lamparas_encendidas() == 0)

	for maceta: MacetaDelCantero in _macetas():
		maceta.regar()
	await _fisica(2)
	_check("P6 las seis macetas están regadas", _mapa.get_node(^"OnTheGround/Cantero/Maceta6").regada)
	_check("P6 sin promesa no se enciende nada", _mapa.lamparas_encendidas() == 0)
	_check("P6 y la promesita no existe", not _mapa.promesa_cumplida_ya("maestra"))

	var lineas: Array = await _mapa.hablar_con("Maestra")
	_check("P6 la promesa se empeña igual", _mapa.promesa_hecha_ya("maestra"))
	_check("P6 y el diálogo de la promesa sale entero", _dice(lineas, "Ya está sellado."), _texto(lineas))
	await _esperar_dialogo()
	_check("P6 la promesita se disuelve en el mismo gesto", _mapa.promesa_cumplida_ya("maestra"))
	_check("P6 y enciende su lámpara", _mapa.lamparas_encendidas() == 1)
	_check(
		"P6 el remate de la escena sale después, no encima",
		_dice(_mapa.ultimas_lineas, "Este pueblo no te merece."),
		_texto(_mapa.ultimas_lineas)
	)


# --- Helpers de escena ----------------------------------------------------


func _negro() -> ColorRect:
	return _mapa.get_node(^"Fundido/Negro") as ColorRect


func _macetas() -> Array[MacetaDelCantero]:
	var salida: Array[MacetaDelCantero] = []
	for nodo: Node in _mapa.get_node(^"OnTheGround/Cantero").get_children():
		if nodo is MacetaDelCantero:
			salida.append(nodo as MacetaDelCantero)
	return salida


func _lapidas() -> Array[LapidaGrabada]:
	var salida: Array[LapidaGrabada] = []
	for nodo: Node in _mapa.get_node(^"OnTheGround/Cementerio").get_children():
		if nodo is LapidaGrabada:
			salida.append(nodo as LapidaGrabada)
	return salida
