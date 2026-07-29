# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name PruebaReglasBase
extends SuiteDePalabra

## § 8.1 del diseño — reglas base, más las banderas de módulo (§ 4).


func _init() -> void:
	nombre = "§ 8.1 reglas base"


func casos() -> Array[String]:
	return [
		"test_credito_sube_y_topea_en_10",
		"test_credito_no_gastado_se_pierde",
		"test_mora_de_mazo_es_acumulativa",
		"test_duelo_incobrable_al_turno_30",
		"test_la_vuelta_solo_para_el_segundo",
		"test_carta_sin_efecto_legal_no_se_puede_jugar",
		"test_banderas_de_modulo_arrancan_apagadas",
	]


func test_credito_sube_y_topea_en_10() -> void:
	var m: MotorDePalabra = duelo()
	var vistos: Array[int] = []
	while m.estado.turno < 24 and not m.estado.terminado:
		if m.estado.activo == 0:
			vistos.append(m.estado.firma(0).credito)
		m.terminar_turno()
	af_eq(vistos.size(), 12, "12 turnos propios en 24 turnos globales")
	if vistos.size() < 12:
		fin()
		return
	af_eq(vistos[0], 1, "el Crédito arranca en 1")
	af_eq(vistos[1], 2, "sube 1 por turno propio")
	af_eq(vistos[9], 10, "al décimo turno propio llega a 10")
	af_eq(vistos[11], 10, "y topea en 10")
	fin()


func test_credito_no_gastado_se_pierde() -> void:
	var m: MotorDePalabra = duelo()
	af_eq(m.estado.firma(0).credito, 1, "turno 1: 1 de Crédito")
	m.terminar_turno()
	af_eq(m.estado.firma(0).credito, 0, "el Crédito no gastado se pierde")
	m.terminar_turno()
	af_eq(m.estado.activo, 0, "de vuelta al primer jugador")
	af_eq(m.estado.firma(0).credito, 2, "no acumula: arranca en 2, no en 3")
	fin()


func test_mora_de_mazo_es_acumulativa() -> void:
	var m: MotorDePalabra = duelo()
	m.depurar_vaciar_mazo(0)
	var aval: int = m.estado.firma(0).aval
	siguiente_turno_de(m, 0)
	af_eq(m.estado.firma(0).aval, aval - 1, "primer robo fallido: 1 de Aval")
	af_eq(m.estado.firma(0).mora_de_mazo, 1, "contador en 1")
	siguiente_turno_de(m, 0)
	af_eq(m.estado.firma(0).aval, aval - 3, "segundo robo fallido: 2 más")
	siguiente_turno_de(m, 0)
	af_eq(m.estado.firma(0).aval, aval - 6, "tercero: 3 más")
	af_eq(m.estado.firma(0).mora_de_mazo, 3, "el contador no se reinicia")
	fin()


func test_duelo_incobrable_al_turno_30() -> void:
	var mesa: ConfigMesa = ConfigMesa.base()
	mesa.desafiante = 1
	var m: MotorDePalabra = duelo(mesa)
	var guardia: int = 0
	while not m.estado.terminado and guardia < 40:
		guardia += 1
		m.terminar_turno()
	af(m.estado.terminado, "el duelo termina solo")
	af_eq(m.estado.turno, 30, "se declara al terminar el turno 30")
	af_eq(m.estado.motivo_fin, "incobrable", "motivo: incobrable")
	af_eq(m.estado.ganador, 0, "en empate pierde quien desafió")
	fin()


func test_la_vuelta_solo_para_el_segundo() -> void:
	var m: MotorDePalabra = duelo(null, 0)
	af_eq(m.estado.firma(0).mano.size(), 3, "el primero arranca con 3 y no roba en su turno 1")
	af_eq(m.estado.firma(1).mano.size(), 5, "el segundo arranca con 4 + La Vuelta")
	af_eq(contar(m, 0, Palabra.Zona.MANO, Palabra.T_LA_VUELTA), 0, "el primero no tiene La Vuelta")
	af_eq(contar(m, 1, Palabra.Zona.MANO, Palabra.T_LA_VUELTA), 1, "el segundo sí")
	fin()


func test_carta_sin_efecto_legal_no_se_puede_jugar() -> void:
	var m: MotorDePalabra = duelo()
	m.depurar_set_credito(0, 10)
	var u_rota: int = m.depurar_poner_en_mano(0, "palabra_rota")
	var u_erratas: int = m.depurar_poner_en_mano(0, "fe_de_erratas")
	var u_pregon: int = m.depurar_poner_en_mano(0, "pregon_de_ventanilla")
	af(
		not m.motivo_ilegal(JugadaDePalabra.jugar(0, u_rota)).is_empty(),
		"Palabra Rota sin Promesas pendientes no se puede jugar"
	)
	af(
		not m.motivo_ilegal(JugadaDePalabra.jugar(0, u_erratas)).is_empty(),
		"Fe de Erratas con el Estrado propio vacío no se puede jugar"
	)
	af(
		not m.motivo_ilegal(JugadaDePalabra.jugar(0, u_pregon)).is_empty(),
		"Pregón de Ventanilla sin De palabra no se puede jugar"
	)
	# Ahora sí: un Fiador con De palabra en el Estrado habilita las dos primeras.
	var jardinera: int = m.depurar_poner_en_estrado(0, "maestra_jardinera")
	af(
		m.motivo_ilegal(JugadaDePalabra.jugar(0, u_pregon)).is_empty(),
		"con un De palabra en el Estrado, el Pregón es legal"
	)
	af(
		m.motivo_ilegal(JugadaDePalabra.jugar(0, u_erratas, jardinera)).is_empty(),
		"con un Fiador aliado, Fe de Erratas es legal"
	)
	fin()


func test_banderas_de_modulo_arrancan_apagadas() -> void:
	var mesa: ConfigMesa = ConfigMesa.base()
	af(not mesa.empenar, "empeñar apagado en la mesa base")
	af(not mesa.al_fiado, "al fiado apagado")
	af(not mesa.balanza, "Balanza apagada")
	af(not mesa.modo_rito, "modo rito apagado")
	af_eq(mesa.amplificacion_de_palabra, 1.0, "amplificación De palabra en 1.0")
	af_eq(mesa.amplificacion_letra_chica, 1.0, "amplificación Letra chica en 1.0")
	af_eq(mesa.repeticiones(Palabra.TR_DE_PALABRA), 1, "sin Balanza, De palabra resuelve una vez")
	af_eq(mesa.repeticiones(Palabra.TR_LETRA_CHICA), 1, "sin Balanza, Letra chica resuelve una vez")
	var m: MotorDePalabra = duelo(mesa)
	var u: int = m.depurar_poner_en_mano(0, "peon_de_vina")
	af(
		not m.motivo_ilegal(JugadaDePalabra.empenar(0, u)).is_empty(),
		"sin el módulo, no se puede empeñar"
	)
	fin()
