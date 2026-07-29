# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name EventoDuelo
extends RefCounted

## Un evento del motor. El bus de eventos es **del motor**: la vista se suscribe a
## [signal MotorDePalabra.evento], nunca al revés (diseño § 6.2.1 — el addon
## card-framework no tiene ni una señal).

## Nombre del evento, en snake_case.
var tipo: String = ""
## Carga útil. Solo tipos primitivos y uids: el motor no conoce nodos de UI.
var datos: Dictionary = {}


static func crear(tipo_evento: String, datos_evento: Dictionary = {}) -> EventoDuelo:
	var e: EventoDuelo = EventoDuelo.new()
	e.tipo = tipo_evento
	e.datos = datos_evento
	return e


func como_texto() -> String:
	return "%s %s" % [tipo, str(datos)]


# --- Nombres de evento (el contrato con la vista y con la Balanza) ---
const DUELO_INICIADO: String = "duelo_iniciado"
const DUELO_TERMINADO: String = "duelo_terminado"
const TURNO_INICIADO: String = "turno_iniciado"
const TURNO_TERMINADO: String = "turno_terminado"
const CREDITO_CAMBIO: String = "credito_cambio"
const CARTA_ROBADA: String = "carta_robada"
const MORA_DE_MAZO: String = "mora_de_mazo"
const MANO_LLENA_AL_EMPENADERO: String = "mano_llena_al_empenadero"
const CARTA_JUGADA: String = "carta_jugada"
const CARTA_AL_VIAJE: String = "carta_al_viaje"
const CARTA_REVELADA: String = "carta_revelada"
const CARTA_DENUNCIADA: String = "carta_denunciada"
const CARTA_EMPENADA: String = "carta_empenada"
const CARTA_RESCATADA: String = "carta_rescatada"
const CARTA_ENTRO_AL_ESTRADO: String = "carta_entro_al_estrado"
const CARTA_MURIO: String = "carta_murio"
const CARTA_TRANSFORMADA: String = "carta_transformada"
const DE_PALABRA_RESUELTO: String = "de_palabra_resuelto"
const LETRA_CHICA_RESUELTA: String = "letra_chica_resuelta"
const ATAQUE: String = "ataque"
const DANO_A_FIRMA: String = "dano_a_firma"
const DANO_A_CARTA: String = "dano_a_carta"
const SELLO_CONSUMIDO: String = "sello_consumido"
const AVAL_CAMBIO: String = "aval_cambio"
const PROMESA_HECHA: String = "promesa_hecha"
const PROMESA_CUMPLIDA: String = "promesa_cumplida"
const PROMESA_ROTA: String = "promesa_rota"
const PROMESA_ANULADA: String = "promesa_anulada"
const PLAZO_CONSUMIDO: String = "plazo_consumido"
const QUEBRANTO_NACIDO: String = "quebranto_nacido"
const QUEBRANTO_A_LA_MORA: String = "quebranto_a_la_mora"
const QUEBRANTO_ENTRO_DESDE_LA_MORA: String = "quebranto_entro_desde_la_mora"
const QUEBRANTO_DISUELTO: String = "quebranto_disuelto"
const CUARTO_QUEBRANTO: String = "cuarto_quebranto"
const INVOCACION_FRUSTRADA: String = "invocacion_frustrada"
const JUGADA_RECHAZADA: String = "jugada_rechazada"
const INTERES_DEVENGADO: String = "interes_devengado"
