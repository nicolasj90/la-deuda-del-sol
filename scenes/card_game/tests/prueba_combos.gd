# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name PruebaCombos
extends SuiteDePalabra

## § 8.4 del diseño — combos y cartas concretas: los cortes a los combos
## degenerados de § 10.


func _init() -> void:
	nombre = "§ 8.4 combos y cartas"


func casos() -> Array[String]:
	return [
		"test_empenar_una_vez_por_turno",
		"test_empeno_no_supera_el_tope_de_credito",
		"test_porteador_topea_en_mas_3",
		"test_fiel_evita_una_sola_destruccion_por_turno",
		"test_fiel_enciende_una_sola_vez_por_turno",
		"test_lampara_roba_maximo_2_por_turno",
		"test_amanecer_con_lampara_no_desborda_la_mano",
		"test_forastera_no_tiene_letra_chica",
		"test_copia_espejo_no_invoca_otra_copia",
		"test_tasador_decano_pone_a_cero_maximo_2",
		"test_robo_con_mano_llena_va_al_empenadero_propio",
		"test_quebranto_del_peaje_pone_quebranto_del_lado_rival",
	]


## Juega un Fiador con cláusula optativa (helper compartido con § 8.3).
func _jugar_con_promesa(
	m: MotorDePalabra, lado: int, id: String, clausula: String, plazo: int
) -> int:
	m.depurar_set_credito(lado, 10)
	var uid: int = m.depurar_poner_en_mano(lado, id)
	var j: JugadaDePalabra = JugadaDePalabra.jugar(lado, uid, -1, clausula, plazo)
	if not m.ejecutar(j):
		af(false, "no se pudo jugar %s con %s: %s" % [id, clausula, m.motivo_ilegal(j)])
	return uid


## Tres cumplimientos de Promesa en un mismo turno, con la cadena
## «jugar otro Fiador».
func _tres_cumplimientos(m: MotorDePalabra) -> void:
	_jugar_con_promesa(m, 0, "peon_de_vina", Palabra.CL_JUGAR_OTRO_FIADOR, 2)
	_jugar_con_promesa(m, 0, "peon_de_vina", Palabra.CL_JUGAR_OTRO_FIADOR, 2)
	_jugar_con_promesa(m, 0, "peon_de_vina", Palabra.CL_JUGAR_OTRO_FIADOR, 2)
	m.depurar_set_credito(0, 10)
	var ultimo: int = m.depurar_poner_en_mano(0, "peon_de_vina")
	af(m.ejecutar(JugadaDePalabra.jugar(0, ultimo)), "el último Fiador cierra la cadena")


func test_empenar_una_vez_por_turno() -> void:
	var m: MotorDePalabra = duelo(ConfigMesa.el_fiado())
	var u1: int = m.depurar_poner_en_mano(0, "peon_de_vina")
	var u2: int = m.depurar_poner_en_mano(0, "mula_de_reparto")
	af(m.ejecutar(JugadaDePalabra.empenar(0, u1)), "el primer empeño va")
	af(not m.ejecutar(JugadaDePalabra.empenar(0, u2)), "el segundo, no: una vez por turno")
	af_eq(m.estado.firma(0).empenadero.size(), 1, "solo una prenda")
	siguiente_turno_de(m, 0)
	af(m.ejecutar(JugadaDePalabra.empenar(0, u2)), "al turno siguiente se puede otra vez")
	af_eq(m.estado.firma(0).empenadero.size(), 2, "dos prendas")
	fin()


func test_empeno_no_supera_el_tope_de_credito() -> void:
	var m: MotorDePalabra = duelo(ConfigMesa.el_fiado())
	m.depurar_set_credito(0, Palabra.CREDITO_TOPE)
	var u: int = m.depurar_poner_en_mano(0, "peon_de_vina")
	af(m.ejecutar(JugadaDePalabra.empenar(0, u)), "se empeña igual")
	af_eq(
		m.estado.firma(0).credito,
		Palabra.CREDITO_TOPE,
		"el Crédito de empeño no pasa el tope de 10"
	)
	fin()


func test_porteador_topea_en_mas_3() -> void:
	var m: MotorDePalabra = duelo(ConfigMesa.el_fiado())
	var uid: int = m.depurar_poner_en_estrado(0, "porteador_empenadero")
	var ec: EstadoCarta = m.estado.carta(uid)
	af_eq(m.ataque(ec), 2, "sin Empeñadero, 2 de ataque")
	af_eq(m.aguante(ec), 5, "y 5 de aguante")
	m.depurar_poner_en_empenadero(0, "peon_de_vina")
	m.depurar_poner_en_empenadero(0, "peon_de_vina")
	af_eq(m.ataque(ec), 4, "con 2 prendas, +2")
	af_eq(m.aguante(ec), 7, "idem aguante")
	for _i: int in 3:
		m.depurar_poner_en_empenadero(0, "peon_de_vina")
	af_eq(m.estado.firma(0).empenadero.size(), 5, "5 prendas")
	af_eq(m.ataque(ec), 5, "topea en +3")
	af_eq(m.aguante(ec), 8, "topea en +3")
	fin()


func test_fiel_evita_una_sola_destruccion_por_turno() -> void:
	var m: MotorDePalabra = duelo()
	var fiel: int = _jugar_con_promesa(m, 0, "fiel_el_que_espera", Palabra.CL_SIN_CLAUSULAS, 3)
	af_eq(m.estado.firma(0).promesas.size(), 1, "hay una Promesa pendiente")
	if m.estado.firma(0).promesas.is_empty():
		fin()
		return
	var p: PromesaDePalabra = m.estado.firma(0).promesas[0]
	af_eq(p.plazo_restante, 3, "la Promesa nace con plazo 3")
	m.depurar_dano_area(0, 9)
	af_eq(m.estado.carta(fiel).zona, Palabra.Zona.ESTRADO, "la primera vez no es destruido")
	af_eq(p.plazo_restante, 2, "consumió un plazo: espera con vos")
	af_eq(m.eventos_de(EventoDuelo.PLAZO_CONSUMIDO).size(), 1, "quedó registrado")
	af_eq(m.estado.carta(fiel).dano, 0, "y queda entero")
	m.depurar_dano_area(0, 9)
	af_eq(m.estado.carta(fiel).zona, Palabra.Zona.DESCARTE, "la segunda vez en el turno sí muere")
	af_eq(p.plazo_restante, 2, "no consumió otro plazo")
	fin()


func test_fiel_enciende_una_sola_vez_por_turno() -> void:
	var m: MotorDePalabra = duelo()
	var fiel: int = m.depurar_poner_en_estrado(0, "fiel_el_que_espera")
	_tres_cumplimientos(m)
	af_eq(m.eventos_de(EventoDuelo.PROMESA_CUMPLIDA).size(), 3, "tres Promesas cumplidas")
	var ec: EstadoCarta = m.estado.carta(fiel)
	af_eq(m.ataque(ec), 5, "+2/+2 una sola vez por turno (3 + 2)")
	af_eq(m.aguante(ec), 5, "idem aguante")
	fin()


func test_lampara_roba_maximo_2_por_turno() -> void:
	var m: MotorDePalabra = duelo()
	m.depurar_poner_en_estrado(0, "lampara_de_palabra")
	var antes: int = m.eventos_de(EventoDuelo.CARTA_ROBADA).size()
	_tres_cumplimientos(m)
	af_eq(m.eventos_de(EventoDuelo.PROMESA_CUMPLIDA).size(), 3, "tres Promesas cumplidas")
	af_eq(
		m.eventos_de(EventoDuelo.CARTA_ROBADA).size() - antes,
		2,
		"la Lámpara roba 2 como máximo por turno"
	)
	fin()


func test_amanecer_con_lampara_no_desborda_la_mano() -> void:
	var m: MotorDePalabra = duelo()
	m.depurar_poner_en_estrado(0, "lampara_de_palabra")
	m.depurar_poner_en_estrado(0, "lampara_de_palabra")
	_jugar_con_promesa(m, 0, "peon_de_vina", Palabra.CL_SIN_CLAUSULAS, 3)
	_jugar_con_promesa(m, 0, "mula_de_reparto", Palabra.CL_SIN_CLAUSULAS, 3)
	_jugar_con_promesa(m, 0, "colmillo_del_diezmo", Palabra.CL_SIN_CLAUSULAS, 3)
	af_eq(m.estado.firma(0).promesas.size(), 3, "tres Promesas pendientes")
	var mano: Array[String] = ["el_amanecer"]
	for _i: int in 9:
		mano.append("peon_de_vina")
	var uids: Array[int] = mano_exacta(m, 0, mano)
	af_eq(m.estado.firma(0).mano.size(), Palabra.MANO_MAX, "la mano arranca llena")
	af_eq(uids.size(), Palabra.MANO_MAX, "diez cartas repartidas")
	if uids.is_empty():
		fin()
		return
	m.depurar_set_credito(0, Palabra.CREDITO_TOPE)
	af(m.ejecutar(JugadaDePalabra.jugar(0, uids[0])), "se juega El Amanecer")
	af_eq(m.eventos_de(EventoDuelo.PROMESA_CUMPLIDA).size(), 3, "cumple las tres")
	af_eq(m.eventos_de(EventoDuelo.PROMESA_ROTA).size(), 0, "cumplir gana sobre «sin Cláusulas»")
	af(m.estado.firma(0).mano.size() <= Palabra.MANO_MAX, "la mano nunca pasa de 10")
	af_eq(m.estado.firma(0).mano.size(), Palabra.MANO_MAX, "queda llena")
	af_eq(m.estado.firma(0).empenadero.size(), 3, "el excedente se empeña, no se destruye")
	af_eq(
		m.eventos_de(EventoDuelo.MANO_LLENA_AL_EMPENADERO).size(), 3, "y queda registrado"
	)
	fin()


func test_forastera_no_tiene_letra_chica() -> void:
	var m: MotorDePalabra = duelo()
	m.depurar_set_credito(0, Palabra.CREDITO_TOPE)
	var odila: int = m.depurar_poner_en_mano(0, "odila_la_forastera")
	af(m.ejecutar(JugadaDePalabra.jugar(0, odila)), "entra Odila")
	m.depurar_dano_area(0, 9)
	af_eq(m.estado.carta(odila).zona, Palabra.Zona.DESCARTE, "Odila murió")
	var forastera: EstadoCarta = buscar_en_mano(m, 0, Palabra.T_LA_FORASTERA)
	af(forastera != null, "vuelve a tu mano como la Forastera")
	if forastera == null:
		return
	af(not forastera.tiene(Palabra.KW_LETRA_CHICA), "la Forastera no tiene Letra chica")
	af(forastera.tiene(Palabra.KW_AL_CONTADO), "pero sí Al contado")
	m.depurar_set_credito(0, Palabra.CREDITO_TOPE)
	af(m.ejecutar(JugadaDePalabra.jugar(0, forastera.uid)), "se juega la Forastera")
	var mano_antes: int = m.estado.firma(0).mano.size()
	m.depurar_dano_area(0, 9)
	af_eq(m.estado.carta(forastera.uid).zona, Palabra.Zona.DESCARTE, "la Forastera murió")
	af_eq(
		m.estado.firma(0).mano.size(),
		mano_antes,
		"no vuelve nada: el bucle de Odila está cortado"
	)
	fin()


func test_copia_espejo_no_invoca_otra_copia() -> void:
	var m: MotorDePalabra = duelo()
	m.depurar_set_credito(0, Palabra.CREDITO_TOPE)
	var gemelas: int = m.depurar_poner_en_mano(0, "cobradoras_gemelas")
	af(m.ejecutar(JugadaDePalabra.jugar(0, gemelas)), "entran las Gemelas")
	af_eq(contar(m, 0, Palabra.Zona.ESTRADO, "cobradoras_gemelas"), 1, "una Gemela")
	af_eq(contar(m, 0, Palabra.Zona.ESTRADO, Palabra.T_COPIA_ESPEJO), 1, "una sola copia espejo")
	af_eq(m.estado.firma(0).estrado.size(), 2, "el Estrado tiene exactamente 2 cartas")
	var copia: CartaDePalabra = CatalogoDePalabra.obtener(Palabra.T_COPIA_ESPEJO)
	af_eq(
		copia.efectos_de(Palabra.TR_DE_PALABRA).size(),
		0,
		"la copia es token sin el efecto de invocar"
	)
	fin()


func test_tasador_decano_pone_a_cero_maximo_2() -> void:
	var m: MotorDePalabra = duelo()
	mano_exacta(
		m,
		0,
		[
			"tasador_decano",
			"cobrador_de_la_camara",
			"cobrador_de_la_camara",
			"cobrador_de_la_camara",
		]
	)
	m.depurar_set_credito(0, Palabra.CREDITO_TOPE)
	var tasador: EstadoCarta = buscar_en_mano(m, 0, "tasador_decano")
	af(m.ejecutar(JugadaDePalabra.jugar(0, tasador.uid)), "entra el Tasador")
	var en_cero: int = 0
	var con_coste: int = 0
	for ec: EstadoCarta in m.estado.firma(0).mano:
		if not ec.tiene(Palabra.KW_INTERES):
			continue
		if m.coste(ec) == 0:
			en_cero += 1
		else:
			con_coste += 1
	af_eq(en_cero, 2, "exactamente 2 cartas con Interés cuestan 0")
	af_eq(con_coste, 1, "la tercera sigue costando")
	siguiente_turno_de(m, 0)
	var sigue_en_cero: int = 0
	for ec2: EstadoCarta in m.estado.firma(0).mano:
		if ec2.tiene(Palabra.KW_INTERES) and m.coste(ec2) == 0:
			sigue_en_cero += 1
	af_eq(sigue_en_cero, 0, "era «este turno»")
	fin()


func test_robo_con_mano_llena_va_al_empenadero_propio() -> void:
	var m: MotorDePalabra = duelo()
	var llena: Array[String] = []
	for _i: int in Palabra.MANO_MAX:
		llena.append("peon_de_vina")
	mano_exacta(m, 0, llena)
	af_eq(m.estado.firma(0).mano.size(), Palabra.MANO_MAX, "la mano está en 10")
	af_eq(m.estado.firma(0).empenadero.size(), 0, "el Empeñadero está vacío")
	siguiente_turno_de(m, 0)
	af_eq(m.estado.firma(0).mano.size(), Palabra.MANO_MAX, "la mano sigue en 10")
	af_eq(m.estado.firma(0).empenadero.size(), 1, "el robo con mano llena va al Empeñadero propio")
	af_eq(m.eventos_de(EventoDuelo.MANO_LLENA_AL_EMPENADERO).size(), 1, "y queda registrado")
	fin()


func test_quebranto_del_peaje_pone_quebranto_del_lado_rival() -> void:
	var m: MotorDePalabra = duelo()
	var peaje: int = m.depurar_poner_en_estrado(0, "quebranto_del_peaje")
	m.depurar_dano_area(0, 9)
	af_eq(m.estado.carta(peaje).zona, Palabra.Zona.DESCARTE, "el Quebranto del Peaje murió")
	af_eq(m.estado.firma(1).quebrantos().size(), 1, "el Quebranto nace del lado rival")
	af_eq(m.estado.firma(0).quebrantos().size(), 0, "no del propio")
	var aval: int = m.estado.firma(1).aval
	m.terminar_turno()
	m.terminar_turno()
	af(m.estado.firma(1).aval < aval, "y le pega a la Firma rival")
	fin()
