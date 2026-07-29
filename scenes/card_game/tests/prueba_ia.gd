# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name PruebaIA
extends SuiteDePalabra

## Tests de IA del diseño § 8.6 (casos 50 a 53) más los centinelas del clon de
## duelo, que es la pieza sobre la que se apoya todo el beam search.

## Decisiones del fuzz del caso 50 («500 estados con semilla»).
const DECISIONES_DE_FUZZ: int = 500


func _init() -> void:
	nombre = "IA por perfil (§ 8.6)"


func casos() -> Array[String]:
	return [
		"test_perfiles_del_acto1_validan",
		"test_el_clon_cubre_todos_los_campos",
		"test_el_clon_no_toca_el_duelo_real",
		"test_ia_nunca_propone_jugada_ilegal",
		"test_ia_respeta_cota_de_200_nodos",
		"test_ia_es_determinista_con_la_misma_semilla",
		"test_salu_no_juega_contra_el_amanecer_anunciado",
		"test_guion_forzado_de_rosaura_solo_juega_legal",
		"test_perfil_garante_prefiere_la_tabla_y_al_contado_la_cara",
	]


# ---------------------------------------------------------------------------
# Datos y clon
# ---------------------------------------------------------------------------


func test_perfiles_del_acto1_validan() -> void:
	var errores: Array[String] = CatalogoDePerfiles.errores()
	af(errores.is_empty(), "los perfiles no validan: %s" % str(errores))
	for id: String in CatalogoDePerfiles.PERFILES_ACTO1:
		var p: PerfilIA = CatalogoDePerfiles.obtener(id)
		af(p != null, "falta el perfil '%s' del § 7.3" % id)
		if p != null:
			af(p.validar().is_empty(), "el perfil '%s' no valida" % id)
	var salu: PerfilIA = CatalogoDePerfiles.obtener("control")
	if salu != null:
		af_eq(salu.sesgo_desconfianza, 1.0, "Salu tiene que desconfiar de todo (§ 7.3)")
	fin()


## Centinela: si el motor gana un campo mutable y el clon no lo copia, la IA
## simula sobre un estado incompleto y el bug es invisible. Este test falla el día
## que eso pasa.
func test_el_clon_cubre_todos_los_campos() -> void:
	af_eq(
		ClonDeDuelo.campos_de(EstadoCarta.new()),
		ClonDeDuelo.CAMPOS_CARTA,
		"EstadoCarta cambió de campos: revisar ClonDeDuelo.clonar_carta"
	)
	af_eq(
		ClonDeDuelo.campos_de(EstadoFirma.new()),
		ClonDeDuelo.CAMPOS_FIRMA,
		"EstadoFirma cambió de campos: revisar ClonDeDuelo._clonar_firma"
	)
	af_eq(
		ClonDeDuelo.campos_de(EstadoDuelo.new()),
		ClonDeDuelo.CAMPOS_DUELO,
		"EstadoDuelo cambió de campos: revisar ClonDeDuelo.clonar_estado"
	)
	af_eq(
		ClonDeDuelo.campos_de(PromesaDePalabra.new()),
		ClonDeDuelo.CAMPOS_PROMESA,
		"PromesaDePalabra cambió de campos: revisar ClonDeDuelo.clonar_promesa"
	)
	fin()


func test_el_clon_no_toca_el_duelo_real() -> void:
	var m: MotorDePalabra = duelo(ConfigMesa.base(), 0, 21, "mula_de_reparto")
	m.depurar_set_credito(0, 10)
	var uids: Array[int] = mano_exacta(m, 0, ["mula_de_reparto", "gallina_lacrevieja"])
	var mano_antes: int = m.estado.firma(0).mano.size()
	var estrado_antes: int = m.estado.firma(0).estrado.size()
	var aval_antes: int = m.estado.firma(1).aval
	var eventos_antes: int = m.registro.size()
	var clon: MotorDePalabra = ClonDeDuelo.clonar_motor(m, 99)
	af(clon.ejecutar(JugadaDePalabra.jugar(0, uids[0])), "el clon tiene que aceptar la jugada")
	af_eq(clon.estado.firma(0).estrado.size(), estrado_antes + 1, "el clon no jugó la carta")
	af_eq(m.estado.firma(0).mano.size(), mano_antes, "el clon movió cartas del duelo real")
	af_eq(m.estado.firma(0).estrado.size(), estrado_antes, "el clon tocó el Estrado real")
	af_eq(m.estado.firma(1).aval, aval_antes, "el clon tocó el Aval real")
	af_eq(m.registro.size(), eventos_antes, "el clon emitió eventos en el duelo real")
	# Los uid se conservan: una jugada armada contra el original vale en el clon.
	af_eq(
		clon.estado.carta(uids[0]).id(), "mula_de_reparto", "el clon perdió el uid de la carta"
	)
	af_no_eq(
		clon.estado.carta(uids[1]),
		m.estado.carta(uids[1]),
		"el clon comparte la instancia de EstadoCarta con el original"
	)
	af_eq(
		clon.estado.carta(uids[1]).def,
		m.estado.carta(uids[1]).def,
		"la definición tiene que compartirse (es inmutable, § 6.2.4)"
	)
	fin()


# ---------------------------------------------------------------------------
# § 8.6 — 50, 51, 52, 53
# ---------------------------------------------------------------------------


## Caso 50: fuzz de 500 decisiones con semilla. La IA pide las jugadas al motor
## (§ 7.2.1), así que lo que se verifica es que lo que devuelve **sigue** siendo
## legal cuando el motor la mira de nuevo.
func test_ia_nunca_propone_jugada_ilegal() -> void:
	var perfiles: Array[PerfilIA] = _perfiles()
	var decisiones: int = 0
	var ilegales: int = 0
	var fuera_de_lista: int = 0
	var semilla: int = 4242
	while decisiones < DECISIONES_DE_FUZZ:
		# Mesa completa cada 3 duelos: así el fuzz también toca empeñar, rescatar
		# y denunciar, que solo existen con los módulos encendidos (§ 4).
		var mesa: ConfigMesa = ConfigMesa.base() if semilla % 3 != 0 else ConfigMesa.el_fiado()
		var perfil_0: PerfilIA = perfiles[semilla % perfiles.size()]
		var perfil_1: PerfilIA = perfiles[(semilla + 3) % perfiles.size()]
		var m: MotorDePalabra = MotorDePalabra.new(semilla)
		m.iniciar(
			mesa,
			MazosDePrueba.del_perfil(perfil_0.id, mesa),
			MazosDePrueba.del_perfil(perfil_1.id, mesa),
			semilla % 2,
			true
		)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = semilla
		var pasos: int = 0
		while not m.estado.terminado and decisiones < DECISIONES_DE_FUZZ and pasos < 400:
			pasos += 1
			var lado: int = m.estado.activo
			var perfil: PerfilIA = perfil_0 if lado == 0 else perfil_1
			var j: JugadaDePalabra = IADePalabra.elegir_jugada(m, perfil, rng, ["el_amanecer"])
			decisiones += 1
			var motivo: String = m.motivo_ilegal(j)
			if not motivo.is_empty():
				ilegales += 1
				_fallo_de_jugada("ilegal", perfil, m, j, motivo)
			elif not _esta_en_la_lista(m, j):
				fuera_de_lista += 1
				_fallo_de_jugada("fuera de jugadas_legales", perfil, m, j, "")
			if not m.ejecutar(j):
				break
		semilla += 1
	af_eq(decisiones, DECISIONES_DE_FUZZ, "el fuzz no llegó a las 500 decisiones")
	af_eq(ilegales, 0, "la IA propuso jugadas ilegales")
	af_eq(fuera_de_lista, 0, "la IA propuso jugadas que no estaban en jugadas_legales")
	fin()


## Caso 51: la cota de 200 nodos es dura, y la posición de este test es la que el
## § 7.4 marca como peligrosa (mano llena, 10 de Crédito, perfil `interes`).
func test_ia_respeta_cota_de_200_nodos() -> void:
	var m: MotorDePalabra = duelo(ConfigMesa.el_fiado(), 0, 31)
	mano_exacta(
		m,
		0,
		[
			"gallina_lacrevieja",
			"peon_de_vina",
			"mula_de_reparto",
			"colmillo_del_diezmo",
			"lampara_de_palabra",
			"tranquera_cerrada",
			"hornera_de_rosaura",
			"cobrador_de_la_camara",
			"sepulturero_cosme",
			"deudo_del_difunto",
		]
	)
	m.depurar_set_credito(0, 10)
	m.depurar_poner_en_estrado(0, "peon_de_vina")
	m.depurar_poner_en_estrado(0, "mula_de_reparto")
	m.depurar_poner_en_estrado(1, "peon_de_vina")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var plan: Dictionary = IADePalabra.planificar(m, CatalogoDePerfiles.obtener("interes"), rng)
	af(int(plan["nodos"]) <= IADePalabra.NODOS_MAX, "se pasó de 200 nodos: %s" % str(plan["nodos"]))
	# Y la cota tiene que **morder**: en esta posición la búsqueda se corta por
	# nodos, no por profundidad. Si un día no muerde, la cota es adorno.
	af_eq(int(plan["nodos"]), IADePalabra.NODOS_MAX, "la cota de nodos no llegó a morder")
	af(not (plan["jugadas"] as Array).is_empty(), "no encontró ninguna jugada que valga la pena")
	af_eq(IADePalabra.BEAM_ANCHO, 4, "el beam del § 7.2.2 es de ancho 4")
	# Y la mano llena sigue en pie: nada de esto tocó el duelo real de más.
	af_eq(m.estado.firma(0).mano.size(), 10, "la planificación movió cartas del duelo real")
	fin()


## Caso 52: misma semilla, misma decisión; y el duelo entero es reproducible.
func test_ia_es_determinista_con_la_misma_semilla() -> void:
	var perfil: PerfilIA = CatalogoDePerfiles.obtener("letra_chica")
	var textos: Array[String] = []
	for intento: int in 2:
		var m: MotorDePalabra = duelo(ConfigMesa.base(), 0, 77)
		mano_exacta(m, 0, ["mula_de_reparto", "gallina_lacrevieja", "sepulturero_cosme"])
		m.depurar_set_credito(0, 6)
		m.depurar_poner_en_estrado(0, "colmillo_del_diezmo")
		m.depurar_poner_en_estrado(1, "peon_de_vina")
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 909
		var plan: Dictionary = IADePalabra.planificar(m, perfil, rng)
		var texto: String = "%d nodos" % int(plan["nodos"])
		for j_v: Variant in plan["jugadas"]:
			texto += " " + (j_v as JugadaDePalabra).como_texto()
		textos.append(texto)
	af_eq(textos[0], textos[1], "dos planes con la misma semilla salieron distintos")
	# Y un duelo completo IA contra IA también es reproducible.
	var resultados: Array[String] = []
	for intento2: int in 2:
		var mesa: ConfigMesa = ConfigMesa.base()
		var m2: MotorDePalabra = MotorDePalabra.new(1234)
		m2.iniciar(
			mesa,
			MazosDePrueba.del_perfil("garante", mesa),
			MazosDePrueba.del_perfil("al_contado", mesa),
			0,
			true
		)
		var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
		rng2.seed = 1234
		var r: Dictionary = PilotoDePalabra.jugar_duelo(
			m2,
			CatalogoDePerfiles.obtener("garante"),
			CatalogoDePerfiles.obtener("al_contado"),
			rng2
		)
		resultados.append(
			(
				"ganador=%d motivo=%s turnos=%d jugadas=%d eventos=%d"
				% [r["ganador"], r["motivo"], r["turnos"], r["jugadas"], m2.registro.size()]
			)
		)
	af_eq(resultados[0], resultados[1], "dos duelos con la misma semilla salieron distintos")
	fin()


## Caso 53: el defecto de personaje de Salu (§ 7.3), como test.
##
## Posición: Salu (lado 1) tiene un 3/3 con una Promesa «no atacar» encima y la
## mano vacía; Ciro (lado 0) **anunció El Amanecer** y ya tiene Crédito para
## pagarlo. Atacar la Firma rompe la Promesa y cuesta un Quebranto: solo vale la
## pena si hay apuro. Salu no cree el anuncio (`sesgo_desconfianza = 1.0`), no
## tiene apuro y no ataca. La misma IA con el mismo perfil y **un solo número
## cambiado** ataca.
func test_salu_no_juega_contra_el_amanecer_anunciado() -> void:
	var anuncio: Array[String] = ["el_amanecer"]
	var salu: PerfilIA = CatalogoDePerfiles.obtener("control")
	var confiada: PerfilIA = CatalogoDePerfiles.variante("control", "sesgo_desconfianza", 0.0)
	af(salu != null and confiada != null, "faltan los perfiles del caso")
	if salu == null or confiada == null:
		fin()
		return
	var m_salu: MotorDePalabra = _posicion_del_amanecer()
	var m_conf: MotorDePalabra = _posicion_del_amanecer()
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 3
	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_b.seed = 3
	var plan_salu: Dictionary = IADePalabra.planificar(m_salu, salu, rng_a, anuncio)
	var plan_conf: Dictionary = IADePalabra.planificar(m_conf, confiada, rng_b, anuncio)
	af_eq(float(plan_salu["urgencia"]), 0.0, "Salu no puede darle peso al anuncio (§ 7.2.6)")
	af(float(plan_conf["urgencia"]) > 0.0, "la IA confiada tiene que creer el anuncio")
	af(
		not _tiene_ataque(plan_salu),
		"Salu jugó contra el Amanecer anunciado: %s" % _texto_del_plan(plan_salu)
	)
	af(
		_tiene_ataque(plan_conf),
		"la IA confiada tendría que apurar a Ciro: %s" % _texto_del_plan(plan_conf)
	)
	# Y la Promesa de Salu sigue en pie: no la rompe ni por apuro ni por error.
	af_eq(
		IADePalabra.elegir_jugada(m_salu, salu, rng_a, anuncio).tipo,
		Palabra.TipoJugada.PASAR,
		"con la mano vacía y sin apuro, Salu pasa"
	)
	fin()


# ---------------------------------------------------------------------------
# Perfiles: que la marca del § 7.3 se note
# ---------------------------------------------------------------------------


func test_guion_forzado_de_rosaura_solo_juega_legal() -> void:
	var rosaura: PerfilIA = CatalogoDePerfiles.obtener("garante")
	af(not rosaura.guion_forzado.is_empty(), "Rosaura necesita guion de tutorial (§ 7.3)")
	var mesa: ConfigMesa = ConfigMesa.base()
	var m: MotorDePalabra = MotorDePalabra.new(8)
	m.iniciar(mesa, MazosDePrueba.del_perfil("garante", mesa), mazo(30), 0, false)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 8
	var guionadas: int = 0
	for turno: int in 6:
		if m.estado.terminado:
			break
		if m.estado.activo == 0:
			var plan: Dictionary = IADePalabra.planificar(m, rosaura, rng)
			if bool(plan["guion"]):
				guionadas += 1
				var j: JugadaDePalabra = (plan["jugadas"] as Array)[0] as JugadaDePalabra
				af_eq(m.motivo_ilegal(j), "", "el guion propuso una jugada ilegal")
		PilotoDePalabra.jugar_turno(m, rosaura, rng)
	af(guionadas > 0, "el guion de Rosaura no se usó ni una vez")
	fin()


## La marca de cada perfil del § 7.3 tiene que verse en la decisión. Misma
## posición, mismo rng: un 3/3 propio, un 2/2 rival y la Firma rival abierta.
## Rosaura (peso_tabla 2, peso_cara 0.3) limpia el Estrado; el Tallador
## (peso_cara 2, peso_tabla 0.3) va a la cara.
func test_perfil_garante_prefiere_la_tabla_y_al_contado_la_cara() -> void:
	var elecciones: Dictionary = {}
	var objetivos: Dictionary = {}
	for id: String in ["garante", "al_contado"]:
		var m: MotorDePalabra = duelo(ConfigMesa.base(), 0, 41)
		m.depurar_vaciar_mano(0)
		m.depurar_poner_en_estrado(0, "mula_de_reparto")
		objetivos[id] = m.depurar_poner_en_estrado(1, "peon_de_vina")
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 17
		elecciones[id] = IADePalabra.elegir_jugada(m, CatalogoDePerfiles.obtener(id), rng)
	var j_garante: JugadaDePalabra = elecciones["garante"]
	var j_contado: JugadaDePalabra = elecciones["al_contado"]
	af_eq(j_garante.tipo, Palabra.TipoJugada.ATACAR, "Rosaura tenía un cuerpo que matar")
	af_eq(
		j_garante.objetivo_uid,
		int(objetivos["garante"]),
		"Rosaura tiene que limpiar el Estrado, no ir a la cara (peso_tabla 2)"
	)
	af_eq(
		j_contado.tipo,
		Palabra.TipoJugada.ATACAR,
		"el Tallador tiene que ir a la cara (peso_cara 2)"
	)
	af_eq(j_contado.objetivo_uid, -1, "el Tallador ataca la Firma, no el cuerpo")
	fin()


# ---------------------------------------------------------------------------
# Auxiliares
# ---------------------------------------------------------------------------


func _perfiles() -> Array[PerfilIA]:
	var salida: Array[PerfilIA] = []
	for id: String in CatalogoDePerfiles.PERFILES_ACTO1:
		var p: PerfilIA = CatalogoDePerfiles.obtener(id)
		if p != null:
			salida.append(p)
	return salida


## Posición del caso 53: Salu (lado 1) con un 3/3 prometido y la mano vacía, Ciro
## (lado 0) con Crédito para El Amanecer.
func _posicion_del_amanecer() -> MotorDePalabra:
	var m: MotorDePalabra = duelo(ConfigMesa.base(), 1, 61)
	m.depurar_set_credito(1, 10)
	var uids: Array[int] = mano_exacta(m, 1, ["mula_de_reparto"])
	m.ejecutar(JugadaDePalabra.jugar(1, uids[0], -1, Palabra.CL_NO_ATACAR, 3))
	siguiente_turno_de(m, 1)
	m.depurar_vaciar_mano(1)
	# Ciro ya puede pagar los 10 de El Amanecer: el anuncio es creíble.
	m.estado.firma(0).credito_max = Palabra.CREDITO_TOPE
	return m


func _tiene_ataque(plan: Dictionary) -> bool:
	for j_v: Variant in plan["jugadas"]:
		if (j_v as JugadaDePalabra).tipo == Palabra.TipoJugada.ATACAR:
			return true
	return false


func _texto_del_plan(plan: Dictionary) -> String:
	var texto: String = ""
	for j_v: Variant in plan["jugadas"]:
		texto += (j_v as JugadaDePalabra).como_texto() + " "
	return texto if not texto.is_empty() else "(plan vacío)"


func _esta_en_la_lista(m: MotorDePalabra, j: JugadaDePalabra) -> bool:
	for otra: JugadaDePalabra in m.jugadas_legales(j.lado):
		if otra.como_texto() == j.como_texto():
			return true
	return false


func _fallo_de_jugada(
	que: String, perfil: PerfilIA, m: MotorDePalabra, j: JugadaDePalabra, motivo: String
) -> void:
	_fallos.append(
		(
			"%s — perfil %s, %s, jugada %s %s"
			% [que, perfil.id, m.estado.como_texto(), j.como_texto(), motivo]
		)
	)
