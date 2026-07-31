# Bitácora — 2026-07-30/31 — Cores verificados jugando + Lacrevieja pueblo real

## Combate y cartas asegurados (pedido explícito del usuario)

Verificados JUGÁNDOLOS con input real en navegador (playwright), no solo headless:
- **Combate**: fix crítico device_id de teclado en Godot 4.5+ (la batalla era
  injugable sin joystick — causa del primer reporte del usuario), menús completos
  con teclado y mouse, Objetos/Destrezas reales, boss E06 dos fases, derrota,
  señales de controllers desconectadas en teardown, click destraba "¡Aparecieron
  enemigos!", cartel fuera del camino.
- **Cartas**: mesa jugada con mouse de punta a punta (drag mano→Estrado, Promesa
  aceptada/rechazada, targeting con click derecho, cierre real del duelo) y el
  camino diegético E03 completo desde el diálogo de Rosaura. Harness permanente:
  `scenes/dev/duelo_dev.tscn` + sonda de mesa.

## Lacrevieja reconstruida como pueblo (juez visual: APROBADO)

Generador `tools/gen-mapa-lacrevieja.py` + TileSet propio desde Kenney (CC0, en
`assets/third_party/`): calles en cuadrícula, plaza empedrada con las 3 lámparas,
panadería con horno a la calle, notaría con placa de lacre, capilla, cementerio
cercado, viñedo, huerta, bordes de arboleda. **Colisiones honestas verificadas
con sondas** (84 chequeos headless + empujes de 2,5 s en navegador): ninguna casa
se atraviesa; cada puerta contesta ("Golpear" + nombre). Carteles solo con
sentido. Contenido F5a intacto (secuencia 85/85, smoke 173/173).

## Pendientes de pulido anotados por el juez (próxima vuelta)

1. La casa de Ciro es idéntica a las vecinas — darle identidad visible.
2. Estrado/mesas de la fiesta son Polygon2D chatos — pasarlos a pixel-art.
3. Dos rótulos se pisan cerca del galpón; "vecina de la esquina" lejos de su casa.
4. Campo sur del spawn medio pelado.
5. Test de física del par lacrevieja↔villarrubrica (hoy solo cableado).

## Cola

Mismos pases de pueblo para villarrubrica/camino/el_fiado → F5b (E08–E15) →
F5c (E16–E28) → arte de batalla (Ækashics, descargas manuales) → feel FF9.
