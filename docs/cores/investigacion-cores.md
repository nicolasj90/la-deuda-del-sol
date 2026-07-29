# Investigación de cores públicos (2026-07-29)

Corrida de investigación con 13 agentes (workflow `buscar-cores`): 4 barridos por categoría
sobre GitHub/GitLab/itch + verificación por clonado e inspección de código de los 9 mejores
candidatos. Resultado completo crudo: bitácora de la sesión. Acá va lo decidido y por qué.

## Stack elegido

| Core | Repo | Licencia | Godot | Rol |
|------|------|----------|-------|-----|
| Aventura/pueblos (RPG parte 1) | [endlessm/threadbare](https://github.com/endlessm/threadbare) `81b2ece` | MPL-2.0 (código) / CC-BY-SA-4.0 (arte propio) | 4.7 | **Base del proyecto**: overworld, NPCs, diálogos (Dialogue Manager), quests, título, transiciones. Diseñado explícitamente para remixar. El proyecto más activo de todo lo encontrado. |
| Combate por turnos + party (RPG parte 2) | [kuryart/godot-jrpg](https://github.com/kuryart/godot-jrpg) `6d62e6e` | MIT | 4.6 | Vendorizado en `vendor/godot_jrpg/`: BattleEngine completo estilo FF (attack/defend/item/skill, AoE, crítico, MP, orden por velocidad, estados), victoria con XP/level-up/dinero/loot, menús (ítems, skills, equipo 5 slots, status), save/load. Split duro lógica/UI (simulación headless posible). |
| Cartas — mesa e interacción | [chun92/card-framework](https://github.com/chun92/card-framework) `a74b713` | MIT | 4.6 | Instalado en `addons/card-framework/`: drag & drop con máquina de estados, manos en abanico, pilas, drop zones con particiones, undo, cartas desde JSON. Autocontenido, 0 errores importado en 4.7. |
| Cartas — motor de reglas | propio (ver referencias) | — | — | El duelo estilo Hearthstone (Crédito, Estrado, keywords, Promesas) se implementa sobre el framework de mesa. **No existe** un motor HS completo en Godot 4 con licencia permisiva — verificado. |
| Puzzles — empuje en grilla | [zurkon/sokoban](https://github.com/zurkon/sokoban) `64030ad` | MIT (código) | 4.5 | Vendorizado en `vendor/sokoban/`: Player/Box/Platform/Level desacoplados por señales, raycasts + tween, placas de presión. Assets de terceros: NO se shipean. |
| Puzzles — vocabulario Zelda | [loudsmilestudios/TetraForce](https://github.com/loudsmilestudios/TetraForce) `fa5fa76` | MIT | 3.3 (referencia) | **No vendorizado** (Godot 3): fuente de porteo para palancas con peso, puertas por señal, llaves/contador de dungeon, antorchas, bloques. Re-clonar al pin cuando se necesite. |

Motor: **Godot 4.7 stable** (`~/tools/godot/Godot_v4.7-stable_linux.x86_64`, instalado junto al
4.6.3 sin tocarlo). Threadbare está guardado con 4.7; el resto migra hacia adelante sin drama.

## Por qué NO godot-open-rpg

Es el core FF-style más completo del ecosistema (verificado), pero es la base de La Compañía
Trémula: la consigna del proyecto es no reutilizar nada de lo que ya tenemos. Además arrastra
red flags propios: sin save de partida, todo el demo en un main.tscn de 921 líneas, Dialogic
2.0-alpha acoplado al combate, issue abierto de errores en 4.6.2.

## Candidatos de cartas descartados (y para qué sirven igual)

- **JavierIslas/Card-Combat-System** (Godot 4.6): exactamente el "cerebro" HS que falta
  (turnos, maná, criaturas vs criaturas, IA) pero **AGPL-3.0** → obligaría a liberar el juego
  entero bajo AGPL. Solo referencia de arquitectura, cero código copiado.
- **db0/godot-card-game-framework** (1366★): el más completo y probado, pero Godot 3, AGPL,
  y su rama godot4 quedó abandonada a mitad de camino en 2022. Referencia del ScriptingEngine
  de efectos.
- **danielyule/hearthbreaker** (Python, **MIT**): única implementación de reglas HS con
  licencia permisiva. Referencia legítima de reglas/edge cases.
- **DesirePathGames/Slay-The-Robot** (Godot 4.6, MIT): pipeline de acciones/interceptores
  data-driven excelente como modelo del motor de efectos; pero es roguelike sin tablero de
  esbirros ni maná escalable.
- **guladam/deck_builder_tutorial** (Godot 4.3, MIT): modelo limpio de "efectos como
  Resources + event bus". Clonado en referencia de sesión.

## Trampas detectadas (no perder tiempo con esto)

- **SucceedHQ-innovations/godot-rpg-framework**: README-ware. 18 archivos, 0 escenas.
- **Gemini Fantasy**: es un tutorial en markdown, no un proyecto clonable; GPL.
- **OpenCCG (skrax/openccg)**: C#, GPL, muerto 2023. El "OpenCCG" famoso es una librería de
  lingüística que no tiene nada que ver.

## Estado de verificación (2026-07-29)

- Threadbare en 4.7: importación limpia y **0 SCRIPT ERROR** corriendo headless 15 s
  (los únicos errores son de display server en headless, esperados).
  Nota: si se re-clona upstream, los `.import` pueden quedar `valid=false` si la primera
  importación corre sobre punteros LFS — restaurar `.import` desde git y reimportar.
  Este repo ya NO usa LFS (assets commiteados directo, filtros quitados de .gitattributes).
- card-framework en 4.7: importación limpia, 0 errores.
- kuryart en 4.7: pendiente de smoke test al integrarlo (F2). Conocidos: borrar el autoload
  fantasma `_mcp_game_helper`/`addons/godot_ai` de su project.godot de origen (no aplica al
  addon vendorizado), instalar deps no vendorizadas (ver plan-integracion.md), "huir" sin
  implementar, strings con mezcla de idiomas.
