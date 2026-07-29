# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name Palabra
extends RefCounted

## Vocabulario compartido del core de cartas «De Palabra».
##
## Solo enums y constantes: es la única dependencia común de todas las clases del
## motor. Sin estado, sin nodos. Todos los valores salen de
## [code]docs/cores/diseno-de-palabra.md[/code] (§ 1, § 2, § 3).

## Tipos de carta (biblia § 5).
enum Tipo { FIADOR, SOPORTE, CLAUSULA }

## Zonas del duelo. [code]VIAJE[/code] es el módulo «al fiado» (§ 4.2) y
## [code]MORA[/code] es la zona nueva de la revisión (§ 3.2.2).
enum Zona { MAZO, MANO, ESTRADO, MORA, EMPENADERO, DESCARTE, VIAJE, FUERA }

## Fases del turno. El motor solo acepta jugadas en [code]ACCIONES[/code].
enum Fase { SIN_INICIAR, INICIO_TURNO, ACCIONES, FIN_TURNO, TERMINADO }

## Tipos de jugada que el motor sabe ejecutar.
enum TipoJugada { PASAR, JUGAR, ATACAR, EMPENAR, RESCATAR, DENUNCIAR }

# --- Reglas base (§ 1) ---
const AVAL_INICIAL: int = 30
const CREDITO_TOPE: int = 10
const ESTRADO_MAX: int = 7
const MANO_MAX: int = 10
const MAZO_TAMANO: int = 30
const MANO_INICIAL_PRIMERO: int = 3
const MANO_INICIAL_SEGUNDO: int = 4
const TOPE_TURNOS: int = 30

# --- Promesas y Quebrantos (§ 3) ---
const PROMESAS_MAX: int = 3
const PLAZO_MAX: int = 3
const QUEBRANTOS_MAX: int = 3
const CUARTO_QUEBRANTO_AVAL: int = 2

# --- Keywords (§ 2) ---
const INTERES_ATAQUE_MAX: int = 5

# --- Al fiado (§ 4.2) ---
const AL_FIADO_DESCUENTO: int = 2
const AL_FIADO_VIAJE: int = 2

const KW_AL_CONTADO: String = "al_contado"
const KW_GARANTE: String = "garante"
const KW_SELLO: String = "sello"
const KW_DE_PALABRA: String = "de_palabra"
const KW_LETRA_CHICA: String = "letra_chica"
const KW_INTERES: String = "interes"

const KEYWORDS: Array[String] = [
	KW_AL_CONTADO,
	KW_GARANTE,
	KW_SELLO,
	KW_DE_PALABRA,
	KW_LETRA_CHICA,
	KW_INTERES,
]

# --- Cláusulas de Promesa disponibles en el Acto 1 (§ 3) ---
const CL_NO_ATACAR: String = "no_atacar"
const CL_JUGAR_OTRO_FIADOR: String = "jugar_otro_fiador"
const CL_NO_DEFENDER: String = "no_defender"
const CL_CUMPLIR_CON_LUZ: String = "cumplir_con_luz"
const CL_SIN_CLAUSULAS: String = "sin_clausulas"

const CLAUSULAS: Array[String] = [
	CL_NO_ATACAR,
	CL_JUGAR_OTRO_FIADOR,
	CL_NO_DEFENDER,
	CL_CUMPLIR_CON_LUZ,
	CL_SIN_CLAUSULAS,
]

## Cláusulas cuyo término habla del Fiador prometido: si ese Fiador muere se
## vuelven imposibles y se rompen en el acto (§ 3.1.1).
const CLAUSULAS_ATADAS_AL_FIADOR: Array[String] = [CL_NO_ATACAR, CL_NO_DEFENDER]

## Cláusulas que se pueden cumplir antes del plazo (las de «hacé X»); el resto
## se cumplen al vencer sin haber sido violadas.
const CLAUSULAS_DE_ACCION: Array[String] = [CL_JUGAR_OTRO_FIADOR, CL_CUMPLIR_CON_LUZ]

# --- Triggers de efecto (orden de resolución en MotorDePalabra) ---
const TR_CLAUSULA: String = "clausula"
const TR_DE_PALABRA: String = "de_palabra"
const TR_LETRA_CHICA: String = "letra_chica"
const TR_INICIO_TURNO_PROPIO: String = "inicio_turno_propio"
const TR_FIN_TURNO_PROPIO: String = "fin_turno_propio"
const TR_FIN_TURNO_RIVAL: String = "fin_turno_rival"
const TR_PROMESA_CUMPLIDA: String = "promesa_cumplida"
const TR_PROMESA_ROTA: String = "promesa_rota"

# --- Módulos por acto (§ 4) ---
const MOD_EMPENAR: String = "empenar"
const MOD_AL_FIADO: String = "al_fiado"
const MOD_BALANZA: String = "balanza"
const MOD_RITO: String = "modo_rito"

const MODULOS: Array[String] = [MOD_EMPENAR, MOD_AL_FIADO, MOD_BALANZA, MOD_RITO]

# --- Ids de tokens (§ 5.9) ---
const T_QUEBRANTO: String = "quebranto"
const T_DEUDO: String = "deudo"
const T_GALLINA_CUMPLIDORA: String = "gallina_cumplidora"
const T_COPIA_ESPEJO: String = "copia_espejo"
const T_LA_FORASTERA: String = "la_forastera"
const T_LA_VUELTA: String = "la_vuelta"


## Nombre legible de un tipo, para eventos y logs.
static func nombre_tipo(tipo: Tipo) -> String:
	match tipo:
		Tipo.FIADOR:
			return "Fiador"
		Tipo.SOPORTE:
			return "Soporte"
		Tipo.CLAUSULA:
			return "Cláusula"
	return "?"
