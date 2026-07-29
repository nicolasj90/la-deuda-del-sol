# La Deuda del Sol

> En un mundo donde las promesas pesan como piedras, generan interés y se heredan como
> deudas, un aprendiz de notario descubre que la palabra sellada que carga desde niño es
> la promesa más antigua del universo: la que obliga al Sol a volver cada mañana.

JRPG en Godot 4.7 con **tres cores**:

1. **RPG por turnos estilo FF9** — pueblos con NPCs, party de 5, combate por turnos,
   menús, equipo, guardado. (Threadbare + framework JRPG de kuryart)
2. **«De Palabra»**, juego de cartas estilo Hearthstone diegético — Crédito, Estrado,
   keywords y el giro de las **Promesas**: cartas que podés jugar bajo palabra, con bonus
   si cumplís y Quebrantos si rompés. Cartas por drops de enemigos, firmas de bosses,
   jefes de cartas, torneos y empeños. (card-framework + motor de reglas propio)
3. **Puzzles estilo Zelda** — bloques en mora, haces de testigos, palancas, llaves;
   cada puzzle enseña el lore del dungeon donde vive. (sokoban + patrones TetraForce)

## Correr el juego

```bash
~/tools/godot/Godot_v4.7-stable_linux.x86_64 --path . --editor   # editor
~/tools/godot/Godot_v4.7-stable_linux.x86_64 --path .            # jugar
./verify.sh                                                      # verificación headless
```

**Requiere Godot 4.7** (instalado junto al 4.6.3, que siguen usando los otros proyectos).
Este repo NO usa Git LFS: los assets van commiteados directo.

## Documentación

- `docs/concepto/concepto-definitivo.md` — mundo, personajes, sinopsis, cartas, puzzles,
  estructura del Acto 1. **Leer primero.**
- `docs/cores/investigacion-cores.md` — qué repos públicos forman cada core y por qué.
- `docs/cores/plan-integracion.md` — fases F0–F6.
- `docs/LICENCIAS.md` — obligaciones por origen (MPL-2.0 / MIT / CC-BY-SA).

## Estructura

- `scenes/`, `assets/`, `addons/threadbare_*` — base Threadbare (MPL-2.0), motor de
  aventura: overworld, NPCs, diálogos, quests.
- `addons/card-framework/` — mesa de cartas (MIT): drag & drop, manos, pilas.
- `vendor/` — cores vendorizados pendientes de integración (`.gdignore`: Godot no los
  escanea): `godot_jrpg/` (combate por turnos, MIT) y `sokoban/` (puzzles, MIT).
