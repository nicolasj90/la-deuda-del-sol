# Bitácora — 2026-07-29 — Fundación (F0 + F1 parcial + guion borrador + arte)

Corrida interrumpida por límite de sesión (resetea 17:40 UTC). Estado al cierre:
`main` en `42ad628`, `./verify.sh` **OK** (0 errores). Bundle:
`~/respaldos/la-deuda-del-sol-20260729-cierre.bundle`.

## Hecho hoy

- **F0**: base Threadbare 81b2ece verificada en Godot 4.7 (binario:
  `~/tools/godot/Godot_v4.7-stable_linux.x86_64`; el symlink `godot` sigue en 4.6.3).
  Cores vendorizados: `addons/card-framework` (chun92, MIT), `vendor/godot_jrpg`
  (kuryart, MIT), `vendor/sokoban` (zurkon, MIT). Sin LFS. Docs: concepto, investigación
  de cores, plan F0–F6, licencias.
- **F1 poda** (completa, verify OK): fuera todo el demo de Threadbare. Conservados:
  `scenes/quests/template_quests/NO_EDIT/` (plantilla que clona storyquest_bootstrap)
  y `scenes/quests/story_quests/el_juguete_perdido/` (referencia de quest completa).
- **Guion Acto 1 en borrador**: `docs/guion/acto1/` — escaleta de 28 escenas (E01–E28,
  con curva de 5 campanadas de la prenda) + 4 bloques con todo el diálogo.
- **Arte decidido**: `docs/arte/direccion-de-arte.md` — mundo 16px re-grade cálido +
  capas pintadas (retratos Sutemo/Noraneko [NC], battlers Ækashics [NC], UI core libre).
  Política de licencias 2 niveles en `docs/LICENCIAS.md` (NC aceptado, etiquetado).

## Pendiente (retomar acá)

1. **F1 esqueleto** (el paso que sigue): crear 4 mapas stub copiando el patrón de
   `lore_quests`-style mínimo o de `el_juguete_perdido`, bajo
   `scenes/quests/story_quests/la_deuda_del_sol/`: lacrevieja ↔ villarrubrica ↔
   camino_del_diezmo ↔ el_fiado, encadenados. Boot: título → lacrevieja.
   **Claves del inventario** (ya aplicadas o a respetar):
   - Los defaults viven en `addons/threadbare_project_settings` (NO tocar el addon):
     override en `project.godot` sección `[threadbare]`: `general/opening_quest`
     (apuntar al quest.tres nuevo) y `general/home_scene` (hub nuevo o lacrevieja).
     La poda ya tocó project.godot — revisar qué dejó puesto.
   - El storybook lista quests por **escaneo dinámico** de `scenes/quests/*/quest.tres`
     (no hay registro hardcodeado). El Elder usa `@export quest_directory`.
   - Revisión adversarial de F1 quedó sin correr: revisar referencias colgantes
     (grep de rutas borradas) al retomar.
2. **Guion — pase de calidad**: script doctors (voces/continuidad: "Ciro jamás miente,
   Fiel jamás afirma, Salu jamás promete" + humor/ritmo) → reescritura por bloque →
   ensamble `INDICE.md` (siembras→payoffs + contrato guion↔gameplay). Los 4 bloques y
   la escaleta ya están en disco: los doctores leen de ahí. Nota de sala pendiente:
   verificar la Fórmula de Cortesía Plena citada en E18/E22 contra el texto canónico
   de E08.
3. **F2**: integrar `vendor/godot_jrpg` (combate por turnos, party de 5) — plan en
   `docs/cores/plan-integracion.md`.
4. Los workflows muertos no son resumibles entre sesiones: relanzar como workflows
   nuevos (los scripts de referencia quedaron en
   `~/.claude/projects/-home-nicolasj90-la-deuda-del-sol/*/workflows/scripts/`).
