# «De Palabra» — diseño del core de cartas (F3)

**Estado: revisado adversarialmente. Listo para implementar.**
Fuente de verdad narrativa: `docs/concepto/concepto-definitivo.md` § «El juego de cartas in-world».
Contrato con el guion: `docs/guion/acto1/INDICE.md` § 4b y § 4e.
Fase del plan: `docs/cores/plan-integracion.md` § F3.

> **Nota de procedencia.** Este documento fue escrito durante el pase de revisión: el pase de
> autoría anterior no dejó archivo. Todo lo que sigue está verificado contra el código real de
> `addons/card-framework/` (leído completo: 2.518 líneas) y contra el contrato del guion.
> La sección final «Decisiones de la revisión» lista los huecos cerrados y los riesgos abiertos.

---

## 0. Principio de arquitectura

Tres capas, con una sola dirección de dependencia:

```
MotorDePalabra (GDScript puro, sin Node, sin card-framework)  ← testeable headless
        ↑ señales propias (EventoDuelo)
VistaDuelo (Control, usa addons/card-framework)               ← solo dibuja y traduce input
        ↑
IADePalabra (función pura: estado + perfil + rng → Jugada)
```

**Regla no negociable:** el motor es la única autoridad sobre la legalidad. El framework
valida cosas (`_card_can_be_added`) *nada más que como afordancia visual*: si el motor y el
contenedor discrepan, gana el motor y la vista se resincroniza. Motivo en § 6.

Todo el azar pasa por un `RandomNumberGenerator` con semilla inyectada (`MotorDePalabra.new(semilla)`).
Sin esto no hay tests deterministas ni se puede reproducir una tirada de Fiel.

---

## 1. Reglas base

| Concepto | Valor |
|---|---|
| Aval de la Firma | 30 |
| Crédito | arranca en 1, +1 al empezar cada turno propio, tope **10** |
| Crédito no gastado | se pierde al terminar el turno (no acumula) |
| Estrado | **7** Fiadores por lado |
| Mano | máximo **10** cartas |
| Mazo | 30 cartas, máximo 2 copias por carta (1 si es legendaria) |
| Mano inicial | 3 cartas el primero, 4 + **«La Vuelta»** el segundo |
| Robo | 1 carta al empezar el turno (el primer jugador no roba en su turno 1) |

**«La Vuelta»** (token, no coleccionable): 0 Crédito, Cláusula. *+1 Crédito este turno.* Corrige
la ventaja del primer jugador. En lunfardo del Fiado es "el vuelto"; en Valdepalabra, "la
diferencia".

### 1.1 Mora de mazo (fatiga)

La biblia no la define y sin ella los duelos no terminan. **Cuando tenés que robar y el mazo
está vacío, tu Firma pierde 1 Aval, y el contador sube 1 por cada robo fallido posterior**
(1, 2, 3, …). Diegéticamente: "el mazo entró en mora". Es acumulativo por Firma y no se
reinicia.

### 1.2 Duelo incobrable (tope de turnos)

Al terminar el **turno 30** el duelo se declara **incobrable**: gana quien tenga más Aval; si
hay empate, pierde quien desafió (en duelos de guion, pierde la IA). Impide partidas infinitas
en duelos obligatorios que bloquean progreso.

### 1.3 Legalidad de jugada

**Una carta no se puede jugar si no puede producir ningún efecto legal.** Aplica a
`Palabra Rota` sin Promesas pendientes, `Fe de Erratas` con el Estrado propio vacío,
`Pregón de Ventanilla` sin Fiadores con **De palabra**, etc. La vista marca esas cartas en gris
con el motivo al hover. Evita estados ambiguos y evita que el jugador se autodestruya un turno.

---

## 2. Keywords

| Keyword | Definición operativa |
|---|---|
| **Al contado** | puede atacar el mismo turno que entra al Estrado |
| **Garante** | mientras haya un Garante enemigo vivo y **revelado**, los ataques deben dirigirse a un Garante. Si hay dos o más, el atacante **elige cuál** |
| **Sello** | ignora la próxima instancia de daño **mayor que 0** y se consume |
| **De palabra** | efecto al entrar al Estrado (resuelve inmediatamente, antes de que el turno siga) |
| **Letra chica** | efecto al morir (resuelve después de que la carta ya salió del Estrado) |
| **Interés** | por cada turno **entero** que la carta pasa en tu mano: +1 coste y +1 ataque (o +1 daño si es Cláusula) |

**Aclaraciones que faltaban y ahora son regla:**

1. **Garante restringe ataques, no Cláusulas.** Un `Pagaré a la Vista` pega en la Firma con
   Garantes en pie.
2. **Garante no protege a las cartas boca abajo** (módulo "al fiado", § 4.2) ni las cartas boca
   abajo tienen Garante: una carta que viaja no tiene keywords reveladas. Solo se la puede
   tocar con **denuncia**, que no es un ataque.
3. **Un Soporte puede tener Garante.** Ser Garante es sobre ser atacado, no sobre atacar
   (`Tranquera Cerrada` 0/4 Garante es la carta más importante del arquetipo de Rosaura).
4. **Sello no impide ser elegido como objetivo**, solo absorbe el daño. Un ataque de 0 de
   ataque **no** consume el Sello.
5. **Interés topea el coste en 10** — nunca vuelve la carta injugable — pero el ataque sigue
   subiendo hasta **+5** sobre el base. Sin este tope, el arquetipo de Bravante se suicida en
   partidas largas (la carta se vuelve basura injugable) y el estado del duelo crece sin cota.
6. **El Interés devengado vive en la instancia de carta y se conserva en el Empeñadero** (una
   prenda empeñada sigue devengando: es exactamente el mundo). Si el rival la rescata, paga el
   coste **actual** y recibe los stats crecidos. Cierra el exploit de "empeño la carta con
   Interés para congelarla".
7. **El descuento de "al fiado" (−2) se aplica al coste base, no al coste crecido por Interés.**
   Sin esto, Interés + al fiado da cuerpos enormes casi gratis.

---

## 3. Promesas (el giro propio)

Al jugar una carta se puede añadir una **cláusula optativa** con plazo. La Promesa se ata a la
**Firma**, no al Fiador.

| Campo | Regla |
|---|---|
| Plazo | 1, 2 o 3 turnos propios. **Máximo 3.** No se puede renovar ni extender |
| Promesas pendientes | máximo **3** por Firma a la vez |
| Cumplida | disuelve la prenda, aplica el bonus de la carta, dispara `promesa_cumplida` |
| Rota | nace un **Quebranto** (§ 3.2), dispara `promesa_rota` |

Tipos de cláusula disponibles en el Acto 1 (cerrados: la IA necesita estimar probabilidad de
cumplimiento por tipo, § 7):

| id | Texto | Se rompe si… |
|---|---|---|
| `no_atacar` | "no atacar con este Fiador por N turnos" | ese Fiador ataca |
| `jugar_otro_fiador` | "jugar otro Fiador antes del fin de mi próximo turno" | vence el plazo sin otro Fiador jugado |
| `no_defender` | "este Fiador no bloquea por N turnos" | lo usás como Garante voluntario |
| `cumplir_con_luz` | "cumplir otra Promesa antes del plazo" | vence sin otra cumplida |
| `sin_clausulas` | "no jugar Cláusulas por N turnos" | jugás una Cláusula |

### 3.1 Los cinco huecos de plazo, cerrados

1. **El plazo vence el mismo turno en que el Fiador muere.** La Promesa es de la Firma y
   **sobrevive** a la muerte del Fiador. Excepción: las cláusulas cuyo término *habla de ese
   Fiador* (`no_atacar`, `no_defender`) se vuelven **imposibles** y **se rompen en el acto**.
   Esto es deliberado: es el motor del arquetipo de palabra rota (matás tu propio Fiador
   prometido para parir el Quebranto), y es literalmente lo que hace `Palabra Rota`.
2. **El plazo vence el turno en que el dueño pierde el duelo.** Si el Aval llega a 0, el duelo
   termina y las Promesas pendientes **se anulan** — no hay Quebranto post mortem.
   **Excepción del Rito** (Acto 3, mesa de lacre vivo): ahí las Promesas pendientes al terminar
   **cuentan como rotas**, porque el rito no se gana, se cumple. El motor expone
   `modo_rito: bool` y el test `test_rito_promesa_pendiente_es_rota` lo fija.
3. **Resolución simultánea.** Al empezar tu turno, los vencimientos resuelven en **orden de
   antigüedad** (la Promesa más vieja primero). Determinista, testeable.
4. **Cumplimiento y ruptura en el mismo evento** (p. ej. `El Amanecer` con una Promesa que
   vence ese mismo turno): **cumplir gana**. Se resuelve el cumplimiento y el vencimiento se
   descarta.
5. **Promesas sobre cartas boca abajo (al fiado):** una carta que viaja **no puede llevar
   Promesa**. La cláusula se declara al revelar. Sin esto, el plazo corre sobre información
   oculta y el rival no puede jugar contra algo que no ve.

### 3.2 Quebrantos — el hueco importante

**Un Quebranto es 2/2, ataca automáticamente a la Firma de quien rompió la promesa, y no puede
llevar Promesas.** (Que no pueda llevar Promesas corta cualquier bucle infinito
romper→parir→romper.)

Tres reglas nuevas, porque el diseño original tenía un agujero explotable:

1. **Tope: 3 Quebrantos por lado.** Si ya hay 3, la ruptura no genera un cuarto; en cambio la
   Firma pierde 2 de Aval directo ("la mora se paga igual").
2. **Estrado lleno (7) y nace un Quebranto:** el Quebranto **NO se descarta**. Va a una zona
   nueva, **la Mora**, fuera del Estrado (máximo 3, la misma bolsa del punto 1), y desde ahí
   pega en la Firma de su dueño cada turno igual que si estuviera en el Estrado — pero no puede
   ser atacado ni bloqueado. En cuanto se libera un lugar en el Estrado, el Quebranto más viejo
   de la Mora entra solo.
   **Por qué:** si el Quebranto se descartara con el Estrado lleno, la jugada óptima del
   arquetipo de palabra rota sería *llenar el Estrado y romper todo gratis*. Eso convierte el
   tema del juego en un exploit. Una promesa rota no se puede esquivar por falta de espacio.
3. **Invocación con Estrado lleno (que no sea Quebranto):** se **frustra** — la invocación se
   evalúa en el momento de resolver, no se encola. Aplica a `Letra chica` que invoca
   (`Sepulturero Cosme` invoca dos Deudos con 6 aliados vivos → entra uno, el otro se frustra) y
   a AoE que mata 3 Fiadores con Letra chica invocadora a la vez (se resuelven en orden de
   posición en el Estrado, izquierda a derecha, y los que no caben se frustran). La vista tiene
   que decir por qué: *"el Estrado no da fe"*.

### 3.3 Empeñar

Habilitado en E17 (El Fiado). **Una vez por turno**: mandá una carta de tu mano al
**Empeñadero** (pila visible para los dos) y ganá +1 Crédito **este turno**. El rival puede
rescatarla pagando su coste actual.

**"Una vez por turno" es una corrección, no un detalle.** La biblia dice "podés empeñar una
carta por +1 Crédito" sin frecuencia. Sin el límite: empeñás 5 cartas el turno 4, tenés 9
Crédito y bajás una legendaria — y de paso el `Porteador del Empeñadero` sale 7/10. Roto por
dos vías a la vez.

El Crédito de empeño **no puede pasar el tope de 10** del turno.

---

## 4. Módulos por acto

El motor arranca con todos los módulos implementados y **apagados por bandera**. La mesa
(`ConfigMesa`) dice qué módulos están activos.

| Módulo | Bandera | Se activa en |
|---|---|---|
| Base + Promesas | siempre | E03 (Rosaura, tutorial) |
| Empeñar | `empenar` | E17 |
| Al fiado | `al_fiado` | E17 (solo mesas de El Fiado) |
| Balanza de la Palabra | `balanza` | Acto 2 (Ronda del Fiado) |
| Rito de lacre vivo | `modo_rito` | Acto 3 (mesa final) |

**Regla de mazo por módulo:** una carta que pertenece a un módulo apagado **no se puede meter
en el mazo** para esa mesa (el armador la rechaza con motivo). Sin esto,
`«Primera mentira gratis»` es una carta muerta en cualquier mesa fuera del puerto, y el jugador
no entiende por qué.

### 4.1 Balanza (Acto 2) — solo el hook

No se diseña acá, pero el motor **tiene que exponer los ganchos desde F3** o hay refactor
después: `promesa_cumplida`, `promesa_rota`, `quebranto_nacido`, y un multiplicador global
consultable `mesa.amplificacion_de_palabra` / `mesa.amplificacion_letra_chica`. El Acto 1
los deja en 1.0.

### 4.2 Al fiado (E17)

Cualquier carta se puede jugar boca abajo pagando **coste base − 2** (mínimo 0). Viaja 2 turnos
y se revela con bono de entrega. Mientras viaja, el rival puede **denunciarla**: 1 vez por
turno, elige una carta en viaje; si acierta el tipo declarado se rompe, si falla el viaje se
acorta 1 turno. Usa `Card.show_front = false` del framework (soportado nativo).

---

## 5. Las cartas — 36 definiciones

35 jugables en el Acto 1 + 1 bloqueada (`nadia_la_impalabra`, postgame). Las 10 de muestra de
la biblia están todas. Formato de datos: `data_src/cartas/*.json` → pipeline → `.tres`
(convención del proyecto), **no** `JsonCardFactory` (motivo en § 6.3).

### 5.1 Neutrales (6)

| id | Nombre | C | Tipo | Stats | Texto |
|---|---|---|---|---|---|
| `gallina_lacrevieja` | Gallina de Lacrevieja | 1 | Fiador | 1/1 | Promesa opc. (2t) `no_atacar`. Cumplida: se vuelve **Gallina Cumplidora** 2/3 con Sello |
| `peon_de_vina` | Peón de Viña | 2 | Fiador | 2/2 | — |
| `mula_de_reparto` | Mula de Reparto | 3 | Fiador | 3/3 | — |
| `colmillo_del_diezmo` | Colmillo del Diezmo | 2 | Fiador | 3/2 | — *(drop de los lobos de E11)* |
| `lampara_de_palabra` | Lámpara de Palabra | 2 | Soporte | 0/3 | Cada vez que cumplís una Promesa, robá 1. **Máximo 2 por turno** |
| `fe_de_erratas` | Fe de Erratas | 2 | Cláusula | — | Devolvé a tu mano un Fiador aliado; su coste baja 1 |

### 5.2 Garante — Rosaura (5)

| id | Nombre | C | Tipo | Stats | Texto |
|---|---|---|---|---|---|
| `tranquera_cerrada` | Tranquera Cerrada | 1 | Soporte | 0/4 | **Garante** |
| `hornera_de_rosaura` | Hornera de Rosaura | 2 | Fiador | 1/4 | **Garante** |
| `sereno_del_archivo` | Sereno del Archivo | 3 | Fiador | 2/4 | **Garante**, **Sello** |
| `porteador_empenadero` | Porteador del Empeñadero | 4 | Fiador | 2/5 | **Garante**. +1/+1 por carta en tu Empeñadero, **hasta +3/+3** |
| `de_mi_mesa_nadie` | «De mi mesa nadie se levanta con hambre» | 3 | Cláusula | — | Dale **Garante** y +0/+2 a todos tus Fiadores |

### 5.3 Letra chica — Cosme / Salu (6)

| id | Nombre | C | Tipo | Stats | Texto |
|---|---|---|---|---|---|
| `deudo_del_difunto` | Deudo del Difunto | 1 | Fiador | 1/1 | **Letra chica:** robá 1 |
| `clausula_al_dorso` | Cláusula al Dorso | 2 | Cláusula | — | Dale a un Fiador aliado «**Letra chica:** el rival descarta 1» |
| `sepulturero_cosme` | Sepulturero Cosme *(firma)* | 3 | Fiador | 2/2 | **Letra chica:** invocá dos Deudos 1/1 |
| `contrato_que_drena` | Contrato que Drena | 3 | Soporte | 0/2 | Al final de cada turno rival su Firma pierde 1 Aval. **Letra chica:** pierde 2 |
| `testamento_apurado` | Testamento Apurado | 4 | Cláusula | — | Destruí un Fiador aliado; robá 2 y +1 Crédito este turno |
| `quebranto_del_peaje` | El Quebranto del Peaje *(firma, boss E15)* | 5 | Fiador | 4/4 | **Letra chica:** nace un Quebranto 2/2 **del lado rival** (le pega a la Firma rival) |

### 5.4 Interés — prestamista / Bravante (5)

| id | Nombre | C | Tipo | Stats | Texto |
|---|---|---|---|---|---|
| `cobrador_de_la_camara` | Cobrador de la Cámara | 2 | Fiador | 2/1 | **Interés** |
| `pagare_a_la_vista` | Pagaré a la Vista | 1 | Cláusula | — | **Interés.** Hacé 2 de daño (hasta 7 con Interés) |
| `lo_suyo_madura` | «Lo suyo madura» | 2 | Cláusula | — | Dale **Interés** a 2 cartas de tu mano; robá 1 |
| `bravante_el_corredor` | Bravante, el Corredor *(firma)* | 5 | Fiador | 4/4 | Al empezar tu turno, una carta al azar de tu mano gana **Interés** |
| `tasador_decano` | el Tasador Decano *(firma, boss E06)* | 6 | Fiador | 5/5 | **De palabra:** hasta **2** cartas con Interés de tu mano cuestan 0 este turno |

### 5.5 De palabra — archivista (5)

| id | Nombre | C | Tipo | Stats | Texto |
|---|---|---|---|---|---|
| `maestra_jardinera` | Maestra Jardinera | 2 | Fiador | 1/3 | **De palabra:** +1/+1 a otro Fiador aliado |
| `tasadora_ciega` | Tasadora Ciega *(firma, E19)* | 3 | Fiador | 2/2 | **De palabra:** revelá una carta de tu mano → copiá a tu mano una carta al azar del mazo rival |
| `archivista_jubilada` | Archivista Jubilada *(firma)* | 4 | Fiador | 3/3 | **De palabra:** robá 1 por Fiador aliado con De palabra en el Estrado, **hasta 3** |
| `pregon_de_ventanilla` | Pregón de Ventanilla | 4 | Cláusula | — | Repetí los **De palabra** de tus Fiadores en el Estrado, **hasta 3** |
| `odila_la_forastera` | Odila, la Forastera | 4 | Fiador leg. | 2/4 | **De palabra:** refrendá — devolvé al Estrado con **Sello** el último Fiador aliado caído. **Letra chica:** vuelve a tu mano como **la Forastera** (4/2, Al contado, **sin Letra chica**) |

### 5.6 Al contado — Tallador / Cachuzo (4)

| id | Nombre | C | Tipo | Stats | Texto |
|---|---|---|---|---|---|
| `changuito_del_muelle` | Changuito del Muelle | 1 | Fiador | 2/1 | **Al contado** |
| `tallador_de_la_puerta` | el Tallador de la Puerta *(firma)* | 3 | Fiador | 3/2 | **Al contado** |
| `cobradoras_gemelas` | Las Cobradoras Gemelas *(firma, boss E24)* | 5 | Fiador leg. | 3/3 | **Al contado.** Invocá una copia espejo 3/3 con Al contado (token, sin este efecto). Cuando una muere, la otra pierde Al contado y gana +2/+2 |
| `primera_mentira_gratis` | «Primera mentira gratis» | 2 | Cláusula | — | *(módulo `al_fiado`)* Jugá una carta al fiado sin costo de viaje: se revela al final de tu turno |

### 5.7 Palabra rota / Quebrantos (4)

| id | Nombre | C | Tipo | Stats | Texto |
|---|---|---|---|---|---|
| `lloron_del_puerto` | el Llorón del Puerto | 2 | Fiador | 2/2 | Gana +1/+1 cada vez que rompés una Promesa |
| `palabra_rota` | Palabra Rota | 3 | Cláusula | — | Rompé una Promesa pendiente tuya: el Quebranto nace de **tu** lado, con **Al contado** |
| `fiel_el_que_espera` | Fiel, el que Espera | 4 | Fiador leg. | 3/3 | La **primera vez por turno** que sería destruido, no lo es: consumís un plazo de una Promesa pendiente (*espera con vos*). Al cumplir una Promesa (**1 vez por turno**): +2/+2 permanente |
| `el_amanecer` | El Amanecer | 10 | Cláusula leg. | — | Cumplí todas tus Promesas pendientes (con sus bonus); disolvé todos los Quebrantos del Estrado y de la Mora; +1 Aval por cada uno |

### 5.8 Bloqueada en el Acto 1 (1)

| id | Nombre | C | Tipo | Stats | Texto |
|---|---|---|---|---|---|
| `nadia_la_impalabra` | Nadia, la Impalabra | 9 | Fiador leg. | 7/7 | **No puede hacer Promesas.** **De palabra:** llevá a tu mano, gratis, todas las cartas del Empeñadero rival *(el excedente sobre 10 se empeña, § 6.7)* |

### 5.9 Tokens (6, no coleccionables, pero **necesitan asset y json**)

`gallina_cumplidora` (2/3 Sello) · `deudo` (1/1) · `quebranto` (2/2) · `copia_espejo` (3/3 Al
contado) · `la_forastera` (4/2 Al contado) · `la_vuelta` (0, Cláusula).

**Presupuesto de arte real: 42 caras de carta**, no 35. Anotarlo en `docs/arte`.

### 5.10 Canales de obtención (cierra el contrato § 4e del INDICE)

| Escena | Entrega |
|---|---|
| E03 mazo de la casa (Rosaura) | `gallina_lacrevieja` ×2, `peon_de_vina`, `lampara_de_palabra` *(la de Rosaura)*, `porteador_empenadero`, `tranquera_cerrada`, `hornera_de_rosaura` |
| E03 premio | mazo propio + `gallina_lacrevieja` #1 |
| E03 Cosme (opc.) | `sepulturero_cosme`, `deudo_del_difunto`, `testamento_apurado` |
| E06 boss | firma `tasador_decano` |
| E08 prestamista (opc.) | `cobrador_de_la_camara`, `lo_suyo_madura` |
| E09 cofre | `lampara_de_palabra` **propia** |
| E10 archivista (opc.) | `archivista_jubilada`, `maestra_jardinera`, `pregon_de_ventanilla` |
| E11 lobos | `colmillo_del_diezmo` |
| E12 Fiel se une | firma `fiel_el_que_espera` |
| E13 cofre | `gallina_lacrevieja` #2, `mula_de_reparto`, `tranquera_cerrada` |
| E15 boss | firma `quebranto_del_peaje` + `clausula_al_dorso`, `contrato_que_drena` |
| E16 Tallador | firma `tallador_de_la_puerta`, `changuito_del_muelle` |
| E17 Cachuzo | `primera_mentira_gratis`, `lloron_del_puerto`, `palabra_rota` |
| E18 | mazo de refrendo **guionado** (incluye `odila_la_forastera`) — no entra a la colección |
| E19 Tasadora | firma `tasadora_ciega` |
| E20 Rematador (opc.) | `fe_de_erratas`, `pagare_a_la_vista` |
| E23 Bravante | firma `bravante_el_corredor` + **`el_amanecer` garantizada** |
| E24 boss | firma `cobradoras_gemelas` |

**Las 5 manos anunciadas de Ciro (§ 4f.1 del INDICE) cierran con este calendario.** Verificado
carta por carta: E03 (2 Gallinas + Peón + Lámpara de la casa) · E16 (2 Gallinas + Lámpara —
la propia ya está desde E09) · E17 (+ Porteador, del mazo inicial) · E23 (+ Tasadora, de E19) ·
E25 (+ El Amanecer, de E23). **Test obligatorio:** `test_manos_anunciadas_son_servibles`
recorre el calendario y falla si una carta anunciada no fue entregada por un canal previo.

---

## 6. Contrato con `addons/card-framework` — verificado contra el código

Lo que sigue está leído del código, no de la documentación del addon.

### 6.1 Lo que el framework sí da

- `Hand` — abanico con curvas, `max_hand_size`, `card_face_up`, reordenamiento por drag.
- `Pile` — mazo, descarte y Empeñadero (`card_face_up`, `restrict_to_top_card`,
  `get_top_cards(n)`).
- `CardContainer` custom para el Estrado: se extiende y se sobreescribe `_card_can_be_added`,
  `_update_target_positions`, `_update_card_states`, `on_card_move_done`, `on_card_pressed`.
- `Card.show_front` — **resuelve "al fiado" gratis** (cara/dorso nativo).
- Animación de movimiento (`move`, tween por `moving_speed`) y hover.

### 6.2 Lo que el framework NO da y hay que construir (nueve puntos)

1. **No hay ni una sola señal en todo el addon.** Verificado: `grep -n "^signal"` no devuelve
   nada en los 11 scripts. La comunicación es por sobreescritura de virtuales.
   → El bus de eventos es del motor (`señal evento(EventoDuelo)`), y la vista se suscribe.
   Nunca al revés.
2. **No se puede soltar una carta sobre otra carta.** Los `DropZone` pertenecen a
   *contenedores*, y `_card_can_be_added(cards)` recibe **solo las cartas**, sin objetivo. Elegir
   a qué Fiador enemigo atacar o a quién buffear **no se puede expresar con drop zones**.
   → Capa propia `ModoObjetivo`: durante la selección se pone
   `can_be_interacted_with = false` en todas las cartas y se maneja el input en un `Control`
   overlay. Es trabajo nuevo, no configuración.
3. **La cara de la carta es un `Texture2D` (`front_image`) y nada más.** No hay labels de
   coste/ataque/aguante. Pero **Interés cambia coste y ataque en tiempo real**, y los +1/+1
   también.
   → `CartaDePalabra extends Card` con `Label`s enlazados al estado del motor es
   **obligatorio**, no un lujo. Con PNGs pre-rendereados el arquetipo de Bravante es
   indibujable.
4. **`card_info` es un `Dictionary` compartido por referencia entre todas las copias.**
   `JsonCardFactory.create_card` hace `preloaded_cards[card_name]["info"]` y lo asigna a
   `card.card_info` — la **misma instancia** para las dos Gallinas del mazo, y cacheada para
   todo el proceso. Escribir estado de runtime ahí corrompe todas las copias **y persiste entre
   duelos**.
   → **Prohibido guardar estado mutable en `card_info`.** Todo el estado vive en el motor
   (`EstadoCarta`), y `card_info` es solo lectura (o `duplicate(true)` al crear).
5. **`JsonCardFactory.preload_card_data()` entra en loop infinito con cualquier dato malo.**
   Líneas 106-142: los dos `continue` no avanzan `file_name`. Un JSON malformado devuelve `{}`,
   entonces `card_info.get("front_image","")` da `""`, `_load_image` devuelve `null`, `continue`
   → **Godot cuelga al arrancar, sin error legible**. Además `card_info.name` (acceso por punto,
   líneas 80 y 100) crashea si el JSON no tiene `"name"`.
   → **No usar `JsonCardFactory`.** `FabricaDePalabra extends CardFactory` que lee los `.tres`
   del pipeline `data_src→.tres`, con validación explícita y `push_error` que no cuelga. Bonus:
   resuelve también los puntos 3 y 4. `verify.sh` valida el set de cartas antes de importar.
6. **El historial crece sin cota y `undo()` es público.** `CardManager._on_drag_dropped` llama
   `move_cards(cards, index)` con `with_history = true` por defecto: cada carta jugada queda en
   `history` con referencias a nodos que después se liberan, y `card_manager.undo()` permitiría
   **des-jugar** una carta.
   → Los contenedores propios sobreescriben `move_cards` forzando `with_history = false`. No se
   expone `undo()` jamás en el duelo.
7. **La mano destruye en silencio lo que no entra.** `Hand._card_can_be_added` rechaza si
   `size + n > max_hand_size`, y `JsonCardFactory._create_card_node` hace
   `card.queue_free(); return null` cuando la rechazan.
   → El motor decide el destino **antes** de instanciar el nodo. Si la mano está en 10, el robo
   va al **Empeñadero propio** (regla de diseño: el excedente se empeña — el rival lo puede
   rescatar, y temáticamente es perfecto). Nunca se crea un nodo para tirarlo.
8. **El primer contenedor que acepta se queda la carta.** `_on_drag_dropped` itera
   `card_container_dict.keys()` (orden de `unique_id`, que es un **`static` que nunca se
   reinicia**) y corta en el primero que devuelve `true`, y `check_card_can_be_dropped` solo pide
   que el mouse esté dentro del sensor.
   → Los sensores de Estrado, Empeñadero y mano **no pueden solaparse**. Test de layout
   obligatorio (`test_sensores_no_se_solapan`). Y `unique_id` **no se persiste** en el save.
9. **`enable_drop_zone` solo se lee en `_ready`.** `_initialize_drop_zone` corre una vez; si
   estaba en `false`, `drop_zone` queda `null` para siempre y `check_card_can_be_dropped`
   devuelve `false` sin recuperación.
   → El Empeñadero existe con drop zone habilitada desde el turno 1 y se **cierra por
   `_card_can_be_added`** consultando `mesa.modulos.empenar`. No se toca `enable_drop_zone` en
   runtime.

### 6.3 Input

El framework es **mouse-only** (`_on_gui_input`, `_on_mouse_enter`, `get_global_mouse_position`).
El JRPG se juega con gamepad y la demo va a testers. → capa de cursor virtual propia sobre el
duelo (mapea D-pad/stick a selección de carta y de objetivo, y sintetiza el drop llamando
directamente al motor). **No** se intenta emular eventos de mouse.

### 6.4 Veredicto del contrato

**Realizable, pero el framework aporta solo la capa de presentación (~30% del trabajo de F3).**
Las reglas, el targeting, los números vivos, la fábrica de cartas y el input de gamepad son
código propio. El plan F3 dice "Vista sobre `addons/card-framework`" — es correcto, siempre que
"vista" se lea literal y nadie espere que el addon aporte lógica de juego.

---

## 7. IA por perfil

`PerfilIA` como `Resource` (`data_src/perfiles_ia/*.json` → `.tres`). La IA es una **función
pura**: `elegir_jugada(estado: EstadoDuelo, perfil: PerfilIA, rng: RandomNumberGenerator) -> Jugada`.
Sin acceso al árbol de nodos, sin `randf()` global. Es la única forma de testearla.

### 7.1 Campos del perfil

| Campo | Rango | Efecto |
|---|---|---|
| `peso_tempo` | 0–2 | valor de tener cuerpos ahora |
| `peso_cara` | 0–2 | ganas de pegarle a la Firma en vez de comer trades |
| `peso_tabla` | 0–2 | valor de conservar el Estrado |
| `peso_mano` | 0–2 | valor de cartas en mano (robo) |
| `sesgo_promesa` | 0–1 | probabilidad de aceptar una cláusula optativa |
| `sesgo_desconfianza` | 0–1 | cuánto asume que la información del rival es mentira |
| `umbral_trade` | 0–1 | cuánto valor de más exige para intercambiar |
| `curva_preferida` | array[10] | coste ideal a jugar por turno |
| `keywords_prioritarias` | array[String] | desempate al elegir jugada |
| `guion_forzado` | array[Jugada] o null | jugadas fijas para los primeros N turnos (tutoriales) |

### 7.2 Algoritmo (acotado a propósito)

1. **Enumerar jugadas legales** pidiéndoselas al motor (`estado.jugadas_legales()`) — la IA
   nunca reimplementa la legalidad. Elimina de un saque la clase de bug "la IA hizo algo
   ilegal".
2. **Beam search de ancho 4, profundidad = agotar el Crédito** (no árbol completo). Cota dura:
   máximo **200 nodos evaluados** por turno. Con 10 de Crédito y 10 cartas en mano el espacio
   completo es intratable y en un JRPG el turno rival tiene que resolverse en < 100 ms.
3. **Evaluar** el estado resultante con una lineal:
   `aval_propio − aval_rival·peso_cara + Σ(ataque+aguante)·peso_tabla + cartas_mano·peso_mano
   + credito_no_gastado·(−0.5) + quebrantos_propios·(−3)`.
4. **Promesas:** por cada cláusula optativa, `p_cumplir` de una tabla fija por tipo
   (`no_atacar` 0.8, `jugar_otro_fiador` = 1 si hay Fiador jugable en mano si no 0.3,
   `no_defender` 0.5, `cumplir_con_luz` 0.4, `sin_clausulas` 0.7). Acepta si
   `p_cumplir · bonus > (1 − p_cumplir) · costo_quebranto · (1 − sesgo_promesa)`.
5. **Ataques:** ordenar por (a) mata sin morir, (b) mata muriendo si el valor sube por encima
   de `umbral_trade`, (c) cara si `peso_cara` alto o si hay letal. Garante lo impone el motor.
6. **Modelo del rival:** solo cartas visibles. Si el rival **anunció** cartas (Ciro), se meten
   en el modelo con peso `1 − sesgo_desconfianza`.

### 7.3 Los 7 perfiles del Acto 1

| Perfil | Rival | Marca |
|---|---|---|
| `garante` | Rosaura (E03) | `peso_tabla` 2, `peso_cara` 0.3, `guion_forzado` los turnos 1-3 (tutorial) |
| `letra_chica` | Cosme (E03) | `umbral_trade` 0.1 — trades felices; valora sus propias muertes |
| `interes` | prestamista (E08), Bravante (E23) | `curva_preferida` sesgada tarde, `peso_mano` 2 |
| `de_palabra` | archivista (E10) | `keywords_prioritarias` = ["de_palabra"] |
| `al_contado` | Tallador (E16) | `peso_cara` 2, `peso_tabla` 0.3 |
| `senuelos` | Cachuzo (E17) | usa `al_fiado` con 50% de señuelos por rng |
| `control` | **Salu** (E25) | **`sesgo_desconfianza` = 1.0** |

**El defecto guionado de Salu es implementable y elegante.** El INDICE (§ 4b, E25) exige: "la IA
juega la mano anunciada de Ciro *como si fuera mentira* — y por eso pierde". Con
`sesgo_desconfianza = 1.0`, el modelo del rival descarta por completo el anuncio de `El Amanecer`
y por lo tanto **no juega para negarlo**: no rompe las Promesas de Ciro ni lo apura. Pierde por
su propio motor de personaje, sin una sola línea de "IA que pierde a propósito". No hace falta
`guion_forzado`.

### 7.4 Veredicto de IA

**Implementable con lo especificado**, con dos condiciones que antes no estaban: la IA pide las
jugadas legales al motor (no las deduce) y la búsqueda tiene cota dura de nodos. Sin la cota, el
perfil `interes` con 10 de Crédito y mano llena es un cuelgue de turno.

---

## 8. Tests (headless, sin escena)

Los duelos son la parte del juego con más estado oculto: acá los tests no son opcionales.
Todos corren sobre `MotorDePalabra` puro con semilla fija.

### 8.1 Reglas base

1. `test_credito_sube_y_topea_en_10`
2. `test_credito_no_gastado_se_pierde`
3. `test_mora_de_mazo_es_acumulativa`
4. `test_duelo_incobrable_al_turno_30`
5. `test_la_vuelta_solo_para_el_segundo`
6. `test_carta_sin_efecto_legal_no_se_puede_jugar`

### 8.2 Keywords

7. `test_dos_garantes_el_atacante_elige`
8. `test_garante_no_restringe_clausulas`
9. `test_garante_no_protege_carta_boca_abajo`
10. `test_soporte_puede_ser_garante`
11. `test_sello_no_se_consume_con_dano_cero`
12. `test_interes_coste_topea_en_10_y_ataque_en_mas_5`
13. `test_interes_sigue_devengando_en_el_empenadero`
14. `test_al_fiado_descuenta_sobre_el_coste_base_no_el_crecido`

### 8.3 Promesas y Quebrantos — **los frágiles**

15. `test_promesa_sobrevive_a_la_muerte_del_fiador`
16. `test_promesa_imposible_se_rompe_en_el_acto` *(no_atacar + Fiador muerto)*
17. `test_promesa_pendiente_se_anula_al_perder_el_duelo`
18. `test_rito_promesa_pendiente_es_rota` *(modo_rito)*
19. `test_vencimientos_resuelven_por_antiguedad`
20. `test_cumplir_gana_sobre_vencer_en_el_mismo_evento`
21. `test_carta_en_viaje_no_puede_llevar_promesa`
22. `test_maximo_3_promesas_pendientes`
23. `test_plazo_no_se_puede_renovar`
24. **`test_quebranto_con_estrado_lleno_va_a_la_mora`** ← el hueco central
25. **`test_quebranto_en_mora_pega_a_su_firma_y_no_es_atacable`**
26. **`test_quebranto_en_mora_entra_al_liberarse_lugar`**
27. `test_cuarto_quebranto_cuesta_2_aval`
28. `test_quebranto_no_puede_llevar_promesas` *(anti-bucle)*
29. `test_letra_chica_invocadora_se_frustra_con_estrado_lleno`
30. `test_aoe_mata_tres_letra_chica_resuelve_izquierda_a_derecha`

### 8.4 Combos y cartas concretas

31. `test_empenar_una_vez_por_turno`
32. `test_empeno_no_supera_el_tope_de_credito`
33. `test_porteador_topea_en_mas_3`
34. `test_fiel_evita_una_sola_destruccion_por_turno`
35. `test_fiel_enciende_una_sola_vez_por_turno`
36. `test_lampara_roba_maximo_2_por_turno`
37. `test_amanecer_con_lampara_no_desborda_la_mano`
38. `test_forastera_no_tiene_letra_chica` *(anti-bucle Odila)*
39. `test_copia_espejo_no_invoca_otra_copia`
40. `test_tasador_decano_pone_a_cero_maximo_2`
41. `test_robo_con_mano_llena_va_al_empenadero_propio`
42. `test_quebranto_del_peaje_pone_quebranto_del_lado_rival`

### 8.5 Contrato con el framework y el guion

43. `test_sensores_no_se_solapan` *(layout; el único que necesita escena)*
44. `test_ninguna_carta_escribe_en_card_info`
45. `test_set_de_cartas_valida_sin_colgar` *(validador del pipeline; cubre el loop infinito)*
46. `test_manos_anunciadas_son_servibles` *(§ 5.10)*
47. `test_todas_las_cartas_de_los_7_mazos_rivales_existen`
48. `test_cada_carta_tiene_al_menos_un_canal_de_obtencion`
49. `test_cartas_de_modulo_apagado_no_entran_al_mazo`

### 8.6 IA

50. `test_ia_nunca_propone_jugada_ilegal` *(fuzz: 500 estados con semilla)*
51. `test_ia_respeta_cota_de_200_nodos`
52. `test_ia_es_determinista_con_la_misma_semilla`
53. `test_salu_no_juega_contra_el_amanecer_anunciado` *(el defecto de personaje, como test)*

---

## 9. Riesgos que quedan abiertos

1. **Balance numérico sin verificar.** Los costes/stats de las 36 cartas son un primer pase
   razonado, no simulado. Mitigación barata: un simulador headless de 10.000 duelos
   perfil-vs-perfil sobre el mismo motor (la IA ya es función pura, sale casi gratis) antes de
   cerrar F3. Sin eso, "Rosaura es imbatible en el tutorial" se descubre jugando.
2. **La Balanza (Acto 2) puede empujar refactor.** Los hooks están, pero una balanza compartida
   que amplifica **De palabra** y duplica **Letra chica** toca resolución de efectos, que es lo
   más delicado del motor. Riesgo aceptado y localizado.
3. **`al fiado` y la información oculta contra la IA.** Que la IA "denuncie" bien sin hacer
   trampa (mirando la carta tapada) exige un modelo de creencias que acá está resuelto con un
   rng y un 50%. Es honesto pero pobre; el Cachuzo va a parecer tonto.
4. **42 caras de carta de arte.** Es el cuello de botella real del acto, no el código.
5. **El tope de 30 turnos podría cortar un duelo de guion.** Si algún duelo obligatorio se
   diseña largo (Salu, control), verificar que la IA de control no empate por tiempo contra un
   jugador pasivo.
6. **Gamepad en el duelo.** Estimado por lo bajo. Es una capa de input entera sobre un addon
   mouse-only.

---

## 10. Decisiones de la revisión

El documento no existía cuando empezó esta pasada (el pase de autoría no dejó archivo). Lo
escribí entero incorporando las correcciones, en vez de escribir un diseño y después parcharlo.
Estas son las decisiones que **no** salen de la biblia ni del guion: son cierres de hueco.

### Huecos de reglas cerrados

| # | Hueco | Decisión | Por qué |
|---|---|---|---|
| 1 | Quebranto nace con el Estrado lleno | Va a **la Mora** (zona nueva, máx. 3), pega a su Firma, no es atacable, entra al Estrado al liberarse lugar | Si se descartara, la jugada óptima del arquetipo de palabra rota sería **llenar el Estrado y romper gratis**. El tema del juego convertido en exploit |
| 2 | Invocación normal con Estrado lleno | Se **frustra** al resolver (no se encola), orden izquierda→derecha | Determinismo; y evita colas de invocación fantasma entre turnos |
| 3 | Cuarto Quebranto | 2 de Aval directo | La mora se paga igual: no hay forma de esquivar una ruptura |
| 4 | Dos Garantes | El atacante elige; Garante no restringe Cláusulas; no protege cartas boca abajo; un Soporte puede ser Garante | Cuatro ambigüedades que la biblia dejaba abiertas y que el jugador descubre en el peor momento |
| 5 | Interés a 10 de Crédito | Coste **topea en 10**, ataque topea en **+5**, sigue devengando en el Empeñadero, el descuento de al fiado se aplica al coste base | Sin tope el arquetipo de Bravante se autodestruye (cartas injugables) y el estado crece sin cota |
| 6 | Promesa cuyo plazo vence el turno que el dueño pierde | Se **anula**… salvo en `modo_rito` (Acto 3), donde **cuenta como rota** | El rito no se gana, se cumple: era una contradicción latente entre el duelo normal y la mesa final |
| 7 | Promesa cuyo Fiador muere | La Promesa es de la **Firma** y sobrevive; las cláusulas que hablan de ese Fiador se vuelven **imposibles** y se rompen ya | Convierte un hueco en el motor del arquetipo de palabra rota, que es lo que `Palabra Rota` ya pedía |
| 8 | Empeñar | **Una vez por turno**, sin pasar el tope de 10 | La biblia no fijaba frecuencia: 5 empeños = 9 Crédito en el turno 4 **y** un Porteador 7/10. Roto por dos vías |
| 9 | Mazo vacío | **Mora de mazo** acumulativa (1, 2, 3…) | No existía; sin ella los duelos no terminan |
| 10 | Duelo eterno | **Incobrable al turno 30** | Los duelos obligatorios bloquean progreso: no puede haber empate infinito |
| 11 | Mano llena al robar | El excedente **se empeña** (Empeñadero propio, rescatable) | El framework destruía la carta en silencio (§ 6.2.7); esto es legible, temático y jugable |
| 12 | Promesas sobre cartas en viaje | **Prohibidas**; la cláusula se declara al revelar | El plazo corría sobre información oculta |
| 13 | Carta sin efecto legal | **No se puede jugar** | Cierra el estado ambiguo de `Palabra Rota` sin promesas, `Fe de Erratas` con Estrado vacío, etc. |
| 14 | Cartas de módulo apagado | El armador de mazo las **rechaza** | `«Primera mentira gratis»` era carta muerta fuera del puerto |

### Combos degenerados encontrados y cortados

| Combo | Corte |
|---|---|
| Llenar el Estrado y romper promesas gratis | La Mora (#1) |
| Empeñar N cartas para rampar Crédito **y** engordar el Porteador | 1 empeño/turno + tope +3/+3 |
| `Fiel` indestructible con una Promesa perpetua | Plazo máx. 3, **no renovable**; Fiel evita **una** destrucción por turno y consume plazo |
| `Fiel` +2/+2 ×5 con `El Amanecer` | Enciende **1 vez por turno** |
| `El Amanecer` + 2 `Lámparas` = robar 10 y quemar la mano | Lámpara roba **máx. 2/turno** + excedente al Empeñadero |
| `Odila` → `Forastera` → `Odila` en bucle | **La Forastera no tiene Letra chica** |
| `Cobradoras Gemelas` invocando copias recursivas | La copia es token **sin el efecto** |
| `Tasador Decano` poniendo a 0 la mano entera de Interés | **Máximo 2 cartas** |
| `Pagaré a la Vista` a 10 de daño | Interés topea en +5 (7 de daño) |
| Bucle romper→Quebranto→romper | **Los Quebrantos no pueden llevar Promesas** |
| Congelar Interés metiendo la carta al Empeñadero | Sigue devengando ahí |
| Interés + descuento de al fiado | El descuento va sobre el coste **base** |

### Cartas muertas eliminadas / cerradas

- **`Maestra Jardinera` agregada** (2, 1/3, De palabra): cierra el pendiente #7 del INDICE — la
  biblia la lista como rival-personalidad de **De palabra** y no tenía ni una carta.
- **`Colmillo del Diezmo` agregada**: el contrato § 4a exige que los lobos de E11 dropeen
  "Fiadores baratos de colmillo" y **ningún canal entregaba ninguno**. Era un drop apuntando al
  vacío.
- **`Peón de Viña` agregada al set**: Ciro la **anuncia en voz alta en E03** (§ 4f.1) y no estaba
  en las 10 de muestra de la biblia. Sin ella, la regla no negociable "Ciro no puede mentir ni
  por desincronización" es imposible de cumplir.
- **`Escribiente de Ventanilla` (3/5 vanilla) descartada**: redundante con `Sereno del Archivo`,
  que hace lo mismo con identidad de arquetipo.
- **`Nadia, la Impalabra` marcada como no obtenible en el Acto 1**: es carta de postgame. Se
  implementa igual (está en las 10 de la biblia) pero el armador la bloquea.

### Correcciones al contrato con `card-framework`

Nueve puntos en § 6.2. Los tres que cambian el plan de trabajo:

1. **No usar `JsonCardFactory`.** Tiene un **loop infinito** (los `continue` de
   `preload_card_data` no avanzan `file_name`): un JSON malformado o un PNG faltante **cuelga
   Godot al arrancar** sin error legible. Se escribe `FabricaDePalabra extends CardFactory`
   sobre los `.tres` del pipeline del proyecto.
2. **`card_info` es una referencia compartida entre todas las copias de una carta y está
   cacheada para todo el proceso.** Guardar estado de runtime ahí corrompe las dos Gallinas del
   mazo a la vez **y arrastra la corrupción entre duelos**. Estado mutable solo en el motor.
3. **La cara de carta es un `Texture2D`, sin labels.** Como Interés cambia coste y ataque en
   vivo, un `Card` custom con labels es **obligatorio**. Un mazo de PNGs no puede dibujar el
   arquetipo de Bravante.

Además: el drop de carta sobre carta **no existe** en el framework (targeting es capa propia),
el addon **no tiene ni una señal** (el bus es del motor), el historial crece sin cota con
`undo()` público (forzar `with_history = false`), los sensores no pueden solaparse (el primer
contenedor que acepta se queda la carta), `enable_drop_zone` no se puede activar en runtime, y
todo el input es mouse-only.

### Correcciones a la IA

- La IA **pide las jugadas legales al motor** en vez de deducirlas. Elimina de raíz la clase de
  bug "la IA jugó algo ilegal".
- **Cota dura de 200 nodos** y beam de ancho 4. El plan F3 decía "heurísticas por keyword" sin
  cota: con 10 de Crédito y mano llena, eso es un cuelgue de turno.
- La IA es **función pura con rng inyectado** — condición para que `test_ia_es_determinista`
  exista.
- El defecto guionado de Salu se implementa como **`sesgo_desconfianza = 1.0`**, no como script:
  descarta el anuncio de `El Amanecer` del modelo del rival y por eso no juega para negarlo.
  Pierde por su propio motor de personaje, que es lo que el guion pide.

### Lo que decidí NO tocar

- **La Balanza de la Palabra** queda como diseño del Acto 2. Acá solo se fijan los hooks
  (`promesa_cumplida`, `promesa_rota`, `quebranto_nacido`, multiplicadores consultables) para no
  refactorizar después.
- **El balance numérico** queda declarado como riesgo #1, no resuelto: se resuelve simulando,
  no discutiendo.
- Los textos, nombres y lore de las cartas siguen la biblia palabra por palabra donde la biblia
  habla.
