# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name EstadoCarta
extends RefCounted

## Instancia de una carta **dentro de un duelo**: acá vive todo el estado mutable.
##
## Cada copia tiene su propio [EstadoCarta] con su propio [member uid]. La
## definición ([member def]) es compartida y de solo lectura.

## Identificador único dentro del duelo. Es la moneda de cambio con la vista.
var uid: int = -1
var def: CartaDePalabra = null
## Lado dueño: 0 o 1.
var dueno: int = 0
var zona: Palabra.Zona = Palabra.Zona.MAZO

## Turnos de Interés devengados (§ 2.6). Sigue subiendo en el Empeñadero.
var interes: int = 0
## Modificadores permanentes de la instancia (+1/+1, buffs, etc.).
var mod_ataque: int = 0
var mod_aguante: int = 0
## Descuento/recargo permanente de coste (Fe de Erratas baja 1).
var mod_coste: int = 0
## Daño acumulado. El cuerpo muere cuando [member dano] >= aguante.
var dano: int = 0
## Marcada para destrucción directa (Testamento Apurado, Palabra Rota, etc.).
var destruir_pendiente: bool = false

## Keywords ganadas en runtime y keywords perdidas en runtime.
var keywords_extra: Array[String] = []
var keywords_quitadas: Array[String] = []
## Efectos otorgados en runtime (Cláusula al Dorso da una Letra chica).
var efectos_extra: Array[Dictionary] = []

## Turno global en el que entró al Estrado (para Al contado).
var entro_en_turno: int = -1
## Turno global en el que atacó (uno por turno).
var ataco_en_turno: int = -1
## Cuesta 0 este turno (Tasador Decano).
var coste_cero_en_turno: int = -1

## Estaba en mano/Empeñadero al empezar el turno de su dueño: si sigue ahí al
## terminarlo, devenga Interés («turno entero», § 2.6).
var marca_interes: bool = false

## Módulo «al fiado» (§ 4.2).
var boca_abajo: bool = false
var viaje_restante: int = 0
var revela_al_fin_de_turno: bool = false
## Tipo declarado al jugarla boca abajo (lo que la denuncia tiene que acertar).
var tipo_declarado: Palabra.Tipo = Palabra.Tipo.FIADOR

## Contadores «una vez por turno» por instancia: clave -> turno global.
var usos_en_turno: Dictionary = {}
## Contadores «N veces por turno» por instancia: clave -> [turno, cantidad].
var cuenta_en_turno: Dictionary = {}


static func crear(nuevo_uid: int, definicion: CartaDePalabra, lado: int) -> EstadoCarta:
	var ec: EstadoCarta = EstadoCarta.new()
	ec.uid = nuevo_uid
	ec.def = definicion
	ec.dueno = lado
	ec.tipo_declarado = definicion.tipo
	return ec


func id() -> String:
	return def.id if def != null else ""


func tipo() -> Palabra.Tipo:
	return def.tipo


func es_cuerpo() -> bool:
	return def.es_cuerpo()


## Keywords efectivas: las de la definición, más las ganadas, menos las perdidas.
## Una carta boca abajo **no tiene keywords reveladas** (§ 2, aclaración 2).
func keywords() -> Array[String]:
	if boca_abajo:
		return []
	var salida: Array[String] = []
	for kw: String in def.keywords:
		if not keywords_quitadas.has(kw):
			salida.append(kw)
	for kw: String in keywords_extra:
		if not salida.has(kw) and not keywords_quitadas.has(kw):
			salida.append(kw)
	return salida


func tiene(kw: String) -> bool:
	return keywords().has(kw)


## Todos los efectos (definición + otorgados) de un trigger.
func efectos_de(trigger: String) -> Array[Dictionary]:
	var salida: Array[Dictionary] = def.efectos_de(trigger)
	for e: Dictionary in efectos_extra:
		if String(e.get("trigger", "")) == trigger:
			salida.append(e)
	return salida


## Bono de ataque por Interés: topea en +5 sobre el base (§ 2.5).
func bono_interes() -> int:
	return mini(interes, Palabra.INTERES_ATAQUE_MAX)


## ¿Ya usó su «una vez por turno» de esta clave?
func uso_en(clave: String, turno: int) -> bool:
	return int(usos_en_turno.get(clave, -1)) == turno


func marcar_uso(clave: String, turno: int) -> void:
	usos_en_turno[clave] = turno


## Cantidad de veces que usó la clave en el turno dado.
func cuenta_de(clave: String, turno: int) -> int:
	var par: Array = cuenta_en_turno.get(clave, [-1, 0])
	return int(par[1]) if int(par[0]) == turno else 0


func sumar_cuenta(clave: String, turno: int) -> void:
	cuenta_en_turno[clave] = [turno, cuenta_de(clave, turno) + 1]
