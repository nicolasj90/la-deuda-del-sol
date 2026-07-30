# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name SondaDeMesa
extends Node

## Sonda de la mesa de «De Palabra»: imprime por consola, cada vez que la mesa
## cambia, una línea [code]MESA_UI {json}[/code] con los rectángulos globales de
## todo lo clicable (mano, Estrados, pilas del rival, botones del HUD, objetivos
## de la capa y opciones del diálogo) más el mensaje y el detalle del HUD.
##
## [b]Para qué[/b]: el arnés de Playwright que juega el duelo con el mouse necesita
## saber dónde está cada carta. El abanico de la mano se recentra con cada robo y
## los naipes llegan a su lugar con tween, así que las coordenadas no se pueden
## hardcodear: hardcodearlas fue exactamente lo que hizo que las primeras corridas
## «apretaran» el hueco entre dos cartas y pareciera que la mesa no respondía.
##
## Se cuelga sola de [signal DueloLauncher.duelo_montado], así que sirve igual
## para la mesa suelta de [code]duelo_dev.tscn[/code] y para el duelo que sale del
## diálogo de Rosaura en el mapa (E03).
##
## Solo la usan las escenas de [code]scenes/dev/[/code]: no toca la vista ni el
## motor y todo lo que lee es API pública ([method VistaDuelo.naipe_de],
## [method MotorDePalabra.coste]).

## Cada cuántos cuadros se recalcula. La mesa se mueve con tweens: no alcanza con
## imprimir cuando el motor emite un evento.
const CUADROS_ENTRE_SONDAS: int = 15

var _vista: VistaDuelo = null
var _motor: MotorDePalabra = null
var _cuenta: int = 0
var _ultima: String = ""


func _ready() -> void:
	# El launcher pausa la escena que tiene la mesa montada (el mapa, o la propia
	# escena dev): sin esto la sonda se apaga justo cuando hay algo que mirar.
	process_mode = Node.PROCESS_MODE_ALWAYS
	DueloLauncher.duelo_montado.connect(_al_montar)
	DueloLauncher.duelo_terminado.connect(_al_terminar)


func _al_montar(motor: MotorDePalabra, vista: VistaDuelo) -> void:
	_motor = motor
	_vista = vista
	_ultima = ""
	print("MESA_UI_LISTA")


func _al_terminar(gano: bool, motivo: String) -> void:
	print("MESA_UI_CERRADA %s %s" % ["gano" if gano else "perdio", motivo])
	_vista = null
	_motor = null


func _process(_delta: float) -> void:
	if _vista == null or not is_instance_valid(_vista) or _motor == null:
		return
	_cuenta += 1
	if _cuenta < CUADROS_ENTRE_SONDAS:
		return
	_cuenta = 0
	var linea: String = "MESA_UI %s" % JSON.stringify(_estado_visible())
	if linea == _ultima:
		return
	_ultima = linea
	print(linea)


## Todo lo que el arnés necesita para jugar con el mouse.
func _estado_visible() -> Dictionary:
	var estado: EstadoDuelo = _motor.estado
	var lado: int = _vista.lado_jugador
	var datos: Dictionary = {
		"turno": estado.turno,
		"activo": estado.activo,
		"mio": estado.activo == lado and not estado.terminado,
		"terminado": estado.terminado,
		"aval": [estado.firma(lado).aval, estado.firma(1 - lado).aval],
		"credito": "%d/%d" % [estado.firma(lado).credito, estado.firma(lado).credito_max],
		"mano": _zona(lado, Palabra.Zona.MANO),
		"estrado": _zona(lado, Palabra.Zona.ESTRADO),
		"estrado_rival": _zona(1 - lado, Palabra.Zona.ESTRADO),
		"empenadero_rival": _zona(1 - lado, Palabra.Zona.EMPENADERO),
		"viaje_rival": _zona(1 - lado, Palabra.Zona.VIAJE),
		"botones": _botones(),
		"mensaje": _texto("HUD/Mensaje"),
		"detalle": _texto("HUD/Detalle"),
		"cartel": _texto("HUD/Cartel"),
	}
	var capa: CapaObjetivo = _vista.get_node_or_null("CapaObjetivo") as CapaObjetivo
	if capa != null and capa.activa:
		var objetivos: Array = []
		for o: Dictionary in capa.objetivos():
			var nodo: Control = o.get("nodo", null) as Control
			var punto: Dictionary = _punto(nodo)
			punto["uid"] = int(o.get("uid", -1))
			objetivos.append(punto)
		datos["capa"] = {"aviso": _texto("CapaObjetivo/Aviso"), "objetivos": objetivos}
	var dialogo: DialogoDePalabra = _vista.get_node_or_null("DialogoDePalabra") as DialogoDePalabra
	if dialogo != null and dialogo.abierto():
		var opciones: Array = []
		var caja: Node = dialogo.get_node_or_null("Panel/Caja/Scroll/Opciones")
		if caja != null:
			for hijo: Node in caja.get_children():
				var boton: Button = hijo as Button
				if boton == null:
					continue
				var punto: Dictionary = _punto(boton)
				punto["texto"] = boton.text
				opciones.append(punto)
		var cancelar: Button = dialogo.get_node_or_null("Panel/Caja/Cancelar") as Button
		datos["dialogo"] = {
			"titulo": _texto("DialogoDePalabra/Panel/Caja/Titulo"),
			"opciones": opciones,
			"cancelar": _punto(cancelar),
		}
	return datos


func _zona(lado: int, z: Palabra.Zona) -> Array:
	var salida: Array = []
	for ec: EstadoCarta in _motor.estado.firma(lado).zona(z):
		var naipe: NaipeDePalabra = _vista.naipe_de(ec.uid)
		if naipe == null:
			continue
		var punto: Dictionary = _punto(naipe)
		punto["uid"] = ec.uid
		punto["id"] = ec.id()
		punto["nombre"] = ec.def.nombre
		punto["coste"] = _motor.coste(ec)
		punto["atq"] = _motor.ataque(ec)
		punto["agu"] = _motor.aguante_restante(ec)
		punto["clicable"] = naipe.can_be_interacted_with
		punto["apagado"] = naipe.modulate.r < 0.9
		if not naipe.tooltip_text.is_empty():
			punto["motivo"] = naipe.tooltip_text
		salida.append(punto)
	return salida


func _botones() -> Dictionary:
	var salida: Dictionary = {}
	for nombre: String in ["Jugar", "AlFiado", "Empenar", "Terminar"]:
		var boton: Button = _vista.get_node_or_null("HUD/Botones/%s" % nombre) as Button
		if boton == null or not boton.visible:
			continue
		var punto: Dictionary = _punto(boton)
		punto["off"] = boton.disabled
		salida[nombre] = punto
	return salida


## Centro y rectángulo global de un Control, redondeados: coordenadas de pantalla
## listas para [code]page.mouse.move()[/code].
func _punto(nodo: Control) -> Dictionary:
	if nodo == null or not is_instance_valid(nodo) or not nodo.is_inside_tree():
		return {}
	var r: Rect2 = nodo.get_global_rect()
	var c: Vector2 = r.get_center()
	return {
		"x": roundi(c.x),
		"y": roundi(c.y),
		"rect": [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)],
	}


func _texto(ruta: String) -> String:
	var nodo: Node = _vista.get_node_or_null(ruta)
	if nodo == null:
		return ""
	return String(nodo.text) if "text" in nodo else ""
