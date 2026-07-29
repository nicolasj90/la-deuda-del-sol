# Descargas pendientes — lista consolidada

Estado al **2026-07-29**, después de la primera tanda de adopción (3 agentes) y su
consolidación. Fuentes: `scouting-assets.md` (nivel A libre), `scouting-assets-nc.md`
(nivel B `[NC]`) y `direccion-de-arte.md` (la decisión que manda).

**Ya adoptado:** 14 packs en `vendor/assets-adoptados/` — ver la tabla en
`docs/LICENCIAS.md`, sección "Assets adoptados". Este archivo es **lo que falta**.

## Reglas para quien ejecute estas descargas

1. **Re-verificar la licencia en la página antes de bajar.** Las licencias de itch pueden
   cambiar; las fechas de verificación del scouting son del 2026-07-29.
2. Descomprimir en la carpeta destino indicada y **escribir el `LICENSE.txt`** del pack con el
   mismo formato que los ya adoptados (licencia textual + URL + fecha + inventario). Si el ZIP
   trae su propio archivo de licencia, **conservarlo sin tocar** además del `LICENSE.txt`.
3. Todo asset `[NC]` se agrega a la tabla de `docs/LICENCIAS.md` con etiqueta `[NC]` al
   adoptarse (regla vigente).
4. Borrar el ZIP después de verificar el contenido.
5. Las 6 carpetas del Bloque 0 ya existen y tienen un `PENDIENTE-DESCARGA.txt` que hay que
   **borrar** al completar la descarga.

---

## Bloque 0 — Reintentos: descargas que fallaron (nivel A, CC0)

Los 6 packs de SFX del conjunto recomendado quedaron en **carpeta vacía**: el agente de audio
creó los directorios pero no bajó ningún archivo. Son todos CC0 y no hay decisión pendiente:
es puro reintento.

| # | URL | Qué elegir | Carpeta destino |
|---|-----|-----------|-----------------|
| 0.1 | https://kenney.nl/assets/casino-audio | El ZIP completo (botón "Download"). Interesan los foley de cartas y fichas para los duelos. | `vendor/assets-adoptados/audio/sfx-kenney-casino-audio/` |
| 0.2 | https://kenney.nl/assets/interface-sounds | El ZIP completo. Clicks y confirmaciones de UI. | `vendor/assets-adoptados/audio/sfx-kenney-interface-sounds/` |
| 0.3 | https://opengameart.org/content/80-cc0-rpg-sfx | El ZIP completo. **Prioridad: las cadenas** (Empeñadero) — no hay otra fuente CC0 buena. También espadas, hechizos, monedas, páginas. | `vendor/assets-adoptados/audio/sfx-rubberduck-80-rpg-sfx/` |
| 0.4 | https://opengameart.org/content/rpg-sound-pack | El ZIP completo. Combate, inventario, tela/botellas/metal (textura mercader-prestamista). | `vendor/assets-adoptados/audio/sfx-artisticdude-rpg-sound-pack/` |
| 0.5 | https://opengameart.org/content/various-paper-sound-effects | Todos los archivos. **Crítico**: el arrugado de papel es la capa base del SFX de sello de lacre. | `vendor/assets-adoptados/audio/sfx-luckius-paper/` |
| 0.6 | https://opengameart.org/content/book-flip-sounds | Todos los archivos. Pasar páginas del libro de cuentas. | `vendor/assets-adoptados/audio/sfx-voltiment555-book-flip/` |

**Notas de ejecución.** OGA (0.3–0.6) sirve enlaces directos a archivo: es reintentable de forma
automática, probablemente falló por rate-limiting. Kenney (0.1–0.2) sirve el ZIP detrás de un
enlace con hash que cambia por versión; los agentes de mundo y UI sí lo lograron con 5 packs
Kenney, así que también es automatizable — hay que leer el enlace real de la página, no adivinarlo.

---

## Bloque 1 — Crítico: el mundo está incompleto (nivel A, CC0)

| # | URL | Qué elegir | Carpeta destino |
|---|-----|-----------|-----------------|
| 1.1 | https://pixel-boy.itch.io/ninja-adventure-asset-pack | **El asset pack completo** (`NinjaAdventure.zip`, itch, gratis / NYOP). Del pack se **cura**: se usan interiores, cuevas, VFX, espíritus, monstruos y NPCs; se **evita** el sabor japonés explícito (torii, pagodas, ninjas, samuráis). | `vendor/assets-adoptados/mundo/ninja-adventure-pack-original/` (carpeta **nueva** — no mezclar con el port) |
| 1.2 | https://0x72.itch.io/dungeontileset-ii | `0x72_DungeonTilesetII_v1.x.zip`. Palancas, trampas, antorchas, autotiles. Va con re-grade a lacre. | `vendor/assets-adoptados/mundo/0x72-dungeon-tileset-ii/` |

**Por qué 1.1 es lo más urgente de toda la lista.** `direccion-de-arte.md` apoya en Ninja
Adventure la **base del overworld, los sprites top-down, los enemigos, los jefes, los VFX y los
espíritus** (base de los quebrantos de papel). Lo que se bajó en su lugar
(`mundo/ninja-adventure-godot-v4-github/`) es un **proyecto de Godot 4.3, no el pack**: 98 PNG,
4 personajes (ninja_blue, samurai_blue, samurai_green, pig) y 2 entornos (autumn, swamp). Con eso
el juego no tiene con qué poblar un pueblo. Además la licencia del **código** de ese port es
desconocida → no copiar scripts ni escenas de ahí.

Ninguna de las dos es scriptable sin más: **itch.io requiere navegador** (páginas NYOP con
"Download" / "No thanks, just take me to the downloads").

---

## Bloque 2 — Audio faltante (nivel A, mezcla CC0 y CC-BY)

### 2.a Firma sonora del sello de lacre

El SFX del sello no existe hecho (hueco #4 del scouting): se **fabrica por capas** y es la marca
del juego. Falta la capa de campana y la de sello.

| # | URL | Qué elegir | Carpeta destino |
|---|-----|-----------|-----------------|
| 2.1 | https://bigsoundbank.com/church-bell-s0135.html | "Church Bell" de Joseph Sardin. Bajar WAV. Se usa **pitcheada -3 a -7 semitonos con reverb** — es la prenda de Ciro y la capa grave del sello. Verificar el texto de licencia del sitio al bajar. | `vendor/assets-adoptados/audio/sfx-bigsoundbank-campana/` |
| 2.2 | https://freesound.org/s/759526/ | "Wax seal" de Cerise_Virtuelle — **CC0**. | `vendor/assets-adoptados/audio/sfx-freesound-lacre/` |
| 2.3 | https://freesound.org/s/178650/ | "Office self inking stamp on paper" de sengjinn — **CC BY 4.0** → atribución obligatoria. | `vendor/assets-adoptados/audio/sfx-freesound-lacre/` |

Freesound exige **cuenta** para descargar: manual (o API con token). Bajar sonido por sonido y
anotar la licencia de cada uno en el `LICENSE.txt` de la carpeta — en Freesound la licencia es
por sonido, no por pack.

### 2.b Música que falta

La paleta musical de `direccion-de-arte.md` es: **David Vitas** (set base) + **Vindsvept** (folk
campiña) + **Scott Buckley** (emotivo) + **H/MIX** `[NC]` (piezas señalables) + **MacLeod**
(barroco/clavecín). De todo eso solo entró RandomMind y una pista de cynicmusic.

| # | URL | Qué elegir | Carpeta destino |
|---|-----|-----------|-----------------|
| 2.4 | https://www.davidvitas.com/rpg-music-pack/ | **El set completo** — es la base declarada de la paleta. CC BY (crédito obligatorio). | `vendor/assets-adoptados/audio/musica-david-vitas/` |
| 2.5 | https://vindsvept.se/licensing/ (catálogo en su canal/Bandcamp) | Pistas **folk de campiña**. CC BY 4.0, crédito obligatorio. Tiene whitelist anti-Content-ID para gamedevs. | `vendor/assets-adoptados/audio/musica-vindsvept/` |
| 2.6 | https://www.scottbuckley.com.au/library/ | 2-3 pistas **emotivas** (la deuda de Ciro). CC-BY 4.0. | `vendor/assets-adoptados/audio/musica-scott-buckley/` |
| 2.7 | https://incompetech.com/music/royalty-free/ | Tags **Renaissance / harpsichord** para duelos de cartas y El Fiado: *Angevin*, *Master of the Feast* y similares. CC-BY 4.0 — **incompetech exige un formato de crédito textual específico, una entrada por pista**. | `vendor/assets-adoptados/audio/musica-kevin-macleod/` |
| 2.8 | https://peritune.com/ | Campiña/pueblo/viaje, tono FF9. **SOLO pistas publicadas antes de 2026-03** (después el autor cambió a licencia propia). Anotar la fecha de publicación de cada pista. | `vendor/assets-adoptados/audio/musica-peritune/` |

**Ojo con la selección por pista:** 2.4–2.8 no son "bajar el ZIP y listo" — hay que **elegir
pistas** contra la lista de escenas del Acto 1 (`docs/guion/acto1/`). Conviene decidir la lista
de pistas antes de bajar, para no meter 2 GB de audio sin uso.

---

## Bloque 3 — Nivel B `[NC]`: nada bajado todavía

`direccion-de-arte.md` asigna a nivel B tres capas enteras: **retratos, battlers y pantallas
especiales**. Ninguna se bajó. La regla 5 de ese documento dice que la adopción ocurre **por capa
cuando su fase la necesita**, así que esto no es un fallo de la tanda — es la agenda.

**Todo el Bloque 3 es itch.io o tienda propia → descarga manual con navegador**, y en varios
casos hace falta email/cuenta.

### 3.a Fase F2 — battlers (pantalla de combate)

| # | URL | Qué elegir | Carpeta destino |
|---|-----|-----------|-----------------|
| 3.1 | https://aekashics.itch.io/aekashics-librarium-librarium-static-batch-megapack | Megapack estático (874 estáticos + 72 animados + busts de monstruos). Enemigos y los 9 jefes. **Crédito OBLIGATORIO a Ækashics + link a akashics.moe.** | `vendor/assets-adoptados-nc/battlers-aekashics-librarium/` |

### 3.b Fase F2/F3 — retratos de diálogo (hueco #1 del nivel libre)

| # | URL | Qué elegir | Carpeta destino |
|---|-----|-----------|-----------------|
| 3.2 | https://sutemo.itch.io/female-character (+ la variante masculina del mismo autor) | **Los PSD por capas** — 10 expresiones, outfits y peinados combinables. Es el sistema de expresiones para los 5 motores de humor del guion. Crédito no obligatorio (consta solo en comentarios → **captura de pantalla al bajar** y acreditar por cortesía). | `vendor/assets-adoptados-nc/retratos-sutemo/` |
| 3.3 | https://noranekogames.itch.io/nika · https://noranekogames.itch.io/nora | Nika y Nora, para **protagonistas**. Crédito **OBLIGATORIO**. Prohíbe AI/NFT/merch. | `vendor/assets-adoptados-nc/retratos-noranekogames/` |
| 3.4 | https://opengameart.org/content/joseph-hewitts-fantasy-rpg-portrait-set-1 | **Nivel A, CC-BY 4.0** — 26 retratos pintados. Vara de estilo y **placeholder libre** del party mientras no haya busts propios. Marcar los usados como `PLACEHOLDER` en el manifest. Es la única entrada de este bloque que **no** es NC ni itch: bajable automáticamente. | `vendor/assets-adoptados/ui-y-cartas/retratos-joseph-hewitt/` |

### 3.c Fase F3 — cartas «De Palabra»

| # | URL | Qué elegir | Carpeta destino |
|---|-----|-----------|-----------------|
| 3.5 | https://tornioduva.itch.io/tornioduva-card-template | Marcos manuscrito / papel envejecido. CC BY-NC 4.0, NYOP. Complementa los TCG Templates CC0 ya adoptados. | `vendor/assets-adoptados-nc/cartas-tornioduva/` |
| 3.6 | https://lunalucid.itch.io/magical-template | Los **8 viales animados** como gemas de coste de Crédito. CC BY-NC 4.0 gratis; hay versión comercial a US$16.99 si algún día se cobra. | `vendor/assets-adoptados-nc/gemas-lunalucid/` |

### 3.d Fase F5 — mapas y pantallas especiales

| # | URL | Qué elegir | Carpeta destino |
|---|-----|-----------|-----------------|
| 3.7 | https://kokororeflections-shop.fourthwall.com/collections/freebies | **KR FREE Tuscan Tiles** (campiña/viñedos, 9/10) y **KR FREE Church and Cathedral** (8.5/10) como **base de paint-over** para pantallas de título/región y fondos de batalla. Resto de freebies (Ocean, Farm, Mansion, Fairy Tale, Crystal Dungeon, Fantasy) según haga falta. Crédito **OBLIGATORIO** a Kokoro Reflections (kokororeflections.com). | `vendor/assets-adoptados-nc/pantallas-kokoro-reflections/` |

**Regla dura que no se puede violar acá:** KR es **48 px pintado** y el mundo del juego es
**16 px**. `direccion-de-arte.md` regla 1 prohíbe mezclar densidades dentro de una capa → KR
entra **solo** en pantallas especiales y fondos de batalla, **nunca** como tileset caminable.

### 3.e Música señalable

| # | URL | Qué elegir | Carpeta destino |
|---|-----|-----------|-----------------|
| 3.8 | https://www.hmix.net/ (términos: /terms.html) | Piezas señalables: **taberna, duelos de cartas, El Fiado**. Registro JRPG japonés nativo. Gratis para juegos no comerciales, crédito recomendado no obligatorio. **Anotar la lista exacta de pistas usadas**: el upgrade comercial es ¥2.200 por pista. | `vendor/assets-adoptados-nc/musica-hmix/` |

---

## Bloque 4 — Opcionales / plan B (nivel A)

Nada de esto bloquea. Bajar solo si la fase correspondiente lo pide.

| # | URL | Qué elegir | Carpeta destino |
|---|-----|-----------|-----------------|
| 4.1 | https://opengameart.org/content/24x32-characters-with-faces-big-pack | Cabbit (Svetlana Kushnariova), **OGA-BY 3.0** — party y NPCs de pueblo con cara a juego, 24x32 sobre tile 16. **Alternativa** a los sprites de Ninja Adventure; el scouting §5 lo proponía para reemplazar `tiny-swords`. Decidir uno de los dos: no mezclar dos gramáticas de personaje. | `vendor/assets-adoptados/mundo/personajes-cabbit-24x32/` |
| 4.2 | https://kenney.nl/assets/ui-pack-rpg-expansion | CC0. Widgets de UI extra si Lamoot + Fantasy UI Borders no alcanzan. | `vendor/assets-adoptados/ui-y-cartas/kenney-ui-pack-rpg-expansion/` |
| 4.3 | https://datagoblin.itch.io/monogram | Fuente bitmap CC0. Solo si el HUD necesita números pixel — Alegreya y Cinzel ya cubren el texto. | `vendor/assets-adoptados/ui-y-cartas/fuente-monogram/` |

---

## Qué NO bajar (decidido, no re-barrer)

- **Golden UI** (Buch, CC-BY-**SA**): metería copyleft en la UI. Plan B pixel, descartado.
- **Flare Portraits, LPC, "The Last Encounter"**: CC-BY-SA / GPL — copyleft sobre los derivados.
- **CaptainSkolot 32 Magic Books**: licencia contradictoria + choca con la cláusula anti-AI de
  Devour, Noraneko y Super Retro World (`scouting-assets-nc.md` §5.2).
- **Elegant GUI kit (Tenshi Yoru) y Devour (emotarts)**: estrictamente NC y sin tier comercial.
  La decisión de `direccion-de-arte.md` es mantener la **UI core en nivel A** (Lamoot +
  game-icons + Fantasy UI Borders) porque la UI es lo más caro de reemplazar.
- **Pixel Cards (Nikoichu)**: NC sin salida y solo servía de prototipo.
- **Cualquier cosa "free for personal use"**, sin licencia explícita, o **NoDerivatives**
  (`docs/LICENCIAS.md`, política de assets).

---

## Resumen

| Bloque | Packs | Nivel | ¿Bloqueante? |
|--------|-------|-------|--------------|
| 0 — reintentos de SFX | 6 | A (CC0) | Sí para el feel; todo automatizable |
| 1 — mundo incompleto | 2 | A (CC0) | **Sí — 1.1 es lo más urgente** |
| 2 — audio (sello + música) | 8 | A (CC0/CC-BY) | Parcial: 2.1–2.3 para la firma sonora |
| 3 — nivel B `[NC]` | 8 | B `[NC]` | No — agenda por fase (F2/F3/F5) |
| 4 — opcionales | 3 | A | No |
| **Total pendiente** | **27** | | |

**Manual con navegador (no automatizable):** todo el Bloque 1, todo el Bloque 3 salvo 3.4,
el 4.1 y 4.3 según fuente, y Freesound (2.2–2.3).
**Automatizable (OGA / kenney.nl / sitios de artista):** Bloque 0 completo, 2.4–2.8, 3.4, 4.2.
