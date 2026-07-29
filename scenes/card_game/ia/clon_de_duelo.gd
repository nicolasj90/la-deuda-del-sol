# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name ClonDeDuelo
extends RefCounted

## Copia profunda de un duelo para que [IADePalabra] pueda **simular** jugadas sin
## tocar la partida real.
##
## Por qué existe: el diseño § 7.2 pide un beam search que evalúe «el estado
## resultante», y § 7.2.1 prohíbe que la IA reimplemente la legalidad. La única
## forma de tener las dos cosas es aplicar las jugadas de verdad, sobre un motor
## clonado: la IA no simula reglas, las **ejecuta** en una copia.
##
## Qué se copia y qué se comparte:
## [codeblock]
## EstadoDuelo / EstadoFirma / EstadoCarta / PromesaDePalabra  -> copia nueva
## CartaDePalabra (definición) y ConfigMesa (mesa)             -> compartidas
## [/codeblock]
## Las dos compartidas son inmutables durante el duelo (§ 6.2.4: el estado mutable
## vive en [EstadoCarta], nunca en la definición), así que compartirlas es seguro y
## ahorra el 90 % del costo del clon.
##
## El clon **no** hereda ni la semilla ni el registro del original: recibe su
## propia semilla para que la simulación sea determinista y reproducible.

## Campos de cada clase que el clon copia. Están declarados para que
## `test_el_clon_cubre_todos_los_campos` falle si el motor gana un campo nuevo:
## un campo mutable olvidado acá es un bug silencioso de IA.
const CAMPOS_CARTA: Array[String] = [
	"uid",
	"def",
	"dueno",
	"zona",
	"interes",
	"mod_ataque",
	"mod_aguante",
	"mod_coste",
	"dano",
	"destruir_pendiente",
	"keywords_extra",
	"keywords_quitadas",
	"efectos_extra",
	"entro_en_turno",
	"ataco_en_turno",
	"coste_cero_en_turno",
	"marca_interes",
	"boca_abajo",
	"viaje_restante",
	"revela_al_fin_de_turno",
	"tipo_declarado",
	"usos_en_turno",
	"cuenta_en_turno",
]

const CAMPOS_FIRMA: Array[String] = [
	"lado",
	"aval",
	"credito",
	"credito_max",
	"mazo",
	"mano",
	"estrado",
	"mora",
	"empenadero",
	"descarte",
	"viaje",
	"promesas",
	"mora_de_mazo",
	"empeno_usado",
	"denuncia_usada",
	"turnos_jugados",
	"fiadores_jugados_en_turno",
	"ultimo_caido",
]

const CAMPOS_DUELO: Array[String] = [
	"mesa",
	"firmas",
	"turno",
	"activo",
	"fase",
	"terminado",
	"ganador",
	"motivo_fin",
	"por_uid",
]

const CAMPOS_PROMESA: Array[String] = [
	"orden",
	"dueno",
	"tipo",
	"plazo_restante",
	"plazo_original",
	"fiador_uid",
	"carta_origen",
	"bonus",
	"nacida_en_turno",
]

const ZONAS_DE_FIRMA: Array[Palabra.Zona] = [
	Palabra.Zona.MAZO,
	Palabra.Zona.MANO,
	Palabra.Zona.ESTRADO,
	Palabra.Zona.MORA,
	Palabra.Zona.EMPENADERO,
	Palabra.Zona.DESCARTE,
	Palabra.Zona.VIAJE,
]


## Motor nuevo con una copia del estado de [param original], listo para recibir
## jugadas. Los uid se conservan: una [JugadaDePalabra] armada contra el original
## es válida contra el clon.
static func clonar_motor(original: MotorDePalabra, semilla: int) -> MotorDePalabra:
	var copia: MotorDePalabra = MotorDePalabra.new(semilla)
	if original == null or original.estado == null:
		return copia
	copia.estado = clonar_estado(original.estado)
	# El motor reparte uid y orden de Promesa desde contadores privados: sin
	# sincronizarlos, un token invocado en la simulación pisaría una carta real
	# en `por_uid` y dos Promesas compartirían antigüedad.
	var uid_max: int = 0
	for uid: int in copia.estado.por_uid.keys():
		uid_max = maxi(uid_max, uid)
	copia._uid_siguiente = uid_max + 1
	var orden_max: int = 0
	for lado: int in [0, 1]:
		for p: PromesaDePalabra in copia.estado.firma(lado).promesas:
			orden_max = maxi(orden_max, p.orden)
	copia._orden_promesa = orden_max + 1
	return copia


static func clonar_estado(original: EstadoDuelo) -> EstadoDuelo:
	var copia: EstadoDuelo = EstadoDuelo.new()
	# La mesa es de solo lectura durante el duelo (§ 4): se comparte a propósito.
	copia.mesa = original.mesa
	copia.turno = original.turno
	copia.activo = original.activo
	copia.fase = original.fase
	copia.terminado = original.terminado
	copia.ganador = original.ganador
	copia.motivo_fin = original.motivo_fin
	# Primero todas las cartas (por_uid es la fuente): así las zonas y los
	# `ultimo_caido` se rearman apuntando a las copias, nunca al original.
	var mapa: Dictionary = {}
	for uid: int in original.por_uid.keys():
		var ec: EstadoCarta = original.por_uid[uid] as EstadoCarta
		if ec == null:
			continue
		mapa[uid] = clonar_carta(ec)
	copia.por_uid = mapa
	var firmas: Array[EstadoFirma] = []
	for f: EstadoFirma in original.firmas:
		firmas.append(_clonar_firma(f, mapa))
	copia.firmas = firmas
	return copia


static func clonar_carta(original: EstadoCarta) -> EstadoCarta:
	var copia: EstadoCarta = EstadoCarta.new()
	copia.uid = original.uid
	# La definición es inmutable (§ 6.2.4): se comparte.
	copia.def = original.def
	copia.dueno = original.dueno
	copia.zona = original.zona
	copia.interes = original.interes
	copia.mod_ataque = original.mod_ataque
	copia.mod_aguante = original.mod_aguante
	copia.mod_coste = original.mod_coste
	copia.dano = original.dano
	copia.destruir_pendiente = original.destruir_pendiente
	copia.keywords_extra = original.keywords_extra.duplicate()
	copia.keywords_quitadas = original.keywords_quitadas.duplicate()
	var efectos: Array[Dictionary] = []
	for e: Dictionary in original.efectos_extra:
		efectos.append(e.duplicate(true))
	copia.efectos_extra = efectos
	copia.entro_en_turno = original.entro_en_turno
	copia.ataco_en_turno = original.ataco_en_turno
	copia.coste_cero_en_turno = original.coste_cero_en_turno
	copia.marca_interes = original.marca_interes
	copia.boca_abajo = original.boca_abajo
	copia.viaje_restante = original.viaje_restante
	copia.revela_al_fin_de_turno = original.revela_al_fin_de_turno
	copia.tipo_declarado = original.tipo_declarado
	copia.usos_en_turno = original.usos_en_turno.duplicate(true)
	copia.cuenta_en_turno = original.cuenta_en_turno.duplicate(true)
	return copia


static func clonar_promesa(original: PromesaDePalabra) -> PromesaDePalabra:
	var copia: PromesaDePalabra = PromesaDePalabra.new()
	copia.orden = original.orden
	copia.dueno = original.dueno
	copia.tipo = original.tipo
	copia.plazo_restante = original.plazo_restante
	copia.plazo_original = original.plazo_original
	copia.fiador_uid = original.fiador_uid
	copia.carta_origen = original.carta_origen
	var bonus: Array[Dictionary] = []
	for op: Dictionary in original.bonus:
		bonus.append(op.duplicate(true))
	copia.bonus = bonus
	copia.nacida_en_turno = original.nacida_en_turno
	return copia


## Nombres de las variables de script de una clase del motor, para el test de
## cobertura del clon.
static func campos_de(objeto: Object) -> Array[String]:
	var salida: Array[String] = []
	for prop: Dictionary in objeto.get_property_list():
		if int(prop.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			salida.append(String(prop.get("name", "")))
	return salida


static func _clonar_firma(original: EstadoFirma, mapa: Dictionary) -> EstadoFirma:
	var copia: EstadoFirma = EstadoFirma.new()
	copia.lado = original.lado
	copia.aval = original.aval
	copia.credito = original.credito
	copia.credito_max = original.credito_max
	copia.mora_de_mazo = original.mora_de_mazo
	copia.empeno_usado = original.empeno_usado
	copia.denuncia_usada = original.denuncia_usada
	copia.turnos_jugados = original.turnos_jugados
	copia.fiadores_jugados_en_turno = original.fiadores_jugados_en_turno
	for z: Palabra.Zona in ZONAS_DE_FIRMA:
		var destino: Array[EstadoCarta] = copia.zona(z)
		destino.clear()
		for ec: EstadoCarta in original.zona(z):
			var clon: EstadoCarta = mapa.get(ec.uid, null) as EstadoCarta
			# Una carta que está en una zona pero no en `por_uid` sería un bug del
			# motor; el clon no lo tapa: la copia igual la lleva.
			destino.append(clon if clon != null else clonar_carta(ec))
	var promesas: Array[PromesaDePalabra] = []
	for p: PromesaDePalabra in original.promesas:
		promesas.append(clonar_promesa(p))
	copia.promesas = promesas
	if original.ultimo_caido != null:
		var caido: EstadoCarta = mapa.get(original.ultimo_caido.uid, null) as EstadoCarta
		copia.ultimo_caido = caido if caido != null else clonar_carta(original.ultimo_caido)
	return copia
