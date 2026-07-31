#!/usr/bin/env python3
# SPDX-FileCopyrightText: La Deuda del Sol Authors
# SPDX-License-Identifier: MPL-2.0
"""
Genera assets/first_party/wildlife/gallina/gallina_idle.png: la gallina de
Lacrevieja, cuatro cuadros de 16x16 en una tira de 64x16.

Uso: python3 tools/gen-sprite-gallina.py

¿Por qué existe este archivo? Porque «las gallinas» del pueblo eran conejos: la
escena usaba res://scenes/game_elements/props/decoration/bunny/bunny.tscn para
Gallina1/2/3 y en pantalla se veían conejos blancos con nombre de gallina. En los
tres packs Kenney adoptados (tiny town, tiny dungeon, roguelike RPG) no hay
gallina, y el guion no puede cambiarlas por conejos: la Gallina es carta del mazo
(data/cartas/tres/gallina_lacrevieja.tres) y la canta Ciro en E03.

El dibujo es a 16px y se muestra a escala 4, la misma grilla que los tiles del
pueblo, así que pega con el resto del mapa (los conejos de Threadbare son de
128px y de otro estilo).

Sin dependencias: el PNG se escribe a mano con zlib de la biblioteca estándar.
"""
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"
DEST = ROOT + "assets/first_party/wildlife/gallina/"
OUT = DEST + "gallina_idle.png"

# o=contorno  w=pluma  s=sombra  r=cresta/barbilla  y=pico y patas  e=ojo
PALETA = {
    ".": (0, 0, 0, 0),
    "o": (62, 39, 49, 255),
    "w": (255, 255, 255, 255),
    "s": (206, 208, 222, 255),
    "r": (214, 64, 56, 255),
    "y": (240, 166, 42, 255),
    "e": (62, 39, 49, 255),
}

PATAS_A = [
    "....oyo.oyo.....",
    "...oyyo.oyyo....",
]
PATAS_B = [
    ".....oyo.oyo....",
    "....oyyo.oyyo...",
]

CUERPO_ALTO = [                     # cabeza levantada
    "................",
    ".........rr.....",
    "........orro....",
    "........owwwo...",
    ".......owewwo...",
    ".......owwwwoy..",
    "oo.....owwwwo...",
    "owwo..owwwwwo...",
    "owwwoowwwwwwo...",
    ".owwwwwwwwwwo...",
    "..owwwwwwwwwo...",
    "..owwssswwwwo...",
    "..owwwwwwwwoo...",
    "...oooooooo.....",
]
CUERPO_ALTO_COLA = [                # igual, con la cola alzada
    "................",
    ".........rr.....",
    "........orro....",
    "........owwwo...",
    "oo.....owewwo...",
    "owwo...owwwwoy..",
    "owwwo..owwwwo...",
    ".owwwoowwwwwo...",
    "..owwwwwwwwwo...",
    ".owwwwwwwwwwo...",
    "..owwwwwwwwwo...",
    "..owwwssswwwo...",
    "..owwwwwwwwoo...",
    "...oooooooo.....",
]
CUERPO_PICOTEA = [                  # cabeza abajo, picoteando
    "................",
    "................",
    "................",
    "................",
    "................",
    "oo.......rr.....",
    "owwo....orro....",
    "owwwo...owwwo...",
    "owwwwoowwewwoy..",
    ".owwwwwwwwwwo...",
    "..owwwwwwwwwo...",
    "..owwssswwwwo...",
    "..owwwwwwwwoo...",
    "...oooooooo.....",
]

CUADROS = [
    CUERPO_ALTO + PATAS_A,
    CUERPO_PICOTEA + PATAS_B,
    CUERPO_ALTO_COLA + PATAS_A,
    CUERPO_PICOTEA + PATAS_A,
]

LADO = 16
for i, cuadro in enumerate(CUADROS):
    assert len(cuadro) == LADO, (i, len(cuadro))
    for j, fila in enumerate(cuadro):
        assert len(fila) == LADO, (i, j, len(fila), fila)

ANCHO, ALTO = LADO * len(CUADROS), LADO


def png(ancho, alto, pixeles):
    """PNG RGBA de 8 bits, sin filtro. pixeles[y][x] = (r, g, b, a)."""
    cruda = b""
    for y in range(alto):
        cruda += b"\x00"
        for x in range(ancho):
            cruda += bytes(pixeles[y][x])

    def trozo(etiqueta, datos):
        return (struct.pack(">I", len(datos)) + etiqueta + datos
                + struct.pack(">I", zlib.crc32(etiqueta + datos) & 0xFFFFFFFF))

    cabecera = struct.pack(">IIBBBBB", ancho, alto, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + trozo(b"IHDR", cabecera)
            + trozo(b"IDAT", zlib.compress(cruda, 9)) + trozo(b"IEND", b""))


pixeles = [[PALETA["."]] * ANCHO for _ in range(ALTO)]
for i, cuadro in enumerate(CUADROS):
    for y, fila in enumerate(cuadro):
        for x, c in enumerate(fila):
            pixeles[y][i * LADO + x] = PALETA[c]

os.makedirs(DEST, exist_ok=True)
with open(OUT, "wb") as f:
    f.write(png(ANCHO, ALTO, pixeles))
print("escrito", OUT, "| %dx%d | %d cuadros de %dpx" % (ANCHO, ALTO, len(CUADROS), LADO))
