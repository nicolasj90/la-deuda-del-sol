# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name PromesaDePalabra
extends RefCounted

## Una Promesa pendiente (diseño § 3). Se ata a la **Firma**, no al Fiador: si el
## Fiador muere, la Promesa sobrevive (§ 3.1.1) salvo que su término hable de ese
## Fiador, y entonces se vuelve imposible y se rompe en el acto.

## Correlativo global del duelo. Define la antigüedad: los vencimientos resuelven
## de menor a mayor (§ 3.1.3).
var orden: int = 0
var dueno: int = 0
## Una de [constant Palabra.CLAUSULAS].
var tipo: String = ""
## Turnos propios que faltan. Baja 1 al empezar cada turno del dueño; a 0 vence.
## No se puede renovar ni extender (§ 3).
var plazo_restante: int = 0
var plazo_original: int = 0
## Fiador al que se refiere el término, o -1 si es una Promesa de la Firma sola.
var fiador_uid: int = -1
## Carta que la ofreció (para el registro y la vista).
var carta_origen: String = ""
## Ops que se aplican al cumplirla. Vacío = la Promesa solo vale por las cartas
## que premian cumplir (Lámpara, Fiel): el diseño no fija un bonus genérico.
var bonus: Array[Dictionary] = []
## Turno global en el que nació.
var nacida_en_turno: int = 0


static func crear(
	nuevo_orden: int,
	lado: int,
	clausula: String,
	plazo: int,
	uid_fiador: int,
	origen: String,
	ops_bonus: Array[Dictionary],
	turno: int
) -> PromesaDePalabra:
	var p: PromesaDePalabra = PromesaDePalabra.new()
	p.orden = nuevo_orden
	p.dueno = lado
	p.tipo = clausula
	p.plazo_restante = plazo
	p.plazo_original = plazo
	p.fiador_uid = uid_fiador
	p.carta_origen = origen
	p.bonus = ops_bonus
	p.nacida_en_turno = turno
	return p


## ¿El término habla del Fiador prometido? (§ 3.1.1)
func atada_al_fiador() -> bool:
	return Palabra.CLAUSULAS_ATADAS_AL_FIADOR.has(tipo)


## ¿Se puede cumplir antes del plazo, haciendo algo?
func es_de_accion() -> bool:
	return Palabra.CLAUSULAS_DE_ACCION.has(tipo)


func como_dict() -> Dictionary:
	return {
		"orden": orden,
		"dueno": dueno,
		"tipo": tipo,
		"plazo_restante": plazo_restante,
		"fiador_uid": fiador_uid,
		"carta_origen": carta_origen,
	}
