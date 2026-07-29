# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends SceneTree

## Runner headless de los tests del motor de «De Palabra» (diseño § 8.1 a § 8.4).
##
## Cada caso imprime PASS o FAIL con el motivo; el proceso sale con código != 0
## si alguno falla.
##
## Uso:
## [codeblock]
## godot --headless --path . -s res://scenes/card_game/tests/runner_motor.gd
## [/codeblock]


func _initialize() -> void:
	var suites: Array[SuiteDePalabra] = [
		PruebaReglasBase.new(),
		PruebaKeywords.new(),
		PruebaPromesas.new(),
		PruebaCombos.new(),
		PruebaIntegridad.new(),
		PruebaSetDeCartas.new(),
		PruebaIA.new(),
		PruebaDuelosIA.new(),
	]
	print("== Motor «De Palabra» — tests headless ==")
	var errores_catalogo: Array[String] = CatalogoDePalabra.errores()
	if not errores_catalogo.is_empty():
		for e: String in errores_catalogo:
			print("FAIL  catálogo: %s" % e)
		print("\nel catálogo de cartas no valida: no se corre nada")
		quit(1)
		return
	print("catálogo: %d cartas válidas" % CatalogoDePalabra.ids().size())
	var total: int = 0
	var fallados: int = 0
	for suite: SuiteDePalabra in suites:
		print("\n-- %s" % suite.nombre)
		for caso: String in suite.casos():
			total += 1
			var fallos: Array[String] = suite.correr(caso)
			if fallos.is_empty():
				print("PASS  %s" % caso)
			else:
				fallados += 1
				print("FAIL  %s" % caso)
				for f: String in fallos:
					print("          %s" % f)
	print("\n== %d casos, %d PASS, %d FAIL ==" % [total, total - fallados, fallados])
	if fallados > 0:
		quit(1)
		return
	quit(0)
