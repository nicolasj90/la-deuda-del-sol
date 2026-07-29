# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name PruebaPromesas
extends SuiteDePalabra

## § 8.3 del diseño — Promesas y Quebrantos: los frágiles.


func _init() -> void:
	nombre = "§ 8.3 Promesas y Quebrantos"


func casos() -> Array[String]:
	return [
		"test_promesa_sobrevive_a_la_muerte_del_fiador",
		"test_promesa_imposible_se_rompe_en_el_acto",
		"test_promesa_pendiente_se_anula_al_perder_el_duelo",
		"test_rito_promesa_pendiente_es_rota",
		"test_vencimientos_resuelven_por_antiguedad",
		"test_cumplir_gana_sobre_vencer_en_el_mismo_evento",
		"test_carta_en_viaje_no_puede_llevar_promesa",
		"test_maximo_3_promesas_pendientes",
		"test_plazo_no_se_puede_renovar",
		"test_quebranto_con_estrado_lleno_va_a_la_mora",
		"test_quebranto_en_mora_pega_a_su_firma_y_no_es_atacable",
		"test_quebranto_en_mora_entra_al_liberarse_lugar",
		"test_cuarto_quebranto_cuesta_2_aval",
		"test_quebranto_no_puede_llevar_promesas",
		"test_letra_chica_invocadora_se_frustra_con_estrado_lleno",
		"test_aoe_mata_tres_letra_chica_resuelve_izquierda_a_derecha",
	]


## Juega un Fiador desde la mano con una cláusula optativa y devuelve su uid.
func _jugar_con_promesa(
	m: MotorDePalabra, lado: int, id: String, clausula: String, plazo: int
) -> int:
	m.depurar_set_credito(lado, 10)
	var uid: int = m.depurar_poner_en_mano(lado, id)
	var j: JugadaDePalabra = JugadaDePalabra.jugar(lado, uid, -1, clausula, plazo)
	if not m.ejecutar(j):
		af(false, "no se pudo jugar %s con la promesa %s: %s" % [id, clausula, m.motivo_ilegal(j)])
	return uid


func test_promesa_sobrevive_a_la_muerte_del_fiador() -> void:
	var m: MotorDePalabra = duelo()
	var uid: int = _jugar_con_promesa(m, 0, "peon_de_vina", Palabra.CL_SIN_CLAUSULAS, 3)
	af_eq(m.estado.firma(0).promesas.size(), 1, "la Promesa quedó pendiente")
	m.depurar_dano_area(0, 5)
	af_eq(m.estado.carta(uid).zona, Palabra.Zona.DESCARTE, "el Fiador murió")
	af_eq(
		m.estado.firma(0).promesas.size(),
		1,
		"la Promesa es de la Firma: sobrevive a la muerte del Fiador"
	)
	af_eq(m.eventos_de(EventoDuelo.PROMESA_ROTA).size(), 0, "y no se rompió")
	fin()


func test_promesa_imposible_se_rompe_en_el_acto() -> void:
	var m: MotorDePalabra = duelo()
	var uid: int = _jugar_con_promesa(m, 0, "peon_de_vina", Palabra.CL_NO_ATACAR, 3)
	m.depurar_dano_area(0, 5)
	af_eq(m.estado.carta(uid).zona, Palabra.Zona.DESCARTE, "el Fiador murió")
	af_eq(m.estado.firma(0).promesas.size(), 0, "«no atacar» se volvió imposible")
	af_eq(m.eventos_de(EventoDuelo.PROMESA_ROTA).size(), 1, "y se rompió en el acto")
	af_eq(m.estado.firma(0).quebrantos().size(), 1, "nació un Quebranto de su lado")
	fin()


func test_promesa_pendiente_se_anula_al_perder_el_duelo() -> void:
	var m: MotorDePalabra = duelo()
	_jugar_con_promesa(m, 0, "peon_de_vina", Palabra.CL_SIN_CLAUSULAS, 3)
	m.depurar_vaciar_mazo(0)
	m.depurar_set_aval(0, 1)
	siguiente_turno_de(m, 0)
	af(m.estado.terminado, "el Aval llegó a 0 y el duelo terminó")
	af_eq(m.estado.ganador, 1, "gana el otro")
	af_eq(m.estado.firma(0).promesas.size(), 0, "no quedan Promesas pendientes")
	af_eq(m.eventos_de(EventoDuelo.PROMESA_ANULADA).size(), 1, "se anuló")
	af_eq(m.eventos_de(EventoDuelo.PROMESA_ROTA).size(), 0, "no hay Quebranto post mortem")
	fin()


func test_rito_promesa_pendiente_es_rota() -> void:
	var mesa: ConfigMesa = ConfigMesa.base()
	mesa.modo_rito = true
	var m: MotorDePalabra = duelo(mesa)
	_jugar_con_promesa(m, 0, "peon_de_vina", Palabra.CL_SIN_CLAUSULAS, 3)
	m.depurar_vaciar_mazo(0)
	m.depurar_set_aval(0, 1)
	siguiente_turno_de(m, 0)
	af(m.estado.terminado, "el duelo terminó")
	af_eq(
		m.eventos_de(EventoDuelo.PROMESA_ROTA).size(),
		1,
		"en el rito, la pendiente cuenta como rota"
	)
	af_eq(
		m.eventos_de(EventoDuelo.PROMESA_ANULADA).size(),
		0,
		"no se anula: el rito no se gana, se cumple"
	)
	fin()


func test_vencimientos_resuelven_por_antiguedad() -> void:
	var m: MotorDePalabra = duelo()
	_jugar_con_promesa(m, 0, "peon_de_vina", Palabra.CL_CUMPLIR_CON_LUZ, 1)
	_jugar_con_promesa(m, 0, "mula_de_reparto", Palabra.CL_CUMPLIR_CON_LUZ, 1)
	var ordenes: Array[int] = []
	for p: PromesaDePalabra in m.estado.firma(0).promesas_por_antiguedad():
		ordenes.append(p.orden)
	af_eq(ordenes.size(), 2, "dos Promesas pendientes")
	siguiente_turno_de(m, 0)
	var rotas: Array[EventoDuelo] = m.eventos_de(EventoDuelo.PROMESA_ROTA)
	af_eq(rotas.size(), 2, "las dos vencen el mismo turno")
	af_eq(int(rotas[0].datos["orden"]), ordenes[0], "la más vieja resuelve primero")
	af_eq(int(rotas[1].datos["orden"]), ordenes[1], "después la más nueva")
	fin()


func test_cumplir_gana_sobre_vencer_en_el_mismo_evento() -> void:
	var m: MotorDePalabra = duelo()
	# La vieja se cumple al vencer (nunca fue violada); la nueva iba a romperse por
	# vencimiento, pero el cumplimiento de la otra la cumple en cascada.
	_jugar_con_promesa(m, 0, "peon_de_vina", Palabra.CL_NO_ATACAR, 1)
	_jugar_con_promesa(m, 0, "mula_de_reparto", Palabra.CL_CUMPLIR_CON_LUZ, 1)
	siguiente_turno_de(m, 0)
	af_eq(m.eventos_de(EventoDuelo.PROMESA_CUMPLIDA).size(), 2, "las dos se cumplen")
	af_eq(m.eventos_de(EventoDuelo.PROMESA_ROTA).size(), 0, "cumplir gana sobre vencer")
	af_eq(m.estado.firma(0).quebrantos().size(), 0, "no nació ningún Quebranto")
	fin()


func test_carta_en_viaje_no_puede_llevar_promesa() -> void:
	var m: MotorDePalabra = duelo(ConfigMesa.el_fiado())
	m.depurar_set_credito(0, 10)
	var uid: int = m.depurar_poner_en_mano(0, "peon_de_vina")
	var j: JugadaDePalabra = JugadaDePalabra.jugar(0, uid, -1, Palabra.CL_NO_ATACAR, 2)
	j.al_fiado = true
	af(not m.motivo_ilegal(j).is_empty(), "una carta que viaja no puede llevar Promesa")
	af(not m.ejecutar(j), "el motor la rechaza")
	af_eq(m.estado.firma(0).promesas.size(), 0, "no quedó ninguna Promesa")
	# Boca abajo sin cláusula sí se puede: la cláusula se declara al revelar.
	var j2: JugadaDePalabra = JugadaDePalabra.jugar(0, uid)
	j2.al_fiado = true
	af(m.ejecutar(j2), "sin cláusula, viaja sin problema")
	fin()


func test_maximo_3_promesas_pendientes() -> void:
	var m: MotorDePalabra = duelo()
	_jugar_con_promesa(m, 0, "peon_de_vina", Palabra.CL_SIN_CLAUSULAS, 3)
	_jugar_con_promesa(m, 0, "mula_de_reparto", Palabra.CL_SIN_CLAUSULAS, 3)
	_jugar_con_promesa(m, 0, "colmillo_del_diezmo", Palabra.CL_SIN_CLAUSULAS, 3)
	af_eq(m.estado.firma(0).promesas.size(), 3, "tres pendientes")
	m.depurar_set_credito(0, 10)
	var cuarta: int = m.depurar_poner_en_mano(0, "peon_de_vina")
	af_eq(
		m.clausulas_ofrecibles(m.estado.carta(cuarta)).size(),
		0,
		"con 3 pendientes no se ofrece ninguna cláusula"
	)
	af(
		not m.motivo_ilegal(
			JugadaDePalabra.jugar(0, cuarta, -1, Palabra.CL_NO_ATACAR, 2)
		).is_empty(),
		"y no se puede declarar una cuarta"
	)
	var con_promesa: int = 0
	for j: JugadaDePalabra in m.jugadas_legales():
		if j.tipo == Palabra.TipoJugada.JUGAR and not j.promesa_tipo.is_empty():
			con_promesa += 1
	af_eq(con_promesa, 0, "las jugadas legales no ofrecen Promesas")
	fin()


func test_plazo_no_se_puede_renovar() -> void:
	var m: MotorDePalabra = duelo()
	_jugar_con_promesa(m, 0, "peon_de_vina", Palabra.CL_NO_ATACAR, 3)
	af_eq(m.estado.firma(0).promesas.size(), 1, "hay una Promesa pendiente")
	if m.estado.firma(0).promesas.is_empty():
		fin()
		return
	var p: PromesaDePalabra = m.estado.firma(0).promesas[0]
	af_eq(p.plazo_restante, 3, "nace con plazo 3")
	siguiente_turno_de(m, 0)
	af_eq(p.plazo_restante, 2, "baja a 2")
	siguiente_turno_de(m, 0)
	af_eq(p.plazo_restante, 1, "baja a 1")
	_jugar_con_promesa(m, 0, "mula_de_reparto", Palabra.CL_NO_ATACAR, 3)
	af_eq(p.plazo_restante, 1, "declarar otra Promesa no renueva la primera")
	af_eq(m.estado.firma(0).promesas.size(), 2, "son dos Promesas distintas")
	af_eq(p.plazo_original, 3, "el plazo original no cambia")
	fin()


func _armar_mora(m: MotorDePalabra) -> void:
	# Un Fiador prometido, el Estrado lleno, y una Cláusula que rompe la Promesa.
	_jugar_con_promesa(m, 0, "peon_de_vina", Palabra.CL_SIN_CLAUSULAS, 3)
	m.depurar_llenar_estrado(0)
	af_eq(m.estado.firma(0).estrado.size(), Palabra.ESTRADO_MAX, "el Estrado está lleno")
	m.depurar_set_credito(0, 10)
	var vuelta: int = m.depurar_poner_en_mano(0, Palabra.T_LA_VUELTA)
	af(m.ejecutar(JugadaDePalabra.jugar(0, vuelta)), "jugar una Cláusula rompe la Promesa")


func test_quebranto_con_estrado_lleno_va_a_la_mora() -> void:
	var m: MotorDePalabra = duelo()
	_armar_mora(m)
	af_eq(m.eventos_de(EventoDuelo.PROMESA_ROTA).size(), 1, "la Promesa se rompió")
	af_eq(m.estado.firma(0).estrado.size(), Palabra.ESTRADO_MAX, "el Estrado sigue en 7")
	af_eq(m.estado.firma(0).mora.size(), 1, "el Quebranto no se descarta: va a la Mora")
	if m.estado.firma(0).mora.is_empty():
		fin()
		return
	af_eq(m.estado.firma(0).mora[0].id(), Palabra.T_QUEBRANTO, "y es un Quebranto")
	af_eq(m.eventos_de(EventoDuelo.QUEBRANTO_A_LA_MORA).size(), 1, "quedó registrado")
	af_eq(m.estado.firma(0).quebrantos().size(), 1, "cuenta para la bolsa de 3")
	fin()


func test_quebranto_en_mora_pega_a_su_firma_y_no_es_atacable() -> void:
	var m: MotorDePalabra = duelo()
	_armar_mora(m)
	af_eq(m.estado.firma(0).mora.size(), 1, "hay un Quebranto en la Mora")
	if m.estado.firma(0).mora.is_empty():
		fin()
		return
	var en_mora: int = m.estado.firma(0).mora[0].uid
	var aval: int = m.estado.firma(0).aval
	m.terminar_turno()
	af_eq(m.estado.firma(0).aval, aval - 2, "el Quebranto en la Mora pega 2 a la Firma de su dueño")
	af_eq(m.estado.activo, 1, "turno del rival")
	var atacante: int = m.depurar_poner_en_estrado(1, "mula_de_reparto")
	var objetivos: Array[int] = m.objetivos_de_ataque(m.estado.carta(atacante))
	af(not objetivos.has(en_mora), "un Quebranto en la Mora no se puede atacar")
	af(
		not m.motivo_ilegal(JugadaDePalabra.atacar(1, atacante, en_mora)).is_empty(),
		"ni siquiera pidiéndolo"
	)
	fin()


func test_quebranto_en_mora_entra_al_liberarse_lugar() -> void:
	var m: MotorDePalabra = duelo()
	_armar_mora(m)
	af_eq(m.estado.firma(0).mora.size(), 1, "arranca en la Mora")
	m.depurar_dano_area(0, 5)
	af_eq(m.estado.firma(0).mora.size(), 0, "al liberarse lugar, la Mora se vacía")
	af_eq(
		contar(m, 0, Palabra.Zona.ESTRADO, Palabra.T_QUEBRANTO),
		1,
		"el Quebranto más viejo entra solo al Estrado"
	)
	af_eq(
		m.eventos_de(EventoDuelo.QUEBRANTO_ENTRO_DESDE_LA_MORA).size(), 1, "quedó registrado"
	)
	fin()


func test_cuarto_quebranto_cuesta_2_aval() -> void:
	var m: MotorDePalabra = duelo()
	_jugar_con_promesa(m, 0, "peon_de_vina", Palabra.CL_SIN_CLAUSULAS, 3)
	_jugar_con_promesa(m, 0, "mula_de_reparto", Palabra.CL_SIN_CLAUSULAS, 3)
	_jugar_con_promesa(m, 0, "colmillo_del_diezmo", Palabra.CL_SIN_CLAUSULAS, 3)
	m.depurar_set_credito(0, 10)
	var vuelta: int = m.depurar_poner_en_mano(0, Palabra.T_LA_VUELTA)
	af(m.ejecutar(JugadaDePalabra.jugar(0, vuelta)), "una Cláusula rompe las tres")
	af_eq(m.estado.firma(0).quebrantos().size(), 3, "nacieron 3 Quebrantos")
	_jugar_con_promesa(m, 0, "peon_de_vina", Palabra.CL_SIN_CLAUSULAS, 3)
	var aval: int = m.estado.firma(0).aval
	m.depurar_set_credito(0, 10)
	var vuelta2: int = m.depurar_poner_en_mano(0, Palabra.T_LA_VUELTA)
	af(m.ejecutar(JugadaDePalabra.jugar(0, vuelta2)), "y otra rompe la cuarta")
	af_eq(m.estado.firma(0).quebrantos().size(), 3, "no hay cuarto Quebranto")
	af_eq(
		m.estado.firma(0).aval,
		aval - Palabra.CUARTO_QUEBRANTO_AVAL,
		"la mora se paga igual: 2 de Aval"
	)
	af_eq(m.eventos_de(EventoDuelo.CUARTO_QUEBRANTO).size(), 1, "quedó registrado")
	fin()


func test_quebranto_no_puede_llevar_promesas() -> void:
	var m: MotorDePalabra = duelo()
	_jugar_con_promesa(m, 0, "peon_de_vina", Palabra.CL_SIN_CLAUSULAS, 3)
	m.depurar_set_credito(0, 10)
	var vuelta: int = m.depurar_poner_en_mano(0, Palabra.T_LA_VUELTA)
	m.ejecutar(JugadaDePalabra.jugar(0, vuelta))
	var quebrantos: Array[EstadoCarta] = m.estado.firma(0).quebrantos()
	af_eq(quebrantos.size(), 1, "nació un Quebranto")
	if quebrantos.is_empty():
		fin()
		return
	var q: EstadoCarta = quebrantos[0]
	af(not m.puede_prometer_carta(q.uid), "un Quebranto no puede llevar Promesas")
	af_eq(m.clausulas_ofrecibles(q).size(), 0, "no se le ofrece ninguna cláusula")
	af_eq(m.estado.firma(0).promesas.size(), 0, "y no quedó ninguna Promesa: el bucle está cortado")
	fin()


func test_letra_chica_invocadora_se_frustra_con_estrado_lleno() -> void:
	var m: MotorDePalabra = duelo()
	var cosme: int = m.depurar_poner_en_estrado(0, "sepulturero_cosme")
	for _i: int in 6:
		m.depurar_poner_en_estrado(0, "mula_de_reparto")
	af_eq(m.estado.firma(0).estrado.size(), Palabra.ESTRADO_MAX, "el Estrado está lleno")
	var atacante: int = m.depurar_poner_en_estrado(1, "mula_de_reparto")
	m.terminar_turno()
	af_eq(m.estado.activo, 1, "turno del rival")
	af(m.ejecutar(JugadaDePalabra.atacar(1, atacante, cosme)), "el rival mata a Cosme")
	af_eq(m.estado.carta(cosme).zona, Palabra.Zona.DESCARTE, "Cosme murió")
	af_eq(
		contar(m, 0, Palabra.Zona.ESTRADO, Palabra.T_DEUDO),
		1,
		"con 6 aliados vivos entra un Deudo"
	)
	af_eq(m.eventos_de(EventoDuelo.INVOCACION_FRUSTRADA).size(), 1, "el otro se frustra")
	af_eq(m.estado.firma(0).estrado.size(), Palabra.ESTRADO_MAX, "el Estrado no pasa de 7")
	fin()


func test_aoe_mata_tres_letra_chica_resuelve_izquierda_a_derecha() -> void:
	var m: MotorDePalabra = duelo()
	var c1: int = m.depurar_poner_en_estrado(0, "sepulturero_cosme")
	var c2: int = m.depurar_poner_en_estrado(0, "sepulturero_cosme")
	var c3: int = m.depurar_poner_en_estrado(0, "sepulturero_cosme")
	for _i: int in 4:
		m.depurar_poner_en_estrado(0, "mula_de_reparto")
	af_eq(m.estado.firma(0).estrado.size(), Palabra.ESTRADO_MAX, "7 en el Estrado")
	m.depurar_dano_area(0, 2)
	var resueltas: Array[EventoDuelo] = m.eventos_de(EventoDuelo.LETRA_CHICA_RESUELTA)
	af_eq(resueltas.size(), 3, "murieron los tres Cosmes")
	var uids: Array[int] = []
	for e: EventoDuelo in resueltas:
		uids.append(int(e.datos["uid"]))
	af_eq(uids, [c1, c2, c3], "las Letras chicas resuelven de izquierda a derecha")
	af_eq(
		contar(m, 0, Palabra.Zona.ESTRADO, Palabra.T_DEUDO),
		3,
		"entran 3 Deudos (quedaban 3 lugares)"
	)
	af_eq(
		m.eventos_de(EventoDuelo.INVOCACION_FRUSTRADA).size(),
		3,
		"las otras 3 invocaciones se frustran"
	)
	af_eq(m.estado.firma(0).estrado.size(), Palabra.ESTRADO_MAX, "el Estrado no pasa de 7")
	fin()
