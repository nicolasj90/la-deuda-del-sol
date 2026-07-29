# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name PruebaDuelosIA
extends SuiteDePalabra

## Humo de IA contra IA: 50 duelos headless mezclando perfiles tienen que terminar
## **todos** sin error y dentro del tope de 30 turnos (§ 1.2).
##
## Es la versión chica del simulador de balance del § 9.1 (10.000 duelos): acá el
## objetivo no es balancear, es que ningún par de perfiles cuelgue el motor, deje
## un turno sin cerrar o rechace jugadas. La distribución de resultados se imprime
## como pista temprana de balance.

const DUELOS: int = 50
## Ningún duelo puede pasar de acá: el motor declara incobrable el turno 30 (§ 1.2).
const TURNOS_TOPE: int = Palabra.TOPE_TURNOS

## Pares de perfiles que se enfrentan, ciclados sobre los 50 duelos (§ 7.3).
const PAREJAS: Array[Array] = [
	["casa", "garante"],
	["garante", "letra_chica"],
	["letra_chica", "interes"],
	["interes", "de_palabra"],
	["de_palabra", "al_contado"],
	["al_contado", "senuelos"],
	["senuelos", "control"],
	["control", "casa"],
	["garante", "al_contado"],
	["letra_chica", "control"],
]


func _init() -> void:
	nombre = "duelos IA vs IA (humo del § 8.6)"


func casos() -> Array[String]:
	return ["test_50_duelos_ia_vs_ia_terminan_limpios"]


func test_50_duelos_ia_vs_ia_terminan_limpios() -> void:
	var por_motivo: Dictionary = {}
	var por_pareja: Dictionary = {}
	var por_perfil: Dictionary = {}
	var por_turnos: Dictionary = {"1-9": 0, "10-14": 0, "15-19": 0, "20-24": 0, "25-29": 0, "30": 0}
	var gano_el_que_empezo: int = 0
	var turnos_total: int = 0
	var turnos_max: int = 0
	var jugadas_total: int = 0
	var nodos_max: int = 0
	var aval_total: int = 0
	var arranque: int = Time.get_ticks_msec()
	for i: int in DUELOS:
		var pareja: Array = PAREJAS[i % PAREJAS.size()]
		var id_0: String = String(pareja[0])
		var id_1: String = String(pareja[1])
		var perfil_0: PerfilIA = CatalogoDePerfiles.obtener(id_0)
		var perfil_1: PerfilIA = CatalogoDePerfiles.obtener(id_1)
		if perfil_0 == null or perfil_1 == null:
			af(false, "faltan perfiles para el duelo %d" % i)
			break
		# Un tercio de los duelos con la mesa de El Fiado (§ 4.2): empeñar, fiar y
		# denunciar también tienen que sobrevivir 30 turnos de IA.
		var mesa: ConfigMesa = ConfigMesa.base() if i % 3 != 0 else ConfigMesa.el_fiado()
		var semilla: int = 1000 + i
		var m: MotorDePalabra = MotorDePalabra.new(semilla)
		m.iniciar(
			mesa,
			MazosDePrueba.del_perfil(id_0, mesa),
			MazosDePrueba.del_perfil(id_1, mesa),
			i % 2,
			true
		)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = semilla
		var r: Dictionary = PilotoDePalabra.jugar_duelo(m, perfil_0, perfil_1, rng)
		var etiqueta: String = "%s vs %s" % [id_0, id_1]
		# --- Lo que el humo exige ---
		af(m.estado.terminado, "duelo %d (%s) no terminó" % [i, etiqueta])
		af(
			int(r["turnos"]) <= TURNOS_TOPE,
			"duelo %d (%s) pasó el tope de turnos: %s" % [i, etiqueta, str(r["turnos"])]
		)
		af(
			int(r["ganador"]) == 0 or int(r["ganador"]) == 1,
			"duelo %d (%s) terminó sin ganador" % [i, etiqueta]
		)
		var rechazadas: Array[EventoDuelo] = m.eventos_de(EventoDuelo.JUGADA_RECHAZADA)
		if not rechazadas.is_empty():
			af(
				false,
				(
					"duelo %d (%s): el motor rechazó %d jugada(s), la primera %s"
					% [i, etiqueta, rechazadas.size(), rechazadas[0].como_texto()]
				)
			)
		af(
			int(r["nodos"]) <= int(r["planes"]) * IADePalabra.NODOS_MAX,
			"duelo %d (%s) se pasó de la cota de nodos" % [i, etiqueta]
		)
		# --- Estadística ---
		var ganador: int = int(r["ganador"])
		var turnos: int = int(r["turnos"])
		var motivo: String = String(r["motivo"])
		por_motivo[motivo] = int(por_motivo.get(motivo, 0)) + 1
		var clave: String = "%s (%s)" % [etiqueta, "fiado" if mesa.al_fiado else "base"]
		var marca: Array = por_pareja.get(clave, [0, 0])
		var casilla: int = clampi(ganador, 0, 1)
		marca[casilla] = int(marca[casilla]) + 1
		por_pareja[clave] = marca
		for lado: int in [0, 1]:
			var id_lado: String = id_0 if lado == 0 else id_1
			var wl: Array = por_perfil.get(id_lado, [0, 0])
			wl[0 if ganador == lado else 1] = int(wl[0 if ganador == lado else 1]) + 1
			por_perfil[id_lado] = wl
		var bucket: String = _bucket_de_turnos(turnos)
		por_turnos[bucket] = int(por_turnos.get(bucket, 0)) + 1
		if ganador == i % 2:
			gano_el_que_empezo += 1
		turnos_total += int(r["turnos"])
		turnos_max = maxi(turnos_max, int(r["turnos"]))
		jugadas_total += int(r["jugadas"])
		nodos_max = maxi(nodos_max, int(r["nodos"]) / maxi(1, int(r["planes"])))
		aval_total += absi(m.estado.firma(0).aval - m.estado.firma(1).aval)
	# § 9.5 — el riesgo abierto es que un perfil de control empate por tiempo. Con
	# estas semillas el número es 0; el umbral deja aire para el balance, no para
	# una IA que se queda quieta.
	var incobrables: int = int(por_motivo.get("incobrable", 0))
	af(
		incobrables <= DUELOS / 10,
		"demasiados duelos incobrables (%d de %d): la IA no cierra" % [incobrables, DUELOS]
	)
	var segundos: float = float(Time.get_ticks_msec() - arranque) / 1000.0
	print("      -- %d duelos en %.1f s" % [DUELOS, segundos])
	print(
		(
			"      -- turnos: promedio %.1f, máximo %d | jugadas por duelo: %.1f"
			% [float(turnos_total) / float(DUELOS), turnos_max, float(jugadas_total) / float(DUELOS)]
		)
	)
	print(
		(
			"      -- nodos por plan (peor duelo): %d de %d | diferencia de Aval al final: %.1f"
			% [nodos_max, IADePalabra.NODOS_MAX, float(aval_total) / float(DUELOS)]
		)
	)
	print("      -- motivos de fin: %s" % str(por_motivo))
	print("      -- turnos: %s" % str(por_turnos))
	print("      -- ganó el que empezó: %d de %d" % [gano_el_que_empezo, DUELOS])
	var ids: Array = por_perfil.keys()
	ids.sort()
	for id: String in ids:
		var wl: Array = por_perfil[id]
		print("      -- perfil %-12s %d ganados · %d perdidos" % [id, int(wl[0]), int(wl[1])])
	for clave: String in por_pareja.keys():
		var marca: Array = por_pareja[clave]
		print("      -- %-34s lado0 %d · lado1 %d" % [clave, int(marca[0]), int(marca[1])])
	fin()


func _bucket_de_turnos(turnos: int) -> String:
	if turnos >= TURNOS_TOPE:
		return "30"
	if turnos >= 25:
		return "25-29"
	if turnos >= 20:
		return "20-24"
	if turnos >= 15:
		return "15-19"
	if turnos >= 10:
		return "10-14"
	return "1-9"
