# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name MotorDePalabra
extends RefCounted

## Motor de reglas de «De Palabra»: **la única autoridad sobre la legalidad**.
##
## GDScript puro, sin [Node], sin card-framework: 100 % testeable headless
## (diseño § 0). Todo el azar pasa por un [RandomNumberGenerator] con semilla
## inyectada. La comunicación con la vista es de adentro hacia afuera: el motor
## emite [signal evento] y la vista se suscribe, nunca al revés (§ 6.2.1).
##
## Uso:
## [codeblock]
## var motor := MotorDePalabra.new(1234)
## motor.iniciar(ConfigMesa.base(), mazo_a, mazo_b, 0)
## for j in motor.jugadas_legales():
##     motor.ejecutar(j)
## motor.terminar_turno()
## [/codeblock]

## Único canal de salida del motor.
signal evento(e: EventoDuelo)

const OBJ_FIADOR_ALIADO: String = "fiador_aliado"
const OBJ_OTRO_FIADOR_ALIADO: String = "otro_fiador_aliado"
const OBJ_CUERPO_ALIADO: String = "cuerpo_aliado"
const OBJ_ENEMIGO_O_FIRMA: String = "enemigo_o_firma"
const OBJ_PROMESA_PROPIA: String = "promesa_propia"
const OBJ_CARTA_MANO_PROPIA: String = "carta_mano_propia"

## Guarda contra bucles de resolución de muertes/efectos. Nunca se debería tocar.
const TOPE_CASCADA: int = 64

var estado: EstadoDuelo = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Registro de todos los eventos del duelo. Lo usan los tests y el replay.
var registro: Array[EventoDuelo] = []

var _uid_siguiente: int = 1
var _orden_promesa: int = 1
var _primero: int = 0
var _terminando: bool = false


func _init(semilla: int = 0) -> void:
	rng.seed = semilla


# ---------------------------------------------------------------------------
# Arranque
# ---------------------------------------------------------------------------


## Arranca un duelo. Los mazos son listas de ids del catálogo.
## [param primero] es el lado que juega el turno 1.
func iniciar(
	mesa: ConfigMesa,
	mazo_a: Array[String],
	mazo_b: Array[String],
	primero: int = 0,
	mezclar: bool = true
) -> void:
	estado = EstadoDuelo.crear(mesa)
	registro = []
	_uid_siguiente = 1
	_orden_promesa = 1
	_terminando = false
	_primero = primero
	estado.activo = primero
	_armar_mazo(0, mazo_a, mezclar)
	_armar_mazo(1, mazo_b, mezclar)
	var segundo: int = estado.rival_de(primero)
	_emitir(EventoDuelo.DUELO_INICIADO, {"primero": primero, "mesa": _mesa_como_dict()})
	_robar(primero, Palabra.MANO_INICIAL_PRIMERO)
	_robar(segundo, Palabra.MANO_INICIAL_SEGUNDO)
	# «La Vuelta»: solo el segundo, para corregir la ventaja del primero (§ 1).
	var vuelta: EstadoCarta = _instanciar(Palabra.T_LA_VUELTA, segundo)
	if vuelta != null:
		_a_zona(vuelta, Palabra.Zona.MANO)
	estado.turno = 0
	_inicio_de_turno()


func _armar_mazo(lado: int, ids: Array[String], mezclar: bool) -> void:
	var f: EstadoFirma = estado.firma(lado)
	for id: String in ids:
		var ec: EstadoCarta = _instanciar(id, lado)
		if ec == null:
			continue
		ec.zona = Palabra.Zona.MAZO
		f.mazo.append(ec)
	if mezclar:
		_mezclar(f.mazo)


func _mezclar(cartas: Array[EstadoCarta]) -> void:
	for i: int in range(cartas.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: EstadoCarta = cartas[i]
		cartas[i] = cartas[j]
		cartas[j] = tmp


func _instanciar(id: String, lado: int) -> EstadoCarta:
	var def: CartaDePalabra = CatalogoDePalabra.obtener(id)
	if def == null:
		return null
	var ec: EstadoCarta = EstadoCarta.crear(_uid_siguiente, def, lado)
	_uid_siguiente += 1
	estado.por_uid[ec.uid] = ec
	return ec


func _mesa_como_dict() -> Dictionary:
	return {
		"empenar": estado.mesa.empenar,
		"al_fiado": estado.mesa.al_fiado,
		"balanza": estado.mesa.balanza,
		"modo_rito": estado.mesa.modo_rito,
	}


# ---------------------------------------------------------------------------
# Consultas públicas (la vista y la IA solo leen por acá)
# ---------------------------------------------------------------------------


## Coste actual en Crédito: base + mods + Interés, **topeado en 10** (§ 2.5).
func coste(ec: EstadoCarta) -> int:
	if ec == null:
		return 0
	if ec.coste_cero_en_turno == estado.turno:
		return 0
	var bruto: int = ec.def.coste_base + ec.mod_coste
	if ec.tiene(Palabra.KW_INTERES):
		bruto += ec.interes
	return clampi(bruto, 0, Palabra.CREDITO_TOPE)


## Coste jugándola al fiado: el descuento va sobre el coste **base**, no sobre el
## crecido por Interés (§ 2.7).
func coste_al_fiado(ec: EstadoCarta) -> int:
	if ec == null:
		return 0
	return maxi(0, ec.def.coste_base + ec.mod_coste - Palabra.AL_FIADO_DESCUENTO)


func ataque(ec: EstadoCarta) -> int:
	if ec == null:
		return 0
	var total: int = ec.def.ataque_base + ec.mod_ataque
	if ec.tiene(Palabra.KW_INTERES):
		total += ec.bono_interes()
	total += _bono_dinamico(ec, "ataque")
	return maxi(0, total)


func aguante(ec: EstadoCarta) -> int:
	if ec == null:
		return 0
	return maxi(0, ec.def.aguante_base + ec.mod_aguante + _bono_dinamico(ec, "aguante"))


func aguante_restante(ec: EstadoCarta) -> int:
	return aguante(ec) - ec.dano


## Daño de una Cláusula de daño; con Interés sube, topeado en +5 (§ 2.5).
func dano_de_clausula(ec: EstadoCarta) -> int:
	var total: int = ec.def.dano_base
	if ec.tiene(Palabra.KW_INTERES):
		total += ec.bono_interes()
	return maxi(0, total)


func _bono_dinamico(ec: EstadoCarta, campo: String) -> int:
	var bd: Dictionary = ec.def.bono_dinamico
	if bd.is_empty() or not bd.has(campo):
		return 0
	if ec.zona != Palabra.Zona.ESTRADO:
		return 0
	var cantidad: int = 0
	match String(bd.get("fuente", "")):
		"empenadero":
			cantidad = estado.firma(ec.dueno).empenadero.size()
		_:
			cantidad = 0
	var por: int = int(bd.get(campo, 0))
	var tope: int = int(bd.get("tope", 999))
	return mini(cantidad * por, tope)


## Un Quebranto es la forma física de una promesa rota, no un Fiador tuyo: ningún
## efecto que hable de «un Fiador aliado» lo toma como objetivo.
##
## Sin esta regla, `Fe de Erratas` lo devuelve a la mano y volver a jugarlo saltea
## el tope de 3 Quebrantos por lado (§ 3.2.1) — que es el tope que hace que la
## mora se pague igual.
func es_quebranto(ec: EstadoCarta) -> bool:
	return ec != null and ec.id() == Palabra.T_QUEBRANTO


## ¿Esta carta puede llevar una Promesa? Los Quebrantos y Nadia no (§ 3.2, § 5.8).
func puede_prometer_carta(uid: int) -> bool:
	var ec: EstadoCarta = estado.carta(uid)
	if ec == null:
		return false
	if not ec.def.puede_prometer:
		return false
	if ec.boca_abajo:
		return false
	return true


## Cláusulas que se le pueden ofrecer a una carta al jugarla.
func clausulas_ofrecibles(ec: EstadoCarta) -> Array[String]:
	var salida: Array[String] = []
	if ec == null or not ec.def.puede_prometer:
		return salida
	var f: EstadoFirma = estado.firma(ec.dueno)
	if f.promesas.size() >= Palabra.PROMESAS_MAX:
		return salida
	for c: String in Palabra.CLAUSULAS:
		if f.promesa_de(ec.uid, c) == null:
			salida.append(c)
	for p: Dictionary in ec.def.promesas:
		var t: String = String(p.get("tipo", ""))
		if not salida.has(t) and Palabra.CLAUSULAS.has(t):
			salida.append(t)
	return salida


## Objetivos legales de un ataque: si hay Garante enemigo revelado, solo Garantes;
## el atacante **elige cuál** (§ 2, aclaración 1 y 4). -1 = la Firma rival.
func objetivos_de_ataque(ec: EstadoCarta) -> Array[int]:
	var salida: Array[int] = []
	if ec == null:
		return salida
	var rival: int = estado.rival_de(ec.dueno)
	var garantes: Array[EstadoCarta] = estado.garantes(rival)
	if not garantes.is_empty():
		for g: EstadoCarta in garantes:
			salida.append(g.uid)
		return salida
	for obj: EstadoCarta in estado.atacables(rival):
		salida.append(obj.uid)
	salida.append(-1)
	return salida


## Objetivos legales para un requisito de objetivo de carta.
func objetivos_legales(ec: EstadoCarta, clase: String) -> Array[int]:
	var salida: Array[int] = []
	var f: EstadoFirma = estado.firma(ec.dueno)
	match clase:
		OBJ_FIADOR_ALIADO, OBJ_OTRO_FIADOR_ALIADO:
			for otro: EstadoCarta in f.estrado:
				if otro.boca_abajo or otro.tipo() != Palabra.Tipo.FIADOR:
					continue
				if es_quebranto(otro):
					continue
				if clase == OBJ_OTRO_FIADOR_ALIADO and otro.uid == ec.uid:
					continue
				salida.append(otro.uid)
		OBJ_CUERPO_ALIADO:
			for otro: EstadoCarta in f.estrado:
				if not otro.boca_abajo and not es_quebranto(otro):
					salida.append(otro.uid)
		OBJ_ENEMIGO_O_FIRMA:
			for otro: EstadoCarta in estado.atacables(estado.rival_de(ec.dueno)):
				salida.append(otro.uid)
			salida.append(-1)
		OBJ_PROMESA_PROPIA:
			for p: PromesaDePalabra in f.promesas_por_antiguedad():
				salida.append(p.orden)
		OBJ_CARTA_MANO_PROPIA:
			for otro: EstadoCarta in f.mano:
				if otro.uid != ec.uid:
					salida.append(otro.uid)
	return salida


# ---------------------------------------------------------------------------
# Enumeración de jugadas legales (§ 7.2.1: la IA nunca deduce legalidad)
# ---------------------------------------------------------------------------


func jugadas_legales(lado: int = -1) -> Array[JugadaDePalabra]:
	var salida: Array[JugadaDePalabra] = []
	if estado == null or estado.terminado or estado.fase != Palabra.Fase.ACCIONES:
		return salida
	var quien: int = estado.activo if lado < 0 else lado
	if quien != estado.activo:
		return salida
	salida.append(JugadaDePalabra.pasar(quien))
	var f: EstadoFirma = estado.firma(quien)
	for ec: EstadoCarta in f.mano.duplicate():
		for j: JugadaDePalabra in _variantes_de_juego(ec):
			if motivo_ilegal(j).is_empty():
				salida.append(j)
		if estado.mesa.empenar:
			var je: JugadaDePalabra = JugadaDePalabra.empenar(quien, ec.uid)
			if motivo_ilegal(je).is_empty():
				salida.append(je)
	for ec: EstadoCarta in f.estrado.duplicate():
		for obj: int in objetivos_de_ataque(ec):
			var ja: JugadaDePalabra = JugadaDePalabra.atacar(quien, ec.uid, obj)
			if motivo_ilegal(ja).is_empty():
				salida.append(ja)
	if estado.mesa.empenar:
		for ec: EstadoCarta in estado.firma(estado.rival_de(quien)).empenadero.duplicate():
			var jr: JugadaDePalabra = JugadaDePalabra.rescatar(quien, ec.uid)
			if motivo_ilegal(jr).is_empty():
				salida.append(jr)
	if estado.mesa.al_fiado:
		for ec: EstadoCarta in estado.firma(estado.rival_de(quien)).viaje.duplicate():
			var tipos: Array[Palabra.Tipo] = [
				Palabra.Tipo.FIADOR, Palabra.Tipo.SOPORTE, Palabra.Tipo.CLAUSULA
			]
			for t: Palabra.Tipo in tipos:
				var jd: JugadaDePalabra = JugadaDePalabra.denunciar(quien, ec.uid, t)
				if motivo_ilegal(jd).is_empty():
					salida.append(jd)
	return salida


func _variantes_de_juego(ec: EstadoCarta) -> Array[JugadaDePalabra]:
	var salida: Array[JugadaDePalabra] = []
	var objetivos: Array[int] = _objetivos_para_jugar(ec)
	var promesas: Array[Array] = [["", 0]]
	for c: String in clausulas_ofrecibles(ec):
		for plazo: int in range(1, Palabra.PLAZO_MAX + 1):
			promesas.append([c, plazo])
	for obj: int in objetivos:
		for par: Array in promesas:
			var j: JugadaDePalabra = JugadaDePalabra.jugar(
				ec.dueno, ec.uid, obj, String(par[0]), int(par[1])
			)
			salida.append(j)
	# Boca abajo el objetivo no se declara: la cláusula (y el objetivo) se eligen
	# al revelar (§ 3.1.5, § 4.2).
	if estado.mesa.al_fiado:
		var jf: JugadaDePalabra = JugadaDePalabra.jugar(ec.dueno, ec.uid)
		jf.al_fiado = true
		salida.append(jf)
	return salida


## Objetivos candidatos al jugar. Para un cuerpo el objetivo es **optativo** (un
## Fiador siempre produce el efecto de ser un cuerpo); para una Cláusula es
## obligatorio (§ 1.3).
func _objetivos_para_jugar(ec: EstadoCarta) -> Array[int]:
	if ec.def.objetivos.is_empty():
		return [-1]
	var clase: String = ec.def.objetivos[0]
	var candidatos: Array[int] = objetivos_legales(ec, clase)
	if clase == OBJ_ENEMIGO_O_FIRMA:
		return candidatos
	if candidatos.is_empty():
		return [-1]
	if ec.tipo() != Palabra.Tipo.CLAUSULA:
		candidatos.append(-1)
	return candidatos


# ---------------------------------------------------------------------------
# Legalidad
# ---------------------------------------------------------------------------


## "" si la jugada es legal; si no, el motivo (la vista lo muestra al hover).
func motivo_ilegal(j: JugadaDePalabra) -> String:
	if estado == null or estado.terminado:
		return "el duelo terminó"
	if estado.fase != Palabra.Fase.ACCIONES:
		return "no es momento de jugar"
	if j.lado != estado.activo:
		return "no es tu turno"
	match j.tipo:
		Palabra.TipoJugada.PASAR:
			return ""
		Palabra.TipoJugada.JUGAR:
			return _motivo_ilegal_jugar(j)
		Palabra.TipoJugada.ATACAR:
			return _motivo_ilegal_atacar(j)
		Palabra.TipoJugada.EMPENAR:
			return _motivo_ilegal_empenar(j)
		Palabra.TipoJugada.RESCATAR:
			return _motivo_ilegal_rescatar(j)
		Palabra.TipoJugada.DENUNCIAR:
			return _motivo_ilegal_denunciar(j)
	return "jugada desconocida"


func _motivo_ilegal_jugar(j: JugadaDePalabra) -> String:
	var ec: EstadoCarta = estado.carta(j.carta_uid)
	if ec == null or ec.dueno != j.lado or ec.zona != Palabra.Zona.MANO:
		return "esa carta no está en tu mano"
	var f: EstadoFirma = estado.firma(j.lado)
	if j.al_fiado:
		if not estado.mesa.al_fiado:
			return "en esta mesa no se fía"
		# Una carta que viaja no puede llevar Promesa (§ 3.1.5).
		if not j.promesa_tipo.is_empty():
			return "una carta que viaja no puede llevar Promesa"
		if f.credito < coste_al_fiado(ec):
			return "no te alcanza el Crédito"
		return ""
	if f.credito < coste(ec):
		return "no te alcanza el Crédito"
	if ec.es_cuerpo() and f.estrado_lleno():
		return "el Estrado no da fe"
	var motivo_promesa: String = _motivo_promesa_ilegal(ec, j.promesa_tipo, j.promesa_plazo)
	if not motivo_promesa.is_empty():
		return motivo_promesa
	if not ec.def.objetivos.is_empty():
		var clase: String = ec.def.objetivos[0]
		var legales: Array[int] = objetivos_legales(ec, clase)
		if ec.tipo() == Palabra.Tipo.CLAUSULA:
			if legales.is_empty():
				return "no hay objetivo legal"
			if not legales.has(j.objetivo_uid):
				return "ese objetivo no es legal"
		elif j.objetivo_uid != -1 and not legales.has(j.objetivo_uid):
			return "ese objetivo no es legal"
	if ec.tipo() == Palabra.Tipo.CLAUSULA and not _clausula_puede_tener_efecto(ec):
		return "no puede producir ningún efecto legal"
	return ""


func _motivo_promesa_ilegal(ec: EstadoCarta, clausula: String, plazo: int) -> String:
	if clausula.is_empty():
		return ""
	if not Palabra.CLAUSULAS.has(clausula):
		return "esa cláusula no existe"
	if plazo < 1 or plazo > Palabra.PLAZO_MAX:
		return "el plazo va de 1 a 3 turnos"
	if not ec.def.puede_prometer:
		return "esta carta no puede hacer Promesas"
	var f: EstadoFirma = estado.firma(ec.dueno)
	if f.promesas.size() >= Palabra.PROMESAS_MAX:
		return "ya tenés 3 Promesas pendientes"
	if f.promesa_de(ec.uid, clausula) != null:
		return "esa Promesa ya está hecha y no se renueva"
	return ""


## § 1.3: una Cláusula que no puede producir ningún efecto no se puede jugar.
func _clausula_puede_tener_efecto(ec: EstadoCarta) -> bool:
	var ops: Array[Dictionary] = ec.efectos_de(Palabra.TR_CLAUSULA)
	if ops.is_empty():
		return true
	for e: Dictionary in ops:
		if _op_puede_tener_efecto(ec, e):
			return true
	return false


func _op_puede_tener_efecto(ec: EstadoCarta, e: Dictionary) -> bool:
	var f: EstadoFirma = estado.firma(ec.dueno)
	match String(e.get("op", "")):
		"romper_promesa":
			return not f.promesas.is_empty()
		"cumplir_todas_las_promesas":
			return not f.promesas.is_empty()
		"disolver_quebrantos":
			return not f.quebrantos().is_empty()
		"repetir_de_palabra":
			return not _fiadores_con_de_palabra(ec.dueno).is_empty()
		"buff":
			if String(e.get("objetivo", "")) == "todos_fiadores_propios":
				return not _fiadores_propios(ec.dueno).is_empty()
			return true
		"dar_interes_en_mano":
			return f.mano.size() > 1
		"jugar_al_fiado_gratis":
			return estado.mesa.al_fiado and f.mano.size() > 1
	return true


func _motivo_ilegal_atacar(j: JugadaDePalabra) -> String:
	var ec: EstadoCarta = estado.carta(j.carta_uid)
	if ec == null or ec.dueno != j.lado or ec.zona != Palabra.Zona.ESTRADO:
		return "esa carta no está en tu Estrado"
	if ec.boca_abajo:
		return "una carta que viaja no ataca"
	if ec.tipo() != Palabra.Tipo.FIADOR:
		return "un Soporte no ataca"
	if ec.id() == Palabra.T_QUEBRANTO:
		return "un Quebranto ataca solo, y a tu Firma"
	if ec.ataco_en_turno == estado.turno:
		return "ya atacó este turno"
	if ec.entro_en_turno == estado.turno and not ec.tiene(Palabra.KW_AL_CONTADO):
		return "entró este turno y no es Al contado"
	if not objetivos_de_ataque(ec).has(j.objetivo_uid):
		return "los Garantes en pie no dejan pasar"
	return ""


func _motivo_ilegal_empenar(j: JugadaDePalabra) -> String:
	if not estado.mesa.empenar:
		return "en esta mesa no hay Empeñadero"
	var f: EstadoFirma = estado.firma(j.lado)
	if f.empeno_usado:
		return "ya empeñaste este turno"
	var ec: EstadoCarta = estado.carta(j.carta_uid)
	if ec == null or ec.dueno != j.lado or ec.zona != Palabra.Zona.MANO:
		return "esa carta no está en tu mano"
	return ""


func _motivo_ilegal_rescatar(j: JugadaDePalabra) -> String:
	if not estado.mesa.empenar:
		return "en esta mesa no hay Empeñadero"
	var ec: EstadoCarta = estado.carta(j.carta_uid)
	if ec == null or ec.zona != Palabra.Zona.EMPENADERO or ec.dueno == j.lado:
		return "esa prenda no es rescatable"
	if estado.firma(j.lado).credito < coste(ec):
		return "no te alcanza el Crédito"
	return ""


func _motivo_ilegal_denunciar(j: JugadaDePalabra) -> String:
	if not estado.mesa.al_fiado:
		return "en esta mesa no se fía"
	var f: EstadoFirma = estado.firma(j.lado)
	if f.denuncia_usada:
		return "ya denunciaste este turno"
	var ec: EstadoCarta = estado.carta(j.carta_uid)
	if ec == null or ec.zona != Palabra.Zona.VIAJE or ec.dueno == j.lado:
		return "esa carta no está viajando"
	return ""


# ---------------------------------------------------------------------------
# Ejecución
# ---------------------------------------------------------------------------


func ejecutar(j: JugadaDePalabra) -> bool:
	var motivo: String = motivo_ilegal(j)
	if not motivo.is_empty():
		_emitir(
			EventoDuelo.JUGADA_RECHAZADA, {"jugada": j.como_texto(), "motivo": motivo}
		)
		return false
	match j.tipo:
		Palabra.TipoJugada.PASAR:
			terminar_turno()
		Palabra.TipoJugada.JUGAR:
			_jugar(j)
		Palabra.TipoJugada.ATACAR:
			_atacar(j)
		Palabra.TipoJugada.EMPENAR:
			_empenar(j)
		Palabra.TipoJugada.RESCATAR:
			_rescatar(j)
		Palabra.TipoJugada.DENUNCIAR:
			_denunciar(j)
	return true


func _jugar(j: JugadaDePalabra) -> void:
	var ec: EstadoCarta = estado.carta(j.carta_uid)
	var f: EstadoFirma = estado.firma(j.lado)
	if j.al_fiado:
		_pagar(j.lado, coste_al_fiado(ec))
		_a_zona(ec, Palabra.Zona.VIAJE)
		ec.boca_abajo = true
		ec.viaje_restante = Palabra.AL_FIADO_VIAJE
		ec.tipo_declarado = ec.def.tipo
		_emitir(EventoDuelo.CARTA_AL_VIAJE, {"uid": ec.uid, "lado": j.lado})
		return
	_pagar(j.lado, coste(ec))
	_emitir(
		EventoDuelo.CARTA_JUGADA,
		{"uid": ec.uid, "id": ec.id(), "lado": j.lado, "objetivo": j.objetivo_uid}
	)
	var ctx: Dictionary = {"objetivo_uid": j.objetivo_uid, "origen_uid": ec.uid}
	if ec.tipo() == Palabra.Tipo.CLAUSULA:
		_a_zona(ec, Palabra.Zona.DESCARTE)
		_resolver_efectos(ec, Palabra.TR_CLAUSULA, ctx)
		if not j.promesa_tipo.is_empty():
			_registrar_promesa(ec, j.promesa_tipo, j.promesa_plazo)
		# Se rompe si jugás una Cláusula (§ 3). Se chequea **después** de resolver:
		# si la Cláusula era El Amanecer, cumplir gana (§ 3.1.4).
		_romper_por_clausula(j.lado)
		_resolver_muertes()
		return
	_a_zona(ec, Palabra.Zona.ESTRADO)
	ec.entro_en_turno = estado.turno
	ec.dano = 0
	_emitir(EventoDuelo.CARTA_ENTRO_AL_ESTRADO, {"uid": ec.uid, "id": ec.id(), "lado": j.lado})
	if not j.promesa_tipo.is_empty():
		_registrar_promesa(ec, j.promesa_tipo, j.promesa_plazo)
	if ec.tipo() == Palabra.Tipo.FIADOR:
		f.fiadores_jugados_en_turno += 1
		_cumplir_jugar_otro_fiador(j.lado, ec.uid)
	_resolver_efectos(ec, Palabra.TR_DE_PALABRA, ctx)
	_resolver_muertes()


func _atacar(j: JugadaDePalabra) -> void:
	var ec: EstadoCarta = estado.carta(j.carta_uid)
	ec.ataco_en_turno = estado.turno
	_emitir(EventoDuelo.ATAQUE, {"uid": ec.uid, "objetivo": j.objetivo_uid})
	# «no atacar con este Fiador»: se rompe en el acto (§ 3).
	var p: PromesaDePalabra = estado.firma(ec.dueno).promesa_de(ec.uid, Palabra.CL_NO_ATACAR)
	if p != null:
		_romper_promesa(p)
	if j.objetivo_uid == -1:
		_dano_a_firma(estado.rival_de(ec.dueno), ataque(ec), "ataque")
	else:
		var obj: EstadoCarta = estado.carta(j.objetivo_uid)
		var golpe: int = ataque(ec)
		var contragolpe: int = ataque(obj)
		_dano_a_carta(obj, golpe)
		_dano_a_carta(ec, contragolpe)
	_resolver_muertes()


func _empenar(j: JugadaDePalabra) -> void:
	var ec: EstadoCarta = estado.carta(j.carta_uid)
	var f: EstadoFirma = estado.firma(j.lado)
	f.empeno_usado = true
	_a_zona(ec, Palabra.Zona.EMPENADERO)
	_emitir(EventoDuelo.CARTA_EMPENADA, {"uid": ec.uid, "lado": j.lado})
	_sumar_credito(j.lado, 1)


func _rescatar(j: JugadaDePalabra) -> void:
	var ec: EstadoCarta = estado.carta(j.carta_uid)
	_pagar(j.lado, coste(ec))
	ec.dueno = j.lado
	_a_zona_de(ec, j.lado, Palabra.Zona.MANO)
	_emitir(EventoDuelo.CARTA_RESCATADA, {"uid": ec.uid, "lado": j.lado})


func _denunciar(j: JugadaDePalabra) -> void:
	var ec: EstadoCarta = estado.carta(j.carta_uid)
	var f: EstadoFirma = estado.firma(j.lado)
	f.denuncia_usada = true
	var acerto: bool = ec.def.tipo == j.tipo_declarado
	_emitir(
		EventoDuelo.CARTA_DENUNCIADA,
		{"uid": ec.uid, "acerto": acerto, "declarado": int(j.tipo_declarado)}
	)
	if acerto:
		_a_zona(ec, Palabra.Zona.DESCARTE)
		ec.boca_abajo = false
		ec.viaje_restante = 0
	else:
		ec.viaje_restante = maxi(0, ec.viaje_restante - 1)


func _pagar(lado: int, cuanto: int) -> void:
	var f: EstadoFirma = estado.firma(lado)
	f.credito = maxi(0, f.credito - cuanto)
	_emitir(EventoDuelo.CREDITO_CAMBIO, {"lado": lado, "credito": f.credito})


func _sumar_credito(lado: int, cuanto: int) -> void:
	var f: EstadoFirma = estado.firma(lado)
	# El Crédito de empeño no puede pasar el tope de 10 del turno (§ 3.3).
	f.credito = mini(Palabra.CREDITO_TOPE, f.credito + cuanto)
	_emitir(EventoDuelo.CREDITO_CAMBIO, {"lado": lado, "credito": f.credito})


# ---------------------------------------------------------------------------
# Turnos
# ---------------------------------------------------------------------------


func _inicio_de_turno() -> void:
	if estado.terminado:
		return
	estado.turno += 1
	estado.fase = Palabra.Fase.INICIO_TURNO
	var lado: int = estado.activo
	var f: EstadoFirma = estado.firma(lado)
	f.turnos_jugados += 1
	f.credito_max = mini(f.credito_max + 1, Palabra.CREDITO_TOPE)
	f.credito = f.credito_max
	f.reiniciar_flags_de_turno()
	_emitir(
		EventoDuelo.TURNO_INICIADO,
		{"turno": estado.turno, "lado": lado, "credito": f.credito}
	)
	# Se marca **antes** de robar: la carta que entra a mitad de turno no pasó un
	# turno entero en la mano (§ 2.6).
	_marcar_interes(lado)
	_avanzar_viajes(lado)
	_vencimientos(lado)
	# El primer jugador no roba en su turno 1 (§ 1).
	if estado.turno > 1:
		_robar(lado, 1)
	_disparar(Palabra.TR_INICIO_TURNO_PROPIO, lado)
	_reponer_mora(0)
	_reponer_mora(1)
	_resolver_muertes()
	if not estado.terminado:
		estado.fase = Palabra.Fase.ACCIONES


func terminar_turno() -> void:
	if estado == null or estado.terminado:
		return
	var lado: int = estado.activo
	estado.fase = Palabra.Fase.FIN_TURNO
	_revelar_al_fin_de_turno(lado)
	_quebrantos_pegan(lado)
	_disparar(Palabra.TR_FIN_TURNO_PROPIO, lado)
	# «Al final de cada turno rival»: el efecto es del rival del que está jugando.
	_disparar(Palabra.TR_FIN_TURNO_RIVAL, estado.rival_de(lado))
	_resolver_muertes()
	_devengar_interes(lado)
	var f: EstadoFirma = estado.firma(lado)
	f.credito = 0
	_emitir(EventoDuelo.TURNO_TERMINADO, {"turno": estado.turno, "lado": lado})
	if estado.terminado:
		return
	if estado.turno >= estado.mesa.tope_turnos:
		_duelo_incobrable()
		return
	estado.activo = estado.rival_de(lado)
	_inicio_de_turno()


func _duelo_incobrable() -> void:
	var a: int = estado.firma(0).aval
	var b: int = estado.firma(1).aval
	var ganador: int = 0
	if a > b:
		ganador = 0
	elif b > a:
		ganador = 1
	else:
		# Empate: pierde quien desafió (§ 1.2).
		ganador = estado.rival_de(estado.mesa.desafiante)
	_terminar_duelo(ganador, "incobrable")


func _terminar_duelo(ganador: int, motivo: String) -> void:
	if _terminando or estado.terminado:
		return
	_terminando = true
	estado.terminado = true
	estado.ganador = ganador
	estado.motivo_fin = motivo
	estado.fase = Palabra.Fase.TERMINADO
	# Las Promesas pendientes se anulan al terminar el duelo… salvo en modo_rito,
	# donde cuentan como rotas: el rito no se gana, se cumple (§ 3.1.2).
	for lado: int in [0, 1]:
		for p: PromesaDePalabra in estado.firma(lado).promesas_por_antiguedad():
			if estado.mesa.modo_rito:
				_romper_promesa(p)
			else:
				estado.firma(lado).promesas.erase(p)
				_emitir(EventoDuelo.PROMESA_ANULADA, p.como_dict())
	_emitir(EventoDuelo.DUELO_TERMINADO, {"ganador": ganador, "motivo": motivo})
	_terminando = false


func _chequear_aval() -> void:
	if estado.terminado:
		return
	var a_muerto: bool = estado.firma(0).aval <= 0
	var b_muerto: bool = estado.firma(1).aval <= 0
	if a_muerto and b_muerto:
		_terminar_duelo(estado.rival_de(estado.mesa.desafiante), "aval_doble")
	elif a_muerto:
		_terminar_duelo(1, "aval")
	elif b_muerto:
		_terminar_duelo(0, "aval")


# ---------------------------------------------------------------------------
# Robo, zonas y mora de mazo
# ---------------------------------------------------------------------------


func _robar(lado: int, cuantas: int) -> Array[EstadoCarta]:
	var robadas: Array[EstadoCarta] = []
	var f: EstadoFirma = estado.firma(lado)
	for _i: int in cuantas:
		if f.mazo.is_empty():
			# Mora de mazo: acumulativa, 1, 2, 3… (§ 1.1).
			f.mora_de_mazo += 1
			_emitir(EventoDuelo.MORA_DE_MAZO, {"lado": lado, "contador": f.mora_de_mazo})
			_dano_a_firma(lado, f.mora_de_mazo, "mora_de_mazo")
			if estado.terminado:
				break
			continue
		var ec: EstadoCarta = f.mazo.pop_front()
		if f.mano_llena():
			# El excedente se empeña, no se destruye en silencio (§ 6.2.7).
			_a_zona(ec, Palabra.Zona.EMPENADERO)
			_emitir(EventoDuelo.MANO_LLENA_AL_EMPENADERO, {"uid": ec.uid, "lado": lado})
		else:
			_a_zona(ec, Palabra.Zona.MANO)
			_emitir(EventoDuelo.CARTA_ROBADA, {"uid": ec.uid, "lado": lado})
		robadas.append(ec)
	return robadas


func _a_zona(ec: EstadoCarta, z: Palabra.Zona) -> void:
	_a_zona_de(ec, ec.dueno, z)


func _a_zona_de(ec: EstadoCarta, lado: int, z: Palabra.Zona) -> void:
	_quitar_de_zona(ec)
	ec.dueno = lado
	ec.zona = z
	if z == Palabra.Zona.MANO or z == Palabra.Zona.EMPENADERO:
		ec.boca_abajo = false
	estado.firma(lado).zona(z).append(ec)


func _quitar_de_zona(ec: EstadoCarta) -> void:
	for lado: int in [0, 1]:
		var f: EstadoFirma = estado.firma(lado)
		for z: Palabra.Zona in [
			Palabra.Zona.MAZO,
			Palabra.Zona.MANO,
			Palabra.Zona.ESTRADO,
			Palabra.Zona.MORA,
			Palabra.Zona.EMPENADERO,
			Palabra.Zona.DESCARTE,
			Palabra.Zona.VIAJE,
		]:
			var arr: Array[EstadoCarta] = f.zona(z)
			var i: int = arr.find(ec)
			if i >= 0:
				arr.remove_at(i)
				return


# ---------------------------------------------------------------------------
# Interés
# ---------------------------------------------------------------------------


func _marcar_interes(lado: int) -> void:
	var f: EstadoFirma = estado.firma(lado)
	for ec: EstadoCarta in f.mano:
		ec.marca_interes = true
	for ec: EstadoCarta in f.empenadero:
		ec.marca_interes = true


## Un turno **entero** en tu mano (o en el Empeñadero, § 2.6) devenga 1 de Interés.
func _devengar_interes(lado: int) -> void:
	var f: EstadoFirma = estado.firma(lado)
	var zonas: Array[Array] = [f.mano, f.empenadero]
	for arr: Array in zonas:
		for ec: EstadoCarta in arr:
			if ec.marca_interes and ec.tiene(Palabra.KW_INTERES):
				ec.interes += 1
				_emitir(EventoDuelo.INTERES_DEVENGADO, {"uid": ec.uid, "interes": ec.interes})
	for ec_todas: EstadoCarta in estado.por_uid.values():
		ec_todas.marca_interes = false


# ---------------------------------------------------------------------------
# Módulo al fiado
# ---------------------------------------------------------------------------


func _avanzar_viajes(lado: int) -> void:
	var f: EstadoFirma = estado.firma(lado)
	for ec: EstadoCarta in f.viaje.duplicate():
		ec.viaje_restante -= 1
		if ec.viaje_restante <= 0:
			_revelar(ec)


func _revelar_al_fin_de_turno(lado: int) -> void:
	var f: EstadoFirma = estado.firma(lado)
	for ec: EstadoCarta in f.viaje.duplicate():
		if ec.revela_al_fin_de_turno:
			_revelar(ec)


func _revelar(ec: EstadoCarta) -> void:
	ec.boca_abajo = false
	ec.revela_al_fin_de_turno = false
	ec.viaje_restante = 0
	ec.mod_ataque += estado.mesa.bono_entrega_ataque
	ec.mod_aguante += estado.mesa.bono_entrega_aguante
	_emitir(EventoDuelo.CARTA_REVELADA, {"uid": ec.uid, "id": ec.id(), "lado": ec.dueno})
	if ec.tipo() == Palabra.Tipo.CLAUSULA:
		_a_zona(ec, Palabra.Zona.DESCARTE)
		_resolver_efectos(ec, Palabra.TR_CLAUSULA, {"origen_uid": ec.uid, "objetivo_uid": -1})
		_resolver_muertes()
		return
	if estado.firma(ec.dueno).estrado_lleno():
		_a_zona(ec, Palabra.Zona.DESCARTE)
		_emitir(
			EventoDuelo.INVOCACION_FRUSTRADA,
			{"uid": ec.uid, "motivo": "el Estrado no da fe"}
		)
		return
	_a_zona(ec, Palabra.Zona.ESTRADO)
	ec.entro_en_turno = estado.turno
	_emitir(EventoDuelo.CARTA_ENTRO_AL_ESTRADO, {"uid": ec.uid, "id": ec.id(), "lado": ec.dueno})
	_resolver_efectos(ec, Palabra.TR_DE_PALABRA, {"origen_uid": ec.uid, "objetivo_uid": -1})
	_resolver_muertes()


# ---------------------------------------------------------------------------
# Daño, muerte y Letra chica
# ---------------------------------------------------------------------------


func _dano_a_firma(lado: int, cuanto: int, motivo: String) -> void:
	if cuanto <= 0:
		return
	var f: EstadoFirma = estado.firma(lado)
	f.aval -= cuanto
	_emitir(
		EventoDuelo.DANO_A_FIRMA, {"lado": lado, "dano": cuanto, "aval": f.aval, "motivo": motivo}
	)
	_chequear_aval()


func _cambiar_aval(lado: int, delta: int) -> void:
	if delta == 0:
		return
	var f: EstadoFirma = estado.firma(lado)
	f.aval += delta
	_emitir(EventoDuelo.AVAL_CAMBIO, {"lado": lado, "delta": delta, "aval": f.aval})
	if delta < 0:
		_chequear_aval()


func _dano_a_carta(ec: EstadoCarta, cuanto: int) -> void:
	if ec == null:
		return
	# Sello ignora la próxima instancia de daño **mayor que 0** (§ 2.4).
	if cuanto <= 0:
		_emitir(EventoDuelo.DANO_A_CARTA, {"uid": ec.uid, "dano": 0})
		return
	if ec.tiene(Palabra.KW_SELLO):
		ec.keywords_quitadas.append(Palabra.KW_SELLO)
		_emitir(EventoDuelo.SELLO_CONSUMIDO, {"uid": ec.uid})
		return
	ec.dano += cuanto
	_emitir(EventoDuelo.DANO_A_CARTA, {"uid": ec.uid, "dano": cuanto, "acumulado": ec.dano})


func _destruir(ec: EstadoCarta) -> void:
	if ec == null or ec.zona != Palabra.Zona.ESTRADO:
		return
	ec.destruir_pendiente = true


## Resuelve todas las muertes pendientes. La Letra chica corre **después** de que
## la carta salió del Estrado, y en orden de posición izquierda a derecha
## (§ 2, § 3.2.3).
func _resolver_muertes() -> void:
	var vueltas: int = 0
	while vueltas < TOPE_CASCADA:
		vueltas += 1
		var candidatos: Array[EstadoCarta] = []
		for lado: int in [0, 1]:
			for ec: EstadoCarta in estado.firma(lado).estrado:
				if ec.destruir_pendiente or ec.dano >= aguante(ec):
					candidatos.append(ec)
		if candidatos.is_empty():
			return
		var muertos: Array[EstadoCarta] = []
		for ec: EstadoCarta in candidatos:
			if _seria_destruido(ec):
				continue
			muertos.append(ec)
		if muertos.is_empty():
			return
		for ec: EstadoCarta in muertos:
			var f: EstadoFirma = estado.firma(ec.dueno)
			_a_zona(ec, Palabra.Zona.DESCARTE)
			ec.destruir_pendiente = false
			# Un Quebranto no cuenta como «Fiador aliado caído»: refrendarlo lo
			# devolvería al Estrado salteando el tope de 3 por lado (§ 3.2.1), y una
			# promesa rota no se vuelve a firmar.
			if ec.tipo() == Palabra.Tipo.FIADOR and ec.id() != Palabra.T_QUEBRANTO:
				f.ultimo_caido = ec
			_emitir(EventoDuelo.CARTA_MURIO, {"uid": ec.uid, "id": ec.id(), "lado": ec.dueno})
			_romper_promesas_imposibles(ec)
		for ec: EstadoCarta in muertos:
			var ctx: Dictionary = {"origen_uid": ec.uid, "objetivo_uid": -1}
			_resolver_efectos(ec, Palabra.TR_LETRA_CHICA, ctx)
			_emitir(EventoDuelo.LETRA_CHICA_RESUELTA, {"uid": ec.uid, "id": ec.id()})
		_reponer_mora(0)
		_reponer_mora(1)


## «Fiel, el que Espera»: la primera vez por turno que sería destruido, no lo es;
## consume un plazo de una Promesa pendiente (§ 5.7).
func _seria_destruido(ec: EstadoCarta) -> bool:
	for e: Dictionary in ec.efectos_de("seria_destruido"):
		if String(e.get("op", "")) != "evitar_destruccion_consumiendo_plazo":
			continue
		if ec.uso_en("evitar_destruccion", estado.turno):
			continue
		var pendientes: Array[PromesaDePalabra] = (
			estado.firma(ec.dueno).promesas_por_antiguedad()
		)
		if pendientes.is_empty():
			continue
		var p: PromesaDePalabra = pendientes[0]
		p.plazo_restante -= 1
		_emitir(EventoDuelo.PLAZO_CONSUMIDO, p.como_dict())
		ec.marcar_uso("evitar_destruccion", estado.turno)
		ec.dano = 0
		ec.destruir_pendiente = false
		return true
	return false


# ---------------------------------------------------------------------------
# Promesas
# ---------------------------------------------------------------------------


func _registrar_promesa(ec: EstadoCarta, clausula: String, plazo: int) -> PromesaDePalabra:
	if not _motivo_promesa_ilegal(ec, clausula, plazo).is_empty():
		return null
	var bonus: Array[Dictionary] = []
	for oferta: Dictionary in ec.def.promesas:
		if String(oferta.get("tipo", "")) == clausula:
			var lista: Array = oferta.get("bonus", [])
			for op: Dictionary in lista:
				bonus.append(op)
	var p: PromesaDePalabra = PromesaDePalabra.crear(
		_orden_promesa, ec.dueno, clausula, plazo, ec.uid, ec.id(), bonus, estado.turno
	)
	_orden_promesa += 1
	estado.firma(ec.dueno).promesas.append(p)
	_emitir(EventoDuelo.PROMESA_HECHA, p.como_dict())
	return p


## Al empezar tu turno bajan los plazos y los vencimientos resuelven en orden de
## antigüedad (§ 3.1.3).
func _vencimientos(lado: int) -> void:
	var f: EstadoFirma = estado.firma(lado)
	for p: PromesaDePalabra in f.promesas_por_antiguedad():
		p.plazo_restante -= 1
	var vencidas: Array[PromesaDePalabra] = []
	for p: PromesaDePalabra in f.promesas_por_antiguedad():
		if p.plazo_restante <= 0:
			vencidas.append(p)
	for p: PromesaDePalabra in vencidas:
		if not f.promesas.has(p):
			# Ya se resolvió en cascada: cumplir gana (§ 3.1.4).
			continue
		if p.es_de_accion():
			_romper_promesa(p)
		else:
			_cumplir_promesa(p)
	_resolver_muertes()


func _cumplir_promesa(p: PromesaDePalabra) -> void:
	var f: EstadoFirma = estado.firma(p.dueno)
	if not f.promesas.has(p):
		return
	f.promesas.erase(p)
	_emitir(EventoDuelo.PROMESA_CUMPLIDA, p.como_dict())
	var fiador: EstadoCarta = estado.carta(p.fiador_uid)
	if fiador != null and fiador.zona == Palabra.Zona.ESTRADO:
		_aplicar_ops(fiador, p.bonus, {"objetivo_uid": p.fiador_uid, "origen_uid": p.fiador_uid})
	_disparar(Palabra.TR_PROMESA_CUMPLIDA, p.dueno)
	# «cumplir otra Promesa antes del plazo» se cumple en cascada.
	for otra: PromesaDePalabra in f.promesas_por_antiguedad():
		if otra.tipo == Palabra.CL_CUMPLIR_CON_LUZ:
			_cumplir_promesa(otra)
			break
	_resolver_muertes()


func _romper_promesa(
	p: PromesaDePalabra, keywords_quebranto: Array = [], lado_quebranto: int = -1
) -> void:
	var f: EstadoFirma = estado.firma(p.dueno)
	if not f.promesas.has(p):
		return
	f.promesas.erase(p)
	_emitir(EventoDuelo.PROMESA_ROTA, p.como_dict())
	_disparar(Palabra.TR_PROMESA_ROTA, p.dueno)
	var lado: int = p.dueno if lado_quebranto < 0 else lado_quebranto
	_nace_quebranto(lado, keywords_quebranto)


## § 3.1.1: la Promesa es de la Firma y sobrevive a la muerte del Fiador; las
## cláusulas cuyo término habla de ese Fiador se vuelven imposibles y se rompen
## en el acto.
func _romper_promesas_imposibles(ec: EstadoCarta) -> void:
	var f: EstadoFirma = estado.firma(ec.dueno)
	for p: PromesaDePalabra in f.promesas_por_antiguedad():
		if p.fiador_uid == ec.uid and p.atada_al_fiador():
			_romper_promesa(p)


func _cumplir_jugar_otro_fiador(lado: int, uid_nuevo: int) -> void:
	var f: EstadoFirma = estado.firma(lado)
	for p: PromesaDePalabra in f.promesas_por_antiguedad():
		if p.tipo == Palabra.CL_JUGAR_OTRO_FIADOR and p.fiador_uid != uid_nuevo:
			_cumplir_promesa(p)
			return


func _romper_por_clausula(lado: int) -> void:
	var f: EstadoFirma = estado.firma(lado)
	for p: PromesaDePalabra in f.promesas_por_antiguedad():
		if p.tipo == Palabra.CL_SIN_CLAUSULAS:
			_romper_promesa(p)


# ---------------------------------------------------------------------------
# Quebrantos y la Mora
# ---------------------------------------------------------------------------


func _nace_quebranto(lado: int, keywords_extra: Array = []) -> EstadoCarta:
	var f: EstadoFirma = estado.firma(lado)
	if f.quebrantos().size() >= Palabra.QUEBRANTOS_MAX:
		# La mora se paga igual: 2 de Aval directo (§ 3.2.1).
		_emitir(EventoDuelo.CUARTO_QUEBRANTO, {"lado": lado})
		_dano_a_firma(lado, Palabra.CUARTO_QUEBRANTO_AVAL, "cuarto_quebranto")
		return null
	var ec: EstadoCarta = _instanciar(Palabra.T_QUEBRANTO, lado)
	if ec == null:
		return null
	for kw: String in keywords_extra:
		ec.keywords_extra.append(String(kw))
	if f.estrado_lleno():
		# El Quebranto NO se descarta: va a la Mora (§ 3.2.2).
		_a_zona(ec, Palabra.Zona.MORA)
		_emitir(EventoDuelo.QUEBRANTO_A_LA_MORA, {"uid": ec.uid, "lado": lado})
	else:
		_a_zona(ec, Palabra.Zona.ESTRADO)
		ec.entro_en_turno = estado.turno
	_emitir(EventoDuelo.QUEBRANTO_NACIDO, {"uid": ec.uid, "lado": lado, "zona": int(ec.zona)})
	return ec


## En cuanto se libera un lugar en el Estrado, el Quebranto más viejo de la Mora
## entra solo (§ 3.2.2).
func _reponer_mora(lado: int) -> void:
	var f: EstadoFirma = estado.firma(lado)
	while not f.mora.is_empty() and not f.estrado_lleno():
		var ec: EstadoCarta = f.mora[0]
		_a_zona(ec, Palabra.Zona.ESTRADO)
		ec.entro_en_turno = estado.turno
		_emitir(EventoDuelo.QUEBRANTO_ENTRO_DESDE_LA_MORA, {"uid": ec.uid, "lado": lado})


## Los Quebrantos pegan en la Firma de su dueño al final de su turno, estén en el
## Estrado o en la Mora (§ 3.2). No se los puede dirigir: atacan solos.
func _quebrantos_pegan(lado: int) -> void:
	var f: EstadoFirma = estado.firma(lado)
	for ec: EstadoCarta in f.quebrantos():
		_dano_a_firma(lado, ataque(ec), "quebranto")
		if estado.terminado:
			return


# ---------------------------------------------------------------------------
# Resolución de efectos
# ---------------------------------------------------------------------------


func _disparar(trigger: String, lado: int) -> void:
	var f: EstadoFirma = estado.firma(lado)
	for ec: EstadoCarta in f.estrado.duplicate():
		if ec.zona != Palabra.Zona.ESTRADO:
			continue
		_resolver_efectos(ec, trigger, {"origen_uid": ec.uid, "objetivo_uid": -1})


func _resolver_efectos(ec: EstadoCarta, trigger: String, ctx: Dictionary) -> void:
	var lista: Array[Dictionary] = ec.efectos_de(trigger)
	if lista.is_empty():
		return
	var reps: int = estado.mesa.repeticiones(trigger)
	for e: Dictionary in lista:
		if bool(e.get("una_vez_por_turno", false)):
			var clave: String = "%s/%s" % [trigger, String(e.get("op", ""))]
			if ec.uso_en(clave, estado.turno):
				continue
			ec.marcar_uso(clave, estado.turno)
		for _r: int in reps:
			_aplicar_op(ec, e, ctx)
	if trigger == Palabra.TR_DE_PALABRA:
		_emitir(EventoDuelo.DE_PALABRA_RESUELTO, {"uid": ec.uid, "id": ec.id()})


func _aplicar_ops(ec: EstadoCarta, ops: Array[Dictionary], ctx: Dictionary) -> void:
	for e: Dictionary in ops:
		_aplicar_op(ec, e, ctx)


func _aplicar_op(ec: EstadoCarta, e: Dictionary, ctx: Dictionary) -> void:
	var lado: int = ec.dueno
	var rival: int = estado.rival_de(lado)
	var f: EstadoFirma = estado.firma(lado)
	var op: String = String(e.get("op", ""))
	match op:
		"robar":
			var n: int = int(e.get("n", 1))
			if e.has("max_por_turno"):
				var clave: String = "robar/%s" % String(e.get("trigger", ""))
				var libre: int = int(e.get("max_por_turno", 0)) - ec.cuenta_de(clave, estado.turno)
				n = mini(n, libre)
				for _i: int in maxi(0, n):
					ec.sumar_cuenta(clave, estado.turno)
			if n > 0:
				_robar(lado, n)
		"aval":
			var destino: int = rival if String(e.get("lado", "propio")) == "rival" else lado
			_cambiar_aval(destino, int(e.get("n", 0)))
		"credito":
			_sumar_credito(lado, int(e.get("n", 0)))
		"dano":
			var cuanto: int = (
				dano_de_clausula(ec) if bool(e.get("usa_dano_base", false)) else int(e.get("n", 0))
			)
			var obj_uid: int = int(ctx.get("objetivo_uid", -1))
			if obj_uid == -1:
				_dano_a_firma(rival, cuanto, "clausula")
			else:
				_dano_a_carta(estado.carta(obj_uid), cuanto)
		"destruir":
			_destruir(_objetivo_de(ec, e, ctx))
		"devolver_a_mano":
			var obj: EstadoCarta = _objetivo_de(ec, e, ctx)
			if obj != null and not es_quebranto(obj):
				obj.dano = 0
				obj.mod_coste += int(e.get("mod_coste", 0))
				_a_zona(obj, Palabra.Zona.MANO)
		"buff":
			_aplicar_buff(ec, e, ctx)
		"otorgar_efecto":
			var obj_e: EstadoCarta = _objetivo_de(ec, e, ctx)
			if obj_e != null:
				var extra: Dictionary = e.get("efecto", {})
				if not extra.is_empty():
					obj_e.efectos_extra.append(extra)
				var kw: String = String(e.get("keyword", ""))
				if not kw.is_empty() and not obj_e.keywords_extra.has(kw):
					obj_e.keywords_extra.append(kw)
		"invocar":
			for _i: int in int(e.get("n", 1)):
				_invocar(lado, String(e.get("carta", "")), e.get("keywords_extra", []))
		"nace_quebranto":
			var destino_q: int = rival if String(e.get("lado", "propio")) == "rival" else lado
			_nace_quebranto(destino_q, e.get("keywords_extra", []))
		"romper_promesa":
			var orden: int = int(ctx.get("objetivo_uid", -1))
			for p: PromesaDePalabra in f.promesas_por_antiguedad():
				if p.orden == orden:
					_romper_promesa(p, e.get("keywords_quebranto", []))
					break
		"cumplir_todas_las_promesas":
			for p2: PromesaDePalabra in f.promesas_por_antiguedad():
				_cumplir_promesa(p2)
		"disolver_quebrantos":
			var por_cada: int = int(e.get("aval_por_cada", 0))
			for q: EstadoCarta in f.quebrantos():
				_a_zona(q, Palabra.Zona.DESCARTE)
				_emitir(EventoDuelo.QUEBRANTO_DISUELTO, {"uid": q.uid, "lado": lado})
				_cambiar_aval(lado, por_cada)
			_reponer_mora(lado)
		"dar_interes_en_mano":
			var faltan: int = int(e.get("n", 1))
			for otra: EstadoCarta in f.mano:
				if faltan <= 0:
					break
				if otra.uid == ec.uid or otra.tiene(Palabra.KW_INTERES):
					continue
				otra.keywords_extra.append(Palabra.KW_INTERES)
				faltan -= 1
		"interes_al_azar_en_mano":
			var candidatas: Array[EstadoCarta] = []
			for otra2: EstadoCarta in f.mano:
				if not otra2.tiene(Palabra.KW_INTERES):
					candidatas.append(otra2)
			if not candidatas.is_empty():
				var elegida: EstadoCarta = candidatas[rng.randi_range(0, candidatas.size() - 1)]
				elegida.keywords_extra.append(Palabra.KW_INTERES)
		"coste_cero_interes":
			var tope: int = int(e.get("max", 1))
			var puestas: int = 0
			for otra3: EstadoCarta in f.mano:
				if puestas >= tope:
					break
				if otra3.tiene(Palabra.KW_INTERES):
					otra3.coste_cero_en_turno = estado.turno
					puestas += 1
		"descartar":
			var quien: int = rival if String(e.get("lado", "rival")) == "rival" else lado
			var fr: EstadoFirma = estado.firma(quien)
			for _i: int in int(e.get("n", 1)):
				if fr.mano.is_empty():
					break
				var idx: int = rng.randi_range(0, fr.mano.size() - 1)
				_a_zona(fr.mano[idx], Palabra.Zona.DESCARTE)
		"copiar_del_mazo_rival":
			var fr2: EstadoFirma = estado.firma(rival)
			if not fr2.mazo.is_empty():
				var idx2: int = rng.randi_range(0, fr2.mazo.size() - 1)
				var copia: EstadoCarta = _instanciar(fr2.mazo[idx2].id(), lado)
				if copia != null:
					_llevar_a_mano(copia, lado)
		"refrendar":
			var caido: EstadoCarta = f.ultimo_caido
			if caido != null and caido.zona == Palabra.Zona.DESCARTE:
				if f.estrado_lleno():
					_emitir(
						EventoDuelo.INVOCACION_FRUSTRADA,
						{"uid": caido.uid, "motivo": "el Estrado no da fe"}
					)
				else:
					caido.dano = 0
					caido.keywords_quitadas.clear()
					if not caido.keywords_extra.has(Palabra.KW_SELLO):
						caido.keywords_extra.append(Palabra.KW_SELLO)
					_a_zona(caido, Palabra.Zona.ESTRADO)
					caido.entro_en_turno = estado.turno
					_emitir(
						EventoDuelo.CARTA_ENTRO_AL_ESTRADO,
						{"uid": caido.uid, "id": caido.id(), "lado": lado}
					)
		"repetir_de_palabra":
			var tope2: int = int(e.get("max", 1))
			var hechos: int = 0
			for otro: EstadoCarta in _fiadores_con_de_palabra(lado):
				if hechos >= tope2:
					break
				_resolver_efectos(
					otro,
					Palabra.TR_DE_PALABRA,
					{"origen_uid": otro.uid, "objetivo_uid": _objetivo_auto(otro)}
				)
				hechos += 1
		"robar_por_de_palabra":
			var cuantos: int = mini(
				_fiadores_con_de_palabra(lado).size(), int(e.get("max", 3))
			)
			if cuantos > 0:
				_robar(lado, cuantos)
		"gemela_cae":
			var ids: Array = e.get("ids", [])
			for otra4: EstadoCarta in estado.firma(lado).estrado:
				if otra4.uid == ec.uid or not ids.has(otra4.id()):
					continue
				if not otra4.keywords_quitadas.has(Palabra.KW_AL_CONTADO):
					otra4.keywords_quitadas.append(Palabra.KW_AL_CONTADO)
				otra4.mod_ataque += int(e.get("ataque", 0))
				otra4.mod_aguante += int(e.get("aguante", 0))
				break
		"transformar":
			var obj_t: EstadoCarta = _objetivo_de(ec, e, ctx)
			var nueva: CartaDePalabra = CatalogoDePalabra.obtener(String(e.get("carta", "")))
			if obj_t != null and nueva != null and obj_t.zona == Palabra.Zona.ESTRADO:
				obj_t.def = nueva
				obj_t.dano = 0
				obj_t.keywords_quitadas.clear()
				_emitir(
					EventoDuelo.CARTA_TRANSFORMADA, {"uid": obj_t.uid, "id": obj_t.id()}
				)
		"transformar_a_mano":
			var nueva2: CartaDePalabra = CatalogoDePalabra.obtener(String(e.get("carta", "")))
			if nueva2 != null:
				var vuelta: EstadoCarta = _instanciar(nueva2.id, lado)
				if vuelta != null:
					_llevar_a_mano(vuelta, lado)
		"robar_empenadero_rival":
			for prenda: EstadoCarta in estado.firma(rival).empenadero.duplicate():
				prenda.dueno = lado
				_llevar_a_mano(prenda, lado)
		"jugar_al_fiado_gratis":
			var obj_f: EstadoCarta = _objetivo_de(ec, e, ctx)
			if obj_f != null and obj_f.zona == Palabra.Zona.MANO:
				_a_zona(obj_f, Palabra.Zona.VIAJE)
				obj_f.boca_abajo = true
				obj_f.viaje_restante = 0
				obj_f.revela_al_fin_de_turno = true
				_emitir(EventoDuelo.CARTA_AL_VIAJE, {"uid": obj_f.uid, "lado": lado})
		"evitar_destruccion_consumiendo_plazo":
			pass
		_:
			push_error("MotorDePalabra: op desconocida '%s' en %s" % [op, ec.id()])


func _llevar_a_mano(ec: EstadoCarta, lado: int) -> void:
	if estado.firma(lado).mano_llena():
		_a_zona_de(ec, lado, Palabra.Zona.EMPENADERO)
		_emitir(EventoDuelo.MANO_LLENA_AL_EMPENADERO, {"uid": ec.uid, "lado": lado})
	else:
		_a_zona_de(ec, lado, Palabra.Zona.MANO)


func _aplicar_buff(ec: EstadoCarta, e: Dictionary, ctx: Dictionary) -> void:
	var objetivos: Array[EstadoCarta] = []
	match String(e.get("objetivo", "elegido")):
		"propio":
			objetivos.append(ec)
		"todos_fiadores_propios":
			objetivos = _fiadores_propios(ec.dueno)
		_:
			var obj: EstadoCarta = _objetivo_de(ec, e, ctx)
			if obj != null:
				objetivos.append(obj)
	var kw: String = String(e.get("keyword", ""))
	for obj2: EstadoCarta in objetivos:
		obj2.mod_ataque += int(e.get("ataque", 0))
		obj2.mod_aguante += int(e.get("aguante", 0))
		if kw.is_empty():
			continue
		if not obj2.keywords_extra.has(kw):
			obj2.keywords_extra.append(kw)
		obj2.keywords_quitadas.erase(kw)
		if kw == Palabra.KW_GARANTE:
			# «este Fiador no bloquea»: se rompe si lo usás como Garante voluntario.
			var p: PromesaDePalabra = estado.firma(obj2.dueno).promesa_de(
				obj2.uid, Palabra.CL_NO_DEFENDER
			)
			if p != null:
				_romper_promesa(p)


func _objetivo_de(ec: EstadoCarta, e: Dictionary, ctx: Dictionary) -> EstadoCarta:
	match String(e.get("objetivo", "elegido")):
		"propio":
			return ec
		_:
			return estado.carta(int(ctx.get("objetivo_uid", -1)))


## Objetivo automático y determinista, para cuando el efecto se repite sin que
## haya un objetivo elegido (Pregón de Ventanilla).
func _objetivo_auto(ec: EstadoCarta) -> int:
	if ec.def.objetivos.is_empty():
		return -1
	var legales: Array[int] = objetivos_legales(ec, ec.def.objetivos[0])
	return legales[0] if not legales.is_empty() else -1


func _invocar(lado: int, id: String, keywords_extra: Array) -> EstadoCarta:
	var f: EstadoFirma = estado.firma(lado)
	if f.estrado_lleno():
		# La invocación se evalúa al resolver; si no cabe, se frustra (§ 3.2.3).
		_emitir(
			EventoDuelo.INVOCACION_FRUSTRADA,
			{"lado": lado, "id": id, "motivo": "el Estrado no da fe"}
		)
		return null
	var ec: EstadoCarta = _instanciar(id, lado)
	if ec == null:
		return null
	for kw: String in keywords_extra:
		ec.keywords_extra.append(String(kw))
	_a_zona(ec, Palabra.Zona.ESTRADO)
	ec.entro_en_turno = estado.turno
	_emitir(EventoDuelo.CARTA_ENTRO_AL_ESTRADO, {"uid": ec.uid, "id": ec.id(), "lado": lado})
	_resolver_efectos(ec, Palabra.TR_DE_PALABRA, {"origen_uid": ec.uid, "objetivo_uid": -1})
	return ec


func _fiadores_propios(lado: int) -> Array[EstadoCarta]:
	var salida: Array[EstadoCarta] = []
	for ec: EstadoCarta in estado.firma(lado).estrado:
		if ec.tipo() == Palabra.Tipo.FIADOR and not ec.boca_abajo and not es_quebranto(ec):
			salida.append(ec)
	return salida


func _fiadores_con_de_palabra(lado: int) -> Array[EstadoCarta]:
	var salida: Array[EstadoCarta] = []
	for ec: EstadoCarta in _fiadores_propios(lado):
		if ec.tiene(Palabra.KW_DE_PALABRA):
			salida.append(ec)
	return salida


# ---------------------------------------------------------------------------
# Eventos
# ---------------------------------------------------------------------------


func _emitir(tipo: String, datos: Dictionary = {}) -> void:
	var e: EventoDuelo = EventoDuelo.crear(tipo, datos)
	registro.append(e)
	evento.emit(e)


## Todos los eventos de un tipo, en orden. Lo usan los tests.
func eventos_de(tipo: String) -> Array[EventoDuelo]:
	var salida: Array[EventoDuelo] = []
	for e: EventoDuelo in registro:
		if e.tipo == tipo:
			salida.append(e)
	return salida


# ---------------------------------------------------------------------------
# Ganchos de depuración (los usan los tests headless; la vista no los toca)
# ---------------------------------------------------------------------------


func depurar_poner_en_mano(lado: int, id: String) -> int:
	var ec: EstadoCarta = _instanciar(id, lado)
	if ec == null:
		return -1
	_a_zona(ec, Palabra.Zona.MANO)
	return ec.uid


func depurar_poner_en_empenadero(lado: int, id: String) -> int:
	var ec: EstadoCarta = _instanciar(id, lado)
	if ec == null:
		return -1
	_a_zona(ec, Palabra.Zona.EMPENADERO)
	return ec.uid


## Pone una carta en el Estrado sin pagarla y sin disparar su De palabra: sirve
## para armar posiciones. Por defecto entra «desde antes», así puede atacar.
func depurar_poner_en_estrado(lado: int, id: String, ya_estaba: bool = true) -> int:
	var ec: EstadoCarta = _instanciar(id, lado)
	if ec == null:
		return -1
	_a_zona(ec, Palabra.Zona.ESTRADO)
	ec.entro_en_turno = -1 if ya_estaba else estado.turno
	return ec.uid


func depurar_llenar_estrado(lado: int, id: String = "peon_de_vina") -> void:
	while not estado.firma(lado).estrado_lleno():
		depurar_poner_en_estrado(lado, id)


func depurar_vaciar_mazo(lado: int) -> void:
	estado.firma(lado).mazo.clear()


func depurar_vaciar_mano(lado: int) -> void:
	for ec: EstadoCarta in estado.firma(lado).mano.duplicate():
		_a_zona(ec, Palabra.Zona.DESCARTE)


func depurar_set_aval(lado: int, valor: int) -> void:
	estado.firma(lado).aval = valor


func depurar_set_credito(lado: int, valor: int) -> void:
	estado.firma(lado).credito = valor
	estado.firma(lado).credito_max = maxi(estado.firma(lado).credito_max, valor)


func depurar_set_mods(uid: int, mod_ataque: int, mod_aguante: int) -> void:
	var ec: EstadoCarta = estado.carta(uid)
	if ec != null:
		ec.mod_ataque = mod_ataque
		ec.mod_aguante = mod_aguante


func depurar_set_interes(uid: int, valor: int) -> void:
	var ec: EstadoCarta = estado.carta(uid)
	if ec != null:
		ec.interes = valor


## Daño simultáneo a todo el Estrado de un lado: el camino que usaría un AoE.
## Ninguna carta del Acto 1 lo hace, pero el orden de resolución sí es regla
## (§ 3.2.3), así que el motor lo expone para poder testearlo.
func depurar_dano_area(lado: int, cuanto: int) -> void:
	for ec: EstadoCarta in estado.firma(lado).estrado.duplicate():
		_dano_a_carta(ec, cuanto)
	_resolver_muertes()


## Termina turnos hasta volver a ser el turno de [param lado].
func depurar_avanzar_a_turno_de(lado: int) -> void:
	var guardia: int = 0
	while not estado.terminado and estado.activo != lado and guardia < 64:
		guardia += 1
		terminar_turno()
	if estado.activo == lado and estado.fase != Palabra.Fase.ACCIONES and not estado.terminado:
		estado.fase = Palabra.Fase.ACCIONES


## Pasa [param cuantos] turnos completos (propios y rivales).
func depurar_pasar_turnos(cuantos: int) -> void:
	for _i: int in cuantos:
		if estado.terminado:
			return
		terminar_turno()
