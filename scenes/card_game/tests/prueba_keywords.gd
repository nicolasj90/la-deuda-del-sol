# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name PruebaKeywords
extends SuiteDePalabra

## § 8.2 del diseño — los 6 keywords y sus aclaraciones convertidas en regla.


func _init() -> void:
	nombre = "§ 8.2 keywords"


func casos() -> Array[String]:
	return [
		"test_dos_garantes_el_atacante_elige",
		"test_garante_no_restringe_clausulas",
		"test_garante_no_protege_carta_boca_abajo",
		"test_soporte_puede_ser_garante",
		"test_sello_no_se_consume_con_dano_cero",
		"test_interes_coste_topea_en_10_y_ataque_en_mas_5",
		"test_interes_sigue_devengando_en_el_empenadero",
		"test_al_fiado_descuenta_sobre_el_coste_base_no_el_crecido",
	]


func test_dos_garantes_el_atacante_elige() -> void:
	var m: MotorDePalabra = duelo()
	var atacante: int = m.depurar_poner_en_estrado(0, "mula_de_reparto")
	var g1: int = m.depurar_poner_en_estrado(1, "hornera_de_rosaura")
	var g2: int = m.depurar_poner_en_estrado(1, "sereno_del_archivo")
	var libre: int = m.depurar_poner_en_estrado(1, "peon_de_vina")
	var objetivos: Array[int] = m.objetivos_de_ataque(m.estado.carta(atacante))
	af_eq(objetivos.size(), 2, "solo los dos Garantes son objetivo")
	af(
		objetivos.has(g1) and objetivos.has(g2),
		"los dos Garantes están disponibles: el atacante elige"
	)
	af(not objetivos.has(libre), "el Fiador sin Garante no se puede tocar")
	af(not objetivos.has(-1), "la Firma tampoco")
	af(m.ejecutar(JugadaDePalabra.atacar(0, atacante, g2)), "puede elegir el segundo Garante")
	af_eq(m.estado.carta(g2).dano, 0, "el Sello del Sereno se comió el golpe")
	fin()


func test_garante_no_restringe_clausulas() -> void:
	var m: MotorDePalabra = duelo()
	m.depurar_set_credito(0, 10)
	m.depurar_poner_en_estrado(1, "hornera_de_rosaura")
	var pagare: int = m.depurar_poner_en_mano(0, "pagare_a_la_vista")
	var aval: int = m.estado.firma(1).aval
	af(
		m.motivo_ilegal(JugadaDePalabra.jugar(0, pagare, -1)).is_empty(),
		"un Pagaré pega en la Firma con Garantes en pie"
	)
	af(m.ejecutar(JugadaDePalabra.jugar(0, pagare, -1)), "la Cláusula se resuelve")
	af_eq(m.estado.firma(1).aval, aval - 2, "2 de daño a la Firma rival")
	fin()


func test_garante_no_protege_carta_boca_abajo() -> void:
	var m: MotorDePalabra = duelo(ConfigMesa.el_fiado(), 1)
	m.depurar_set_credito(1, 10)
	var viajera: int = m.depurar_poner_en_mano(1, "peon_de_vina")
	var j: JugadaDePalabra = JugadaDePalabra.jugar(1, viajera)
	j.al_fiado = true
	af(m.ejecutar(j), "el lado 1 juega una carta al fiado")
	af_eq(m.estado.carta(viajera).zona, Palabra.Zona.VIAJE, "la carta viaja")
	var garante: int = m.depurar_poner_en_estrado(1, "hornera_de_rosaura")
	m.terminar_turno()
	af_eq(m.estado.activo, 0, "turno del lado 0")
	var atacante: int = m.depurar_poner_en_estrado(0, "mula_de_reparto")
	var objetivos: Array[int] = m.objetivos_de_ataque(m.estado.carta(atacante))
	af_eq(objetivos, [garante], "el Garante impone el objetivo")
	af(not objetivos.has(viajera), "la carta boca abajo no es atacable ni la protege el Garante")
	var denuncia: JugadaDePalabra = JugadaDePalabra.denunciar(0, viajera, Palabra.Tipo.FIADOR)
	af(
		m.motivo_ilegal(denuncia).is_empty(),
		"la denuncia no es un ataque: pasa por encima del Garante"
	)
	af(m.ejecutar(denuncia), "se denuncia")
	af_eq(m.estado.carta(viajera).zona, Palabra.Zona.DESCARTE, "acertó el tipo: se rompe")
	fin()


func test_soporte_puede_ser_garante() -> void:
	var m: MotorDePalabra = duelo()
	var atacante: int = m.depurar_poner_en_estrado(0, "mula_de_reparto")
	var tranquera: int = m.depurar_poner_en_estrado(1, "tranquera_cerrada")
	m.depurar_poner_en_estrado(1, "peon_de_vina")
	var objetivos: Array[int] = m.objetivos_de_ataque(m.estado.carta(atacante))
	af_eq(objetivos, [tranquera], "un Soporte con Garante impone el objetivo")
	var soporte_propio: int = m.depurar_poner_en_estrado(0, "tranquera_cerrada")
	af_eq(
		m.motivo_ilegal(JugadaDePalabra.atacar(0, soporte_propio, tranquera)),
		"un Soporte no ataca",
		"ser Garante es sobre ser atacado, no sobre atacar"
	)
	fin()


func test_sello_no_se_consume_con_dano_cero() -> void:
	var m: MotorDePalabra = duelo()
	var sereno: int = m.depurar_poner_en_estrado(1, "sereno_del_archivo")
	var flojo: int = m.depurar_poner_en_estrado(0, "peon_de_vina")
	m.depurar_set_mods(flojo, -2, 0)
	af_eq(m.ataque(m.estado.carta(flojo)), 0, "el atacante pega 0")
	af(m.ejecutar(JugadaDePalabra.atacar(0, flojo, sereno)), "el ataque de 0 es legal")
	af(m.estado.carta(sereno).tiene(Palabra.KW_SELLO), "un ataque de 0 no consume el Sello")
	af_eq(m.eventos_de(EventoDuelo.SELLO_CONSUMIDO).size(), 0, "no hubo Sello consumido")
	var fuerte: int = m.depurar_poner_en_estrado(0, "mula_de_reparto")
	af(m.ejecutar(JugadaDePalabra.atacar(0, fuerte, sereno)), "ahora sí pega")
	af(not m.estado.carta(sereno).tiene(Palabra.KW_SELLO), "el Sello se consumió")
	af_eq(m.estado.carta(sereno).dano, 0, "y absorbió todo el daño")
	fin()


func test_interes_coste_topea_en_10_y_ataque_en_mas_5() -> void:
	var m: MotorDePalabra = duelo()
	var uid: int = m.depurar_poner_en_mano(0, "cobrador_de_la_camara")
	m.depurar_pasar_turnos(19)
	var ec: EstadoCarta = m.estado.carta(uid)
	af_eq(ec.interes, 9, "9 turnos propios enteros en la mano devengan 9")
	af_eq(m.coste(ec), 10, "el coste topea en 10 (base 2 + 9 sería 11)")
	af_eq(m.ataque(ec), 7, "el ataque topea en +5 sobre el base (2 + 5)")
	af_eq(ec.def.ataque_base, 2, "la definición no se toca nunca")
	fin()


func test_interes_sigue_devengando_en_el_empenadero() -> void:
	var m: MotorDePalabra = duelo()
	var uid: int = m.depurar_poner_en_empenadero(0, "cobrador_de_la_camara")
	m.depurar_pasar_turnos(3)
	af_eq(m.estado.carta(uid).interes, 1, "una prenda empeñada sigue devengando")
	m.depurar_pasar_turnos(2)
	af_eq(m.estado.carta(uid).interes, 2, "y sigue")
	af_eq(m.estado.carta(uid).zona, Palabra.Zona.EMPENADERO, "sin salir del Empeñadero")
	fin()


func test_al_fiado_descuenta_sobre_el_coste_base_no_el_crecido() -> void:
	var m: MotorDePalabra = duelo(ConfigMesa.el_fiado())
	var uid: int = m.depurar_poner_en_mano(0, "cobrador_de_la_camara")
	m.depurar_set_interes(uid, 3)
	var ec: EstadoCarta = m.estado.carta(uid)
	af_eq(m.coste(ec), 5, "con 3 de Interés el coste normal es 5")
	af_eq(m.coste_al_fiado(ec), 0, "al fiado el descuento va sobre el base: 2 - 2 = 0")
	m.depurar_set_credito(0, 4)
	var j: JugadaDePalabra = JugadaDePalabra.jugar(0, uid)
	j.al_fiado = true
	af(m.ejecutar(j), "se puede jugar al fiado")
	af_eq(m.estado.firma(0).credito, 4, "no costó Crédito")
	fin()
