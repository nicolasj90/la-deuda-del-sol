# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name IADePalabra
extends RefCounted

## IA de «De Palabra» (diseño § 7). **Función pura**: estado + perfil + rng →
## Jugada. Sin acceso al árbol de nodos, sin [method @GlobalScope.randf] global,
## sin estado estático: la única forma de testearla (§ 7.2, § 8.6).
##
## Tres reglas que vienen del diseño y no se negocian:
## [br]1. Las jugadas legales **se le piden al motor** ([method
##    MotorDePalabra.jugadas_legales]). La IA nunca reimplementa la legalidad, así
##    que la clase de bug «la IA jugó algo ilegal» no existe (§ 7.2.1).
## [br]2. Beam search de **ancho 4** con **cota dura de 200 nodos** evaluados por
##    decisión (§ 7.2.2). Sin la cota, el perfil `interes` con 10 de Crédito y mano
##    llena cuelga el turno.
## [br]3. El modelo del rival usa **solo información visible**. Lo que el rival
##    anunció entra con peso [code]1 − sesgo_desconfianza[/code] (§ 7.2.6): con
##    [code]sesgo_desconfianza = 1.0[/code] el anuncio se descarta por completo, y
##    de ahí sale el defecto de personaje de Salu (§ 7.3) sin una sola línea de
##    «IA que pierde a propósito».
##
## Uso:
## [codeblock]
## var rng := RandomNumberGenerator.new()
## rng.seed = 1234
## var j := IADePalabra.elegir_jugada(motor, perfil, rng)
## motor.ejecutar(j)
## [/codeblock]

## § 7.2.2 — ancho del beam.
const BEAM_ANCHO: int = 4
## § 7.2.2 — cota dura de nodos evaluados por decisión. Es un tope, no un objetivo.
const NODOS_MAX: int = 200
## Candidatos que se expanden por nodo, ya ordenados por heurística estática. Con
## 8 × 4 una posición rica **toca** la cota de 200 antes de agotar la profundidad:
## la cota es un tope real, no adorno.
const CANDIDATOS_POR_NODO: int = 8
## Profundidad máxima del beam: «agotar el Crédito» son 10 jugadas de 1, más
## ataques; 8 alcanza y acota el peor caso.
const PROFUNDIDAD_MAX: int = 8

## Valor de ganar (o perder) el duelo en la evaluación.
const VALOR_VICTORIA: float = 10000.0
## Penalización por Quebranto propio de la lineal del § 7.2.3. Es también el
## «costo_quebranto» de la regla de Promesas del § 7.2.4.
const COSTO_QUEBRANTO: float = 3.0
## Peso del Crédito no gastado en la lineal (§ 7.2.3).
const PESO_CREDITO_SOBRANTE: float = -0.5
## Cuánto sube el `peso_cara` efectivo por unidad de urgencia del anuncio rival.
## Es lo que hace que una IA que **cree** el anuncio apure al rival (y que Salu,
## que no lo cree, no lo apure).
const PESO_URGENCIA: float = 2.0
## Mejora mínima para preferir una jugada a quedarse quieto.
const EPSILON: float = 0.001

## § 7.2.4 — probabilidad de cumplimiento por tipo de cláusula. `jugar_otro_fiador`
## depende del estado: 1 si hay otro Fiador en mano, si no 0.3.
const P_CUMPLIR: Dictionary = {
	Palabra.CL_NO_ATACAR: 0.8,
	Palabra.CL_NO_DEFENDER: 0.5,
	Palabra.CL_CUMPLIR_CON_LUZ: 0.4,
	Palabra.CL_SIN_CLAUSULAS: 0.7,
}
const P_JUGAR_OTRO_FIADOR_CON_FIADOR: float = 1.0
const P_JUGAR_OTRO_FIADOR_SIN_FIADOR: float = 0.3

## Valor aproximado de las ops de bonus de una Promesa (§ 7.2.4 pide comparar
## `bonus` contra el costo del Quebranto; el diseño no tabula el bonus, así que
## acá se estima por op y se documenta).
const VALOR_OP: Dictionary = {
	"transformar": 2.0,
	"invocar": 2.0,
	"robar": 1.0,
	"aval": 1.0,
	"credito": 0.5,
	"buff": 1.0,
	"disolver_quebrantos": 3.0,
	"cumplir_todas_las_promesas": 3.0,
}
const VALOR_OP_DESCONOCIDA: float = 1.0
## Valor que se le pone a tener en el Estrado una carta que premia cumplir
## (Lámpara, Fiel): con ellas una Promesa sin bonus propio igual vale algo.
const VALOR_PREMIO_POR_CUMPLIR: float = 2.0


## La jugada que la IA elige **ahora**. Es lo que usa la vista en el turno rival.
static func elegir_jugada(
	motor: MotorDePalabra,
	perfil: PerfilIA,
	rng: RandomNumberGenerator,
	anuncio: Array[String] = []
) -> JugadaDePalabra:
	var plan: Dictionary = planificar(motor, perfil, rng, anuncio)
	var jugadas: Array = plan["jugadas"]
	if jugadas.is_empty():
		var lado: int = 0
		if motor != null and motor.estado != null:
			lado = motor.estado.activo
		return JugadaDePalabra.pasar(lado)
	return jugadas[0] as JugadaDePalabra


## Planifica el turno entero con un beam search acotado y devuelve el diagnóstico
## completo. La primera jugada del plan es lo que [method elegir_jugada] devuelve;
## el plan completo lo usa [PilotoDePalabra] para no replanificar por jugada.
##
## No toca [param motor]: todo se simula sobre clones ([ClonDeDuelo]).
##
## Devuelve
## [code]{ jugadas, nodos, urgencia, valor, valor_base, guion, candidatos }[/code].
static func planificar(
	motor: MotorDePalabra,
	perfil: PerfilIA,
	rng: RandomNumberGenerator,
	anuncio: Array[String] = []
) -> Dictionary:
	var plan: Dictionary = {
		"jugadas": [] as Array[JugadaDePalabra],
		"nodos": 0,
		"urgencia": 0.0,
		"valor": 0.0,
		"valor_base": 0.0,
		"guion": false,
		"candidatos": 0,
	}
	if motor == null or motor.estado == null or perfil == null:
		return plan
	var e: EstadoDuelo = motor.estado
	if e.terminado or e.fase != Palabra.Fase.ACCIONES:
		return plan
	var lado: int = e.activo
	var azar: RandomNumberGenerator = rng if rng != null else RandomNumberGenerator.new()
	var urgencia: float = urgencia_del_anuncio(motor, lado, perfil, anuncio)
	plan["urgencia"] = urgencia
	# Guion forzado de tutorial (§ 7.1): se usa solo si la jugada es legal.
	var guionada: JugadaDePalabra = _jugada_de_guion(motor, perfil, lado)
	if guionada != null:
		var lista_guion: Array[JugadaDePalabra] = [guionada]
		plan["jugadas"] = lista_guion
		plan["guion"] = true
		return plan
	var semilla_sim: int = azar.randi()
	var valor_base: float = evaluar(motor, lado, perfil, urgencia)
	plan["valor_base"] = valor_base
	plan["valor"] = valor_base
	var nodos: int = 0
	var candidatos_vistos: int = 0
	var mejor_camino: Array[JugadaDePalabra] = []
	var mejor_valor: float = valor_base
	var beam: Array[Dictionary] = [
		{"motor": motor, "camino": [] as Array[JugadaDePalabra], "bonus": 0.0, "valor": valor_base}
	]
	for profundidad: int in PROFUNDIDAD_MAX:
		var siguientes: Array[Dictionary] = []
		for nodo: Dictionary in beam:
			var m: MotorDePalabra = nodo["motor"] as MotorDePalabra
			if m.estado.terminado or m.estado.fase != Palabra.Fase.ACCIONES:
				continue
			if m.estado.activo != lado:
				continue
			var candidatos: Array[Dictionary] = _candidatos(m, perfil, azar, urgencia, lado)
			candidatos_vistos += candidatos.size()
			for c: Dictionary in candidatos:
				if nodos >= NODOS_MAX:
					break
				nodos += 1
				var sim: MotorDePalabra = ClonDeDuelo.clonar_motor(m, semilla_sim + nodos)
				var j: JugadaDePalabra = c["jugada"] as JugadaDePalabra
				if not sim.ejecutar(j):
					continue
				var bonus: float = float(nodo["bonus"]) + float(c["bonus"])
				var valor: float = evaluar(sim, lado, perfil, urgencia) + bonus
				var camino: Array[JugadaDePalabra] = (nodo["camino"] as Array).duplicate()
				camino.append(j)
				siguientes.append(
					{"motor": sim, "camino": camino, "bonus": bonus, "valor": valor}
				)
				if valor > mejor_valor + EPSILON:
					mejor_valor = valor
					mejor_camino = camino
			if nodos >= NODOS_MAX:
				break
		if siguientes.is_empty() or nodos >= NODOS_MAX:
			break
		siguientes.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool: return float(a["valor"]) > float(b["valor"])
		)
		beam = siguientes.slice(0, BEAM_ANCHO)
	plan["jugadas"] = mejor_camino
	plan["nodos"] = nodos
	plan["candidatos"] = candidatos_vistos
	plan["valor"] = mejor_valor
	return plan


## Lineal de evaluación del § 7.2.3:
## [code]aval_propio − aval_rival·peso_cara + Σ(ataque+aguante)·peso_tabla
## + cartas_mano·peso_mano + credito_no_gastado·(−0.5) + quebrantos_propios·(−3)[/code]
##
## La Σ es sobre el **Estrado propio** («valor de conservar el Estrado», § 7.1);
## los Quebrantos quedan fuera de la Σ porque ya pesan −3 y porque el motor no los
## cuenta como Fiadores propios. Lo que la lineal no ve (el Estrado rival) lo
## aporta el bonus de trade de cada ataque (§ 7.2.5), que es donde el diseño pone
## las decisiones de intercambio.
static func evaluar(
	motor: MotorDePalabra, lado: int, perfil: PerfilIA, urgencia: float = 0.0
) -> float:
	var e: EstadoDuelo = motor.estado
	if e.terminado:
		if e.ganador == lado:
			return VALOR_VICTORIA
		return -VALOR_VICTORIA
	var yo: EstadoFirma = e.firma(lado)
	var otro: EstadoFirma = e.firma(e.rival_de(lado))
	var valor: float = float(yo.aval) - float(otro.aval) * peso_cara_efectivo(perfil, urgencia)
	for ec: EstadoCarta in yo.estrado:
		if motor.es_quebranto(ec) or ec.boca_abajo:
			continue
		valor += float(motor.ataque(ec) + motor.aguante_restante(ec)) * perfil.peso_tabla
	valor += float(yo.mano.size()) * perfil.peso_mano
	valor += float(yo.credito) * PESO_CREDITO_SOBRANTE
	valor += float(yo.quebrantos().size()) * -COSTO_QUEBRANTO
	return valor


## `peso_cara` corregido por la urgencia del anuncio rival: una IA que cree el
## anuncio apura (§ 7.2.6). Con `sesgo_desconfianza = 1.0` la urgencia es 0 y esto
## devuelve el `peso_cara` del perfil, siempre.
static func peso_cara_efectivo(perfil: PerfilIA, urgencia: float) -> float:
	return perfil.peso_cara + PESO_URGENCIA * urgencia


## Cuánto pesa en el modelo lo que el rival **anunció** (§ 7.2.6). 0 si no anunció
## nada, si no puede pagarlo todavía, o si el perfil no le cree nada
## ([code]sesgo_desconfianza = 1.0[/code]).
static func urgencia_del_anuncio(
	motor: MotorDePalabra, lado: int, perfil: PerfilIA, anuncio: Array[String]
) -> float:
	if anuncio.is_empty():
		return 0.0
	var confianza: float = 1.0 - perfil.sesgo_desconfianza
	if confianza <= 0.0:
		return 0.0
	var rival: EstadoFirma = motor.estado.firma(motor.estado.rival_de(lado))
	var total: float = 0.0
	for id: String in anuncio:
		if not CatalogoDePalabra.existe(id):
			continue
		var c: CartaDePalabra = CatalogoDePalabra.obtener(id)
		# Todavía no la puede pagar: no es una amenaza de este turno ni del que viene.
		if rival.credito_max + 2 < c.coste_base:
			continue
		total += float(c.coste_base) / float(Palabra.CREDITO_TOPE)
	return minf(total, 2.0) * confianza


# ---------------------------------------------------------------------------
# Candidatos
# ---------------------------------------------------------------------------


## Jugadas que vale la pena expandir en un nodo, ordenadas por heurística
## estática y recortadas a [constant CANDIDATOS_POR_NODO].
##
## PASAR nunca es candidata: quedarse quieto es la línea base contra la que se
## comparan los planes, y expandirla arrancaría el turno del rival dentro de la
## simulación.
static func _candidatos(
	motor: MotorDePalabra,
	perfil: PerfilIA,
	rng: RandomNumberGenerator,
	urgencia: float,
	lado: int
) -> Array[Dictionary]:
	var legales: Array[JugadaDePalabra] = motor.jugadas_legales(lado)
	var salida: Array[Dictionary] = []
	# Las 16 variantes de Promesa por (carta, objetivo) se colapsan a una sola
	# decisión con la regla del § 7.2.4: la Promesa no se busca, se decide.
	var promesa_por_carta: Dictionary = {}
	var grupos_vistos: Dictionary = {}
	var senuelo_uid: int = _uid_de_senuelo(motor, perfil, rng, lado)
	for j: JugadaDePalabra in legales:
		match j.tipo:
			Palabra.TipoJugada.PASAR:
				continue
			Palabra.TipoJugada.JUGAR:
				var ec: EstadoCarta = motor.estado.carta(j.carta_uid)
				if ec == null:
					continue
				if j.al_fiado:
					var bono_senuelo: float = 1.5 if ec.uid == senuelo_uid else 0.0
					salida.append(
						{
							"jugada": j,
							"bonus": bono_senuelo,
							"estimado": bono_senuelo + 0.5 * perfil.peso_tempo,
						}
					)
					continue
				if not promesa_por_carta.has(j.carta_uid):
					promesa_por_carta[j.carta_uid] = _decidir_promesa(motor, ec, perfil)
				var decision: Dictionary = promesa_por_carta[j.carta_uid]
				if j.promesa_tipo != String(decision["tipo"]):
					continue
				if not j.promesa_tipo.is_empty() and j.promesa_plazo != int(decision["plazo"]):
					continue
				var clave: String = "%d|%d" % [j.carta_uid, j.objetivo_uid]
				if grupos_vistos.has(clave):
					continue
				grupos_vistos[clave] = true
				salida.append(_candidato_de_juego(motor, j, ec, perfil, decision))
			Palabra.TipoJugada.ATACAR:
				salida.append(_candidato_de_ataque(motor, j, perfil, urgencia))
			Palabra.TipoJugada.EMPENAR:
				var ep: EstadoCarta = motor.estado.carta(j.carta_uid)
				var valor_prenda: float = _valor_de_carta(motor, ep) * perfil.peso_tabla
				var bono_empeno: float = 0.5 - 0.25 * valor_prenda
				salida.append({"jugada": j, "bonus": bono_empeno, "estimado": bono_empeno})
			Palabra.TipoJugada.RESCATAR:
				var rc: EstadoCarta = motor.estado.carta(j.carta_uid)
				var bono_rescate: float = 0.25 * _valor_de_carta(motor, rc) * perfil.peso_mano
				salida.append({"jugada": j, "bonus": bono_rescate, "estimado": bono_rescate})
			Palabra.TipoJugada.DENUNCIAR:
				# Sin mirar la carta tapada: la corazonada es del rng (§ 9.3).
				var apuesta: Palabra.Tipo = _tipo_al_azar(rng)
				var bono_denuncia: float = 0.6 if j.tipo_declarado == apuesta else 0.0
				salida.append({"jugada": j, "bonus": bono_denuncia, "estimado": bono_denuncia})
	salida.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["estimado"]) > float(b["estimado"])
	)
	return salida.slice(0, CANDIDATOS_POR_NODO)


static func _candidato_de_juego(
	motor: MotorDePalabra,
	j: JugadaDePalabra,
	ec: EstadoCarta,
	perfil: PerfilIA,
	decision: Dictionary
) -> Dictionary:
	var bonus: float = float(decision["valor"])
	# Tempo: «valor de tener cuerpos ahora» (§ 7.1).
	if ec.es_cuerpo():
		bonus += 0.5 * perfil.peso_tempo
	# Curva preferida: coste ideal por turno propio (§ 7.1).
	var curva: int = perfil.coste_de_curva(motor.estado.firma(ec.dueno).turnos_jugados)
	if curva >= 0:
		bonus -= 0.25 * absf(float(motor.coste(ec)) - float(curva))
	# Desempate por keywords/arquetipo prioritarios (§ 7.1).
	bonus += _bono_prioridad(perfil, ec)
	var estimado: float = bonus
	if ec.es_cuerpo():
		estimado += _valor_de_carta(motor, ec) * perfil.peso_tabla
	else:
		estimado += 1.0
	estimado -= 0.5 * float(motor.coste(ec))
	return {"jugada": j, "bonus": bonus, "estimado": estimado}


## § 7.2.5 — orden de ataques: (a) mata sin morir, (b) mata muriendo si el valor
## sube por encima de `umbral_trade`, (c) cara si `peso_cara` alto o si hay letal.
## El Garante lo impone el motor: acá solo se puntúa lo que ya es legal.
##
## El bonus cubre **solo** lo que la lineal no ve (el Estrado rival y el
## sobreprecio que el perfil exige por un trade). El daño a la cara y la pérdida
## del cuerpo propio ya los ve [method evaluar]: no se cuentan dos veces.
static func _candidato_de_ataque(
	motor: MotorDePalabra, j: JugadaDePalabra, perfil: PerfilIA, urgencia: float
) -> Dictionary:
	var atacante: EstadoCarta = motor.estado.carta(j.carta_uid)
	if atacante == null:
		return {"jugada": j, "bonus": 0.0, "estimado": 0.0}
	var golpe: int = motor.ataque(atacante)
	if j.objetivo_uid == -1:
		var estimado_cara: float = float(golpe) * peso_cara_efectivo(perfil, urgencia)
		return {"jugada": j, "bonus": 0.0, "estimado": estimado_cara}
	var obj: EstadoCarta = motor.estado.carta(j.objetivo_uid)
	if obj == null:
		return {"jugada": j, "bonus": 0.0, "estimado": 0.0}
	var contragolpe: int = motor.ataque(obj)
	var mata: bool = (
		golpe > 0 and not obj.tiene(Palabra.KW_SELLO) and golpe >= motor.aguante_restante(obj)
	)
	var muero: bool = (
		contragolpe > 0
		and not atacante.tiene(Palabra.KW_SELLO)
		and contragolpe >= motor.aguante_restante(atacante)
	)
	var bonus: float = 0.0
	if mata:
		bonus += _valor_de_carta(motor, obj) * perfil.peso_tabla
	elif obj.tiene(Palabra.KW_SELLO) and golpe > 0:
		# Quemar un Sello vale poco, pero no es cero.
		bonus += 0.2
	else:
		bonus += 0.25 * float(mini(golpe, motor.aguante_restante(obj))) * perfil.peso_tabla
	if muero:
		# `umbral_trade`: «cuánto valor de más exige para intercambiar». La pérdida
		# del cuerpo propio ya la contó la lineal; acá se cobra solo el sobreprecio.
		bonus -= _valor_de_carta(motor, atacante) * perfil.umbral_trade * perfil.peso_tabla
		# «Valora sus propias muertes»: el perfil de Letra chica (§ 7.3) pide
		# morirse, y lo pide por su lista de prioridades.
		if atacante.tiene(Palabra.KW_LETRA_CHICA):
			bonus += _bono_prioridad(perfil, atacante)
	return {"jugada": j, "bonus": bonus, "estimado": bonus}


## § 7.2.4 — decide la cláusula optativa de una carta al jugarla.
## Devuelve [code]{ tipo, plazo, valor }[/code]; [code]tipo == ""[/code] = sin Promesa.
static func _decidir_promesa(
	motor: MotorDePalabra, ec: EstadoCarta, perfil: PerfilIA
) -> Dictionary:
	var sin_promesa: Dictionary = {"tipo": "", "plazo": 0, "valor": 0.0}
	var ofrecibles: Array[String] = motor.clausulas_ofrecibles(ec)
	if ofrecibles.is_empty():
		return sin_promesa
	var mejor: Dictionary = sin_promesa
	var mejor_valor: float = 0.0
	for clausula: String in ofrecibles:
		var p: float = _p_cumplir(motor, ec, clausula)
		var bonus: float = _valor_del_bonus(motor, ec, clausula)
		# Acepta si p·bonus > (1 − p)·costo_quebranto·(1 − sesgo_promesa).
		var exigido: float = (1.0 - p) * COSTO_QUEBRANTO * (1.0 - perfil.sesgo_promesa)
		if p * bonus <= exigido:
			continue
		var valor: float = p * bonus - (1.0 - p) * COSTO_QUEBRANTO
		if valor > mejor_valor:
			mejor_valor = valor
			mejor = {"tipo": clausula, "plazo": _plazo_para(ec, clausula), "valor": valor}
	return mejor


static func _p_cumplir(motor: MotorDePalabra, ec: EstadoCarta, clausula: String) -> float:
	if clausula != Palabra.CL_JUGAR_OTRO_FIADOR:
		return float(P_CUMPLIR.get(clausula, 0.5))
	for otra: EstadoCarta in motor.estado.firma(ec.dueno).mano:
		if otra.uid != ec.uid and otra.tipo() == Palabra.Tipo.FIADOR:
			return P_JUGAR_OTRO_FIADOR_CON_FIADOR
	return P_JUGAR_OTRO_FIADOR_SIN_FIADOR


## Valor del bonus de cumplir: las ops que la carta ofrece para esa cláusula, más
## lo que valen las cartas propias que **premian cumplir** (Lámpara, Fiel), que es
## el único valor de una Promesa sin bonus propio (§ 3, PromesaDePalabra.bonus).
static func _valor_del_bonus(
	motor: MotorDePalabra, ec: EstadoCarta, clausula: String
) -> float:
	var valor: float = 0.0
	for oferta: Dictionary in ec.def.promesas:
		if String(oferta.get("tipo", "")) != clausula:
			continue
		for op_v: Variant in oferta.get("bonus", []):
			var op: Dictionary = op_v
			valor += float(VALOR_OP.get(String(op.get("op", "")), VALOR_OP_DESCONOCIDA))
	for otra: EstadoCarta in motor.estado.firma(ec.dueno).estrado:
		if not otra.efectos_de(Palabra.TR_PROMESA_CUMPLIDA).is_empty():
			valor += VALOR_PREMIO_POR_CUMPLIR
	return valor


## Plazo elegido: el que la carta declara para esa cláusula si lo declara; si no,
## el más corto para las prohibiciones (menos tiempo de romperla) y el más largo
## para las de acción (más tiempo de cumplirla).
static func _plazo_para(ec: EstadoCarta, clausula: String) -> int:
	for oferta: Dictionary in ec.def.promesas:
		if String(oferta.get("tipo", "")) == clausula:
			return clampi(int(oferta.get("plazo", 1)), 1, Palabra.PLAZO_MAX)
	if Palabra.CLAUSULAS_DE_ACCION.has(clausula):
		return Palabra.PLAZO_MAX
	return 1


# ---------------------------------------------------------------------------
# Guion forzado (§ 7.1) — tutoriales
# ---------------------------------------------------------------------------


## Traduce el paso de guion del turno propio en curso a una jugada real. Devuelve
## null si el perfil no tiene guion para este turno o si ninguno de sus pasos es
## legal ahora: el guion **nunca** puede producir una jugada ilegal.
##
## No necesita memoria: un paso «jugar» deja de resolver en cuanto la carta salió
## de la mano, y un paso «atacar» deja de ser legal en cuanto ese Fiador atacó.
static func _jugada_de_guion(
	motor: MotorDePalabra, perfil: PerfilIA, lado: int
) -> JugadaDePalabra:
	var f: EstadoFirma = motor.estado.firma(lado)
	for paso: Dictionary in perfil.guion_de_turno(f.turnos_jugados):
		var j: JugadaDePalabra = _jugada_de_paso(motor, paso, lado)
		if j != null and motor.motivo_ilegal(j).is_empty():
			return j
	return null


static func _jugada_de_paso(
	motor: MotorDePalabra, paso: Dictionary, lado: int
) -> JugadaDePalabra:
	var f: EstadoFirma = motor.estado.firma(lado)
	var id: String = String(paso.get("carta", ""))
	match String(paso.get("tipo", "")):
		"pasar":
			return JugadaDePalabra.pasar(lado)
		"jugar":
			for ec: EstadoCarta in f.mano:
				if ec.id() != id:
					continue
				var objetivo: int = _objetivo_de_paso(motor, paso, ec)
				return JugadaDePalabra.jugar(
					lado,
					ec.uid,
					objetivo,
					String(paso.get("promesa", "")),
					int(paso.get("plazo", 0))
				)
		"atacar":
			for ec: EstadoCarta in f.estrado:
				if ec.id() != id:
					continue
				var objetivos: Array[int] = motor.objetivos_de_ataque(ec)
				if objetivos.is_empty():
					continue
				var objetivo: int = -1
				if String(paso.get("objetivo", "firma")) != "firma" or not objetivos.has(-1):
					objetivo = objetivos[0]
				return JugadaDePalabra.atacar(lado, ec.uid, objetivo)
	return null


static func _objetivo_de_paso(
	motor: MotorDePalabra, paso: Dictionary, ec: EstadoCarta
) -> int:
	if String(paso.get("objetivo", "")) == "firma":
		return -1
	if ec.def.objetivos.is_empty():
		return -1
	var legales: Array[int] = motor.objetivos_legales(ec, ec.def.objetivos[0])
	if legales.is_empty():
		return -1
	return legales[0]


# ---------------------------------------------------------------------------
# Auxiliares
# ---------------------------------------------------------------------------


## Valor de cuerpo de una carta: ataque + aguante que le queda. Para una Cláusula
## en mano es su daño (o 1 si no pega).
static func _valor_de_carta(motor: MotorDePalabra, ec: EstadoCarta) -> float:
	if ec == null:
		return 0.0
	if not ec.es_cuerpo():
		return maxf(1.0, float(motor.dano_de_clausula(ec)))
	return float(motor.ataque(ec) + motor.aguante_restante(ec))


static func _bono_prioridad(perfil: PerfilIA, ec: EstadoCarta) -> float:
	if perfil.keywords_prioritarias.is_empty():
		return 0.0
	if perfil.keywords_prioritarias.has(ec.def.arquetipo):
		return 0.75
	for kw: String in ec.def.keywords:
		if perfil.keywords_prioritarias.has(kw):
			return 0.75
	return 0.0


## Carta que este turno se tiraría boca abajo como señuelo (§ 7.3, el Cachuzo):
## la de menos valor de la mano, y solo si el rng lo decide.
static func _uid_de_senuelo(
	motor: MotorDePalabra, perfil: PerfilIA, rng: RandomNumberGenerator, lado: int
) -> int:
	if not motor.estado.mesa.al_fiado or perfil.prob_senuelo <= 0.0:
		return -1
	if rng.randf() >= perfil.prob_senuelo:
		return -1
	var peor: EstadoCarta = null
	var peor_valor: float = 0.0
	for ec: EstadoCarta in motor.estado.firma(lado).mano:
		var v: float = _valor_de_carta(motor, ec)
		if peor == null or v < peor_valor:
			peor = ec
			peor_valor = v
	return peor.uid if peor != null else -1


static func _tipo_al_azar(rng: RandomNumberGenerator) -> Palabra.Tipo:
	var tipos: Array[Palabra.Tipo] = [
		Palabra.Tipo.FIADOR, Palabra.Tipo.SOPORTE, Palabra.Tipo.CLAUSULA
	]
	return tipos[rng.randi_range(0, tipos.size() - 1)]
