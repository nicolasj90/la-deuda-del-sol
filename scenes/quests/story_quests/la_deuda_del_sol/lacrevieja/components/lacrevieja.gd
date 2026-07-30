# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
class_name MapaLacrevieja
extends Node2D

## Lacrevieja, el día de la Mayoría de Palabra: E01 → E04 del Acto 1.
##
## Este script es el director de la zona tutorial. No inventa nada: el diálogo
## sale [b]textual[/b] de [code]docs/guion/acto1/01-lacrevieja-y-vencimiento.md[/code]
## (los [code].dialogue[/code] de al lado) y el contrato de gameplay sale del
## § 4c–4d del [code]INDICE.md[/code].
##
## [b]Qué maneja[/b]
## [br]— [b]E01[/b] «El peso de siempre»: al entrar por primera vez corre el
##   sueño-prólogo (fundido a negro + diálogo), el despertar y la apertura de la
##   plaza. Se dispara solo, una única vez, con el hecho
##   [constant HECHO_PROLOGO].
## [br]— [b]E02[/b] «Tres promesitas»: tres promesas de vecino en cualquier orden.
##   Prometer materializa la promesita ([method prometer]); cumplir la tarea la
##   disuelve ([method cumplir]) y enciende una [LamparaDePalabra] de la plaza.
## [br]— [b]E03[/b] «De mi mesa nadie se levanta con hambre»: duelo tutorial de
##   «De Palabra» contra Rosaura ([method duelo_con_rosaura], perfil
##   [code]garante[/code], mazo prestado de la casa) y el duelo opcional de Cosme
##   ([method duelo_con_cosme], perfil [code]letra_chica[/code]).
## [br]— [b]E04[/b] «Mayoría de palabra»: la ceremonia y la
##   [b]PRIMERA CAMPANADA[/b] ([method campanada]) — SFX de campana + shake suave.
##   Cierra con autosave, como pide el § 4f.8.
##
## [b]Cómo lo llaman los diálogos[/b]: cada NPC lleva un [TalkBehavior] al que
## este nodo se agrega como [member TalkBehavior.extra_context] en
## [method _ready], así que los [code].dialogue[/code] pueden escribir
## [code]do Lacrevieja.prometer("rosaura")[/code] o
## [code]if Lacrevieja.plaza_lista():[/code] sin más cableado.
##
## [b]Headless[/b]: con [member dialogo_sin_globo] los diálogos corren sin globo
## (línea por línea, para el smoke) y con [member duelos_automaticos] la IA juega
## también el lado de Ciro. El prólogo NO arranca solo si la escena no es la
## escena actual del árbol, así que instanciarla como hija (regresión F4, smokes)
## nunca dispara cinemáticas.

## Emitida cuando Ciro empeña una de las tres promesitas de E02.
signal promesa_hecha(cual: String)

## Emitida cuando una promesita se disuelve y su lámpara se enciende.
signal promesa_cumplida(cual: String)

## Emitida cuando las tres lámparas de la plaza quedan encendidas (cierre de E02).
signal plaza_encendida

## Emitida al cerrar el duelo tutorial de Rosaura (E03).
signal duelo_rosaura_cerrado(gano: bool)

## Emitida en cada campanada de la prenda. En esta zona sólo suena una: la
## primera, en E04.
signal campanada_sonada(numero: int)

## Emitida al terminar la ceremonia de la Mayoría de Palabra (E04).
signal ceremonia_terminada

## Las tres promesitas de E02, en el orden en que las presenta el guion.
const PROMESAS: Array[String] = ["rosaura", "maestra", "cosme"]

## Hechos con los que la zona vive en [member GlobalState.facts].
const HECHO_PROLOGO: String = "ldds_e01_prologo_visto"
const HECHO_PROMESA: String = "ldds_e02_promesa_%s"
const HECHO_CUMPLIDA: String = "ldds_e02_cumplida_%s"
const HECHO_DUELO_ROSAURA: String = "ldds_e03_duelo_rosaura_ganado"
const HECHO_DUELO_COSME: String = "ldds_e03_duelo_cosme_jugado"
## La cuenta de campanadas es del acto entero, no de esta zona: la segunda suena en
## E07, lejos de acá (§ 5b del INDICE). Una sola clave, en [BanderasDeuda].
const HECHO_CAMPANADAS: String = BanderasDeuda.CAMPANADAS

## La ceremonia de E04 no tiene hecho propio: usa la bandera de guion del bloque
## ([constant BanderasDeuda.E04_MAYORIA]), que es la que E05 pide como requisito
## para que el Vencimiento arranque. Una sola fuente de verdad para el enganche
## E04 → E05.
const HECHO_CEREMONIA: String = BanderasDeuda.E04_MAYORIA

## Cartas de difunto que Cosme regala gane quien gane el duelo opcional
## ([code]data/cartas/fuente/canales.json[/code], canal opcional de E03).
const CARTAS_DE_COSME: Dictionary = {
	"sepulturero_cosme": 1,
	"deudo_del_difunto": 1,
	"testamento_apurado": 1,
}

## La mano que Ciro canta en E03, palabra por palabra: «Tengo dos Gallinas, un
## Peón de Viña y la Lámpara de Palabra». Regla no negociable del § 4f.1.
const MANO_DE_CIRO_E03: Array[String] = [
	"gallina_lacrevieja",
	"gallina_lacrevieja",
	"peon_de_vina",
	"lampara_de_palabra",
]

## Premio del duelo tutorial: la Gallina de regalo y el Porteador que Ciro
## anuncia en E17 (§ 4e de trazabilidad). El mazo propio lo entrega
## [method Coleccion.entregar_mazo_inicial] desde el diálogo.
const PREMIO_E03: Dictionary = {
	"gallina_lacrevieja": 1,
	"porteador_empenadero": 1,
}

@export_group("Diálogos")
## E01: sueño-prólogo, despertar y apertura de la plaza.
@export var dialogo_prologo: DialogueResource
@export var dialogo_rosaura: DialogueResource
@export var dialogo_maestra: DialogueResource
@export var dialogo_cosme: DialogueResource
@export var dialogo_fedatario: DialogueResource

@export_group("Producción")
## Corre el prólogo de E01 al entrar por primera vez. Sólo pega si esta escena es
## la escena actual del árbol.
@export var autoarrancar_prologo: bool = true

## Corre los diálogos sin globo, línea por línea. Lo prende el smoke headless.
@export var dialogo_sin_globo: bool = false

## La IA juega también el lado de Ciro en los duelos. Lo prende el smoke headless.
@export var duelos_automaticos: bool = false

## Semilla de los duelos automáticos (0 = azar de verdad).
@export var semilla_duelos: int = 0

## Líneas de la última corrida de diálogo sin globo. Sólo lo lee el smoke.
var ultimas_lineas: Array[String] = []

var _hechos_sueltos: Dictionary = {}
var _globo_falso: Control
var _en_dialogo: bool = false

@onready var lamparas: Array[Node] = [%Lampara1, %Lampara2, %Lampara3]
@onready var pila_de_lena: PuntoDeCarga = %PilaDeLena
@onready var horno_grande: PuntoDeCarga = %HornoGrande
@onready var campana: AudioStreamPlayer = %Campana
@onready var _negro: ColorRect = %Negro


func _ready() -> void:
	_cablear_npcs()
	_cablear_tareas()
	_restaurar_estado()
	if autoarrancar_prologo and get_tree().current_scene == self:
		correr_prologo()


# ---------------------------------------------------------------------------
# Hechos (persisten en el save de Threadbare, como la Colección)
# ---------------------------------------------------------------------------


## Valor de un hecho de la zona.
func hecho(clave: String, por_defecto: Variant = false) -> Variant:
	return _hechos().get(clave, por_defecto)


## Escribe un hecho y guarda la partida.
func marcar(clave: String, valor: Variant = true) -> void:
	_hechos()[clave] = valor
	_guardar()


## Borra los hechos de la zona (partida nueva, o el smoke antes de empezar).
func reiniciar_hechos() -> void:
	var hechos: Dictionary = _hechos()
	for clave: String in _todas_las_claves():
		hechos.erase(clave)
	_restaurar_estado()


func _todas_las_claves() -> Array[String]:
	var claves: Array[String] = [
		HECHO_PROLOGO,
		HECHO_DUELO_ROSAURA,
		HECHO_DUELO_COSME,
		HECHO_CEREMONIA,
		HECHO_CAMPANADAS,
	]
	for cual: String in PROMESAS:
		claves.append(HECHO_PROMESA % cual)
		claves.append(HECHO_CUMPLIDA % cual)
	return claves


func _hechos() -> Dictionary:
	if GameState != null and GameState.global != null:
		return GameState.global.facts
	return _hechos_sueltos


func _guardar() -> void:
	if GameState != null and GameState.global != null:
		GameState.save()


# ---------------------------------------------------------------------------
# E01 — «El peso de siempre»
# ---------------------------------------------------------------------------


## ¿Ya se vio el sueño-prólogo?
func prologo_visto() -> bool:
	return bool(hecho(HECHO_PROLOGO))


## Sueño-prólogo + despertar + apertura de la plaza. Idempotente.
func correr_prologo() -> void:
	if prologo_visto():
		return
	marcar(HECHO_PROLOGO)
	# Negro, el sueño, y de vuelta la luz: «fundidos + diálogo», nada más. El
	# fundido es propio (un CanvasLayer de la escena, por debajo del globo) y no
	# el autoload de transiciones, que se come el input mientras está visible.
	await _fundir(1.0)
	await correr_dialogo(dialogo_prologo, "sueno")
	await _fundir(0.0)
	await correr_dialogo(dialogo_prologo, "despertar")
	# La plaza: Rosaura explica la Ley del Empeño antes de la primera promesita.
	await correr_dialogo(dialogo_rosaura, "apertura")


# ---------------------------------------------------------------------------
# E02 — «Tres promesitas»
# ---------------------------------------------------------------------------


## ¿Ya prometió esta promesita?
func promesa_hecha_ya(cual: String) -> bool:
	return bool(hecho(HECHO_PROMESA % cual))


## ¿Ya la cumplió (y su lámpara está encendida)?
func promesa_cumplida_ya(cual: String) -> bool:
	return bool(hecho(HECHO_CUMPLIDA % cual))


## Empeña una de las tres promesitas. Devuelve [code]true[/code] si nació una nueva.
func prometer(cual: String) -> bool:
	if cual not in PROMESAS or promesa_hecha_ya(cual):
		return false
	marcar(HECHO_PROMESA % cual)
	promesa_hecha.emit(cual)
	# Si el jugador hizo la tarea antes de prometerla (regar seis macetas no pide
	# permiso), la promesita nace y se disuelve en el mismo gesto. Se espera a que
	# cierre el diálogo en curso para no pisarlo con el remate.
	if _tarea_terminada(cual):
		_cumplir_cuando_calle(cual)
	return true


func _cumplir_cuando_calle(cual: String) -> void:
	while _en_dialogo:
		await get_tree().process_frame
	if cumplir(cual):
		await correr_dialogo(dialogo_de(cual), "cumplida")


## Disuelve la promesita y enciende una lámpara. Devuelve [code]true[/code] si cambió algo.
func cumplir(cual: String) -> bool:
	if cual not in PROMESAS or not promesa_hecha_ya(cual) or promesa_cumplida_ya(cual):
		return false
	marcar(HECHO_CUMPLIDA % cual)
	_encender_proxima_lampara()
	promesa_cumplida.emit(cual)
	if plaza_lista():
		plaza_encendida.emit()
	return true


## Cuántas lámparas de la plaza están encendidas.
func lamparas_encendidas() -> int:
	var cuenta: int = 0
	for lampara: Node in lamparas:
		if lampara is LamparaDePalabra and (lampara as LamparaDePalabra).encendida:
			cuenta += 1
	return cuenta


## ¿Las tres lámparas de la plaza están encendidas? (cierre de E02).
func plaza_lista() -> bool:
	return lamparas_encendidas() >= 3


## Ordinal de la última lámpara encendida, para las acotaciones del guion
## («la primera lámpara se enciende sola»): así el texto acompaña el orden real
## en que el jugador cumplió, que el guion deja libre.
func ordinal_lampara() -> String:
	match lamparas_encendidas():
		1:
			return "primera"
		2:
			return "segunda"
		3:
			return "tercera"
	return "próxima"


## El mismo ordinal con mayúscula inicial (arranca oración en E02).
func ordinal_lampara_titulo() -> String:
	return ordinal_lampara().capitalize()


func _encender_proxima_lampara() -> void:
	for lampara: Node in lamparas:
		if lampara is LamparaDePalabra and (lampara as LamparaDePalabra).encender():
			return


## El [code].dialogue[/code] del vecino de esa promesita.
func dialogo_de(cual: String) -> DialogueResource:
	match cual:
		"rosaura":
			return dialogo_rosaura
		"maestra":
			return dialogo_maestra
		"cosme":
			return dialogo_cosme
	return null


func _tarea_terminada(cual: String) -> bool:
	match cual:
		"rosaura":
			return horno_grande != null and horno_grande.cumplido()
		"maestra":
			return _macetas_secas() == 0 and not _macetas().is_empty()
		"cosme":
			return _lapidas_sin_leer() == 0 and not _lapidas().is_empty()
	return false


# ---------------------------------------------------------------------------
# E03 — duelos de «De Palabra»
# ---------------------------------------------------------------------------


## ¿Ganó el duelo tutorial de Rosaura?
func duelo_rosaura_ganado() -> bool:
	return bool(hecho(HECHO_DUELO_ROSAURA))


## ¿Ya se jugó el duelo opcional de Cosme?
func duelo_cosme_jugado() -> bool:
	return bool(hecho(HECHO_DUELO_COSME))


## Duelo tutorial de E03: Rosaura con mazo puro Garante, Ciro con el mazo
## prestado de la casa y la mano fijada por script — la que canta en voz alta.
## Corrutina: [code]do Lacrevieja.duelo_con_rosaura()[/code] desde el diálogo.
func duelo_con_rosaura() -> bool:
	var opciones: Dictionary = {
		"mazo_jugador": mazo_de_la_casa(),
		"mano_jugador": MANO_DE_CIRO_E03.duplicate(),
		"anuncio_jugador": MANO_DE_CIRO_E03.duplicate(),
		"premio": PREMIO_E03.duplicate(),
	}
	var gano: bool = await _duelo("garante", opciones)
	if gano:
		marcar(HECHO_DUELO_ROSAURA)
	duelo_rosaura_cerrado.emit(gano)
	return gano


## Duelo opcional de E03: Cosme con mazo puro Letra chica. El premio no va acá:
## Cosme regala las cartas de difunto gane quien gane (ver
## [method entregar_cartas_de_cosme]).
func duelo_con_cosme() -> bool:
	var gano: bool = await _duelo("letra_chica", {})
	marcar(HECHO_DUELO_COSME)
	return gano


## «Llevate estas: cartas de difunto.» Idempotente por [Coleccion].
func entregar_cartas_de_cosme() -> Dictionary:
	if Coleccion == null:
		return {}
	return Coleccion.agregar_varias(CARTAS_DE_COSME.duplicate())


## El mazo de enseñar de Rosaura, completado a las 30 cartas reglamentarias.
## Es prestado: no entra a la colección (continuidad de E03).
func mazo_de_la_casa() -> Array[String]:
	return ArmadorDeMazos.completar(Coleccion.MAZO_DE_LA_CASA, ConfigMesa.base(), "garante")


func _duelo(perfil: String, opciones: Dictionary) -> bool:
	var op: Dictionary = opciones.duplicate()
	if duelos_automaticos:
		op["auto"] = true
		op["perfil_jugador"] = "casa"
		op["ritmo"] = 0.0
		op["pausa_cierre"] = 0.0
		op["pausar_mapa"] = false
		op["mostrar_todo"] = true
		op["velocidad_naipes"] = 100000
		op["semilla"] = semilla_duelos
	return await DueloLauncher.duelo(perfil, op)


# ---------------------------------------------------------------------------
# E04 — «Mayoría de palabra»
# ---------------------------------------------------------------------------


## ¿La ceremonia ya pasó?
func ceremonia_hecha() -> bool:
	return bool(hecho(HECHO_CEREMONIA))


## ¿Se puede refrendar la Mayoría? El guion pide la plaza encendida (E02) y el
## mediodía en el horno ya jugado (E03) antes del atardecer de E04.
func listo_para_ceremonia() -> bool:
	return plaza_lista() and duelo_rosaura_ganado()


## Cuántas campanadas sonaron hasta ahora en la partida (en esta zona, la primera).
func campanadas() -> int:
	return int(hecho(HECHO_CAMPANADAS, 0))


## La prenda suena. Placeholder de sonido: una campana de mano grave, más el
## shake suave de cámara. Curva del § 5b: ésta es la [b]primera[/b].
func campanada() -> int:
	var numero: int = BanderasDeuda.sonar_campanada()
	if GameState == null or GameState.global == null:
		# Escena sola desde el editor: la cuenta vive en los hechos sueltos.
		numero = int(hecho(HECHO_CAMPANADAS, 0)) + 1
		marcar(HECHO_CAMPANADAS, numero)
	if campana != null and campana.stream != null:
		campana.play()
	_sacudir_camara()
	campanada_sonada.emit(numero)
	return numero


## Cierra E04: hecho + autosave (§ 4f.8 «autosaves guionados»).
func cerrar_ceremonia() -> void:
	if ceremonia_hecha():
		return
	marcar(HECHO_CEREMONIA)
	ceremonia_terminada.emit()


## Corre la ceremonia entera desde código (el camino normal es hablarle al
## fedatario). Devuelve [code]false[/code] si todavía no corresponde.
func correr_ceremonia() -> bool:
	if ceremonia_hecha() or not listo_para_ceremonia():
		return false
	await correr_dialogo(dialogo_fedatario, "ceremonia")
	return ceremonia_hecha()


func _sacudir_camara() -> void:
	# En headless no hay cámara: el shake se saltea sin ruido.
	if CameraShake == null:
		return
	var vista: Viewport = get_viewport()
	if vista == null or vista.get_camera_2d() == null:
		return
	CameraShake.shake()


# ---------------------------------------------------------------------------
# Diálogos
# ---------------------------------------------------------------------------


## Le habla a un NPC de la zona por el nombre de su nodo («Rosaura», «Cosme»…) y
## devuelve las líneas que salieron. Es el gancho del smoke headless: recorre el
## mismo [code].dialogue[/code] y el mismo título que el botón de interacción.
func hablar_con(nombre: String, titulo: String = "") -> Array[String]:
	var npc: Node = get_node_or_null(NodePath("%%%s" % nombre))
	if npc == null:
		push_error("[Lacrevieja] no existe el NPC «%s»." % nombre)
		return []
	var comportamiento: TalkBehavior = npc.get_node_or_null(^"TalkBehavior") as TalkBehavior
	if comportamiento == null:
		push_error("[Lacrevieja] «%s» no tiene TalkBehavior." % nombre)
		return []
	var recurso: DialogueResource = comportamiento.dialogue
	if npc is Talker and (npc as Talker).dialogue != null:
		recurso = (npc as Talker).dialogue
	var cual: String = titulo if not titulo.is_empty() else comportamiento.title
	# Mismos estados de juego que pasa [TalkBehavior] al abrir el globo: el NPC va
	# primero, así los diálogos pueden ramificar por `npc_name` (los vecinos).
	await correr_dialogo(recurso, cual, [npc])
	return ultimas_lineas.duplicate()


## ¿Hay un diálogo de la zona corriendo ahora mismo?
func en_dialogo() -> bool:
	return _en_dialogo


## Corre un diálogo de la zona. Con [member dialogo_sin_globo] va línea por línea
## y deja el texto en [member ultimas_lineas]; si no, monta el globo de Threadbare.
## [param extras] son estados de juego extra (por ejemplo el NPC que habla).
func correr_dialogo(recurso: DialogueResource, titulo: String, extras: Array = []) -> void:
	ultimas_lineas.clear()
	if recurso == null:
		push_warning("[Lacrevieja] diálogo sin recurso (título «%s»)." % titulo)
		return
	if _en_dialogo:
		push_warning("[Lacrevieja] ya hay un diálogo corriendo; se ignora «%s»." % titulo)
		return
	_en_dialogo = true
	var estados: Array = extras.duplicate()
	if dialogo_sin_globo:
		estados.append(_estados_sin_globo())
		var linea: DialogueLine = await DialogueManager.get_next_dialogue_line(
			recurso, titulo, estados
		)
		var tope: int = 400
		while linea != null and tope > 0:
			tope -= 1
			ultimas_lineas.append(linea.text)
			linea = await DialogueManager.get_next_dialogue_line(recurso, linea.next_id, estados)
	else:
		estados.append({"Lacrevieja": self})
		DialogueManager.show_dialogue_balloon(recurso, titulo, estados)
		await DialogueManager.dialogue_ended
	_en_dialogo = false


## Funde el velo negro de la escena hasta [param alfa] (0 = transparente,
## 1 = negro pleno). En la corrida sin globo es instantáneo.
func _fundir(alfa: float, duracion: float = 0.9) -> void:
	if _negro == null:
		return
	if dialogo_sin_globo or duracion <= 0.0:
		_negro.color.a = alfa
		return
	var tween: Tween = create_tween()
	tween.tween_property(_negro, "color:a", alfa, duracion)
	await tween.finished


## Estados de juego para la corrida sin globo: este nodo bajo el nombre que usan
## los diálogos, más un doble del globo (los `do balloon.hide()` del patrón de
## producción tienen que seguir corriendo).
func _estados_sin_globo() -> Dictionary:
	if _globo_falso == null or not is_instance_valid(_globo_falso):
		_globo_falso = Control.new()
		_globo_falso.name = "GloboFalso"
		add_child(_globo_falso)
	return {"Lacrevieja": self, "balloon": _globo_falso}


# ---------------------------------------------------------------------------
# Cableado de la escena
# ---------------------------------------------------------------------------


func _cablear_npcs() -> void:
	for comportamiento: TalkBehavior in _buscar(TalkBehavior):
		if self not in comportamiento.extra_context:
			comportamiento.extra_context.append(self)


func _cablear_tareas() -> void:
	horno_grande.completo.connect(_on_lena_entrada)
	for maceta: MacetaDelCantero in _macetas():
		maceta.regada_ahora.connect(_on_maceta_regada)
	for lapida: LapidaGrabada in _lapidas():
		lapida.leida_ahora.connect(_on_lapida_leida)


func _restaurar_estado() -> void:
	# Las lámparas y las tareas se derivan de los hechos: volver a la zona con la
	# partida cargada tiene que mostrar la plaza como quedó.
	var cumplidas: int = 0
	for cual: String in PROMESAS:
		if promesa_cumplida_ya(cual):
			cumplidas += 1
	for i: int in lamparas.size():
		var lampara: Node = lamparas[i]
		if lampara is LamparaDePalabra:
			(lampara as LamparaDePalabra).encendida = i < cumplidas
	pila_de_lena.cargando = false
	horno_grande.fijar_entregados(horno_grande.cupo if promesa_cumplida_ya("rosaura") else 0)
	for maceta: MacetaDelCantero in _macetas():
		maceta.regada = promesa_cumplida_ya("maestra")
	for lapida: LapidaGrabada in _lapidas():
		lapida.leida = promesa_cumplida_ya("cosme")
		lapida.enmendada = promesa_cumplida_ya("cosme") and lapida.tiene_errata()


func _on_lena_entrada() -> void:
	if cumplir("rosaura"):
		await correr_dialogo(dialogo_de("rosaura"), "cumplida")


func _on_maceta_regada() -> void:
	if _macetas_secas() > 0:
		return
	if cumplir("maestra"):
		await correr_dialogo(dialogo_de("maestra"), "cumplida")


func _on_lapida_leida(_con_errata: bool) -> void:
	if _lapidas_sin_leer() > 0:
		return
	# Cosme saca gubia y martillo: talla la hache que le debía a la finada.
	for lapida: LapidaGrabada in _lapidas():
		lapida.enmendar()
	if cumplir("cosme"):
		await correr_dialogo(dialogo_de("cosme"), "cumplida")


func _macetas() -> Array[MacetaDelCantero]:
	var salida: Array[MacetaDelCantero] = []
	for nodo: Node in _buscar(MacetaDelCantero):
		salida.append(nodo as MacetaDelCantero)
	return salida


func _lapidas() -> Array[LapidaGrabada]:
	var salida: Array[LapidaGrabada] = []
	for nodo: Node in _buscar(LapidaGrabada):
		salida.append(nodo as LapidaGrabada)
	return salida


func _macetas_secas() -> int:
	var cuenta: int = 0
	for maceta: MacetaDelCantero in _macetas():
		if not maceta.regada:
			cuenta += 1
	return cuenta


func _lapidas_sin_leer() -> int:
	var cuenta: int = 0
	for lapida: LapidaGrabada in _lapidas():
		if not lapida.leida:
			cuenta += 1
	return cuenta


## Todos los descendientes de esta escena que sean de ese tipo.
func _buscar(tipo: Variant) -> Array[Node]:
	var salida: Array[Node] = []
	_buscar_en(self, tipo, salida)
	return salida


func _buscar_en(raiz: Node, tipo: Variant, salida: Array[Node]) -> void:
	for hijo: Node in raiz.get_children():
		if is_instance_of(hijo, tipo):
			salida.append(hijo)
		_buscar_en(hijo, tipo, salida)
