# Plan de integración — La Deuda del Sol

Los tres cores del juego, en orden de integración. Cada fase se ejecuta como corrida
autónoma por Workflow con bitácora, según las convenciones de trabajo de los otros
proyectos. El juego es un **JRPG por turnos estilo FF9** (ese es el core principal),
con **De Palabra** (cartas estilo Hearthstone diegéticas) y **puzzles estilo Zelda**
como segundo y tercer core.

## F0 — Fundación (HECHO, 2026-07-29)

- Base Threadbare `81b2ece` verificada corriendo en Godot 4.7 (0 script errors).
- `addons/card-framework/` instalado (importa limpio en 4.7).
- `vendor/godot_jrpg/` y `vendor/sokoban/` vendorizados (con `.gdignore`: Godot no los
  escanea hasta que se integren).
- LFS eliminado del repo; git_lfs_checker desinstalado; proyecto renombrado.
- Concepto definitivo en `docs/concepto/concepto-definitivo.md`.

## F1 — Poda y esqueleto propio

- Inventariar las quests demo de Threadbare (`scenes/quests/`): conservar el motor
  (game_state, scene_switcher, props, diálogo, título) y quitar el contenido de muestra
  que no sirva de template.
- Pantalla de título "La Deuda del Sol"; español como locale principal (Threadbare trae
  infraestructura i18n con gettext).
- Definir la estructura de mapas del Acto 1: Lacrevieja, Villarrúbrica + Archivo Bajo,
  Camino del Diezmo + Viñedo en Prenda, El Fiado + Lonja de Ultramar.
- verify.sh corriendo en CI mental: importar + smoke headless.

## F2 — Core RPG por turnos (FF9)

El corazón del juego. Integrar `vendor/godot_jrpg` como addon activo:

- Copiar a `addons/godot_jrpg/`, registrar sus 8 autoloads (GameManager, MenuManager,
  EventRunner, Audio, UI, VFXManager, InputManager, Commands) y el input map.
- Deps: Threadbare ya trae **dialogue_manager**, **phantom_camera**, **input_helper**.
  Faltan del plug.gd de kuryart: safe_resource_loader, universal_fade, gd-plug (evaluar
  cuáles hacen falta de verdad; vendorizar las que sí).
- Puente Threadbare ↔ BattleEngine: trigger de encuentro en el overworld (Area2D o evento
  de diálogo) → GameManager pasa a BATTLE → escena de combate → volver al mapa con estado.
- Party de 5: Ciro (Empeñador: micro-promesas en batalla), Ferra (Garante/tanque),
  Salu (letra chica/debuffs), Odila (selladora/sanadora), Fiel (azar y bruma).
  Datos como .tres (tubería data_src→.tres si conviene, como en los otros proyectos).
- Sistema de micro-promesas de Ciro en combate (promesa → bonus si se cumple → quebranto
  invocado si se rompe): primera mecánica propia sobre el BattleEngine.
- Conocidos a corregir de kuryart: "huir" no implementado (run_button_up sin listener),
  strings hardcodeadas en portugués, editor de base de datos esqueleto (no lo usamos).

## F3 — Core de cartas «De Palabra» (Hearthstone)

- Motor de reglas propio en GDScript (no existe uno permisivo hecho — verificado):
  estado de duelo (Firma 30 Aval, Crédito 1→10, Estrado máx. 7), turnos, robo,
  keywords (Al contado, Garante, Sello, De palabra, Letra chica, Interés) y el giro
  de **Promesas** con plazos + Quebrantos. Lógica separada de la vista (testeable headless,
  mismo patrón que BattleEngine).
- Vista sobre `addons/card-framework`: mano en abanico, Estrado como CardContainer custom,
  drag & drop con validación de Crédito, animaciones de ataque.
- Referencias de arquitectura (sin copiar código AGPL): pipeline de acciones de
  Slay The Robot (MIT), efectos-como-Resources de guladam (MIT), reglas de
  hearthbreaker (MIT).
- IA rival por arquetipo (curva de maná + heurísticas por keyword; los rivales-personalidad
  del concepto son perfiles de IA).
- **Obtención de cartas — canales completos** (pedido explícito):
  - **drops de enemigos comunes** del combate RPG (familias de cartas por familia de
    enemigo, con probabilidad, anunciado en la pantalla de victoria),
  - **firma-cartas garantizadas de los bosses** del RPG,
  - **jefes de cartas**: duelos obligatorios que bloquean progreso y opcionales con
    cartas exclusivas,
  - Tasadora Ciega (cartas por historias), tiendas/sobres, empeño y recompra, cofres
    de puzzle y quests.
- 30–40 cartas jugables del Acto 1 (las 10 del concepto incluidas); colección persistida
  en el save del RPG (mismo GameManager).

## F4 — Core de puzzles (Zelda)

- Capa de puzzle sobre los mapas Threadbare: portar de `vendor/sokoban` el patrón
  Player/Box/Platform por señales (adaptar tile 16→tamaño de grilla propio) y de
  TetraForce (re-clonar, Godot 3 → 4) el vocabulario: palancas con `requires_weight`,
  puertas por señal, llaves + contador de dungeon, antorchas, bloques con snap.
- Placas que respondan también al jugador (extensión conocida sobre sokoban).
- Construir los dos puzzles del Acto 1: **Cerradura de Testigos** (versión tutorial:
  1 estatua, 2 estanterías, haces de luz) y **Viñedo en Prenda** (bloques en mora:
  cumplir la tarea del sello para poder empujar). La Lonja de Ultramar usa sokoban puro
  con el chiste de los letreros.

## F5 — Contenido del Acto 1 «El vencimiento»

Secuencia completa en `docs/concepto/concepto-definitivo.md` (§ Estructura del Acto 1):
7 beats, 3 dungeons, 3 bosses de RPG, 3 duelos obligatorios + opcionales, escenas.
Diálogos en español rioplatense con los 5 motores de humor del concepto.

## F6 — Feel, estética y demo

- Auditoría de feel sobre el juego real (lección aprendida: verificar en game scene,
  no en arena de debug).
- Vara estética: reemplazo progresivo de assets CC-BY-SA de Threadbare por identidad
  propia (lacre, papel, sellos, dorados de Valdepalabra).
- Export web + demo con instalador para testers (Windows/Linux), como en los otros
  proyectos.
