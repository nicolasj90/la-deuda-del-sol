#!/usr/bin/env python3
# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
"""
Genera scenes/quests/story_quests/la_deuda_del_sol/tiles_pueblo.tres: el TileSet
16x16 del pueblo, sobre los tres atlas Kenney CC0 de assets/third_party/.

Uso: python3 tools/gen-tiles-pueblo.py

CUIDADO: reescribe el .tres completo. Si alguien tocó el TileSet desde el editor
de Godot, esos cambios se pierden. Para cambios permanentes, editá este script
(las listas de colisión de abajo) y volvé a correrlo.

Capas de física, iguales a las del resto del repo (ver tiles/water.tres):
  physics_layer_0 -> collision_layer 16  "walls"              (paredes, techos,
                                                               árboles, cercos, props)
  physics_layer_1 -> collision_layer 8   "sight occluders"    (cuerpo de las casas)
  physics_layer_2 -> collision_layer 512 "non_walkable_floor" (agua)
El jugador tiene collision_mask 531, así que 16 y 512 lo frenan.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"
OUT = ROOT + "scenes/quests/story_quests/la_deuda_del_sol/tiles_pueblo.tres"

FULL = (-8, -8, 8, -8, 8, 8, -8, 8)
BH = (-8, 0, 8, 0, 8, 8, -8, 8)          # media baldosa de abajo
HB = (-8, -4, 8, -4, 8, 4, -8, 4)        # banda horizontal (cercos horizontales)
VB = (-4, -8, 4, -8, 4, 8, -4, 8)        # banda vertical (cercos verticales)

L_WALL = 0   # physics_layer_0 -> collision_layer 16  "walls"
L_OCC = 1    # physics_layer_1 -> collision_layer 8   "sight occluders"
L_FLOOR = 2  # physics_layer_2 -> collision_layer 512 "non_walkable_floor"


def wall(poly=FULL):
    return [(L_WALL, poly), (L_OCC, poly)]


def solid(poly=FULL):
    return [(L_WALL, poly)]


def water(poly=FULL):
    return [(L_FLOOR, poly)]


def rect(x0, x1, y0, y1):
    return [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)]


# ---------------------------------------------------------------- source 0
# Kenney Tiny Town, 12x11, 16px sin separacion. Se crean las 132 baldosas.
tt_tiles = rect(0, 11, 0, 10)
tt_phys = {}


def tt(coords, phys):
    for c in coords:
        tt_phys[c] = phys


# arboles. Las copas de los arboles altos colisionan enteras a proposito: apiladas
# copa+tronco son el "muro" con el que se cierran los bordes del mapa (ver
# tools/gen-mapa-lacrevieja.py). Sin eso queda una franja caminable entre la mitad
# de arriba de la copa y la mitad de abajo del tronco, y el jugador se escapa.
tt([(3, 0), (4, 0)], solid(FULL))                   # copas de arbol grande
tt([(3, 1), (4, 1)], solid(BH))                     # troncos arbol grande
tt([(3, 2), (4, 2)], solid(BH))                     # arbolitos chicos
tt([(5, 0)], solid(BH))                             # arbusto redondo
tt(rect(6, 11, 2, 2), solid(BH))                    # base de bosquecitos
# cercos de madera
tt([(8, 3), (9, 3), (10, 3), (8, 5), (10, 5)], solid(FULL))   # esquinas / cruce
tt([(11, 3), (8, 4), (10, 4), (11, 4), (11, 5)], solid(VB))   # tramos verticales
tt([(8, 6), (9, 6), (10, 6)], solid(HB))                      # tramos horizontales
tt([(9, 4)], solid(BH))                                       # buzon
tt([(11, 6)], solid(BH))                                      # cartel de madera
# (9,5) = hueco/portillo del cerco -> caminable a proposito
# techos (2 filas) y paredes: cuerpo de la casa, solido + tapa vision
tt(rect(0, 7, 4, 5), wall())
tt([(0, 6), (1, 6), (3, 6), (4, 6), (5, 6), (7, 6)], wall())
tt([(0, 7), (4, 7)], wall())                        # paredes con ventana
# (2,6) y (6,6) = vanos de puerta; (1..3,7) y (5..7,7) = puertas -> caminables
# muralla / piedra
tt(rect(0, 2, 8, 8), wall())
tt(rect(3, 6, 8, 8), wall())
tt(rect(0, 2, 10, 10), wall())
tt([(6, 10)], wall())
tt([(7, 8)], solid(FULL))                           # escotilla de madera
# props
tt([(8, 7), (8, 8)], solid(FULL))                   # pozo (2 baldosas)
tt([(10, 7), (11, 7)], solid(BH))                   # colmena / diana
tt([(10, 8), (11, 8)], solid(BH))                   # tronco apilado / bebedero
tt([(10, 10), (11, 10)], solid(BH))                 # barriles

# ---------------------------------------------------------------- source 1
# Kenney Tiny Dungeon, 12x11, 16px sin separacion. Se crean las 132 baldosas.
td_tiles = rect(0, 11, 0, 10)
td_phys = {}


def td(coords, phys):
    for c in coords:
        td_phys[c] = phys


td([(4, 2), (4, 3)], wall())                        # muro de ladrillo con reja
td(rect(9, 11, 4, 4), wall())                       # muro de ladrillo gris
td([(8, 4)], solid(FULL))                           # roca
td([(6, 4), (7, 4)], solid(BH))                     # banco / cama
td([(0, 6)], solid(BH))                             # MESA / mostrador
td([(1, 6)], solid(BH))                             # banqueta
td([(2, 6)], solid(BH))                             # yunque
td([(3, 5), (3, 6)], solid(FULL))                   # alacena / estanteria (2 alto)
td([(4, 5)], solid(BH))                             # cruz de piedra
td([(5, 5)], solid(BH))                             # LAPIDA
td([(4, 6), (5, 6), (6, 6)], solid(HB))             # baranda de hierro
td(rect(7, 8, 5, 6), solid(FULL))                   # rejas / celda

# ---------------------------------------------------------------- source 2
# Kenney Roguelike/RPG pack, 57x31, 16px con separacion 1px. Subconjunto curado.
rl_tiles = []
rl_phys = {}


def rl(coords, phys=None):
    for c in coords:
        if c not in rl_tiles:
            rl_tiles.append(c)
        if phys is not None:
            rl_phys[c] = phys


# agua
rl(rect(0, 1, 0, 4), water())                       # relleno de agua abierta
rl(rect(2, 4, 0, 2), water())                       # laguna 3x3 con orilla de tierra
rl(rect(2, 4, 3, 5), solid(FULL))                   # fuente/pileta 3x3 con brocal
# suelos caminables
rl(rect(5, 9, 0, 1))                                # pasto / tierra / piedra / arena
rl(rect(5, 9, 2, 5))                                # empedrados y ladrillos
rl(rect(5, 9, 6, 10))                               # parches de tierra
rl(rect(0, 4, 6, 14))                               # canteros de flores sobre pasto
# puesto de feria
rl(rect(10, 11, 0, 3))                              # toldos a rayas (sin colision)
rl(rect(10, 13, 4, 6), solid(BH))                   # MOSTRADORES de feria con mercaderia
rl(rect(14, 17, 6, 6), solid(BH))                   # cajones de verdura
rl([(16, 0), (17, 0), (18, 0)], solid(BH))          # tablones de mostrador
# horno / fragua
rl([(12, 0), (13, 0), (14, 0)], solid(FULL))        # HORNO de piedra (12 apagado, 13/14 con fuego)
rl([(15, 0)], solid(BH))                            # yunque
rl(rect(54, 55, 8, 10), solid(FULL))                # HORNO de ladrillo abovedado con fuego
rl(rect(54, 55, 6, 7), solid(BH))                   # fogones / braseros
# cementerio
rl([(51, 9), (52, 9)], solid(BH))                   # LAPIDAS de piedra
rl([(53, 9)], solid(BH))                            # cruz de madera
rl([(51, 10), (52, 10), (53, 10)], solid(BH))       # cruces de piedra
# banderas y gallardetes (fiesta)
rl(rect(49, 53, 0, 8))
# cerco de tranquera de madera
rl(rect(46, 49, 23, 24), solid(HB))
rl(rect(50, 51, 23, 24), solid(VB))
rl(rect(52, 53, 23, 24), solid(FULL))
# arboles y arbustos (vinedos)
rl(rect(13, 18, 9, 11), solid(BH))
rl(rect(19, 28, 9, 11))
for c in [(19, 9), (20, 9), (21, 9), (22, 9), (23, 9), (24, 9), (25, 9), (26, 9), (27, 9),
          (23, 10), (24, 10), (25, 10), (26, 10), (27, 10),
          (23, 11), (24, 11), (26, 11), (27, 11)]:
    rl_phys[c] = solid(BH)
# flores sueltas
rl(rect(41, 44, 23, 24))

import re


def uid_de(res_path):
    """Lee el uid real que Godot le asignó al PNG importado."""
    txt = open(ROOT + res_path[len("res://"):] + ".import").read()
    return re.search(r'^uid="(uid://[^"]+)"', txt, re.M).group(1)


P_TT = "res://assets/third_party/kenney_tiny_town/tilemap_packed.png"
P_TD = "res://assets/third_party/kenney_tiny_dungeon/tilemap_packed.png"
P_RL = "res://assets/third_party/kenney_roguelike_rpg_pack/roguelikeSheet_transparent.png"

SOURCES = [
    ("1_tt", uid_de(P_TT), P_TT, "TileSetAtlasSource_tinytown", 0, tt_tiles, tt_phys),
    ("2_td", uid_de(P_TD), P_TD, "TileSetAtlasSource_tinydungeon", 0, td_tiles, td_phys),
    ("3_rl", uid_de(P_RL), P_RL, "TileSetAtlasSource_roguelike", 1, rl_tiles, rl_phys),
]


def poly_str(p):
    return "PackedVector2Array(%s)" % ", ".join(str(v) for v in p)


lines = ['[gd_resource type="TileSet" format=3 uid="uid://dtilespueblo01"]', ""]
for rid, uid, path, _sub, _sep, _t, _p in SOURCES:
    lines.append('[ext_resource type="Texture2D" uid="%s" path="%s" id="%s"]' % (uid, path, rid))
lines.append("")

for rid, _uid, _path, sub, sep, tiles, phys in SOURCES:
    lines.append('[sub_resource type="TileSetAtlasSource" id="%s"]' % sub)
    lines.append('texture = ExtResource("%s")' % rid)
    lines.append("texture_region_size = Vector2i(16, 16)")
    if sep:
        lines.append("separation = Vector2i(%d, %d)" % (sep, sep))
    for (x, y) in tiles:
        k = "%d:%d" % (x, y)
        lines.append("%s/0 = 0" % k)
        for (layer, p) in phys.get((x, y), []):
            lines.append("%s/0/physics_layer_%d/polygon_0/points = %s" % (k, layer, poly_str(p)))
    lines.append("")

lines += [
    "[resource]",
    "resource_name = \"tiles_pueblo\"",
    "tile_size = Vector2i(16, 16)",
    "occlusion_layer_0/light_mask = 1",
    "physics_layer_0/collision_layer = 16",
    "physics_layer_0/collision_mask = 0",
    "physics_layer_0/collision_priority = 100.0",
    "physics_layer_1/collision_layer = 8",
    "physics_layer_1/collision_mask = 0",
    "physics_layer_2/collision_layer = 512",
    "physics_layer_2/collision_mask = 0",
]
for i, (_rid, _uid, _path, sub, _sep, _t, _p) in enumerate(SOURCES):
    lines.append('sources/%d = SubResource("%s")' % (i, sub))
lines.append("")

open(OUT, "w").write("\n".join(lines))
n = sum(len(s[5]) for s in SOURCES)
nc = sum(len(s[6]) for s in SOURCES)
print("escrito", OUT, "| baldosas:", n, "| con colision:", nc)
