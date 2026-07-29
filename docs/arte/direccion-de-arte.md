# Dirección de arte — decisión unificada (2026-07-29)

Síntesis de los dos scoutings (`scouting-assets.md` nivel A libre, `scouting-assets-nc.md`
nivel B NC). Los dos informes proponían identidades distintas; esta es la decisión que
toma lo mejor de cada uno sin dejar huecos.

## La regla madre (modelo FF9)

**Mundo pixel 16 px/tile con re-grade cálido global + capa pintada de alta resolución
encima** (retratos, batalla, cartas, pantallas de región). FF9 hacía exactamente esto:
mundo low-res, interfaz y arte de personajes prerenderizados cálidos. La mezcla de
densidades es deliberada y por capas — nunca dentro de la misma capa.

## Por capa

| Capa | Stack | Nivel | Por qué |
|------|-------|-------|---------|
| Overworld, pueblos, dungeons, sprites top-down | Ninja Adventure (base, curado sin sabor japonés) + Kenney Tiny Town/Tiny Dungeon + props George Bailey + 0x72 DungeonTileset II + cultivos Kenney Roguelike; re-grade cálido dorados/lacre | A (CC0/CC-BY) | Cobertura completa sin huecos — el stack pintado 48px NO tiene sprites top-down libres: adoptar KR para el mundo dejaba el juego sin personajes. |
| Retratos de diálogo | Sutemo busts PSD por capas (10 expresiones, combinables) + Noraneko Nika/Nora para protagonistas; vara/fallback libre: Joseph Hewitt (CC-BY) | B [NC] | El hueco #1 del nivel libre. Sistema de expresiones real para los 5 motores de humor del guion. |
| Pantalla de combate por turnos | Battlers Ækashics Librarium (874 estáticos + 72 animados) para enemigos/jefes; fondos de batalla pintados (KR freebies como base de paint-over). Representación del party: decidir en F2 según qué muestre el BattleEngine | B [NC] | Pantalla separada del overworld → puede ser 100% pintada sin chocar con los 16px. Los quebrantos de papel/bruma siguen siendo derivado propio (shader de bruma + textura de papel). |
| Cartas «De Palabra» | Marcos TornioDuva (manuscrito/papel envejecido) [NC] + TCG Templates CC0 + arte de cartas con game-icons (CC-BY) + gemas de Crédito: viales LunaLucid [NC] | Mixto | La mesa de duelo es otra capa pintada; papel envejecido = identidad lacre/pergamino gratis. |
| UI general (menús, diálogo, HUD) | RPG GUI Construction Kit (CC-BY) reskineado a pergamino/lacre + Fantasy UI Borders CC0 + acentos dorados propios; fuentes Alegreya + Cinzel (OFL) | **A adrede** | La advertencia del informe NC: la UI es lo más caro de reemplazar si algún día se comercializa. La UI core se mantiene libre. |
| Música | Base David Vitas (CC-BY, set completo) + Vindsvept (folk campiña) + Scott Buckley (emotivo) + H/MIX GALLERY [NC] para piezas señalables (taberna, duelos, El Fiado) + MacLeod barroco | Mixto | H/MIX trae el registro JRPG japonés nativo; upgrade comercial barato (¥2.200/pista) si hiciera falta. Leitmotif de la deuda: composición propia pendiente (F6). |
| SFX | 100% CC0 del nivel A + wax seal CC0 de Freesound; **firma sonora del sello de lacre fabricada por capas** (papel + impacto + campana pitcheada con reverb) | A | No existe hecho; se fabrica una vez y es la marca del juego. |
| Pantallas especiales (título, tarjetas de región, ilustraciones) | KR freebies (Tuscan, Church/Cathedral) como base pintada | B [NC]* | *La licencia KR verificada permite también uso comercial con crédito — es de las NC que sobreviven a todo. |

## Reglas operativas

1. Nunca mezclar densidades dentro de una capa (un sprite 48px caminando sobre tiles 16px = prohibido).
2. Todo asset NC entra etiquetado `[NC]` en `docs/LICENCIAS.md` al adoptarse (regla ya vigente).
3. El re-grade cálido es UN shader/LUT global compartido, no retoques por tile — coherencia gratis.
4. Excluido en ambos niveles: CaptainSkolot (licencia contradictoria + cláusula anti-AI de
   otros packs del stack), rips de IP, "personal use".
5. Adopción real de packs (descarga + import + LICENCIAS) ocurre por capa cuando su fase la
   necesita: F2 battlers, F3 cartas, F5 mapas, F6 el resto.
