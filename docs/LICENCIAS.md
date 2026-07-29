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

## Reglas operativas

1. `vendor/` nunca entra en un export preset.
2. Todo asset nuevo de terceros entra con su archivo `.license` al lado (patrón REUSE que
   ya usa Threadbare); los NC además se listan acá con `[NC]`.
3. Antes de la demo pública: `grep -r "SPDX" --include="*.gd"` para confirmar encabezados
   MPL intactos + auditoría de `assets/third_party/`.
