# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name PerfilIA
extends Resource

## Perfil de personalidad de un rival de «De Palabra» (diseño § 7.1).
##
## Es **solo datos**: la que decide es [IADePalabra], que es una función pura
## ([code]estado + perfil + rng → Jugada[/code]). Un perfil no tiene métodos que
## miren el duelo.
##
## Pipeline: [code]data/perfiles_ia/fuente/perfiles.json[/code] →
## [code]scenes/card_game/tools/generar_perfiles.gd[/code] →
## [code]data/perfiles_ia/tres/*.tres[/code].

## Identificador estable, en snake_case (clave del catálogo).
@export var id: String = ""
## Nombre del rival que usa este perfil, para logs y depuración.
@export var nombre: String = ""

## § 7.1 — valor de tener cuerpos ahora (0–2).
@export var peso_tempo: float = 1.0
## § 7.1 — ganas de pegarle a la Firma en vez de comer trades (0–2).
@export var peso_cara: float = 1.0
## § 7.1 — valor de conservar el Estrado (0–2).
@export var peso_tabla: float = 1.0
## § 7.1 — valor de cartas en mano (0–2).
@export var peso_mano: float = 1.0
## § 7.1 — probabilidad de aceptar una cláusula optativa (0–1).
@export var sesgo_promesa: float = 0.5
## § 7.1 — cuánto asume que la información del rival es mentira (0–1).
## Con 1.0 el anuncio del rival se descarta por completo: es el defecto de
## personaje de Salu (§ 7.3).
@export var sesgo_desconfianza: float = 0.0
## § 7.1 — cuánto valor de más exige para intercambiar (0–1).
@export var umbral_trade: float = 0.3
## § 7.1 — coste ideal a jugar por turno propio. Vacío = sin preferencia de curva;
## si está, tiene que tener 10 entradas (turnos 1 a 10).
@export var curva_preferida: Array[int] = []
## § 7.1 — desempate al elegir jugada. Keywords de [constant Palabra.KEYWORDS] y/o
## arquetipos de [constant CartaDePalabra.ARQUETIPOS].
@export var keywords_prioritarias: Array[String] = []
## § 7.1 — jugadas fijas para los primeros N turnos (tutoriales).
##
## Serializable: cada entrada es un [Dictionary] descriptivo, no una
## [JugadaDePalabra] (que es [RefCounted] y no entra en un [code].tres[/code]).
## [IADePalabra] lo traduce contra el estado real y **solo lo usa si la jugada es
## legal**; si no, cae en la búsqueda normal.
## [codeblock]
## { "turno_propio": 1, "tipo": "jugar", "carta": "tranquera_cerrada" }
## { "turno_propio": 2, "tipo": "atacar", "carta": "hornera_de_rosaura", "objetivo": "firma" }
## { "turno_propio": 3, "tipo": "pasar" }
## [/codeblock]
@export var guion_forzado: Array[Dictionary] = []
## § 7.3 (perfil `senuelos`, el Cachuzo): probabilidad de tirar una carta mala
## boca abajo como señuelo cuando la mesa fía. 0 = nunca.
@export var prob_senuelo: float = 0.0

const TIPOS_DE_GUION: Array[String] = ["jugar", "atacar", "pasar"]


## Valida el perfil y devuelve la lista de errores (vacía si está bien). Nunca
## cuelga: el pipeline la usa para fallar con código != 0.
func validar() -> Array[String]:
	var errores: Array[String] = []
	if id.strip_edges().is_empty():
		errores.append("perfil sin id")
	if nombre.strip_edges().is_empty():
		errores.append("%s: sin nombre" % id)
	errores.append_array(_rango("peso_tempo", peso_tempo, 0.0, 2.0))
	errores.append_array(_rango("peso_cara", peso_cara, 0.0, 2.0))
	errores.append_array(_rango("peso_tabla", peso_tabla, 0.0, 2.0))
	errores.append_array(_rango("peso_mano", peso_mano, 0.0, 2.0))
	errores.append_array(_rango("sesgo_promesa", sesgo_promesa, 0.0, 1.0))
	errores.append_array(_rango("sesgo_desconfianza", sesgo_desconfianza, 0.0, 1.0))
	errores.append_array(_rango("umbral_trade", umbral_trade, 0.0, 1.0))
	errores.append_array(_rango("prob_senuelo", prob_senuelo, 0.0, 1.0))
	if not curva_preferida.is_empty() and curva_preferida.size() != 10:
		errores.append(
			"%s: curva_preferida tiene %d entradas (van 10 o ninguna)" % [id, curva_preferida.size()]
		)
	for c: int in curva_preferida:
		if c < 0 or c > Palabra.CREDITO_TOPE:
			errores.append("%s: coste de curva fuera de rango (%d)" % [id, c])
	for k: String in keywords_prioritarias:
		if not Palabra.KEYWORDS.has(k) and not CartaDePalabra.ARQUETIPOS.has(k):
			errores.append("%s: prioridad desconocida '%s'" % [id, k])
	for paso: Dictionary in guion_forzado:
		var tipo: String = String(paso.get("tipo", ""))
		if not TIPOS_DE_GUION.has(tipo):
			errores.append("%s: paso de guion con tipo '%s'" % [id, tipo])
		var turno: int = int(paso.get("turno_propio", 0))
		if turno < 1:
			errores.append("%s: paso de guion sin turno_propio" % id)
		if tipo != "pasar" and String(paso.get("carta", "")).is_empty():
			errores.append("%s: paso de guion '%s' sin carta" % [id, tipo])
	return errores


## Coste ideal para el turno propio [param turnos_jugados] (1 en adelante).
## -1 = el perfil no declara curva.
func coste_de_curva(turnos_jugados: int) -> int:
	if curva_preferida.is_empty():
		return -1
	var i: int = clampi(turnos_jugados - 1, 0, curva_preferida.size() - 1)
	return curva_preferida[i]


## Pasos de guion de un turno propio, en el orden declarado.
func guion_de_turno(turnos_jugados: int) -> Array[Dictionary]:
	var salida: Array[Dictionary] = []
	for paso: Dictionary in guion_forzado:
		if int(paso.get("turno_propio", 0)) == turnos_jugados:
			salida.append(paso)
	return salida


func _rango(campo: String, valor: float, minimo: float, maximo: float) -> Array[String]:
	if valor < minimo or valor > maximo:
		return ["%s: %s fuera de rango (%s)" % [id, campo, str(valor)]]
	return []
