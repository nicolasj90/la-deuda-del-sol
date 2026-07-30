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
AGUA = {(dx, dy): T(RL, 2 + dx, 0 + dy, True) for dx in range(3) for dy in range(3)}

# árboles: copa (sella el borde) + tronco
COPA_VERDE, TRONCO_VERDE = T(TT, 4, 0, True), T(TT, 4, 1, True)
COPA_OTONO, TRONCO_OTONO = T(TT, 3, 0, True), T(TT, 3, 1, True)
ARBOLITOS = [T(TT, 3, 2, True), T(TT, 4, 2, True), T(TT, 5, 0, True)]
HONGOS = T(TT, 5, 2)
BROTES = T(TT, 5, 1)

# viñedo: parras con uva del pack roguelike
PARRA = [T(RL, 24, 11, True), T(RL, 24, 10, True)]
FRUTAL = [T(RL, 23, 9, True), T(RL, 23, 10, True), T(RL, 23, 11, True)]

# canteros de flores
CANTEROS = [T(RL, 2, 7), T(RL, 3, 7), T(RL, 2, 10), T(RL, 3, 10), T(RL, 2, 13), T(RL, 3, 13)]
FLORCITAS = [T(RL, 0, 6), T(RL, 1, 6), T(RL, 0, 9), T(RL, 1, 12)]

# props
POZO_ALTO, POZO_BAJO = T(TT, 8, 7, True), T(TT, 8, 8, True)
HORNO_ALTO, HORNO_BAJO = T(RL, 54, 9, True), T(RL, 54, 10, True)
MESA_LARGA = [T(RL, 16, 0, True), T(RL, 17, 0, True), T(RL, 18, 0, True)]
MOSTRADOR = [T(RL, 12, 4, True), T(RL, 13, 4, True)]
PUESTOS = [T(RL, 11, 4, True), T(RL, 12, 4, True), T(RL, 13, 4, True),
           T(RL, 11, 6, True), T(RL, 13, 6, True)]
CORDON = T(RL, 7, 4)                 # cordón de ladrillo del borde de la plaza
LAPIDAS_DECO = [T(RL, 51, 9, True), T(RL, 52, 9, True), T(RL, 51, 10, True),
                T(RL, 52, 10, True), T(RL, 53, 10, True)]
CRUZ_MADERA = T(RL, 53, 9, True)
CRUZ_PIEDRA = T(RL, 51, 10)          # sobre el techo de la capilla: no necesita física
BANDERINES = [T(RL, 51, 0), T(RL, 52, 0), T(RL, 51, 3),
              T(RL, 52, 3), T(RL, 51, 6), T(RL, 52, 6)]
CARTEL_MADERA = T(TT, 11, 6, True)   # tabla de oficio colgada

# cercos
CERCO_H = [T(RL, 46, 23, True), T(RL, 47, 23, True), T(RL, 48, 23, True)]
CERCO_V = [T(RL, 50, 23, True), T(RL, 51, 23, True)]
CERCO_ESQ = T(RL, 52, 23, True)
TAPIA = [T(TD, 9, 4, True), T(TD, 10, 4, True), T(TD, 11, 4, True)]

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

tierra = set()
for zona in (CALLE_MAYOR, CALLE_NORTE, CALLE_SUR, CONECTOR_NO, CONECTOR_SO,
             CONECTOR_NE, CONECTOR_SE, BAJADA_OESTE, BAJADA_ESTE, PLAZA,
             VINEDO, CEMENTERIO, PORTON_CEMENTERIO, PATIO_NOTARIA):
    tierra.update(zona)

for (x, y) in sorted(tierra):
    izq = (x - 1, y) not in tierra
    der = (x + 1, y) not in tierra
    arr = (x, y - 1) not in tierra
    aba = (x, y + 1) not in tierra
    ax = 0 if izq else (2 if der else 1)
    ay = 1 if arr else (3 if aba else 2)
    if (ax, ay) == (1, 2) and azar(7) == 0:
        put("Caminos", x, y, TIERRA_LLANA[azar(len(TIERRA_LLANA))])
    else:
        put("Caminos", x, y, T(TT, ax, ay + 0))

# empedrado de la plaza: adentro del anillo de tierra
EMPEDRADO_PLAZA = rect(25, 15, 36, 24)
for (x, y) in EMPEDRADO_PLAZA:
    borde = x in (25, 36) or y in (15, 24)
    put("Caminos", x, y, CORDON if borde else EMPEDRADO[azar(len(EMPEDRADO))])

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


CASAS = [
    #  x0, y0, ancho, alto, estilo, puerta_x, nombre
    (13, 8, 4, 3, "roja", 14, "casa de la vecina de la esquina"),
    (18, 8, 4, 3, "gris", 19, "casa vecina norte"),
    (25, 7, 7, 4, "gris", 28, "NOTARÍA del fedatario"),
    (41, 7, 5, 4, "gris", 43, "CAPILLA DEL LACRE"),
    (13, 15, 6, 4, "roja", 15, "PANADERÍA DE ROSAURA"),
    (44, 16, 4, 3, "roja", 45, "casa vecina del levante"),
    (15, 25, 5, 4, "roja", 17, "CASA DE CIRO"),
    (10, 26, 3, 3, "gris", 11, "GALPÓN DE LA LEÑA"),
    (26, 26, 4, 3, "gris", 27, "casa vecina del sur"),
    (33, 26, 4, 3, "roja", 34, "casa de las gallinas"),
    (44, 26, 4, 3, "gris", 45, "casa vecina del sudeste"),
]
for (x0, y0, an, al, es, px, _n) in CASAS:
    casa(x0, y0, an, al, es, px)

# cruz de piedra sobre el techo de la capilla: se lee capilla, no casa
put("Techos", 43, 7, CRUZ_PIEDRA)

# patio de tapia de la notaría (E06): al este del edificio, abierto a la calle
for y in range(7, 11):
    put("Paredes", 32, y, TAPIA[y % len(TAPIA)])
    put("Paredes", 36, y, TAPIA[(y + 1) % len(TAPIA)])
for x in range(33, 36):
    put("Paredes", x, 7, TAPIA[x % len(TAPIA)])
put("Decoracion", 34, 9, T(RL, 16, 0, True))      # atril / mesa del patio

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

# tablas de oficio: la panadería y la notaría se anuncian desde la calle
put("Paredes", 19, 18, CARTEL_MADERA)
put("Paredes", 24, 10, CARTEL_MADERA)

# guirnaldas: banderines sobre el anillo norte de la plaza
for i, x in enumerate(range(24, 38)):
    put("Decoracion", x, 14, BANDERINES[i % len(BANDERINES)])

# ---------------------------------------------------------------------------
# 6. Cementerio chico, detrás de la capilla: cerco, cruces y lápidas de piedra
# ---------------------------------------------------------------------------
for x in range(48, 57):
    put("Paredes", x, 3, CERCO_H[x % len(CERCO_H)])
    if x not in (51, 52, 53):
        put("Paredes", x, 10, CERCO_H[(x + 1) % len(CERCO_H)])
for y in range(4, 10):
    put("Paredes", 48, y, CERCO_V[y % len(CERCO_V)])
    put("Paredes", 56, y, CERCO_V[(y + 1) % len(CERCO_V)])
put("Paredes", 48, 3, CERCO_ESQ)
put("Paredes", 56, 3, CERCO_ESQ)
put("Paredes", 48, 10, CERCO_ESQ)
put("Paredes", 56, 10, CERCO_ESQ)
for i, (x, y) in enumerate([(50, 5), (54, 5), (50, 8), (55, 8), (53, 4), (49, 7)]):
    put("Paredes", x, y, LAPIDAS_DECO[i % len(LAPIDAS_DECO)])
put("Paredes", 55, 4, CRUZ_MADERA)

# ---------------------------------------------------------------------------
# 7. Huerta y arboledas: relleno decorativo, siempre fuera de calles y casas
# ---------------------------------------------------------------------------
ocupado = set(capa["Paredes"]) | set(capa["Techos"]) | tierra

HUERTA = rect(25, 32, 36, 36)
for (x, y) in HUERTA:
    if (x, y) in ocupado:
        continue
    if y % 2 == 0:
        put("Decoracion", x, y, CANTEROS[(x + y) % len(CANTEROS)])

LAGUNA = rect(51, 33, 53, 35)
for (x, y) in LAGUNA:
    put("Caminos", x, y, AGUA[(x - 51, y - 33)])
    ocupado.add((x, y))

RELLENO = (rect(3, 2, 56, 3) + rect(10, 4, 24, 7) + rect(33, 2, 47, 6)
           + rect(10, 13, 12, 14) + rect(9, 22, 19, 24) + rect(38, 13, 39, 18)
           + rect(42, 22, 57, 27) + rect(3, 37, 56, 37) + rect(10, 32, 22, 36)
           + rect(38, 31, 50, 36) + rect(22, 6, 24, 12) + rect(46, 11, 47, 14))
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

# ---------------------------------------------------------------------------
# 8. Chequeo de caminabilidad: todo lo que el jugador tiene que alcanzar
# ---------------------------------------------------------------------------
def solida(x, y):
    for n in ("Caminos", "Paredes", "Techos"):
        t = capa[n].get((x, y))
        if t is not None and t in SOLIDAS:
            return True
    return False


SPAWN = (17, 31)
DESTINOS = {
    "puerta de la casa de Ciro": (17, 29),
    "horno grande": (12, 19),
    "pila de leña": (13, 28),
    "puerta de la panadería": (15, 19),
    "cantero norte": (28, 16),
    "estrado": (35, 18),
    "lámpara del poniente": (27, 22),
    "lámpara del levante": (35, 22),
    "puerta de la notaría": (28, 11),
    "patio de la notaría": (34, 10),
    "puerta de la capilla": (43, 11),
    "cementerio (lápidas)": (52, 6),
    "salida este a Villarrúbrica": (58, 20),
    "viñedo del oeste": (4, 20),
    "mesas de la fiesta": (30, 23),
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
[ext_resource type="PackedScene" uid="uid://bmacetacantero01" path="res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/maceta_del_cantero.tscn" id="15_maceta"]
[ext_resource type="PackedScene" uid="uid://blapidagrabada01" path="res://scenes/quests/story_quests/la_deuda_del_sol/lacrevieja/lapida_grabada.tscn" id="16_lapida"]
[ext_resource type="PackedScene" uid="uid://djmdhrse34vgq" path="res://scenes/game_elements/props/decoration/bunny/bunny.tscn" id="17_bunny"]
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
[ext_resource type="SpriteFrames" uid="uid://cqe47tmqq3mu4" path="res://scenes/game_elements/characters/components/sprite_frames/elder2.tres" id="30_sf_vecino2"]
[ext_resource type="SpriteFrames" uid="uid://bsjdohkkb776w" path="res://scenes/game_elements/characters/components/sprite_frames/bunny_yellow.tres" id="31_sf_gallina"]
[ext_resource type="AudioStream" uid="uid://dhvit65nmsp7h" path="res://assets/third_party/nepalese_hand_bells/handBells-g3.ogg" id="32_campana"]
[ext_resource type="Script" path="res://scenes/quests/story_quests/la_deuda_del_sol/componentes/restaurador_del_acto.gd" id="99_restaurador"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_tele"]
size = Vector2(64, 192)

[node name="Lacrevieja" type="Node2D"]
editor_description = "Lacrevieja el día de la Mayoría de Palabra: E01–E04 del Acto 1. Pueblo de 60x40 celdas sobre tiles_pueblo.tres (Kenney CC0), generado por tools/gen-mapa-lacrevieja.py: plaza empedrada con las tres lámparas, panadería de Rosaura y su horno, galpón de la leña, casa de Ciro al sur, notaría con patio, capilla y cementerio de Cosme al noreste, viñedos en el borde oeste y salida este a Villarrúbrica. Diálogo textual del guion en lacrevieja/*.dialogue."
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
    "estrado": "Vector2(2272, 1064)",
    "lamp1": w(27, 23),
    "lamp2": w(31, 23),
    "lamp3": w(35, 23),
    "pila": w(13, 28),
    "horno": "Vector2(800, 1212)",
})

for i in range(6):
    partes.append('''
[node name="Maceta%d" parent="OnTheGround/Cantero" instance=ExtResource("15_maceta")]
position = %s%s
''' % (i + 1, w(26 + i, 15), "\nrota = true" if i == 5 else ""))

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
sprite_frames = ExtResource("30_sf_vecino2")
dialogue = ExtResource("23_dlg_vecinos")

[node name="Gallina1" parent="OnTheGround" instance=ExtResource("17_bunny")]
position = %(g1)s
sprite_frames = ExtResource("31_sf_gallina")

[node name="Gallina2" parent="OnTheGround" instance=ExtResource("17_bunny")]
position = %(g2)s
sprite_frames = ExtResource("31_sf_gallina")

[node name="Gallina3" parent="OnTheGround" instance=ExtResource("17_bunny")]
position = %(g3)s
sprite_frames = ExtResource("31_sf_gallina")

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
    "maestra": w(28, 16),
    "cosme": w(52, 7),
    "fedatario": "Vector2(2272, 1032)",
    "vecina": w(21, 22),
    "mesas": w(29, 25),
    "gallinas": w(33, 23),
    "g1": w(30, 25),
    "g2": "Vector2(1968, 1648)",
    "g3": "Vector2(2088, 1584)",
    "trigger": w(17, 29),
})

open(OUT, "w").write("".join(partes))

total = sum(len(c) for c in capa.values())
print("escrito", OUT)
print("  %dx%d celdas | baldosas pintadas: %d" % (W, H, total))
for n in CAPAS:
    print("    %-11s %5d" % (n, len(capa[n])))
print("  caminables alcanzadas desde el spawn: %d" % len(alcanzado))
print("  destinos verificados: %d/%d" % (len(DESTINOS) - len(fallas), len(DESTINOS)))
