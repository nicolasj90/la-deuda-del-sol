# Scouting de assets — La Deuda del Sol

Fecha: 2026-07-29. Cuatro scouts (tilesets, personajes/retratos, UI/cartas/fuentes, música/SFX).
Todas las licencias fueron **verificadas en la página real de cada asset** en esa fecha; al adoptar,
re-verificar en la página antes de descargar (las licencias de itch pueden cambiar).

Regla dura vigente: solo CC0 / CC-BY / CC-BY-SA / OFL con licencia explícita en la página.
Nada de "royalty free", EULAs propios ni licencias implícitas en comentarios.

---

## 1. Recomendación principal por categoría

**Decisión de coherencia global:** mundo pixel a **16 px/tile** con re-grade cálido global
(dorados, lacre, atardecer) + **UI pintada de alta resolución** por encima (el modelo FF9:
mundo low-res, interfaz y retratos prerenderizados cálidos). Los retratos pintados viven en la
caja de diálogo, no compiten en densidad con los sprites.

### Tilesets y props de mundo (16 px/tile)
| Rol | Asset | Licencia |
|---|---|---|
| Base general: exteriores, interiores (taberna/notaría), templos, cuevas, VFX | **Ninja Adventure** (pixel-boy) | CC0 |
| Pueblo + mazmorra con estilo idéntico (transición Valdepalabra→Empeñadero) | **Kenney Tiny Town + Tiny Dungeon** | CC0 |
| Props de interior: estanterías, escritorios, papeles (notaría, archivo) | **16x16 Game Assets** (George Bailey) | CC-BY 4.0 |
| Mecánica de dungeon: palancas, trampas, antorchas, autotiles Godot | **16x16 DungeonTileset II** (0x72), con re-grade a lacre | CC0 |
| Cantera de cultivos (proxy de viñedo) y relleno de campiña/puerto | **Kenney Roguelike/RPG Pack** | CC0 |

Del pack Ninja Adventure se **cura** el contenido: se usa la gramática (interiores, cuevas,
VFX, espíritus) y se evita lo de sabor japonés explícito (torii, pagodas, ninjas).

### Personajes, enemigos y retratos
| Rol | Asset | Licencia |
|---|---|---|
| Party + NPCs de pueblo (aristócratas, townfolk) con cara a juego, 24x32 sobre tile 16 | **24x32 characters with faces** (Cabbit) | **OGA-BY 3.0** (elegida de la doble oferta) |
| Monstruos, 9 jefes, espíritus (base de los quebrantos) | **Ninja Adventure** | CC0 |
| Retratos pintados para busts de diálogo (vara de estilo + placeholder del party) | **Joseph Hewitt's Fantasy RPG Portrait Set 1** | CC-BY 4.0 |

### UI, cartas y fuentes (carril pintado, alta resolución)
| Rol | Asset | Licencia |
|---|---|---|
| Paneles papel/pergamino (base reskineable vía XCF a lacre/dorado) | **RPG GUI Construction Kit v1.0** (Lamoot) | CC-BY 3.0 |
| Iconos de ítems, skills y keywords de cartas (wax-seal, quill-ink, scrolls; SVG recoloreable) | **game-icons.net** | CC-BY 3.0 (por autor) |
| Marcos de carta re-renderizables (.blend incluido; skin propio papel+lacre+filete dorado) | **TCG Templates** (KillGorack) | CC0 |
| Tablero de duelo, dorsos, fichas/gemas de coste | **Kenney Boardgame Pack** | CC0 |
| Marcos ornamentados rápidos (9-slice) para diálogo | **Kenney Fantasy UI Borders** | CC0 |
| Fuente de diálogo y texto largo (español completo garantizado) | **Alegreya** (Huerta Tipográfica) | OFL 1.1 |
| Títulos, logo, nombres de carta (caps romanas) | **Cinzel** | OFL 1.1 |

Se **evita Golden UI (Buch, CC-BY-SA)** para no sumar copyleft en la UI; queda como plan B pixel.

### Música
| Rol | Asset | Licencia |
|---|---|---|
| Taberna e interiores (laúd) | **RandomMind — serie Medieval** (OGA) | CC0 |
| Batalla estándar | **cynicmusic — Battle Theme A** | CC0 |
| Campiña, pueblo, viaje (tono FF9) | **PeriTune** — solo pistas publicadas **antes de 2026-03** | CC-BY 4.0 |
| Duelos de cartas + El Fiado (clavecín/barroco: Angevin, Master of the Feast, etc.) | **Kevin MacLeod** (incompetech) | CC-BY 4.0 |
| Tema emotivo (la deuda de Ciro) | **Scott Buckley** | CC-BY 4.0 |
| Pantalla de título (opcional) | **Matthew Pablo — Soliloquy** | CC-BY 3.0 |

Nota: de Matthew Pablo, verificar pista por pista; "The Last Encounter" es CC-BY-**SA** — usar
solo si se acepta SA sobre el audio; no está en el conjunto recomendado.

### SFX — 100% CC0
| Rol | Asset |
|---|---|
| Cartas sobre mesa, fichas (duelos) + clicks de UI | **Kenney Casino Audio + Interface Sounds** |
| Espadas, hechizos, monedas, páginas, **cadenas** (Empeñadero) | **rubberduck — 80 CC0 RPG SFX** |
| Combate, inventario, tela/botellas/metal (textura mercader-prestamista) | **artisticdude — RPG Sound Pack** |
| Papel: arrugar, rasgar, mapas (pagarés) | **Luckius — Various Paper Sound Effects** |
| Pasar páginas (menú libro de cuentas) | **Voltiment555 — Book Flip Sounds** |
| Campanada real de iglesia (la prenda de Ciro: pitch -3 a -7 st + reverb) | **BigSoundBank — Church Bell (Joseph Sardin)** |

---

## 2. Tabla completa de candidatos

### Tilesets y props (Scout 1)
| # | Asset | Autor | Licencia | URL | Score |
|---|---|---|---|---|---|
| 1 | Ninja Adventure Asset Pack | pixel-boy (+AAA) | CC0 | https://pixel-boy.itch.io/ninja-adventure-asset-pack | 8.5 |
| 2 | Kenney Roguelike/RPG Pack | Kenney | CC0 | https://kenney.nl/assets/roguelike-rpg-pack | 8 |
| 3 | Kenney Tiny Town + Tiny Dungeon | Kenney | CC0 | https://kenney.nl/assets/tiny-town · https://kenney.nl/assets/tiny-dungeon | 8 |
| 4 | Zelda-like tilesets and sprites | ArMM1998 | CC0 | https://opengameart.org/content/zelda-like-tilesets-and-sprites | 7.5 |
| 5 | 16x16 Game Assets | George Bailey (George_) | CC-BY 4.0 | https://opengameart.org/content/16x16-game-assets | 7.5 |
| 6 | Tiny 16: Basic | Lanea Zimmerman (Sharm) | CC-BY 4.0 / CC-BY 3.0 / OGA-BY 3.0 | https://opengameart.org/content/tiny-16-basic | 7 |
| 7 | Zoria Tileset | DragonDePlatino | CC-BY 4.0 | https://opengameart.org/content/zoria-tileset | 7 |
| 8 | Paquete LPC (Base + Farming + Crops) | Zimmerman, Eddeland, bluecarrot16 et al. | CC-BY-SA 3.0 / GPL 3.0 (copyleft) | https://opengameart.org/content/liberated-pixel-cup-lpc-base-assets-sprites-map-tiles · https://opengameart.org/content/lpc-farming-tilesets-magic-animations-and-ui-elements · https://opengameart.org/content/lpc-crops | 7 |
| 9 | 16x16 DungeonTileset II | 0x72 | CC0 | https://0x72.itch.io/dungeontileset-ii | 6.5 |
| 10 | Pixel Art Top Down – Basic | Cainos | Propia permisiva (no CC, no redistribuir en crudo) | https://cainos.itch.io/pixel-art-top-down-basic | 6 |

Rechazados: Time Fantasy freebies (sin licencia formal), Serene Village / Mystic Woods /
Sprout Lands (EULAs propios de itch, fuera de regla).

### Personajes, enemigos y retratos (Scout 2)
| # | Asset | Autor | Licencia | URL | Score |
|---|---|---|---|---|---|
| 1 | Fantasy RPG Portrait Set 1 | Joseph Hewitt | CC-BY 4.0 | https://opengameart.org/content/joseph-hewitts-fantasy-rpg-portrait-set-1 | 9 |
| 2 | 24x32 characters with faces (big pack) | Svetlana Kushnariova (Cabbit) | CC-BY 3.0 / OGA-BY 3.0 | https://opengameart.org/content/24x32-characters-with-faces-big-pack | 9 |
| 3 | Universal LPC Spritesheet Generator | comunidad LPC | por asset: CC0…CC-BY-SA/GPL | https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator | 8.5 |
| 4 | Ninja Adventure Asset Pack | Pixel-Boy y AAA | CC0 | https://pixel-boy.itch.io/ninja-adventure-asset-pack | 8 |
| 5 | Flare Portrait Packs (1, 4, 5, Female) | Justin Nichol | CC-BY-SA 3.0 / GPL (copyleft) | https://opengameart.org/content/flare-portrait-pack-number-one | 7.5 |
| 6 | [LPC] Wolf Animation | Redshrike + William.Thompsonj | CC-BY 3.0/4.0 u OGA-BY 3.0 | https://opengameart.org/content/lpc-wolf-animation | 7 |
| 7 | Fantasy Portrait Pack | Ravenmore | CC-BY 3.0 | https://opengameart.org/content/fantasy-portrait-pack-by-ravenmore | 6.5 |
| 8 | RPG portraits (pixel 32x32) | Buch | CC0 | https://opengameart.org/content/rpg-portraits | 5.5 |

Rechazados: PixelArt Bandits de lyssir (sin licencia explícita), NPC Fantasy Inn Portraits
(no verificable, pinta AI-gen).

### UI, cartas y fuentes (Scout 3)
| # | Asset | Autor | Licencia | URL | Score |
|---|---|---|---|---|---|
| 1 | game-icons.net (~4000 SVG) | Lorc, Delapouite, Skoll et al. | CC-BY 3.0 | https://game-icons.net | 10 |
| 2 | Alegreya (+SC +Sans) | Huerta Tipográfica | OFL 1.1 | https://github.com/huertatipografica/Alegreya | 9.5 |
| 3 | RPG GUI Construction Kit v1.0 | Matjaž Lamut (Lamoot) | CC-BY 3.0 | https://opengameart.org/content/rpg-gui-construction-kit-v10 | 9 |
| 4 | Cinzel | Natanael Gama | OFL 1.1 | https://github.com/NDISCOVER/Cinzel | 8 |
| 5 | Golden UI — Bigger Than Ever | Buch | CC-BY-SA 3.0 (copyleft) | https://opengameart.org/content/golden-ui-bigger-than-ever-edition | 7.5 |
| 6 | TCG Templates | KillGorack | CC0 | https://opengameart.org/content/tcg-templates | 7.5 |
| 7 | Kenney UI Pack (RPG expansion) | Kenney | CC0 | https://kenney.nl/assets/ui-pack-rpg-expansion | 7.5 |
| 8 | Kenney Fantasy UI Borders | Kenney | CC0 | https://kenney.nl/assets/fantasy-ui-borders | 7 |
| 9 | Kenney Boardgame Pack | Kenney | CC0 | https://kenney.nl/assets/boardgame-pack | 7 |
| 10 | monogram (fuente bitmap) | datagoblin | CC0 | https://datagoblin.itch.io/monogram | 6.5 |
| — | Card Bases for TCG | Bananacup | CC0 | https://opengameart.org/content/card-bases-for-tcg-collectibles-etc | 6 |

Rechazados: Pixel Cards FREE (NC), Card Frames de markusdarius (sin licencia formal),
Pixel Art GUI Elements de Tohami (404/no verificable), VisuStella y scrolls "vintage" de itch.

### Música y SFX (Scout 4)
| # | Asset | Autor | Licencia | URL | Score |
|---|---|---|---|---|---|
| 1 | Catálogo incompetech | Kevin MacLeod | CC-BY 4.0 | https://incompetech.com/music/royalty-free/ | 9 |
| 2 | PeriTune | Sakuya | CC-BY 4.0 (solo pre-2026-03; después licencia propia) | https://peritune.com/ | 8.5 |
| 3 | Scott Buckley | Scott Buckley | CC-BY 4.0 | https://www.scottbuckley.com.au/library/ | 8 |
| 4 | Soliloquy / The Last Encounter | Matthew Pablo | CC-BY 3.0 / CC-BY-SA 3.0 (por pista) | https://opengameart.org/content/soliloquy · https://opengameart.org/content/rpg-battle-theme-the-last-encounter-0 | 8 |
| 5 | Serie "Medieval" (Bard's Tale etc.) | RandomMind | CC0 | https://opengameart.org/content/medieval-the-bards-tale | 8 |
| 6 | Battle Theme A | cynicmusic | CC0 | https://opengameart.org/content/battle-theme-a | 7 |
| 7 | Casino Audio + Interface Sounds | Kenney | CC0 | https://kenney.nl/assets/casino-audio · https://kenney.nl/assets/interface-sounds | 9 |
| 8 | 80 CC0 RPG SFX | rubberduck | CC0 | https://opengameart.org/content/80-cc0-rpg-sfx | 8.5 |
| 9 | RPG Sound Pack | artisticdude | CC0 | https://opengameart.org/content/rpg-sound-pack | 8.5 |
| 10 | Papel y campana (Luckius + Voltiment555 + BigSoundBank) | varios | CC0 | https://opengameart.org/content/various-paper-sound-effects · https://opengameart.org/content/book-flip-sounds · https://bigsoundbank.com/church-bell-s0135.html | 8 |
| — | Fantasy Sound Effects Library | Little Robot Sound Factory | CC-BY 3.0 | https://opengameart.org/content/fantasy-sound-effects-library | 7.5 |

Descartados: Alexander Nakarada (ya no es CC), Pixabay/Zapsplat/ElevenLabs/Sample Focus
(licencias propias), Freesound (solo pista por pista con CC0 verificada).

---

## 3. Obligaciones de atribución del conjunto recomendado

Lista lista-para-pegar en `CREDITS.md` (o el sistema de créditos de Threadbare).
Completar `[Título]` con las pistas concretas al adoptarlas.

```markdown
## Arte
- "16x16 Game Assets" by George Bailey — https://opengameart.org/content/16x16-game-assets — CC-BY 4.0
- "24x32 characters with faces (big pack)" by Svetlana Kushnariova (Cabbit) — https://opengameart.org/content/24x32-characters-with-faces-big-pack — OGA-BY 3.0
- "Joseph Hewitt's Fantasy RPG Portrait Set 1" by Joseph Hewitt — https://opengameart.org/content/joseph-hewitts-fantasy-rpg-portrait-set-1 — CC-BY 4.0

## UI e iconos
- "RPG GUI Construction Kit v1.0" by Lamoot (Matjaž Lamut) — https://opengameart.org/content/rpg-gui-construction-kit-v10 — CC-BY 3.0
- Icons made by Lorc, Delapouite and contributors. Available on https://game-icons.net — CC-BY 3.0
  (ajustar la lista de autores a los iconos realmente usados)

## Fuentes (OFL 1.1 — conservar el archivo de licencia junto a cada fuente)
- Alegreya, by Juan Pablo del Peral / Huerta Tipográfica — https://github.com/huertatipografica/Alegreya — SIL OFL 1.1
- Cinzel, by Natanael Gama — https://github.com/NDISCOVER/Cinzel — SIL OFL 1.1

## Música
- "[Título]" Kevin MacLeod (incompetech.com)
  Licensed under Creative Commons: By Attribution 4.0 License
  http://creativecommons.org/licenses/by/4.0/
  (este texto es el formato exigido por incompetech; una entrada por pista)
- Music: "[Título]" by PeriTune — https://peritune.com — CC-BY 4.0 (pistas publicadas antes de 2026-03)
- Music: "[Título]" by Scott Buckley — https://www.scottbuckley.com.au — CC-BY 4.0
- "Soliloquy" by Matthew Pablo — https://www.matthewpablo.com — CC-BY 3.0 (si se adopta)

## CC0 (sin obligación legal; cortesía)
- Ninja Adventure Asset Pack — Pixel-Boy & AAA
- Tiny Town, Tiny Dungeon, Roguelike/RPG Pack, Boardgame Pack, Fantasy UI Borders,
  Casino Audio, Interface Sounds — Kenney (kenney.nl)
- 16x16 DungeonTileset II — 0x72
- TCG Templates — KillGorack
- Serie "Medieval" — RandomMind; Battle Theme A — cynicmusic (pixelsphere.org)
- 80 CC0 RPG SFX — rubberduck; RPG Sound Pack — artisticdude
- Various Paper Sound Effects — Luckius; Book Flip Sounds — Voltiment555
- Church Bell — Joseph Sardin (bigsoundbank.com)
```

Reglas operativas:
- **OGA-BY 3.0 (Cabbit):** atribución igual que CC-BY pero sin la cláusula de medidas
  tecnológicas; citar autor + link a la página OGA.
- **CC-BY:** no sugerir endorsement; indicar si hubo modificaciones (habrá: re-grade).
  Anotar "modified (color grading)" donde aplique.
- **OFL:** no vender las fuentes por separado; conservar `OFL.txt` en el repo junto al TTF.
- La base **Threadbare es CC-BY-SA**: los créditos existentes de Threadbare se mantienen
  mientras quede código/arte suyo; el conjunto recomendado no agrega ningún SA nuevo.
- Ningún asset del conjunto recomendado exige más que esto. Si se suma Golden UI, Flare
  Portraits, LPC o "The Last Encounter", entra **copyleft (SA)** sobre los derivados: decisión
  consciente, no por accidente.

---

## 4. Huecos sin buen candidato libre + plan B

1. **Retratos del party (5 protagonistas) con identidad propia.** Hewitt da 26 retratos
   genéricos pintados: sirve de vara de estilo y de placeholder, pero Ciro y compañía no
   están ahí. Plan B: **encargar/pintar 5 busts propios** (600x900, pintura tradicional
   cálida, usando Hewitt como referencia de factura); mientras tanto, castear 5 retratos de
   Hewitt como stand-ins y marcarlos `PLACEHOLDER` en el manifest.

2. **Quebrantos de papel/bruma (enemigos temáticos).** No existe pack literal. Plan B:
   **derivados propios sobre los espíritus CC0 de Ninja Adventure**: recolor pálido
   (papel viejo/sepia), overlay de textura de papel y shader de bruma en Godot; CC0 permite
   derivar sin restricción. Jefes-quebranto: sprites propios sobre esa misma base.

3. **Viñedos a 16 px.** No hay tile de vid dedicado. Plan B: proxy con los cultivos en
   hilera del Kenney Roguelike/RPG Pack + **dibujar 4-6 tiles propios de vid/parral**
   (tarea chica de pixel art, mismo grid de 16).

4. **SFX de sello de lacre.** No existe libre y dedicado. Plan B: **fabricarlo por capas**:
   arrugado de papel (Luckius) + impacto sordo (Kenney) + campana de BigSoundBank
   pitcheada -3/-7 semitonos con reverb. Es además la firma sonora del juego: vale hacerlo
   bien una vez y reutilizarlo en UI de pagarés, duelos y guardado.

5. **Música mediterránea/española (guitarra) y leitmotif de la deuda.** El catálogo libre
   no tiene guitarra española decente ni, obviamente, un leitmotif propio. Plan B: MacLeod
   (tags Renaissance/harpsichord) como aproximación cortesana; para el leitmotif,
   **componer o encargar un tema corto propio** con 2-3 variaciones (título, duelo, prenda
   de Ciro); Buckley cubre el registro emotivo mientras tanto.

6. **Match estético FF9 directo.** Solo existe pago (Time Fantasy, World of Solaria; EULAs
   propios, fuera de la regla dura). Anotado como **compra futura opcional** si algún día
   hay presupuesto; no bloquea: el combo 16 px + re-grade cálido + UI pintada aproxima la
   sensación.

---

## 5. Reemplazos de placeholders Threadbare actuales

| Placeholder actual (repo) | Lo reemplaza | Nota |
|---|---|---|
| `assets/third_party/tiny-swords/` y `tiny-swords-non-cc0/` | Cabbit (party/NPCs) + Ninja Adventure (enemigos/jefes) | Al eliminar `tiny-swords-non-cc0` se limpia la única mancha de licencia del repo |
| `assets/first_party/tiles/`, `rocks/`, `towers/`, `wildlife/` (arte Threadbare) | Ninja Adventure + Tiny Town/Tiny Dungeon + George_ + 0x72 | Migrar TileMaps escena por escena; el grid ya es compatible (16 px) |
| `assets/first_party/user_interface/` | RPG GUI Construction Kit (paneles) + game-icons.net (iconos) + Kenney Fantasy UI Borders | Reskin XCF hacia lacre/dorado antes de integrar |
| `assets/third_party/fonts/jersey/` | Alegreya (diálogo) + Cinzel (títulos/cartas) | jersey puede quedar solo para números pixel del HUD, o migrar a monogram (CC0) |
| Visuales del `addons/card-framework` | TCG Templates (marcos) + Kenney Boardgame Pack (tablero/dorsos/fichas) | El addon aporta la lógica; el skin es nuestro |
| `assets/first_party/music/` + `assets/third_party/sounds/` (ambient, eternal_loom, etc.) | Paleta sonora nueva: RandomMind + cynicmusic + PeriTune + MacLeod + Buckley; SFX Kenney/rubberduck/artisticdude/papel | Reemplazo por escena a medida que se re-ambienta |
| `assets/third_party/nepalese_hand_bells/` | Church Bell (BigSoundBank) pitcheada | Es la campana de la prenda de Ciro |
| `assets/third_party/sewing-machine/`, `assets/first_party/collectibles/`, `intro/`, `logo/` | Sin reemplazo directo: assets propios (logo con Cinzel; colectables con game-icons recoloreados) | El logo es primera identidad visible: prioridad temprana |
| `assets/third_party/kenney_input_prompts/` | **Se queda** | CC0, correcto y estándar |
| `assets/third_party/endless/` | Revisar en fase de adopción | Decidir si la escena que lo usa sobrevive |

---

## Próxima fase (adopción)

1. Descargar el conjunto recomendado, verificando cada licencia en página al bajar.
2. Colocar bajo `assets/third_party/<pack>/` con `.license` por archivo (convención REUSE
   del repo) y actualizar `LICENCIAS.md` + CREDITS con la lista de la sección 3.
3. Prueba de convivencia: una escena de Valdepalabra con Tiny Town + Ninja Adventure +
   props George_ + un NPC Cabbit + panel Lamoot, todo con el mismo re-grade, antes de
   comprometer el resto.
