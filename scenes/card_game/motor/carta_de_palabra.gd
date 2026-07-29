# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name CartaDePalabra
extends Resource

## Definición **inmutable** de una carta de «De Palabra» (diseño § 5).
##
## Es solo datos: ni una sola propiedad de esta clase cambia durante un duelo.
## Todo el estado de runtime vive en [EstadoCarta] (diseño § 6.2.4: guardar
## estado mutable en la definición corrompe todas las copias de la carta y
## arrastra la corrupción entre duelos).
##
## Los efectos son declarativos: [code]{ "trigger": ..., "op": ..., ... }[/code].
## El único que sabe interpretarlos es [MotorDePalabra].

## Arquetipos del set (diseño § 5.1 a § 5.9). No tienen efecto mecánico: son la
## agrupación del set y la marca que usan los perfiles de IA (§ 7.3) y el armador.
const ARQUETIPOS: Array[String] = [
	"neutral",
	"garante",
	"letra_chica",
	"interes",
	"de_palabra",
	"al_contado",
	"palabra_rota",
	"postgame",
	"token",
]

## Identificador estable, en snake_case. Es la clave del catálogo.
@export var id: String = ""
## Nombre para mostrar.
@export var nombre: String = ""
## Texto de reglas tal como lo lee el jugador.
@export var texto: String = ""
## Texto de sabor. Solo se llena donde la biblia habla (§ 10: «los textos,
## nombres y lore de las cartas siguen la biblia palabra por palabra»); vacío
## donde no, para no inventar canon.
@export var lore: String = ""
## Arquetipo del set, de [constant ARQUETIPOS].
@export var arquetipo: String = "neutral"
@export var tipo: Palabra.Tipo = Palabra.Tipo.FIADOR
## Coste en Crédito **base**. El coste real lo calcula el motor (Interés, § 2.5).
@export var coste_base: int = 0
@export var ataque_base: int = 0
@export var aguante_base: int = 0
## Daño base de una Cláusula de daño (p. ej. Pagaré a la Vista: 2).
@export var dano_base: int = 0
## Keywords de la lista de [constant Palabra.KEYWORDS].
@export var keywords: Array[String] = []
## Efectos declarativos. Cada entrada lleva al menos [code]trigger[/code] y [code]op[/code].
@export var efectos: Array[Dictionary] = []
## Ofertas de Promesa propias de la carta:
## [code]{ "tipo": ..., "plazo": ..., "bonus": [ops] }[/code] (§ 3).
@export var promesas: Array[Dictionary] = []
## Objetivos que hay que elegir para jugarla. Si no hay ninguno legal, la carta
## no se puede jugar (§ 1.3).
@export var objetivos: Array[String] = []
## Bono que se recalcula solo, p. ej. el Porteador del Empeñadero (§ 5.2).
@export var bono_dinamico: Dictionary = {}
## Tokens: no coleccionables, no entran a mazos.
@export var es_token: bool = false
@export var es_legendaria: bool = false
## Los Quebrantos y Nadia no pueden llevar Promesas (§ 3.2, § 5.8).
@export var puede_prometer: bool = true
## Módulo al que pertenece; vacío = base. Una carta de módulo apagado no entra
## al mazo (§ 4).
@export var modulo: String = ""
## Bloqueada para el armador de mazos del Acto 1 (§ 5.8).
@export var bloqueada: bool = false
## Ruta del arte de la cara. La usa la vista, no el motor.
@export var arte: String = ""


## ¿Es una carta que ocupa lugar en el Estrado?
func es_cuerpo() -> bool:
	return tipo == Palabra.Tipo.FIADOR or tipo == Palabra.Tipo.SOPORTE


func tiene_kw(kw: String) -> bool:
	return keywords.has(kw)


## Máximo de copias por mazo (§ 1): 2, o 1 si es legendaria.
func max_copias() -> int:
	return 1 if es_legendaria else 2


## Efectos de un trigger, en el orden en que fueron declarados.
func efectos_de(trigger: String) -> Array[Dictionary]:
	var salida: Array[Dictionary] = []
	for e: Dictionary in efectos:
		if String(e.get("trigger", "")) == trigger:
			salida.append(e)
	return salida


## Valida la definición y devuelve la lista de errores (vacía si está bien).
## La usa el generador del pipeline y el validador del set: nunca cuelga, nunca
## entra en loop (diseño § 6.2.5).
func validar() -> Array[String]:
	var errores: Array[String] = []
	if id.strip_edges().is_empty():
		errores.append("carta sin id")
	if nombre.strip_edges().is_empty():
		errores.append("%s: sin nombre" % id)
	if coste_base < 0:
		errores.append("%s: coste_base negativo" % id)
	if not ARQUETIPOS.has(arquetipo):
		errores.append("%s: arquetipo desconocido '%s'" % [id, arquetipo])
	if es_token and arquetipo != "token":
		errores.append("%s: es token y su arquetipo no es 'token'" % id)
	if tipo == Palabra.Tipo.CLAUSULA:
		if ataque_base != 0 or aguante_base != 0:
			errores.append("%s: una Cláusula no puede tener stats" % id)
	else:
		if aguante_base <= 0:
			errores.append("%s: un cuerpo necesita aguante > 0" % id)
	for kw: String in keywords:
		if not Palabra.KEYWORDS.has(kw):
			errores.append("%s: keyword desconocida '%s'" % [id, kw])
	if not modulo.is_empty() and not Palabra.MODULOS.has(modulo):
		errores.append("%s: módulo desconocido '%s'" % [id, modulo])
	for e: Dictionary in efectos:
		if not e.has("trigger"):
			errores.append("%s: efecto sin trigger" % id)
		if not e.has("op"):
			errores.append("%s: efecto sin op" % id)
	for p: Dictionary in promesas:
		var t: String = String(p.get("tipo", ""))
		if not Palabra.CLAUSULAS.has(t):
			errores.append("%s: cláusula de promesa desconocida '%s'" % [id, t])
		var plazo: int = int(p.get("plazo", 0))
		if plazo < 1 or plazo > Palabra.PLAZO_MAX:
			errores.append("%s: plazo fuera de rango (%d)" % [id, plazo])
	return errores
