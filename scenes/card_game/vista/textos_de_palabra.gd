# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name TextosDePalabra
extends RefCounted

## Todo el texto visible del duelo, en castellano rioplatense.
##
## Vive separado de [VistaDuelo] por dos motivos: el motor no conoce texto de UI
## (§ 0) y el registro del duelo tiene que poder leerse sin abrir la escena.
##
## Ninguna función de acá toca nodos: son puras (evento + resolutor de nombres →
## línea de texto), así que el runner headless las puede probar igual.

## Cláusulas de Promesa (diseño § 3). `%d` es el plazo en turnos propios.
const CLAUSULAS: Dictionary = {
	Palabra.CL_NO_ATACAR: "No atacar con este Fiador por %d turno(s)",
	Palabra.CL_JUGAR_OTRO_FIADOR: "Jugar otro Fiador antes del fin de mi próximo turno",
	Palabra.CL_NO_DEFENDER: "Este Fiador no bloquea por %d turno(s)",
	Palabra.CL_CUMPLIR_CON_LUZ: "Cumplir otra Promesa antes del plazo",
	Palabra.CL_SIN_CLAUSULAS: "No jugar Cláusulas por %d turno(s)",
}

const ZONAS: Dictionary = {
	Palabra.Zona.MAZO: "Mazo",
	Palabra.Zona.MANO: "Mano",
	Palabra.Zona.ESTRADO: "Estrado",
	Palabra.Zona.MORA: "Mora",
	Palabra.Zona.EMPENADERO: "Empeñadero",
	Palabra.Zona.DESCARTE: "Descarte",
	Palabra.Zona.VIAJE: "Viaje",
	Palabra.Zona.FUERA: "Fuera",
}

const KEYWORDS: Dictionary = {
	Palabra.KW_AL_CONTADO: "Al contado",
	Palabra.KW_GARANTE: "Garante",
	Palabra.KW_SELLO: "Sello",
	Palabra.KW_DE_PALABRA: "De palabra",
	Palabra.KW_LETRA_CHICA: "Letra chica",
	Palabra.KW_INTERES: "Interés",
}

const MOTIVOS_FIN: Dictionary = {
	"aval": "el Aval llegó a cero",
	"aval_doble": "las dos Firmas cayeron juntas",
	"incobrable": "duelo incobrable: se cerró por tope de turnos",
}


## Texto de una cláusula con su plazo. Las cláusulas sin plazo en el término
## («jugar otro Fiador», «cumplir otra Promesa») ignoran el número.
static func clausula(tipo: String, plazo: int = 0) -> String:
	var plantilla: String = String(CLAUSULAS.get(tipo, tipo))
	if plantilla.contains("%d"):
		return plantilla % maxi(plazo, 1)
	return plantilla


static func zona(z: Palabra.Zona) -> String:
	return String(ZONAS.get(z, "?"))


static func keyword(kw: String) -> String:
	return String(KEYWORDS.get(kw, kw))


## Lista de keywords de una carta, ya en castellano.
static func keywords_de(lista: Array[String]) -> String:
	var partes: PackedStringArray = []
	for kw: String in lista:
		partes.append(keyword(kw))
	return " · ".join(partes)


static func lado(numero: int, lado_jugador: int) -> String:
	return "tu Firma" if numero == lado_jugador else "la Firma rival"


static func motivo_fin(motivo: String) -> String:
	return String(MOTIVOS_FIN.get(motivo, motivo))


## Una línea de registro por evento del motor (§ 6.2.1: el contrato con la vista
## son los nombres de [EventoDuelo]).
##
## [param nombre_de] resuelve un uid a un nombre de carta; la vista le pasa su
## propio resolutor porque el motor no manda nombres en la carga útil.
static func linea(e: EventoDuelo, nombre_de: Callable, lado_jugador: int = 0) -> String:
	var d: Dictionary = e.datos
	var quien: String = lado(int(d.get("lado", 0)), lado_jugador)
	var carta: String = _nombre(nombre_de, int(d.get("uid", -1)))
	match e.tipo:
		EventoDuelo.DUELO_INICIADO:
			return "Se abre el duelo. Empieza %s." % lado(int(d.get("primero", 0)), lado_jugador)
		EventoDuelo.DUELO_TERMINADO:
			return (
				"Fin del duelo: ganó %s (%s)."
				% [lado(int(d.get("ganador", 0)), lado_jugador), motivo_fin(String(d.get("motivo", "")))]
			)
		EventoDuelo.TURNO_INICIADO:
			return (
				"— Turno %d de %s (Crédito %d) —"
				% [int(d.get("turno", 0)), quien, int(d.get("credito", 0))]
			)
		EventoDuelo.TURNO_TERMINADO:
			return "%s cierra el turno." % _mayus(quien)
		EventoDuelo.CREDITO_CAMBIO:
			return "Crédito de %s: %d." % [quien, int(d.get("credito", 0))]
		EventoDuelo.CARTA_ROBADA:
			return "%s roba %s." % [_mayus(quien), carta]
		EventoDuelo.MORA_DE_MAZO:
			return (
				"El mazo de %s entró en mora (%d)." % [quien, int(d.get("contador", 0))]
			)
		EventoDuelo.MANO_LLENA_AL_EMPENADERO:
			return "Mano llena: %s se empeña en el Empeñadero de %s." % [carta, quien]
		EventoDuelo.CARTA_JUGADA:
			return "%s juega %s." % [_mayus(quien), carta]
		EventoDuelo.CARTA_AL_VIAJE:
			return "%s manda una carta al fiado: viaja boca abajo." % _mayus(quien)
		EventoDuelo.CARTA_REVELADA:
			return "Se revela %s." % carta
		EventoDuelo.CARTA_DENUNCIADA:
			return (
				"Denuncia sobre una carta en viaje: %s."
				% ("acertó, se rompe" if bool(d.get("acerto", false)) else "falló, el viaje se acorta")
			)
		EventoDuelo.CARTA_EMPENADA:
			return "%s empeña %s por +1 de Crédito." % [_mayus(quien), carta]
		EventoDuelo.CARTA_RESCATADA:
			return "%s rescata %s del Empeñadero." % [_mayus(quien), carta]
		EventoDuelo.CARTA_ENTRO_AL_ESTRADO:
			return "%s sube al Estrado de %s." % [carta, quien]
		EventoDuelo.CARTA_MURIO:
			return "Cae %s." % carta
		EventoDuelo.CARTA_TRANSFORMADA:
			return "%s se transforma." % carta
		EventoDuelo.DE_PALABRA_RESUELTO:
			return "De palabra de %s." % carta
		EventoDuelo.LETRA_CHICA_RESUELTA:
			return "Letra chica de %s." % carta
		EventoDuelo.ATAQUE:
			var obj: int = int(d.get("objetivo", -1))
			var contra: String = "la Firma" if obj < 0 else _nombre(nombre_de, obj)
			return "%s ataca a %s." % [carta, contra]
		EventoDuelo.DANO_A_FIRMA:
			return (
				"%s pierde %d de Aval (queda %d)."
				% [_mayus(quien), int(d.get("dano", 0)), int(d.get("aval", 0))]
			)
		EventoDuelo.DANO_A_CARTA:
			return "%s recibe %d de daño." % [carta, int(d.get("dano", 0))]
		EventoDuelo.SELLO_CONSUMIDO:
			return "El Sello de %s absorbe el golpe." % carta
		EventoDuelo.AVAL_CAMBIO:
			return (
				"Aval de %s: %+d (queda %d)."
				% [quien, int(d.get("delta", 0)), int(d.get("aval", 0))]
			)
		EventoDuelo.PROMESA_HECHA:
			var plazo: int = int(d.get("plazo_restante", 1))
			return "Promesa firmada: %s." % clausula(String(d.get("tipo", "")), plazo)
		EventoDuelo.PROMESA_CUMPLIDA:
			return "Promesa cumplida: %s." % clausula(String(d.get("tipo", "")))
		EventoDuelo.PROMESA_ROTA:
			return "Promesa rota: %s." % clausula(String(d.get("tipo", "")))
		EventoDuelo.PROMESA_ANULADA:
			return "Promesa anulada por el fin del duelo."
		EventoDuelo.PLAZO_CONSUMIDO:
			return (
				"Se consume un plazo: quedan %d turno(s) de %s."
				% [int(d.get("plazo_restante", 0)), clausula(String(d.get("tipo", "")))]
			)
		EventoDuelo.QUEBRANTO_NACIDO:
			return "Nace un Quebranto en %s." % quien
		EventoDuelo.QUEBRANTO_A_LA_MORA:
			return "El Estrado no da fe: el Quebranto va a la Mora de %s." % quien
		EventoDuelo.QUEBRANTO_ENTRO_DESDE_LA_MORA:
			return "Un Quebranto entra al Estrado desde la Mora de %s." % quien
		EventoDuelo.QUEBRANTO_DISUELTO:
			return "Se disuelve un Quebranto de %s." % quien
		EventoDuelo.CUARTO_QUEBRANTO:
			return "Ya hay tres Quebrantos: la mora se paga igual, %s pierde Aval." % quien
		EventoDuelo.INVOCACION_FRUSTRADA:
			return "Invocación frustrada: %s." % String(d.get("motivo", "el Estrado no da fe"))
		EventoDuelo.JUGADA_RECHAZADA:
			return "Jugada rechazada: %s." % String(d.get("motivo", ""))
		EventoDuelo.INTERES_DEVENGADO:
			return "%s devenga Interés (%d)." % [carta, int(d.get("interes", 0))]
	return e.como_texto()


## Mayúscula solo en la primera letra: [method String.capitalize] también
## capitaliza «Rival» y queda raro.
static func _mayus(texto: String) -> String:
	if texto.is_empty():
		return texto
	return texto.substr(0, 1).to_upper() + texto.substr(1)


static func _nombre(nombre_de: Callable, uid: int) -> String:
	if uid < 0:
		return "una carta"
	if not nombre_de.is_valid():
		return "la carta #%d" % uid
	var salida: String = String(nombre_de.call(uid))
	return salida if not salida.is_empty() else "la carta #%d" % uid
