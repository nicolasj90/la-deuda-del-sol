#!/usr/bin/env python3
# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
"""
Genera scenes/quests/story_quests/la_deuda_del_sol/lacrevieja.tscn: el PUEBLO de
Lacrevieja (60x40 celdas de 16px, TileMapLayers a escala 4 => celda de 64px de
mundo, la misma grilla que el resto del repo).

Uso: python3 tools/gen-mapa-lacrevieja.py

CUIDADO: reescribe la escena completa. Si alguien mueve un NPC desde el editor de
Godot, ese cambio se pierde. Para cambios permanentes se edita este script (las
tablas de abajo) y se vuelve a correr.

Geografía, según docs/guion/acto1/01-lacrevieja-y-vencimiento.md (E01-E06):
  - plaza central empedrada con las tres lámparas de palabra, el estrado de la
    ceremonia, el cantero norte de macetas y las mesas largas de la fiesta;
  - panadería de Rosaura con su horno grande al costado, y el galpón de la leña
    lejos, del otro lado de la calle mayor (el acarreo ES el minijuego);
  - casa de Ciro al sur, sobre la calle del sur: ahí arrancan E01 y E05;
  - notaría del fedatario al norte, con su patio de tapia (E06);
  - capilla del lacre al noreste y, detrás, el cementerio chico de Cosme;
  - viñedos en todo el borde oeste; salida este por la calle mayor a Villarrúbrica.

Identidad de los edificios (ronda 2 del juez visual): la NOTARÍA se lee por sus
pilastras de tapia, el portón doble, la placa de lacre, las ventanas encendidas y
el cartel de oficio con pluma y tintero en la calle norte; la CAPILLA, por el
portón en arco de piedra de dos celdas, el rosetón, los ventanales ojivales, el
campanario y la cruz del techo; la CASA DE CIRO, por el cartel con el apellido, la
ropa tendida, el banco, la leña y el hacha del galpón. Las manzanas de pasto
llevan cerco vivo con portillo, trastos de patio y sendas peatonales, y las
calzadas llevan charcos, huellas y adoquines sueltos en los cruces.

Ninguna casa se puede atravesar: el tejado y la pared son sólidos, y el único hueco
es el vano de la puerta, que se puede pisar pero no cruzar. Cada vano lleva su
PuertaDeVecino (nodo mudo, sin física propia) para que golpear conteste quién vive
ahí y por qué hoy no atiende. Los carteles van sólo donde hacen falta — plaza,
panadería, notaría, camposanto, salida a Villarrúbrica — y nunca sobre la calzada.
Todo esto lo verifica scenes/.../lacrevieja/tests/sonda_muros.tscn, que camina el
pueblo con el cuerpo del jugador.

Todo el contenido de F5a (NPCs con su .dialogue, promesitas, lámparas, triggers de
E01-E05, spawns, teleporter, RestauradorDelActo) se conserva con el mismo nombre y
el mismo path: solo cambia de lugar. Los scripts y los tests los buscan por
NodePath / unique_name_in_owner, nunca por posición.
"""
import base64
import os
import struct
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"
OUT = ROOT + "scenes/quests/story_quests/la_deuda_del_sol/lacrevieja.tscn"

W, H = 60, 40          # celdas del mapa
CELL = 64              # px de mundo por celda (16px * escala 4)
ESCALA = 4

TT, TD, RL = 0, 1, 2   # ids de source del TileSet (tiny town, tiny dungeon, roguelike)

# ---------------------------------------------------------------------------
# Baldosas usadas, con su clase de colisión (solo para el chequeo de caminabilidad
# de este script; la física de verdad vive en tools/gen-tiles-pueblo.py).
# ---------------------------------------------------------------------------
SOLIDAS = set()


def T(src, ax, ay, solida=False):
    if solida:
        SOLIDAS.add((src, ax, ay))
    return (src, ax, ay)


# suelo
PASTO = [T(TT, 0, 0), T(TT, 0, 0), T(TT, 0, 0), T(TT, 0, 0), T(TT, 0, 0),
         T(TT, 0, 0), T(TT, 1, 0), T(TT, 1, 0), T(TT, 2, 0)]
TIERRA_LLANA = [T(TT, 3, 3), T(TT, 4, 3), T(TT, 5, 3)]
# Empedrado de la plaza: adoquín gris claro. Van dos variantes casi iguales a
# propósito — las otras baldosas de esa fila del atlas son de otro color y mezcladas
# dan un camuflaje manchado, no un piso.
EMPEDRADO = [T(RL, 6, 2), T(RL, 6, 2), T(RL, 6, 2), T(RL, 6, 3)]
# Pileta de la huerta: brocal de piedra 3x3. La «laguna 3x3 con orilla» del pack
# trae SU PROPIO verde saturado en las cuatro esquinas y sobre el pasto de Tiny
# Town se ve como un parche cuadrado (el juez lo marcó en la huerta del sur). El
# brocal de piedra no tiene fondo verde: se apoya en cualquier suelo.
PILETA = {(dx, dy): T(RL, 2 + dx, 3 + dy, True) for dx in range(3) for dy in range(3)}
# Parches de piso para que las calzadas no sean tierra plana uniforme.
CHARCOS = [T(RL, 5, 11), T(RL, 6, 11), T(RL, 7, 11), T(RL, 8, 12), T(RL, 9, 12)]
HUELLAS = [T(RL, 5, 7), T(RL, 6, 8), T(RL, 7, 7), T(RL, 8, 9), T(RL, 9, 8)]
ADOQUIN_SUELTO = [T(RL, 5, 14), T(RL, 6, 14), T(RL, 7, 13), T(RL, 8, 14), T(RL, 9, 13)]

# árboles: copa (sella el borde) + tronco
COPA_VERDE, TRONCO_VERDE = T(TT, 4, 0, True), T(TT, 4, 1, True)
COPA_OTONO, TRONCO_OTONO = T(TT, 3, 0, True), T(TT, 3, 1, True)
ARBOLITOS = [T(TT, 3, 2, True), T(TT, 4, 2, True), T(TT, 5, 0, True)]
HONGOS = T(TT, 5, 2)
BROTES = T(TT, 5, 1)

# viñedo: parras con uva del pack roguelike
PARRA = [T(RL, 24, 11, True), T(RL, 24, 10, True)]
FRUTAL = [T(RL, 23, 9, True), T(RL, 23, 10, True), T(RL, 23, 11, True)]

# Canteros de flores del pack roguelike: son un autotile 3x3 con brocal de piedra
# (columnas 2=izq / 3=medio / 4=der; filas 6-8 naranja, 9-11 blanco, 12-14 azul).
# Hay que estamparlos como rectángulo: una baldosa suelta del medio queda como un
# parche verde con el brocal cortado.
CANTERO_FILA = {"naranja": 6, "blanco": 9, "azul": 12}
# Florcitas sueltas: SIEMPRE de Tiny Town, que es el atlas del pasto. Las «flores
# sobre pasto» del pack roguelike traen su propio verde (más oscuro) y un pedazo de
# piedra blanca cortado, así que sobre este pasto se leen como parches sucios.
FLORCITAS = [T(TT, 2, 0), T(TT, 2, 0), T(TT, 7, 3), T(TT, 5, 1)]
# Matas de flores del pack roguelike: éstas SÍ vienen sin fondo (sólo la mata), así
# que sobre el pasto de Tiny Town no dejan parche.
FLORES_SUELTAS = [T(RL, 41, 23), T(RL, 42, 23), T(RL, 43, 23), T(RL, 44, 23),
                  T(RL, 41, 24), T(RL, 42, 24), T(RL, 43, 24), T(RL, 44, 24)]

# props
POZO_ALTO, POZO_BAJO = T(TT, 8, 7, True), T(TT, 8, 8, True)
HORNO_ALTO, HORNO_BAJO = T(RL, 54, 9, True), T(RL, 54, 10, True)
MESA_LARGA = [T(RL, 16, 0, True), T(RL, 17, 0, True), T(RL, 18, 0, True)]
MOSTRADOR = [T(RL, 12, 4, True), T(RL, 13, 4, True)]
PUESTOS = [T(RL, 11, 4, True), T(RL, 12, 4, True), T(RL, 13, 4, True),
           T(RL, 11, 6, True), T(RL, 13, 6, True)]
CORDON = T(RL, 7, 4)                 # cordón de ladrillo del borde de la plaza
LAPIDAS_DECO = [T(RL, 51, 11, True), T(RL, 52, 11, True), T(RL, 53, 11, True),
                T(RL, 51, 9, True), T(RL, 52, 9, True)]
CRUZ_MADERA = T(RL, 53, 9, True)
CRUZ_PIEDRA = T(RL, 51, 10)          # sobre el techo de la capilla: no necesita física
BANDERINES = [T(RL, 51, 0), T(RL, 52, 0), T(RL, 51, 3),
              T(RL, 52, 3), T(RL, 51, 6), T(RL, 52, 6)]
CARTEL_MADERA = T(TT, 11, 6, True)   # tabla de oficio colgada
POSTE_CARTEL = [T(RL, 19, 0, True), T(RL, 20, 0, True), T(RL, 21, 0, True)]
BARRIL = [T(TT, 10, 10, True), T(TT, 11, 10, True)]
CAJON = T(TT, 10, 8, True)           # cajón de madera / leña estibada
HACHA = T(TT, 11, 9)                 # hacha apoyada (deco, no frena)
PAN = T(TT, 9, 7)                    # hogaza: el emblema de la panadería
BANCO = T(RL, 16, 0, True)           # tablón de banco
TENDEDERO = [T(RL, 51, 13), T(RL, 52, 13)]   # cuerda con ropa colgada

# Cercos. La geometría del atlas importa: (46,23) es una HOJA DE TRANQUERA y
# (50,23) está VACÍA, y por usarlas como «tramo de cerco» el recinto del
# cementerio se leía como postes sueltos con huecos. Los tramos continuos son
# (52,23)/(52,24) en horizontal y (51,23)/(51,24) en vertical.
CERCO_H = [T(RL, 52, 23, True), T(RL, 52, 24, True), T(RL, 53, 23, True)]
CERCO_V = [T(RL, 51, 23, True), T(RL, 51, 24, True)]
CERCO_ESQ = T(RL, 53, 24, True)
HOJA_TRANQUERA = [T(RL, 46, 23, True), T(RL, 46, 24, True)]
SETO = [T(RL, 19, 10, True), T(RL, 20, 10, True), T(RL, 21, 10, True)]
SETO_OSCURO = [T(RL, 19, 11, True), T(RL, 20, 11, True), T(RL, 21, 11, True)]
TAPIA = [T(TD, 9, 4, True), T(TD, 10, 4, True), T(TD, 11, 4, True)]

# Fachadas de oficio. Van en la capa Techos, ENCIMA de la pared de la casa: le dan
# identidad al edificio sin tocarle el cuerpo ni la colisión (la pone la pared).
PORTON_DOBLE = [T(RL, 44, 7), T(RL, 45, 7)]
VENTANA_CALIDA = [T(RL, 44, 6), T(RL, 45, 6)]
VITRAL = T(RL, 47, 8)                # ventanal ojival
ROSETON = T(RL, 46, 0)               # rosetón de la capilla
ARCO_IZQ, ARCO_DER = T(TT, 3, 9), T(TT, 4, 9)   # portón en arco de piedra (2 celdas)
ALMENA = [T(TT, 3, 8, True), T(TT, 4, 8, True)]  # coronamiento del campanario
SELLO_DE_LACRE = T(RL, 42, 15)       # el emblema del Fedatario
PLUMA_Y_TINTERO = T(RL, 45, 15)
PERGAMINO = T(RL, 41, 15)
LIBRO_DE_PALABRA = T(RL, 50, 15)
ATRIL = T(RL, 16, 0, True)

# casas: (techo_izq, techo_med, techo_der) x2 filas, pared, y frente
ESTILOS = {
    "roja": {
        "techo_alto": (T(TT, 4, 4, True), T(TT, 5, 4, True), T(TT, 6, 4, True)),
        "techo_bajo": (T(TT, 4, 5, True), T(TT, 5, 5, True), T(TT, 6, 5, True)),
        "pared": (T(TT, 0, 6, True), T(TT, 1, 6, True), T(TT, 3, 6, True)),
        "frente": T(TT, 0, 7, True),
        "puerta": T(TT, 1, 7),
    },
    "gris": {
        "techo_alto": (T(TT, 0, 4, True), T(TT, 1, 4, True), T(TT, 2, 4, True)),
        "techo_bajo": (T(TT, 0, 5, True), T(TT, 1, 5, True), T(TT, 2, 5, True)),
        "pared": (T(TT, 4, 6, True), T(TT, 5, 6, True), T(TT, 7, 6, True)),
        "frente": T(TT, 4, 7, True),
        "puerta": T(TT, 5, 7),
    },
}

# ---------------------------------------------------------------------------
# Capas
# ---------------------------------------------------------------------------
CAPAS = ["Suelo", "Caminos", "Decoracion", "Paredes", "Techos"]
Z = {"Suelo": -3, "Caminos": -2, "Decoracion": -1, "Paredes": 0, "Techos": 1}
capa = {n: {} for n in CAPAS}


def put(nombre, x, y, tile):
    if 0 <= x < W and 0 <= y < H:
        capa[nombre][(x, y)] = tile


def rect(x0, y0, x1, y1):
    return [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)]


_semilla = 0x5EED


def azar(n: int) -> int:
    """PRNG determinista chiquito: el mapa tiene que salir igual en cada corrida."""
    global _semilla
    _semilla = (_semilla * 1103515245 + 12345) & 0x7FFFFFFF
    return (_semilla >> 8) % n


# ---------------------------------------------------------------------------
# 1. Suelo: pasto en todo el mapa
# ---------------------------------------------------------------------------
for x, y in rect(0, 0, W - 1, H - 1):
    put("Suelo", x, y, PASTO[azar(len(PASTO))])

# ---------------------------------------------------------------------------
# 2. Calles, plaza y viñedo: máscara de tierra con bordes festoneados
# ---------------------------------------------------------------------------
CALLE_MAYOR = rect(2, 19, 59, 21)        # A: este-oeste, la que sale a Villarrúbrica
CALLE_NORTE = rect(12, 11, 52, 12)       # B
CALLE_SUR = rect(10, 29, 50, 30)         # C
CONECTOR_NO = rect(20, 12, 21, 19)       # D
CONECTOR_SO = rect(20, 21, 21, 29)       # E
CONECTOR_NE = rect(40, 12, 41, 19)       # F
CONECTOR_SE = rect(40, 21, 41, 29)       # G
BAJADA_OESTE = rect(24, 13, 25, 13)      # B -> plaza
BAJADA_ESTE = rect(32, 13, 33, 13)       # B -> plaza
PLAZA = rect(24, 14, 37, 25)
VINEDO = rect(2, 4, 8, 36)
CEMENTERIO = rect(49, 4, 55, 9)
PORTON_CEMENTERIO = rect(51, 10, 53, 10)
PATIO_NOTARIA = rect(33, 8, 35, 10)      # E06: el patio de tinta dormida
# Plazoleta de tierra frente al portón del cementerio: viniendo por la calle norte
# el portón tiene que verse desde lejos y el camino tiene que señalarlo. Sin esto
# el jugador topaba contra el cerco y no encontraba la entrada.
ATRIO_CEMENTERIO = rect(50, 11, 54, 12)
# Sendas peatonales de dos celdas que cruzan las manzanas de pasto: sin ellas las
# manzanas son campos vacíos y la única forma de moverse son las tres calzadas.
SENDA_NE = rect(49, 13, 50, 18)
SENDA_SO = rect(23, 26, 24, 28)
SENDA_SE = rect(37, 26, 38, 28)
CALLEJON_HUERTA = rect(24, 31, 38, 31)   # servicio de la huerta del sur
ERA_PILETA = rect(50, 32, 54, 36)        # era de tierra alrededor de la pileta

tierra = set()
for zona in (CALLE_MAYOR, CALLE_NORTE, CALLE_SUR, CONECTOR_NO, CONECTOR_SO,
             CONECTOR_NE, CONECTOR_SE, BAJADA_OESTE, BAJADA_ESTE, PLAZA,
             VINEDO, CEMENTERIO, PORTON_CEMENTERIO, PATIO_NOTARIA,
             ATRIO_CEMENTERIO, SENDA_NE, SENDA_SO, SENDA_SE, CALLEJON_HUERTA,
             ERA_PILETA):
    tierra.update(zona)

for (x, y) in sorted(tierra):
    izq = (x - 1, y) not in tierra
    der = (x + 1, y) not in tierra
    arr = (x, y - 1) not in tierra
    aba = (x, y + 1) not in tierra
    ax = 0 if izq else (2 if der else 1)
    ay = 1 if arr else (3 if aba else 2)
    if (ax, ay) == (1, 2) and azar(10) < 4:
        put("Caminos", x, y, TIERRA_LLANA[azar(len(TIERRA_LLANA))])
    else:
        put("Caminos", x, y, T(TT, ax, ay + 0))

# empedrado de la plaza: adentro del anillo de tierra
EMPEDRADO_PLAZA = rect(25, 15, 36, 24)
for (x, y) in EMPEDRADO_PLAZA:
    borde = x in (25, 36) or y in (15, 24)
    put("Caminos", x, y, CORDON if borde else EMPEDRADO[azar(len(EMPEDRADO))])

# ---------------------------------------------------------------------------
# 2b. Uso de la calzada: charcos, huellas y adoquines sueltos. Tres celdas de
# tierra plana uniforme se leen como una pista de aterrizaje, no como una calle.
# ---------------------------------------------------------------------------
_plaza = set(EMPEDRADO_PLAZA)
for (x, y) in sorted(tierra):
    if (x, y) in _plaza:
        continue
    d = azar(9)
    if d == 0:
        put("Decoracion", x, y, CHARCOS[azar(len(CHARCOS))])
    elif d == 1:
        put("Decoracion", x, y, HUELLAS[azar(len(HUELLAS))])

# Adoquines sueltos en los cruces: la piedra aparece justo donde más se pisa.
# OJO con el orden de los argumentos: acá rect() es rect(x0, y0, x1, y1) (en
# tools/gen-tiles-pueblo.py es rect(x0, x1, y0, y1), que no es lo mismo). Escrito
# con la otra convención, rect(20, 21, 29, 30) tapaba diez por diez celdas y
# desparramaba adoquín por medio cuadrante sudoeste — el «arroyo de piedra» que
# cruzaba la plaza y bajaba por el conector.
CRUCES = (rect(20, 11, 21, 12) + rect(40, 11, 41, 12) + rect(20, 19, 21, 21)
          + rect(40, 19, 41, 21) + rect(20, 29, 21, 30) + rect(40, 29, 41, 30)
          + rect(24, 19, 25, 21) + rect(36, 19, 37, 21))
for (x, y) in CRUCES:
    if (x, y) in tierra and (x, y) not in _plaza and azar(3) < 2:
        put("Decoracion", x, y, ADOQUIN_SUELTO[azar(len(ADOQUIN_SUELTO))])

# ---------------------------------------------------------------------------
# 3. Bordes cerrados: dos filas/columnas de árboles (copa sólida + tronco)
# ---------------------------------------------------------------------------
def arbol_alto(x, y):
    """Árbol de dos celdas: copa arriba (sella), tronco abajo."""
    if azar(2):
        put("Paredes", x, y, COPA_VERDE)
        put("Paredes", x, y + 1, TRONCO_VERDE)
    else:
        put("Paredes", x, y, COPA_OTONO)
        put("Paredes", x, y + 1, TRONCO_OTONO)


for x in range(W):                       # borde norte y sur
    arbol_alto(x, 0)
    arbol_alto(x, H - 2)
for y in range(2, 37, 2):                # borde oeste
    arbol_alto(0, y)
    arbol_alto(1, y)
for y in list(range(2, 17, 2)) + list(range(22, 37, 2)):   # borde este (hueco: la salida)
    arbol_alto(W - 2, y)
    arbol_alto(W - 1, y)
put("Paredes", W - 2, 18, ARBOLITOS[0])  # tapan el codo de la salida
put("Paredes", W - 1, 18, ARBOLITOS[1])

# ---------------------------------------------------------------------------
# 4. Viñedo del oeste: hileras de parra sobre la tierra labrada
# ---------------------------------------------------------------------------
HILERAS = [5, 7, 9, 11, 13, 15, 17, 24, 26, 28, 30, 32, 34]
for y in HILERAS:
    for x in range(2, 9):
        put("Paredes", x, y, PARRA[(x + y) % len(PARRA)])
for (x, y) in [(9, 5), (9, 9), (9, 13), (9, 25), (9, 29), (9, 33)]:
    put("Paredes", x, y, FRUTAL[2])      # frutales de linde
    put("Paredes", x, y - 1, FRUTAL[1])
    put("Paredes", x, y - 2, FRUTAL[0])

# ---------------------------------------------------------------------------
# 5. Edificios
# ---------------------------------------------------------------------------
def casa(x0, y0, ancho, alto, estilo, puerta_x):
    """Estampa una casa: dos filas de techo, paredes y frente con puerta."""
    e = ESTILOS[estilo]
    assert alto in (3, 4), alto
    for i in range(ancho):
        x = x0 + i
        k = 0 if i == 0 else (2 if i == ancho - 1 else 1)
        put("Techos", x, y0, e["techo_alto"][k])
        put("Techos", x, y0 + 1, e["techo_bajo"][k])
        if alto == 4:
            put("Paredes", x, y0 + 2, e["pared"][k])
        put("Paredes", x, y0 + alto - 1, e["puerta"] if x == puerta_x else e["frente"])


# Cada casa lleva su PuertaDeVecino sobre el vano: ninguna se puede atravesar (el
# tejado y la pared son sólidos), así que el vano tiene que contestar algo cuando
# Ciro golpea. Los campos son: nodo, etiqueta que se lee al acercarse, y la línea
# de la casa cerrada. Registro Valdepalabra, líneas cortas.
CASAS = [
    #  x0, y0, ancho, alto, estilo, puerta_x, nombre, (nodo, etiqueta, aviso)
    (13, 8, 4, 3, "roja", 14, "casa de la vecina de la esquina",
     ("PuertaVecinaEsquina", "casa de la vecina de la esquina",
      "Trabada por dentro. Bajó a la plaza a guardar sitio y a mirar quién cumple.")),
    (18, 8, 4, 3, "gris", 19, "casa vecina norte",
     ("PuertaVecinaNorte", "casa del vecino del norte",
      "Cerrada. Un papel en la hoja: «Vuelvo después de la campanada».")),
    (25, 7, 7, 4, "gris", 28, "NOTARÍA del fedatario",
     ("PuertaNotaria", "notaría de Lacrevieja",
      "Portón cerrado con lacre fresco. El fedatario refrenda hoy en el estrado, no acá.")),
    (41, 7, 5, 4, "gris", 43, "CAPILLA DEL LACRE",
     ("PuertaCapilla", "capilla del lacre",
      "Abierta de par en par y vacía. Adentro huele a cera y a nadie.")),
    (13, 15, 6, 4, "roja", 15, "PANADERÍA DE ROSAURA",
     ("PuertaPanaderia", "panadería de Rosaura",
      "La puerta está para el pan, no para la leña: el horno grande da a la calle.")),
    (44, 16, 4, 3, "roja", 45, "casa vecina del levante",
     ("PuertaVecinaLevante", "casa del levante",
      "Cerrada. Adentro no contesta nadie: hoy nadie se queda adentro.")),
    (15, 25, 5, 4, "roja", 17, "CASA DE CIRO",
     ("PuertaCasaDeCiro", "casa de los Albar",
      "Tu casa. La puerta queda abierta un segundo sobre la casa vacía, y se cierra sola.")),
    (10, 26, 3, 3, "gris", 11, "GALPÓN DE LA LEÑA",
     ("PuertaGalpon", "galpón de la leña",
      "El galpón está vacío por dentro: la leña quedó estibada afuera, contra la pared.")),
    (26, 26, 4, 3, "gris", 27, "casa vecina del sur",
     ("PuertaVecinaSur", "casa del vecino del sur",
      "Cerrada. Se oye la fiesta desde acá, que es donde está el dueño.")),
    (33, 26, 4, 3, "roja", 34, "casa de las gallinas",
     ("PuertaCasaGallinas", "casa de las gallinas",
      "Cerrada, y el gallinero abierto. Las gallinas andan sueltas por la plaza.")),
    (44, 26, 4, 3, "gris", 45, "casa vecina del sudeste",
     ("PuertaVecinaSudeste", "casa del sudeste",
      "Cerrada con tranca. En la hoja, marcado a cuchillo: «en regla».")),
]
for (x0, y0, an, al, es, px, _n, _p) in CASAS:
    casa(x0, y0, an, al, es, px)

# ---------------------------------------------------------------------------
# 5a. CAPILLA DEL LACRE (41,7): portón en arco, rosetón, vitrales y campanario.
# Con sólo la cruz en el techo era la misma casa gris de cuatro filas.
# ---------------------------------------------------------------------------
# La cruz va en la fila de ARRIBA del tejado, no encima de una teja: la capa
# Techos es la última, así que estampada en (43,7) no se superponía al tejado —
# lo REEMPLAZABA, y el caballete de la capilla quedaba con un hueco de pasto.
put("Techos", 43, 6, CRUZ_PIEDRA)                 # cruz de piedra sobre el caballete
put("Paredes", 42, 10, ESTILOS["gris"]["puerta"])  # el vano se agranda a dos celdas
put("Techos", 42, 10, ARCO_IZQ)                    # portón en arco de piedra
put("Techos", 43, 10, ARCO_DER)
put("Techos", 43, 9, ROSETON)                      # rosetón sobre el portón
put("Techos", 41, 9, VITRAL)                       # ventanales ojivales
put("Techos", 45, 9, VITRAL)
put("Techos", 41, 6, ALMENA[0])                    # campanario asomando del tejado
put("Techos", 42, 6, ALMENA[1])

# ---------------------------------------------------------------------------
# 5b. NOTARÍA DEL FEDATARIO (25,7): pilastras de tapia, portón doble, ventanas
# encendidas, placa de lacre y cartel de oficio con pluma y tintero en la calle.
# ---------------------------------------------------------------------------
for y in range(7, 10):                             # pilastra de piedra al poniente
    put("Paredes", 24, y, TAPIA[y % len(TAPIA)])
put("Techos", 28, 10, PORTON_DOBLE[0])             # portón doble de madera
put("Techos", 28, 9, SELLO_DE_LACRE)               # placa de lacre sobre el portón
put("Techos", 26, 9, VENTANA_CALIDA[0])            # despacho con la luz prendida
put("Techos", 30, 9, VENTANA_CALIDA[1])
put("Paredes", 24, 10, POSTE_CARTEL[0])            # cartel de oficio, desde la calle
put("Techos", 24, 10, PLUMA_Y_TINTERO)

# patio de tapia de la notaría (E06): al este del edificio, abierto a la calle
for y in range(7, 11):
    put("Paredes", 32, y, TAPIA[y % len(TAPIA)])
    put("Paredes", 36, y, TAPIA[(y + 1) % len(TAPIA)])
for x in range(33, 36):
    put("Paredes", x, 7, TAPIA[x % len(TAPIA)])
put("Paredes", 34, 9, ATRIL)                       # atril del patio
put("Techos", 34, 9, LIBRO_DE_PALABRA)             # con el libro de palabra abierto
put("Paredes", 33, 8, BARRIL[0])
put("Techos", 35, 8, PERGAMINO)
put("Paredes", 35, 8, CAJON)

# ---------------------------------------------------------------------------
# 5c. CASA DE CIRO (15,25): cartel con el apellido, ropa tendida, banco, leña y
# el hacha junto al galpón. En el spawn tiene que distinguirse de cualquier otra.
# ---------------------------------------------------------------------------
# El patio de la leña es el callejón de dos celdas (13-14) entre el galpón y la
# casa, y tiene que quedar ABIERTO a la calle del sur: ahí adentro está la pila que
# arranca el acarreo de E02. Antes el cartel tapaba (14,28) y el cajón con el banco
# tapaban la fila 27, así que el callejón entero era un bolsón sellado y la sonda de
# muros no llegaba a la leña. Ahora los trastos se corren contra el cerco del fondo
# y el cartel de los Albar va colgado del seto, no en la boca del callejón.
put("Paredes", 13, 25, CAJON)                      # leña estibada, contra el fondo
put("Paredes", 14, 25, BANCO)                      # banco contra la pared de la casa
put("Decoracion", 13, 26, TENDEDERO[0])            # ropa tendida en el patio
put("Decoracion", 14, 26, TENDEDERO[1])
put("Decoracion", 13, 28, HACHA)                   # el hacha del galpón
put("Paredes", 19, 24, BARRIL[1])
for x in range(13, 20):                            # cerco vivo del fondo del patio
    if x != 16:                                    # portillo
        put("Paredes", x, 24, SETO[x % len(SETO)])
put("Paredes", 14, 24, CARTEL_MADERA)              # cartel de los Albar, sobre el seto
put("Techos", 14, 24, PERGAMINO)

# la panadería se anuncia con la hogaza sobre su tabla de oficio
put("Techos", 19, 18, PAN)

# horno grande de Rosaura, pegado al costado de la panadería
put("Paredes", 12, 17, HORNO_ALTO)
put("Paredes", 12, 18, HORNO_BAJO)

# pozo de la plaza
put("Paredes", 26, 17, POZO_ALTO)
put("Paredes", 26, 18, POZO_BAJO)

# puestos de feria de la plaza
put("Paredes", 34, 20, MOSTRADOR[0])
put("Paredes", 35, 20, MOSTRADOR[1])
for i, x in enumerate(range(29, 34)):             # mostradores con comida de la fiesta
    put("Paredes", x, 17, PUESTOS[i % len(PUESTOS)])

# mesas largas de la fiesta
for i, x in enumerate(range(28, 34)):
    put("Paredes", x, 24, MESA_LARGA[i % len(MESA_LARGA)])

# tabla de oficio de la panadería (la de la notaría es el poste de la calle norte)
put("Paredes", 19, 18, CARTEL_MADERA)

# guirnaldas: banderines sobre el anillo norte de la plaza
for i, x in enumerate(range(24, 38)):
    put("Decoracion", x, 14, BANDERINES[i % len(BANDERINES)])

# ---------------------------------------------------------------------------
# 6. Cementerio chico, detrás de la capilla: cerco, cruces y lápidas de piedra
# ---------------------------------------------------------------------------
# El recinto tiene que leerse CERRADO: tramos continuos celda por celda, sin
# alternar con la baldosa vacía del atlas ni con la hoja de tranquera.
for x in range(48, 57):
    put("Paredes", x, 3, CERCO_H[x % len(CERCO_H)])
    if x not in (51, 52, 53):                      # el portón: tres celdas abiertas
        put("Paredes", x, 10, CERCO_H[(x + 1) % len(CERCO_H)])
for y in range(4, 10):
    put("Paredes", 48, y, CERCO_V[y % len(CERCO_V)])
    put("Paredes", 56, y, CERCO_V[(y + 1) % len(CERCO_V)])
for (x, y) in [(48, 3), (56, 3), (48, 10), (56, 10)]:
    put("Paredes", x, y, CERCO_ESQ)
# Las dos hojas de la tranquera, abiertas contra el cerco: marcan la boca sin
# taparla, y el atrio de tierra de abajo la señala desde la calle norte.
put("Paredes", 50, 10, HOJA_TRANQUERA[0])
put("Paredes", 54, 10, HOJA_TRANQUERA[1])
put("Paredes", 54, 11, POSTE_CARTEL[2])            # cartel del camposanto
put("Techos", 54, 11, CRUZ_PIEDRA)
for i, (x, y) in enumerate([(50, 5), (54, 5), (50, 8), (55, 8), (53, 4), (49, 7),
                            (49, 5), (55, 6)]):
    put("Paredes", x, y, LAPIDAS_DECO[i % len(LAPIDAS_DECO)])
put("Paredes", 55, 4, CRUZ_MADERA)
put("Paredes", 49, 9, CRUZ_MADERA)

# ---------------------------------------------------------------------------
# 7. Huerta y arboledas: relleno decorativo, siempre fuera de calles y casas
# ---------------------------------------------------------------------------
ocupado = set(capa["Paredes"]) | set(capa["Techos"]) | tierra

def cantero(x0, y0, ancho, alto, color):
    """Estampa un cantero rectangular con su brocal (autotile 3x3 del pack)."""
    fila = CANTERO_FILA[color]
    for j in range(alto):
        for i in range(ancho):
            cx = 2 if i == 0 else (4 if i == ancho - 1 else 3)
            cy = fila + (0 if j == 0 else (2 if j == alto - 1 else 1))
            put("Decoracion", x0 + i, y0 + j, T(RL, cx, cy))


# Huerta del sur: cuatro canteros de verdad, con brocal, entre la calle del sur y
# la arboleda del borde. Sin baldosas sueltas.
for (hx, hy, hw, hh, hc) in [(25, 32, 4, 3, "naranja"), (31, 32, 4, 3, "blanco"),
                             (25, 35, 5, 2, "azul"), (32, 35, 5, 2, "naranja")]:
    cantero(hx, hy, hw, hh, hc)

# Pileta de la huerta, con su brocal de piedra sobre la era de tierra: el estanque
# anterior era un cuadrado de pasto saturado del otro pack que no empalmaba con el
# pasto del mapa.
PILETA_HUERTA = rect(51, 33, 53, 35)
for (x, y) in PILETA_HUERTA:
    put("Paredes", x, y, PILETA[(x - 51, y - 33)])
    ocupado.add((x, y))
put("Paredes", 50, 33, BARRIL[1])                 # balde junto a la pileta
put("Paredes", 54, 35, CAJON)

# ---------------------------------------------------------------------------
# 7b. Patios de las manzanas: cerco vivo con portillo, leña, barriles y ropa
# tendida. Sin esto las manzanas quedan de pasto pelado de punta a punta.
# ---------------------------------------------------------------------------
def _libre(x, y):
    """Nunca se pinta cerco sobre la calzada: el paso tiene que quedar abierto."""
    return (x, y) not in tierra


def seto_h(x0, x1, y, hueco=None, oscuro=False):
    juego = SETO_OSCURO if oscuro else SETO
    for x in range(x0, x1 + 1):
        if x != hueco and _libre(x, y):
            put("Paredes", x, y, juego[x % len(juego)])


def cerco_h(x0, x1, y, hueco=None):
    for x in range(x0, x1 + 1):
        if x != hueco and _libre(x, y):
            put("Paredes", x, y, CERCO_H[x % len(CERCO_H)])


def cerco_v(x, y0, y1, hueco=None):
    for y in range(y0, y1 + 1):
        if y != hueco and _libre(x, y):
            put("Paredes", x, y, CERCO_V[y % len(CERCO_V)])


# fondo de las dos casas del noroeste
seto_h(13, 21, 6, hueco=17)
put("Decoracion", 13, 7, TENDEDERO[0])
put("Decoracion", 14, 7, TENDEDERO[1])
put("Paredes", 20, 7, BARRIL[0])
put("Paredes", 22, 9, CAJON)

# manzana del levante: patio de la casa vecina del levante + leñera
cerco_h(43, 48, 14, hueco=46)
cerco_v(43, 15, 18, hueco=17)
put("Paredes", 48, 16, CAJON)
put("Paredes", 47, 13, BARRIL[1])
put("Decoracion", 44, 14, TENDEDERO[0])
put("Decoracion", 45, 14, TENDEDERO[1])

# manzana del sur: el cerco que separa los dos patios y sus trastos
cerco_v(30, 26, 28, hueco=27)
put("Paredes", 31, 27, CAJON)
put("Paredes", 32, 28, BARRIL[0])
put("Decoracion", 31, 26, TENDEDERO[0])
put("Decoracion", 32, 26, TENDEDERO[1])
seto_h(39, 43, 27, hueco=41, oscuro=True)

# manzana del sudeste
cerco_v(43, 22, 25, hueco=24)
put("Paredes", 48, 28, CAJON)
put("Paredes", 49, 24, BARRIL[1])

RELLENO = (rect(3, 2, 56, 3) + rect(10, 4, 24, 7) + rect(33, 2, 47, 6)
           + rect(10, 13, 12, 14) + rect(9, 22, 19, 24) + rect(38, 13, 39, 18)
           + rect(42, 22, 57, 27) + rect(3, 37, 56, 37) + rect(10, 32, 22, 36)
           + rect(38, 31, 50, 36) + rect(22, 6, 24, 12) + rect(46, 11, 47, 14)
           + rect(42, 13, 52, 18) + rect(22, 26, 24, 28) + rect(31, 31, 49, 31)
           + rect(53, 13, 57, 18) + rect(9, 25, 12, 25))
# Celdas reservadas: acá van nodos de escena que ponen su propio cuerpo (el cartel
# de la salida a Villarrúbrica), así que el relleno no puede plantarles un árbol
# encima ni dejarles un arbusto sólido al lado que tape la vereda.
for (x, y) in [(57, 18), (56, 18)]:
    ocupado.add((x, y))

for (x, y) in RELLENO:
    if (x, y) in ocupado or (x, y) in tierra:
        continue
    d = azar(20)
    if d == 0 and (x, y + 1) not in ocupado and (x, y + 1) not in tierra:
        arbol_alto(x, y)
        ocupado.add((x, y))
        ocupado.add((x, y + 1))
    elif d in (1, 2):
        put("Paredes", x, y, ARBOLITOS[azar(len(ARBOLITOS))])
        ocupado.add((x, y))
    elif d in (3, 4):
        put("Decoracion", x, y, FLORCITAS[azar(len(FLORCITAS))])
    elif d == 5:
        put("Decoracion", x, y, HONGOS if azar(2) else BROTES)
    elif d == 6:                                   # trastos de patio: leña y barriles
        put("Paredes", x, y, BARRIL[azar(len(BARRIL))] if azar(2) else CAJON)
        ocupado.add((x, y))
    elif d == 7:                                   # mata de flores del pack roguelike
        put("Decoracion", x, y, FLORES_SUELTAS[azar(len(FLORES_SUELTAS))])

# ---------------------------------------------------------------------------
# 8. Chequeo de caminabilidad: todo lo que el jugador tiene que alcanzar
# ---------------------------------------------------------------------------
def solida(x, y):
    for n in ("Caminos", "Paredes", "Techos"):
        t = capa[n].get((x, y))
        if t is not None and t in SOLIDAS:
            return True
    return False


# El spawn arrancaba en (17,31): un descampado con la casa de Ciro FUERA DE CUADRO
# y media pantalla de arbustos de relleno. Desde (18,30) —la calzada de la calle del
# sur, contra la vereda de su casa— el primer frame entra la casa, el galpón de la
# leña y la boca del conector hacia la plaza.
SPAWN = (18, 30)
DESTINOS = {
    "puerta de la casa de Ciro": (17, 29),
    "horno grande": (12, 19),
    "pila de leña": (13, 28),
    "puerta de la panadería": (15, 19),
    "cantero norte": (28, 17),
    "estrado": (34, 17),
    "lámpara del poniente": (27, 19),
    "lámpara del centro": (30, 21),
    "lámpara del levante": (34, 18),
    "puerta de la notaría": (28, 11),
    "patio de la notaría": (34, 10),
    "puerta de la capilla": (43, 11),
    "atrio del cementerio": (52, 11),
    "cementerio (lápidas)": (52, 6),
    "salida este a Villarrúbrica": (58, 20),
    "viñedo del oeste": (4, 20),
    "mesas de la fiesta": (30, 23),
    "senda del levante": (49, 15),
    "huerta del sur": (30, 31),
    "pileta de la huerta": (52, 32),
}
alcanzado = {SPAWN}
cola = deque([SPAWN])
while cola:
    x, y = cola.popleft()
    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
        if not (0 <= nx < W and 0 <= ny < H) or (nx, ny) in alcanzado:
            continue
        if solida(nx, ny):
            continue
        alcanzado.add((nx, ny))
        cola.append((nx, ny))

fallas = [n for n, c in DESTINOS.items() if c not in alcanzado]
assert not fallas, "no se llega caminando a: %s" % ", ".join(fallas)
for (x, y) in [(0, 0), (0, H - 1), (W - 1, 0), (W - 1, H - 1)]:
    assert (x, y) not in alcanzado, "el borde en %s,%s tiene fuga" % (x, y)


# ---------------------------------------------------------------------------
# 9. Serialización
# ---------------------------------------------------------------------------
def tile_map_data(celdas):
    buf = struct.pack("<H", 0)
    for (x, y) in sorted(celdas, key=lambda c: (c[1], c[0])):
        src, ax, ay = celdas[(x, y)]
        buf += struct.pack("<hhHHHH", x, y, src, ax, ay, 0)
    return base64.b64encode(buf).decode()


def w(cx, cy=None):
    """Centro de mundo de una celda (o de una coordenada suelta)."""
    if cy is None:
        return int(cx * CELL)
    return "Vector2(%d, %d)" % (int((cx + 0.5) * CELL), int((cy + 0.5) * CELL))


CAB = '''[gd_scene format=3 uid="uid://blacrevieja01"]

[ext_resource type="Script" uid="uid://c8405c212rbn6" path="res://scenes/game_elements/props/background_music/components/background_music.gd" id="1_bgm"]
[ext_resource type="AudioStream" uid="uid://bbamdm6wtjjcn" path="res://assets/first_party/music/Threadbare_Bed.ogg" id="2_music"]
[ext_resource type="TileSet" uid="uid://dtilespueblo01" path="res://scenes/quests/story_quests/la_deuda_del_sol/tiles_pueblo.tres" id="3_tiles"]
[ext_resource type="PackedScene" uid="uid://0ull24fvmhwk" path="res://scenes/game_elements/props/teleporter/teleporter.tscn" id="6_tele"]
[ext_resource type="PackedScene" uid="uid://iu2q66clupc6" path="res://scenes/game_elements/characters/player/player.tscn" id="7_player"]
[ext_resource type="SpriteFrames" uid="uid://dtoylirwywk0j" path="res://scenes/game_elements/characters/components/sprite_frames/storyweaver_blue.tres" id="8_frames"]
[ext_resource type="PackedScene" uid="uid://covsdqqsd6rsy" path="res://scenes/game_elements/props/sign/sign.tscn" id="9_sign"]
[ext_resource type="Script" uid="uid://0enyu5v4ra34" path="res://scenes/game_elements/props/spawn_point/components/spawn_point.gd" id="10_spawn"]
[ext_resource type="PackedScene" uid="uid://btrigvenc0e05" path="res://scenes/quests/story_quests/la_deuda_del_sol/vencimiento/componentes/trigger_de_vencimiento.tscn" id="11_trigvenc"]
[ext_resource type="Script" path="res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/components/lacrevieja.gd" id="11_lacrevieja"]
[ext_resource type="PackedScene" uid="uid://ipvcfv2g0oi1" path="res://scenes/game_elements/characters/npcs/talker/talker.tscn" id="12_talker"]
[ext_resource type="PackedScene" uid="uid://blamparapalabra01" path="res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/lampara_de_palabra.tscn" id="13_lampara"]
[ext_resource type="PackedScene" uid="uid://bpuntodecarga01" path="res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/punto_de_carga.tscn" id="14_carga"]
[ext_resource type="PackedScene" uid="uid://bpuertavecino01" path="res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/puerta_de_vecino.tscn" id="33_puerta"]
[ext_resource type="PackedScene" uid="uid://bmacetacantero01" path="res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/maceta_del_cantero.tscn" id="15_maceta"]
[ext_resource type="PackedScene" uid="uid://blapidagrabada01" path="res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/lapida_grabada.tscn" id="16_lapida"]
[ext_resource type="PackedScene" uid="uid://bgallinaprop01" path="res://scenes/game_elements/props/decoration/gallina/gallina.tscn" id="17_gallina"]
[ext_resource type="Resource" path="res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/e01_prologo.dialogue" id="18_dlg_prologo"]
[ext_resource type="Resource" path="res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/rosaura.dialogue" id="19_dlg_rosaura"]
[ext_resource type="Resource" path="res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/maestra.dialogue" id="20_dlg_maestra"]
[ext_resource type="Resource" path="res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/cosme.dialogue" id="21_dlg_cosme"]
[ext_resource type="Resource" path="res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/fedatario.dialogue" id="22_dlg_fedatario"]
[ext_resource type="Resource" path="res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/vecinos.dialogue" id="23_dlg_vecinos"]
[ext_resource type="SpriteFrames" uid="uid://cxjwwgm86d6it" path="res://scenes/game_elements/characters/components/sprite_frames/storyweaver_red.tres" id="24_sf_rosaura"]
[ext_resource type="SpriteFrames" uid="uid://c11381gwu87k4" path="res://scenes/game_elements/characters/components/sprite_frames/storyweaver_green.tres" id="25_sf_maestra"]
[ext_resource type="SpriteFrames" uid="uid://bfkd5s4fn0uw0" path="res://scenes/game_elements/characters/components/sprite_frames/monk.tres" id="26_sf_cosme"]
[ext_resource type="SpriteFrames" uid="uid://bpfnbr7ig4s5g" path="res://scenes/game_elements/characters/components/sprite_frames/elder.tres" id="27_sf_fedatario"]
[ext_resource type="SpriteFrames" uid="uid://07di3updrwh0" path="res://scenes/game_elements/characters/components/sprite_frames/storyweaver_purple.tres" id="28_sf_vecina"]
[ext_resource type="SpriteFrames" uid="uid://0m3xjnws7y4y" path="res://scenes/game_elements/characters/components/sprite_frames/storyweaver_yellow.tres" id="29_sf_vecino"]
[ext_resource type="SpriteFrames" uid="uid://cqe47tmqq3mu4" path="res://scenes/game_elements/characters/components/sprite_frames/elder2.tres" id="30_sf_ayudante"]
[ext_resource type="SpriteFrames" uid="uid://cy47injh7y40w" path="res://scenes/game_elements/characters/npcs/npc_prop/sprite_frames/fray_idle_yellow.tres" id="31_sf_vecino2"]
[ext_resource type="AudioStream" uid="uid://dhvit65nmsp7h" path="res://assets/third_party/nepalese_hand_bells/handBells-g3.ogg" id="32_campana"]
[ext_resource type="Script" path="res://scenes/quests/story_quests/la_deuda_del_sol/componentes/restaurador_del_acto.gd" id="99_restaurador"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_tele"]
size = Vector2(64, 192)

[node name="Lacrevieja" type="Node2D"]
editor_description = "Lacrevieja el día de la Mayoría de Palabra: E01–E04 del Acto 1. Pueblo de 60x40 celdas sobre tiles_pueblo.tres (Kenney CC0), generado por tools/gen-mapa-lacrevieja.py: plaza empedrada con las tres lámparas repartidas, panadería de Rosaura y su horno, galpón de la leña, casa de Ciro con su patio al sur, notaría con portón doble y patio de tinta, capilla con portón en arco y cementerio cercado de Cosme al noreste, viñedos en el borde oeste y salida este a Villarrúbrica. NO se edita a mano: se edita el generador y se vuelve a correr. Diálogo textual del guion en lacrevieja/*.dialogue."
script = ExtResource("11_lacrevieja")
dialogo_prologo = ExtResource("18_dlg_prologo")
dialogo_rosaura = ExtResource("19_dlg_rosaura")
dialogo_maestra = ExtResource("20_dlg_maestra")
dialogo_cosme = ExtResource("21_dlg_cosme")
dialogo_fedatario = ExtResource("22_dlg_fedatario")

[node name="BackgroundMusic" type="Node" parent="."]
script = ExtResource("1_bgm")
stream = ExtResource("2_music")
metadata/_custom_type_script = "uid://c8405c212rbn6"

[node name="TileMapLayers" type="Node2D" parent="."]
scale = Vector2(%d, %d)
''' % (ESCALA, ESCALA)

partes = [CAB]
for nombre in CAPAS:
    partes.append('\n[node name="%s" type="TileMapLayer" parent="TileMapLayers"]\n' % nombre)
    if Z[nombre]:
        partes.append("z_index = %d\n" % Z[nombre])
    partes.append('tile_map_data = PackedByteArray("%s")\n' % tile_map_data(capa[nombre]))
    partes.append('tile_set = ExtResource("3_tiles")\n')

partes.append('''
[node name="Teleporters" type="Node2D" parent="."]

[node name="TeleporterEste" parent="Teleporters" instance=ExtResource("6_tele")]
position = %(tele)s
next_scene = "uid://bvillarubrica"
spawn_point_path = NodePath("OnTheGround/SpawnOeste")

[node name="CollisionShape2D" type="CollisionShape2D" parent="Teleporters/TeleporterEste"]
shape = SubResource("RectangleShape2D_tele")

[node name="OnTheGround" type="Node2D" parent="."]
y_sort_enabled = true

[node name="Player" parent="OnTheGround" instance=ExtResource("7_player")]
position = %(player)s
player_name = "Ciro"
sprite_frames = ExtResource("8_frames")

[node name="Camera2D" type="Camera2D" parent="OnTheGround/Player"]
limit_left = 0
limit_top = 0
limit_right = %(ancho)d
limit_bottom = %(alto)d

[node name="SpawnOeste" type="Marker2D" parent="OnTheGround" groups=["spawn_point"]]
position = %(spawn_o)s
script = ExtResource("10_spawn")
metadata/_custom_type_script = "uid://0enyu5v4ra34"

[node name="SpawnEste" type="Marker2D" parent="OnTheGround" groups=["spawn_point"]]
position = %(spawn_e)s
script = ExtResource("10_spawn")
metadata/_custom_type_script = "uid://0enyu5v4ra34"

[node name="Cartel" parent="OnTheGround" instance=ExtResource("9_sign")]
position = %(cartel)s
text = "Lacrevieja — pueblo natal de Ciro. La fiesta de la Mayoría de Palabra es hoy."

[node name="CartelSalida" parent="OnTheGround" instance=ExtResource("9_sign")]
position = %(cartel_salida)s
text = "Camino del Diezmo → Villarrúbrica. Se sale del pueblo por la calle mayor."

[node name="Estrado" type="Polygon2D" parent="OnTheGround"]
position = %(estrado)s
color = Color(0.42, 0.28, 0.19, 1)
polygon = PackedVector2Array(-64, -24, 64, -24, 64, 16, -64, 16)

[node name="EstradoTabla" type="Polygon2D" parent="OnTheGround/Estrado"]
color = Color(0.55, 0.38, 0.25, 1)
polygon = PackedVector2Array(-58, -20, 58, -20, 58, -6, -58, -6)

[node name="Lampara1" parent="OnTheGround" instance=ExtResource("13_lampara")]
unique_name_in_owner = true
position = %(lamp1)s
etiqueta = "lámpara del poniente"

[node name="Lampara2" parent="OnTheGround" instance=ExtResource("13_lampara")]
unique_name_in_owner = true
position = %(lamp2)s
etiqueta = "lámpara del centro"

[node name="Lampara3" parent="OnTheGround" instance=ExtResource("13_lampara")]
unique_name_in_owner = true
position = %(lamp3)s
etiqueta = "lámpara del levante"

[node name="PilaDeLena" parent="OnTheGround" node_paths=PackedStringArray("enlace") instance=ExtResource("14_carga")]
unique_name_in_owner = true
position = %(pila)s
enlace = NodePath("../HornoGrande")
etiqueta = "leña del galpón"
accion = "Cargar un atado"

[node name="HornoGrande" parent="OnTheGround" node_paths=PackedStringArray("enlace") instance=ExtResource("14_carga")]
unique_name_in_owner = true
position = %(horno)s
modo = 1
enlace = NodePath("../PilaDeLena")
cupo = 3
etiqueta = "horno grande de Rosaura"
accion = "Entrar la leña"

[node name="Cantero" type="Node2D" parent="OnTheGround"]
''' % {
    "tele": w(58, 20),
    "player": w(*SPAWN),
    "ancho": W * CELL,
    "alto": H * CELL,
    "spawn_o": w(4, 20),
    "spawn_e": w(56, 20),
    "cartel": w(23, 18),
    # Los carteles van sólo donde hacen falta y NUNCA sobre la calzada: éste, en el
    # pasto de la vereda norte, a un paso del portal de árboles por donde se sale a
    # Villarrúbrica. La calle mayor (y 19-21) queda entera libre.
    "cartel_salida": w(57, 18),
    "estrado": w(35, 16),
    # Las tres lámparas repartidas por la plaza, separadas en X y en Y: las tres en
    # la misma fila de abajo se leían como tres palos en fila, no como alumbrado.
    "lamp1": w(26, 19),
    "lamp2": w(30, 22),
    "lamp3": w(35, 18),
    "pila": w(13, 28),
    "horno": "Vector2(800, 1212)",
})

# Las seis macetas, una por celda, en el cantero del borde norte de la plaza. Ya no
# hace falta espaciarlas de dos en dos: el rótulo «maceta — seca» dejó de estar
# siempre encendido (ahora sólo aparece cuando el jugador tiene la maceta a tiro) y
# el estado se lee por el sprite — planta mustia o verde, y agua en el tiesto.
for i in range(6):
    partes.append('''
[node name="Maceta%d" parent="OnTheGround/Cantero" instance=ExtResource("15_maceta")]
position = %s%s
''' % (i + 1, w(26 + i, 16), "\nrota = true" if i == 5 else ""))

partes.append('''
[node name="Cementerio" type="Node2D" parent="OnTheGround"]

[node name="Lapida1" parent="OnTheGround/Cementerio" instance=ExtResource("16_lapida")]
position = %(lap1)s
inscripcion = "Aquí descansa, en regla y sin mora, Simón Vergara."

[node name="Lapida2" parent="OnTheGround/Cementerio" instance=ExtResource("16_lapida")]
position = %(lap2)s
inscripcion = "Aquí descansa, en regla y sin mora, Erminia del Soto."
errata = "H"

[node name="Rosaura" parent="OnTheGround" instance=ExtResource("12_talker")]
unique_name_in_owner = true
position = %(rosaura)s
npc_name = "Rosaura"
sprite_frames = ExtResource("24_sf_rosaura")
dialogue = ExtResource("19_dlg_rosaura")

[node name="Maestra" parent="OnTheGround" instance=ExtResource("12_talker")]
unique_name_in_owner = true
position = %(maestra)s
npc_name = "la Maestra jardinera"
sprite_frames = ExtResource("25_sf_maestra")
dialogue = ExtResource("20_dlg_maestra")

[node name="Cosme" parent="OnTheGround" instance=ExtResource("12_talker")]
unique_name_in_owner = true
position = %(cosme)s
npc_name = "Cosme"
sprite_frames = ExtResource("26_sf_cosme")
dialogue = ExtResource("21_dlg_cosme")

[node name="Fedatario" parent="OnTheGround" instance=ExtResource("12_talker")]
unique_name_in_owner = true
position = %(fedatario)s
npc_name = "el Fedatario"
sprite_frames = ExtResource("27_sf_fedatario")
dialogue = ExtResource("22_dlg_fedatario")

[node name="VecinaDeLaEsquina" parent="OnTheGround" instance=ExtResource("12_talker")]
unique_name_in_owner = true
position = %(vecina)s
npc_name = "vecina de la esquina"
sprite_frames = ExtResource("28_sf_vecina")
dialogue = ExtResource("23_dlg_vecinos")

[node name="VecinoDeLasMesas" parent="OnTheGround" instance=ExtResource("12_talker")]
unique_name_in_owner = true
position = %(mesas)s
npc_name = "vecino de las mesas"
sprite_frames = ExtResource("29_sf_vecino")
dialogue = ExtResource("23_dlg_vecinos")

[node name="VecinoDeLasGallinas" parent="OnTheGround" instance=ExtResource("12_talker")]
unique_name_in_owner = true
position = %(gallinas)s
npc_name = "vecino de las gallinas"
sprite_frames = ExtResource("31_sf_vecino2")
dialogue = ExtResource("23_dlg_vecinos")

[node name="AyudanteDelFedatario" parent="OnTheGround" instance=ExtResource("12_talker")]
unique_name_in_owner = true
position = %(ayudante)s
npc_name = "el ayudante del Fedatario"
sprite_frames = ExtResource("30_sf_ayudante")
dialogue = ExtResource("23_dlg_vecinos")

[node name="Gallina1" parent="OnTheGround" instance=ExtResource("17_gallina")]
position = %(g1)s

[node name="Gallina2" parent="OnTheGround" instance=ExtResource("17_gallina")]
position = %(g2)s

[node name="Gallina3" parent="OnTheGround" instance=ExtResource("17_gallina")]
position = %(g3)s

[node name="Campana" type="AudioStreamPlayer" parent="."]
unique_name_in_owner = true
stream = ExtResource("32_campana")
volume_db = -4.0
pitch_scale = 0.5

[node name="Fundido" type="CanvasLayer" parent="."]
layer = 50

[node name="Negro" type="ColorRect" parent="Fundido"]
unique_name_in_owner = true
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
color = Color(0, 0, 0, 0)

[node name="TriggerDeVencimiento" parent="OnTheGround" instance=ExtResource("11_trigvenc")]
position = %(trigger)s
asumir_e04 = false

[node name="RestauradorDelActo" type="Node" parent="."]
script = ExtResource("99_restaurador")
''' % {
    "lap1": w(51, 6),
    "lap2": w(53, 6),
    "rosaura": w(16, 19),
    # La Maestra jardinera, delante de su cantero de macetas y no sobre empedrado
    # pelado; y a siete celdas del Fedatario, para que no se lean como el mismo NPC.
    "maestra": w(27, 17),
    "cosme": w(52, 7),
    "fedatario": w(35, 16),
    "ayudante": w(34, 10),
    # La esquina del conector con la calle mayor, pero SOBRE EL PASTO: parada en
    # (21,22) tapaba media calzada del conector (2 celdas de ancho) y el jugador
    # quedaba trabado contra ella al subir de la casa de Ciro a la plaza.
    "vecina": w(22, 22),
    "mesas": w(29, 25),
    "gallinas": w(34, 23),
    "g1": w(33, 25),
    "g2": "Vector2(2208, 1616)",
    "g3": "Vector2(2288, 1640)",
    "trigger": w(17, 29),
})

# Las once puertas, una por casa, sobre su vano.
partes.append('\n[node name="Puertas" type="Node2D" parent="OnTheGround"]\n')
for (_x0, y0, _an, al, _es, px, _n, (nodo, etiqueta, aviso)) in CASAS:
    partes.append('''
[node name="%s" parent="OnTheGround/Puertas" instance=ExtResource("33_puerta")]
position = %s
etiqueta = "%s"
aviso = "%s"
''' % (nodo, w(px, y0 + al - 1), etiqueta, aviso))

open(OUT, "w").write("".join(partes))

total = sum(len(c) for c in capa.values())
print("escrito", OUT)
print("  %dx%d celdas | baldosas pintadas: %d" % (W, H, total))
for n in CAPAS:
    print("    %-11s %5d" % (n, len(capa[n])))
print("  caminables alcanzadas desde el spawn: %d" % len(alcanzado))
print("  destinos verificados: %d/%d" % (len(DESTINOS) - len(fallas), len(DESTINOS)))
