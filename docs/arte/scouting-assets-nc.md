# Scouting de assets — Nivel B [NC] (NonCommercial permitido)

> Consolidado del director de arte sobre 4 barridos (tilesets, personajes/battlers/retratos, UI/cartas/gemas, música/SFX).
> Contexto legal: el juego es **gratuito**, por lo que las licencias NC son válidas. Ver §5 antes de cualquier decisión de comercialización.
> Este archivo es del **nivel B**. El nivel A (libre) vive en `scouting-assets.md` y lo escribe otra corrida.

Hallazgo estructural confirmado por 3 barridos: **OpenGameArt no acepta licencias NC** (solo free-culture). Todo el nivel B vive en itch.io, tiendas propias de artistas y la escena RPG Maker/Ren'Py.

---

## 1. Decisión de dirección: stack "pintado 48 px / HD"

Los barridos dejaron dos familias internamente coherentes y **mutuamente excluyentes** como base del mundo:

- **Stack A — Pintado (ELEGIDO):** Kokoro Reflections 48 px (mundo) + Ækashics (battlers pintados HD) + Sutemo/NoranekoGames (retratos HD) + Elegant GUI kit / Devour (UI HD) + LunaLucid (viales/gemas HD).
- **Stack B — Pixel SNES 16 px (alternativa documentada):** Time Fantasy + Super Retro World (mundo/personajes) + Holder's (battlers animados 64 px) + Nikoichu (cartas 27×38).

**Motivo:** el brief es FF9 — campiña dorada con viñedos, tejados cálidos, catedral. KR Tuscan + Church ES ese brief de forma literal, en estilo pintado (el registro FF9, no SNES). Además el stack A resuelve de una sola vez los dos huecos prioritarios del nivel libre (retratos y battlers) en la misma densidad visual. **Regla dura: no mezclar densidades** — nada de 16 px sobre mundo 48 px pintado.

## 2. Recomendación principal por categoría

| Categoría | Titular | Suplente/acento |
|---|---|---|
| Mundo exterior (campiña/viñedos) | **KR FREE Tuscan Tiles** (9/10) | KR Farm, KR Fantasy |
| Catedral/iglesia | **KR FREE Church and Cathedral** (8.5/10) | KR Glass City (acentos dorados/vitrales) |
| Interiores (taberna, notaría, mansión) | **KR Mansion + resto freebies KR** (8/10) | — |
| Puerto / dungeon | KR Ocean (costa) + KR Crystal Dungeon | ⚠ hueco parcial, ver §6 |
| **Retratos (prioridad #1)** | **Sutemo busts PSD por capas** (8/10) — 10 expresiones, outfits, peinados combinables | NoranekoGames Nika/Nora para protagonistas (7.5/10) |
| **Battlers (prioridad #2)** | **Ækashics Librarium Static Megapack** (9/10) — 874 estáticos + 72 animados + busts de monstruos | Tyler Warren Favorites 30 (7/10) |
| Battlers animados de héroes | Holder's (8/10) — **solo si se adopta stack B**; en stack A clash de estilo | — |
| UI/menús | **Elegant GUI kit — Tenshi Yoru** (7/10) | Devour — emotarts (paleta dorada, doilies → lacre) |
| Cartas del duelo | **TornioDuva card template** (marcos manuscrito/papel envejecido) | Nikoichu solo para prototipo funcional |
| Gemas/coste de energía | **LunaLucid Magical Template** — 8 viales animados | CC0 del nivel A |
| BGM | **H/MIX GALLERY** (9/10, idioma JRPG japonés nativo) + **David Vitas RPG Music Pack** (9/10, set base completo CC BY) | Vindsvept (folk campiña), Steven O'Brien (solemne), Aaron Krogh + Fesliyan (relleno) |
| SFX | **Freesound por-sonido**: Wax seal (CC0), sello sobre papel (CC BY) | filtrar licencia sonido por sonido |

## 3. Tabla completa de candidatos

Todos provienen del barrido NC y quedan etiquetados **[NC]** (nivel del barrido). La columna "¿Comercial?" indica si la licencia sobreviviría a una eventual comercialización del juego.

### Tilesets y mundo

| # | Pack — Autor | Licencia (textual, verificada) | URL | Score | ¿Comercial? |
|---|---|---|---|---|---|
| [NC] | KR FREE Tuscan Tiles — Kokoro Reflections | "You may use our resources for commercial or noncommercial games" + "For free tiles: please give credit to Kokoro Reflections (kokororeflections.com)" + "They must be included in a game" (no repostear sueltos); "You're welcome to use it with any engine" | https://kokororeflections-shop.fourthwall.com/collections/freebies | 9 | Sí |
| [NC] | KR FREE Church and Cathedral — Kokoro Reflections | Idéntica (kokororeflections.com/terms-use/) | misma colección | 8.5 | Sí |
| [NC] | KR freebies restantes (Ocean, Farm, Mansion, Fairy Tale, Crystal Dungeon, Fantasy) | Idéntica | https://kokororeflections-shop.fourthwall.com/collections/freebies | 8 | Sí |
| [NC] | Super Retro World Free Interior Pack — Gif | "use the assets for non-commercial projects", "use the assets for commercial projects", "modify the assets"; no redistribuir sueltos, no NFT/IA | https://gif-superretroworld.itch.io/interior-pack | 7.5 | Sí |
| [NC] | Dark Dimension Tileset — finalbossblues | "free with no strings attached… using them in commercial projects is fine… No credit necessary", sin redistribución directa | https://finalbossblues.itch.io/dark-dimension-tileset | 7.5 | Sí |
| [NC] | Beach Tileset — finalbossblues | Cubierta por licencia del sitio (finalbossblues.com/timefantasy/free-graphics/); **verificar terms.txt del ZIP** | https://finalbossblues.itch.io/tf-beach-tileset | 7 | Sí (verificar) |
| [NC] | Ashlands Tileset — finalbossblues | Misma de la serie (autor confirma comercial, sin crédito) | https://finalbossblues.itch.io/ashlands-tileset | 7 | Sí |
| [NC] | KR FREE Glass City — Kokoro Reflections | "You may use it in any of the ways set down in our Terms of Use" | https://kokororeflections.itch.io/kr-free-glass-city-tileset-for-rpgs | 7 | Sí |
| [NC] | Cloud City Tileset — finalbossblues | Misma de la serie | https://finalbossblues.itch.io/cloud-city-tileset | 6 | Sí |
| [NC] | Mystic Woods free — Game Endeavor | "You can only use these assets in non-commercial projects. You can modify the assets. You can not redistribute or resale, even if modified." (versión gratis con filtro de ruido) | https://game-endeavor.itch.io/mystic-woods | 5 | **No** |

### Personajes, battlers, retratos

| # | Pack — Autor | Licencia (textual, verificada) | URL | Score | ¿Comercial? |
|---|---|---|---|---|---|
| [NC] | Ækashics Librarium Static Batch Megapack | "Free for commercial use" y NC; cualquier motor ("love2d, Godot, Unreal, Unity"); crédito OBLIGATORIO a Ækashics + link a akashics.moe; ediciones solo dentro del proyecto; no redistribuir sueltos | https://aekashics.itch.io/aekashics-librarium-librarium-static-batch-megapack | 9 | Sí |
| [NC] | Time Fantasy Freebies — FinalBossBlues | "Most of the graphics on this site are free with no strings attached… commercial projects is fine. No credit necessary." + "Some graphics are for non-commercial use only. It will be noted on the post" → **revisar nota post por post** | https://finalbossblues.com/timefantasy/free-graphics/ | 8.5 | Sí, salvo posts marcados NC |
| [NC] | Holder's Animated Battlers | "Free to use in any engine", comercial y NC, derivados permitidos; crédito obligatorio (links a holder-anibat.itch.io y animatedbattlers.wordpress.com); no compilar en packs, no NFT | https://holder-anibat.itch.io/holders-animated-battlers-free-heroes | 8 | Sí |
| [NC] | Sutemo Female/Male Character busts | "This sprite can be used in personal or commercial projects. however you can't resell the sprite on its own." Crédito no necesario (confirmado en comentarios) | https://sutemo.itch.io/female-character | 8 | Sí |
| [NC] | NoranekoGames Nika y Nora | "For games, yes! It must still follow the rule that it cannot be sold alone"; crédito OBLIGATORIO; no AI/NFT/merch | https://noranekogames.itch.io/nika · /nora | 7.5 | Sí |
| [NC] | Tyler Warren Favorites 30 | "Unlimited Commercial Use License… royalty free and usable in any engine without limitations"; crédito opcional | https://tylerjwarren.itch.io/free-tyler-warren-rpg-battlers-favorites-30 | 7 | Sí |

### UI, cartas, gemas

| # | Pack — Autor | Licencia (textual, verificada) | URL | Score | ¿Comercial? |
|---|---|---|---|---|---|
| [NC] | Elegant GUI kit — Chiara (Tenshi Yoru) | CC BY-NC 4.0 + "This kit CAN ONLY be used for free, non-commercial projects"; crédito a "Tenshi Yoru" o "Chiara Colucci" | https://tenshi-yoru.itch.io/elegant-gui-kit | 7 | **No** |
| [NC] | 32 Magic Books — CaptainSkolot | CC BY-NC-SA 4.0 (metadata) pero el texto dice "free and commercial use permitted" — **contradicción interna**; AI-assisted | https://captainskolot.itch.io/magic-books-pixelart-pixel-art-sprite-grimoire-pack-for-rpg-fantasy | 7 | **No** (ambigua) |
| [NC] | Pixel Cards FREE — Nikoichu | CC BY-NC-SA 4.0: "You cannot use them for commercial purposes, like in a game that you earn money from by selling, including ads or in-app purchases" | https://nikoichu.itch.io/pixel-cards-free | 6 | **No** |
| [NC] | Magical Template — LunaLucid | CC BY-NC 4.0 gratis; versión comercial US$16.99; piezas sueltas usables fuera de Ren'Py (confirmado por la autora) | https://lunalucid.itch.io/magical-template | 6 | **No** (upgrade pago disponible) |
| [NC] | Devour GUI pack — emotarts | CC BY-NC-SA 4.0, crédito requerido; "DO NOT use these assets on a project that uses / promotes AI" | https://emotarts.itch.io/devour | 5.5 | **No** |
| [NC] | Card Template — TornioDuva | CC BY-NC 4.0, NYOP; arte 100% original, sin AI | https://tornioduva.itch.io/tornioduva-card-template | 5 | **No** |
| [NC] | VN Japanese Anime Complete Pack — azureXtwilight | CC BY-NC 4.0 según filtro de itch — **no verificada en la página; confirmar antes de usar** | https://azurextwilight.itch.io/japanese-anime-complete-asset-pack | 4 | **No** (sin verificar) |

### Música y SFX

| # | Pack — Autor | Licencia (textual, verificada) | URL | Score | ¿Comercial? |
|---|---|---|---|---|---|
| [NC] | H/MIX GALLERY — Hirokazu Akiyama | Tier doujin/indie: gratis sin licencia para juegos no comerciales; "クレジット表記は利用の条件ではありません" (crédito no obligatorio, recomendado); edición permitida; no redistribuir como pack; comercial = Standard License ¥2.200/pista | https://www.hmix.net/ (terms: /terms.html) | 9 | **No** (upgrade ¥2.200/pista) |
| [NC] | RPG Music Pack — David Vitas | CC BY: "Royalty Free License... as long as you credit the original artist (CC-BY)" | https://www.davidvitas.com/rpg-music-pack/ | 9 | Sí |
| [NC] | Vindsvept | CC BY 4.0, "absolutely free to use, even for commercial use"; whitelist anti-Content-ID para gamedevs | https://vindsvept.se/licensing/ | 8.5 | Sí |
| [NC] | Aaron Krogh RPG Music & Loops | "free use, including commercial use... please include me in your projects' credits with my full name, Aaron Krogh"; "can be used for any kind of project" (no atado a RPG Maker) | https://forums.rpgmakerweb.com/threads/rpg-music-pack-free-commercial-use.926/ | 8 | Sí |
| [NC] | Free VGM Starter Pack — Nathan David McWilliams | "Royalty-free! Free for personal and commercial use", crédito obligatorio como "Nathan David McWilliams" | https://mysticflute.itch.io/free-music-pack | 8 | Sí |
| [NC] | Freesound (por sonido) | "Wax seal" (Cerise_Virtuelle, #759526): CC0. "Office self inking stamp on paper" (sengjinn, #178650): CC BY 4.0. Verificar licencia en cada página de sonido | https://freesound.org/ | 8.5 | Según sonido |
| [NC] | Steven O'Brien | CC Attribution + Music License Agreement: uso en videojuego con crédito en créditos finales, comercial incluido; USD 30/pista para sacar atribución; sin Content ID | https://www.steven-obrien.net/ | 7.5 | Sí |
| [NC] | FesliyanStudios | "Video game use is permitted"; gratis en uso no comercial con crédito "Credit to https://www.FesliyanStudios.com for the background music"; comercial requiere donación; no Content ID ni redistribuir | https://www.fesliyanstudios.com/policy | 7 | **No** (donación) |

### Rechazados consolidados (no re-barrer)

- **EULA atada a RPG Maker:** Celianna, PandaMaru, Avery, whtdragon, Kauzz, Starmage busts, todo lo del RTP/tienda oficial RPG Maker.
- **Pagos sin versión NC gratis:** Winlu Fantasy Tileset, Gems and Wood Fantasy GUI, Wenrexa Skill Icons #2, Gothic VN GUI.
- **Sin licencia verificable:** Nyteon portraits (además AI), Adrian von Ziegler, Celestial Aeon Project, ZapSplat (403), Kai Engel (se retiró de CC 2025-07-01).
- **ND o fit malo:** Tabletop Audio (BY-NC-ND), Sprout Lands (chibi-pastel), Disco Framework (paleta fría), LimeZu Serene Village (es CC-BY → nivel A).

## 4. Obligaciones de atribución del conjunto recomendado (para CREDITS)

Crédito **obligatorio**:

```
ARTE
- Tilesets del mundo: Kokoro Reflections (kokororeflections.com)
- Battlers de enemigos: Ækashics — akashics.moe
- Retratos base: NoranekoGames (noranekogames.itch.io) [si se usan Nika/Nora]

UI
- GUI kit: Tenshi Yoru (Chiara Colucci) — tenshi-yoru.itch.io/elegant-gui-kit
- Elementos de UI: emotarts — emotarts.itch.io/devour (CC BY-NC-SA 4.0) [si se usa Devour]
- Marcos de carta: TornioDuva — tornioduva.itch.io (CC BY-NC 4.0)
- Viales/gemas: LunaLucid — lunalucid.itch.io/magical-template (CC BY-NC 4.0)

MÚSICA
- "Track" by David Vitas — davidvitas.com (CC BY)
- "Track" by Vindsvept — released under CC-BY 4.0
- Aaron Krogh [nombre completo, obligatorio]
- Nathan David McWilliams [nombre exacto, obligatorio]
- Music by https://www.steven-obrien.net/ — "Track" — Steven O'Brien

SFX
- "Office self inking stamp on paper" by sengjinn (freesound.org) — CC BY 4.0
```

Crédito **no obligatorio pero recomendado** (cortesía): H/MIX GALLERY (Hirokazu Akiyama), Sutemo, finalbossblues/Time Fantasy, Tyler Warren, Cerise_Virtuelle (CC0).

Regla transversal de todo el conjunto: **no redistribuir ningún asset suelto** (deben ir empaquetados dentro del build del juego) y **no usarlos en material NFT/AI**.

## 5. Advertencias

### 5.1 Si el juego se comercializa algún día (lista exacta de reemplazo/upgrade)

Estrictamente NC — habría que **reemplazar o licenciar** antes de cobrar un peso (incluye ads e IAP):

| Asset | Vía de salida |
|---|---|
| Elegant GUI kit (Tenshi Yoru) | Reemplazar (no ofrece tier comercial) |
| Devour (emotarts) | Reemplazar |
| Pixel Cards (Nikoichu) | Reemplazar (solo prototipo de todas formas) |
| Magical Template (LunaLucid) | **Upgrade US$16.99** (versión comercial oficial) |
| Card Template (TornioDuva) | Reemplazar o negociar con el autor |
| H/MIX GALLERY | **Standard License ¥2.200 por pista** — barato, prever lista de pistas usadas |
| FesliyanStudios | Donación al autor |
| Mystic Woods free | Reemplazar (o comprar versión paga sin filtro de ruido) |
| CaptainSkolot Magic Books | Reemplazar (licencia ambigua, ver 5.3) |
| Freesound BY-NC sueltos | Auditar sonido por sonido |

Todo lo demás del conjunto recomendado (KR, Ækashics, Sutemo, Noraneko, Time Fantasy, Holder, Tyler Warren, Vitas, Vindsvept, Krogh, McWilliams, O'Brien) **sobrevive la comercialización sin cambios**.

### 5.2 Conflicto de cláusulas AI — decisión tomada

Devour (emotarts) prohíbe usarse en proyectos que usen AI-assets; los grimorios de CaptainSkolot son AI-assisted. **Son mutuamente excluyentes en el mismo juego.** Decisión: entra **Devour**, queda **fuera CaptainSkolot** (suma la contradicción de licencia y la política anti-AI de varios otros packs del conjunto — Noraneko y SRW también prohíben AI).

### 5.3 Licencias ambiguas — confirmar con el autor antes de usar

1. **CaptainSkolot 32 Magic Books:** metadata CC BY-NC-SA vs texto "commercial use permitted". Excluido por 5.2; si se reconsidera, pedir aclaración escrita.
2. **azureXtwilight VN Pack:** licencia solo vista en el filtro de itch, no en la página. Confirmar antes de tocar.
3. **TF Beach Tileset:** la página no repite el texto de licencia de la serie — verificar `terms.txt` dentro del ZIP al descargar.
4. **Time Fantasy freebies en general:** algunos posts están marcados "non-commercial use only" — anotar el estado post por post al descargar cada uno.
5. **Sutemo:** crédito "no necesario" consta solo en comentarios — captura de pantalla al descargar, y acreditar igual por cortesía.

## 6. Huecos que este nivel NO cierra

- **Sprites top-down de personajes/NPCs en estilo pintado 48 px** compatible con KR: no existe gratis. Opciones: generador de sprites 48 px del nivel A, comisión, o degradar a stack B (16 px) todo el juego.
- **Retratos humanos en cantidad (20+ NPCs):** Sutemo da variantes por capas pero no 20 caras distintas. Vía: Sutemo + comisiones en el mismo estilo.
- **Puerto barroco chillón:** KR Ocean es costa genérica; los props barrocos habrá que editarlos/comisionarlos.
- **Dungeon de baldosas/sellos:** KR Crystal Dungeon es "cristal"; re-grade o edición.
- **Gemas de coste literales:** 0 resultados NC; los viales de LunaLucid son proxy. Cubrir con CC0 del nivel A.
- **Campana grave y foley de cartas:** resolvible dentro de Freesound filtrando licencia por sonido (pendiente de curaduría).
- **Tipografías:** fuera de alcance de los 4 barridos.
