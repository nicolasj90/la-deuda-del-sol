# Licencias y obligaciones — La Deuda del Sol

Estado al 2026-07-29. Auditar de nuevo antes de cualquier release público.

## Código

| Origen | Licencia | Obligaciones |
|--------|----------|--------------|
| Threadbare (base del proyecto: scenes/, addons/threadbare_*, storyquest_bootstrap) | **MPL-2.0** | Copyleft **por archivo**: los archivos MPL modificados siguen siendo MPL y su fuente debe estar disponible; archivos nuevos propios pueden tener cualquier licencia. **Mantener los encabezados SPDX** de los archivos de origen. Compatible con juego comercial. |
| addons/card-framework | MIT (Hyunjoon Park) | Conservar LICENSE (ya incluido en el addon). |
| vendor/godot_jrpg | MIT (KuryArt) | Conservar LICENSE (incluido). |
| vendor/sokoban | MIT (Luke Yoshioka) | Conservar LICENSE (incluido). Solo código: sus assets no se shipean. |
| addons/dialogue_manager, phantom_camera, input_helper | MIT | Conservar licencias de cada addon. |
| TetraForce (cuando se porte código de puzzles) | MIT (Joseph Lesko) | Atribuir en CREDITS al portar. |
| Godot Engine 4.7 | MIT | Atribución estándar en créditos. |

**Prohibido copiar código de:** Card-Combat-System (AGPL), db0/godot-card-game-framework
(AGPL), Fireplace (AGPL), openccg (GPL), Gemini Fantasy (GPL), Mira's Journal (GPL +
arte all-rights-reserved), fornclake/zelda (sin licencia). Solo lectura de arquitectura.
Referencia de reglas HS con licencia permisiva: hearthbreaker (MIT).

## Assets

| Origen | Licencia | Plan |
|--------|----------|------|
| Threadbare `assets/first_party/` | **CC-BY-SA-4.0** (The Threadbare Authors) | Usables con atribución; derivados quedan CC-BY-SA. Sirven de placeholder de calidad; reemplazo progresivo por arte propio (F6). |
| Threadbare `assets/third_party/` | Varias, etiquetadas por archivo con REUSE (`.license` junto a cada asset) | Auditar por-asset antes de release; respetar cada etiqueta. |
| vendor/godot_jrpg assets (LPC wulax OGA-BY 3.0, Hyptosis CC-BY 3.0, etc.) | Mixtas | NO shipear: el addon se usa por su código; sprites de batalla propios. |
| vendor/sokoban assets (dani-maccari, o-lobster, etc., itch.io) | Individuales, no cubiertas por el MIT | NO shipear. `vendor/` tiene `.gdignore` y se excluye del export. |

## Política de assets del proyecto (decisión del 2026-07-29)

El juego es **gratuito y sin monetización** (web + instalador para testers). Por decisión
del dueño del proyecto, los assets se aceptan en dos niveles:

- **Nivel A — libres** (CC0, CC-BY, OGA-BY, MIT, OFL): preferidos a igual calidad.
  Sin restricción de futuro.
- **Nivel B — NonCommercial** (CC BY-NC, BY-NC-SA y equivalentes): **aceptados**, porque
  la distribución gratuita está permitida. Obligación operativa: cada asset NC se registra
  en la tabla de este archivo con etiqueta `[NC]`. Si algún día el juego se comercializa,
  esa lista es exactamente lo que hay que reemplazar antes.
- **Excluido de builds**: "free for personal use" y similares — publicar el juego (aunque
  sea gratis) es distribución pública, no uso personal. Solo para maquetas privadas.
  También excluido: sin licencia explícita, y NoDerivatives (no permite adaptar).

## Assets adoptados (vendor/assets-adoptados)

Primera tanda de adopción, 2026-07-29 (tres agentes: mundo, UI/cartas, audio). Consolidada y
verificada archivo por archivo el mismo día. **14 packs adoptados**, todos de **nivel A
(libres)**: ningún `[NC]` entró en esta tanda.

Cada pack tiene su `LICENSE.txt` en la raíz de su carpeta, con la licencia textual, la URL de
origen, la fecha de verificación y el inventario del contenido. Donde el pack traía su propio
archivo upstream (`License.txt` de Kenney, `OFL.txt` de las fuentes, `license.txt` de
game-icons) ese archivo se conserva sin tocar y es la fuente de verdad; el `LICENSE.txt` del
proyecto es el resumen operativo.

| Pack | Autor | Licencia | `[NC]` | ¿Atribución requerida? |
|------|-------|----------|--------|------------------------|
| **Mundo** (5) | | | | |
| `mundo/ninja-adventure-godot-v4-github` | Pixel-Boy y AAA (arte); porteador **desconocido** (código) | CC0 1.0 el arte; **código del port sin determinar** | No | No (cortesía sí) |
| `mundo/kenney-tiny-town` | Kenney (Kenney Vleugels) | CC0 1.0 | No | No (cortesía sí) |
| `mundo/kenney-tiny-dungeon` | Kenney (Kenney Vleugels) | CC0 1.0 | No | No (cortesía sí) |
| `mundo/kenney-roguelike-rpg-pack` | Kenney, con ayuda de Lynn Evers | CC0 1.0 | No | No (cortesía sí) |
| `mundo/george-bailey-16x16-game-assets` | George Bailey (OGA: `George_`) | CC-BY 4.0 | No | **SÍ** — + indicar modificaciones (habrá re-grade) |
| **UI y cartas** (7) | | | | |
| `ui-y-cartas/game-icons-net` | Lorc, Delapouite, Skoll, John Colburn y ~32 más | CC-BY 3.0 (algunos autores CC0) | No | **SÍ** — acreditar a los autores de los iconos realmente usados |
| `ui-y-cartas/rpg-gui-construction-kit-lamoot` | Lamoot (Matjaž Lamut) | CC-BY 3.0 | No | **SÍ** — + indicar modificaciones (reskin a pergamino/lacre) |
| `ui-y-cartas/tcg-templates-killgorack` | KillGorack | CC0 1.0 | No | No (cortesía sí) |
| `ui-y-cartas/kenney-boardgame-pack` | Kenney (Kenney Vleugels) | CC0 1.0 | No | No (cortesía sí) |
| `ui-y-cartas/kenney-fantasy-ui-borders` | Kenney (Kenney Vleugels) | CC0 1.0 | No | No (cortesía sí) |
| `ui-y-cartas/fuente-alegreya` | Juan Pablo del Peral / Huerta Tipográfica | OFL 1.1 | No | No en el producto, pero **conservar `OFL.txt` junto al TTF** |
| `ui-y-cartas/fuente-cinzel` | Natanael Gama (NDISCOVER) | OFL 1.1 | No | No en el producto, pero **conservar `OFL.txt` junto al TTF** |
| **Audio** (2) | | | | |
| `audio/musica-randommind-medieval` | RandomMind | CC0 1.0 | No | No (cortesía sí) |
| `audio/musica-cynicmusic-battle-theme-a` | cynicmusic (Pixelsphere) | CC0 1.0 | No | No (cortesía sí) |

Los tres packs con atribución obligatoria son **george-bailey**, **game-icons-net** y
**rpg-gui-construction-kit-lamoot**; los dos CC-BY exigen además declarar que hubo
modificaciones, y el plan de arte prevé re-grade y reskin sobre ambos → anotar siempre
`modified`. El texto listo para pegar está en el `LICENSE.txt` de cada pack.

### Salvedades de esta tanda

1. **`ninja-adventure-godot-v4-github` no es el asset pack.** Lo que se bajó es un proyecto de
   Godot 4.3 (port de la demo): 98 PNG, 37 `.gd`, 21 `.tscn`, 4 OGG. El pack original de
   itch.io tiene miles de sprites. El arte presente es CC0 de Pixel-Boy, pero **la licencia del
   código del port es desconocida** (no vino `LICENSE` ni `README`, y no quedó registrada la URL
   del repo) → **no copiar código ni escenas de ahí** hasta identificarlo. El pack original
   sigue pendiente de descarga.
2. **`musica-randommind-medieval`: procedencia por archivo sin registrar.** Los 20 archivos no
   salen todos de la misma entrada de OGA (`battle_*`, `victory`, `defeat`, `harvestseason` son
   entradas aparte). Todo el catálogo del autor es CC0, así que el riesgo es bajo, pero hay que
   mapear archivo → URL antes del release.
3. **Peso.** `musica-randommind-medieval` son 243 MB (WAV + MP3 duplicados) y `game-icons-net`
   son 72 MB / 12.543 archivos. No entran al export (`vendor/` tiene `.gdignore`), pero al
   integrar conviene convertir el audio a OGG y curar un subset de iconos hacia
   `assets/third_party/` en vez de importar los sets completos.
4. **Pendiente:** 6 packs de SFX quedaron en carpeta vacía (cada una con un
   `PENDIENTE-DESCARGA.txt`). Lista consolidada de descarga manual en
   `docs/arte/descargas-pendientes.md`.

Al mover cualquiera de estos packs a `assets/third_party/` rige la regla 2 de abajo: `.license`
por archivo (patrón REUSE) además del `LICENSE.txt` del pack.

## Reglas operativas

1. `vendor/` nunca entra en un export preset.
2. Todo asset nuevo de terceros entra con su archivo `.license` al lado (patrón REUSE que
   ya usa Threadbare); los NC además se listan acá con `[NC]`.
3. Antes de la demo pública: `grep -r "SPDX" --include="*.gd"` para confirmar encabezados
   MPL intactos + auditoría de `assets/third_party/`.
