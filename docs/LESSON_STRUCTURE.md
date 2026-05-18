# SpeakOffline Lesson Structure

A planning document for the lesson/card progression. The intent is to mirror Duolingo's Spanish (from English) Path as closely as possible. This doc is the source-of-truth for regenerating all flashcards.

**Per-section files** (large; split for manageability):
- This file — Sections 1 (Rookie) and 2 (Explorer), 34 units total
- [LESSON_STRUCTURE_S3.md](LESSON_STRUCTURE_S3.md) — Section 3 (A1 cap, 28 units; preterite introduced at 3.24)
- [LESSON_STRUCTURE_S4.md](LESSON_STRUCTURE_S4.md) — Section 4 (A2, 52 units; imperfect at 4.3, present perfect at 4.34, future at 4.37)
- [LESSON_STRUCTURE_S5.md](LESSON_STRUCTURE_S5.md) — Section 5 (B1, 50 units; conditional at 5.16, **subjunctive at 5.38**, past perfect at 5.42)
- [LESSON_STRUCTURE_S6.md](LESSON_STRUCTURE_S6.md) — Section 6 (B1, 50 units; relative pronouns at 6.17, **past subjunctive at 6.30**, passive voice at 6.38)
- [LESSON_STRUCTURE_S7.md](LESSON_STRUCTURE_S7.md) — Section 7 (B2, 36 units; conditional sentences at 7.7, future perfect at 7.14, `haber` at 7.29)
- [LESSON_STRUCTURE_S8.md](LESSON_STRUCTURE_S8.md) — Section 8 (B2 finale, 36 units; possessive pronouns, verb+preposition pairs, course capstone)

**Total course:** 8 sections, 286 units. Confirmed from per-unit sources: 12 units (Sections 1 + 2 partial). Inferred: 274 units.

---

## 1. Scope and version

- **Target course:** Duolingo Spanish for English speakers, the 286-unit "Path" (live through early 2026).
- **Coverage in this doc:** Section 1 (Rookie) and Section 2 (Explorer), at lesson-level granularity where source data allows.
- **Out of scope (for now):** Sections 3+ (Trailblazer, Pathfinder, Wanderer, etc.) — add later in follow-up docs.

### Important version caveat

In February 2026, Duolingo replaced the Spanish-from-English course with a new **AI-generated** version with a different unit distribution (10+31+30+60+250+250+180+180). This doc tracks the **286-unit Path**, not the new AI course, because:
1. The Path is what the established community resources document.
2. It has stable, pedagogically-vetted progression.
3. The new AI course's content is not yet documented anywhere outside the Duolingo app itself.

If we ever want to track the new course, we'll need to pull unit/lesson data directly from the live Duolingo app.

---

## 2. Structure

```
Course
└── Section (e.g., "Rookie", "Explorer") — broad CEFR-aligned phases
    └── Unit (e.g., "1.3 Get around in a city") — themed, ~5 lessons
        └── Lesson — single sitting, introduces 5–15 new items + practice
            └── Card — one phrase/sentence in our app
```

Approximate volumes (Path):
- Section 1: 8 units, ~40 lessons, ~250–400 cards' worth of content
- Section 2: 26 units, ~130 lessons, ~800–1300 cards' worth of content

Current `SpeakOffline/cards.json` has ~2,000 cards (7 per unit × 286 units) across the 8 Duolingo-aligned decks. (The earlier 851-card seed lived under the legacy `Intro / A1 - Beginner / A2 - Elementary / B1 - Intermediate / B2 - Upper Intermediate` deck names and was purged via the v2 migration.)

---

## 3. Card metadata (proposed)

Each card should carry enough metadata to:
- Place it in the correct Section / Unit / Lesson
- Know what vocabulary/grammar it introduces vs. reinforces
- Support filtered review (e.g., "all cards using preterite tense")

Proposed schema additions on top of current `Card.swift`:

| Field | Type | Example |
| --- | --- | --- |
| `duoSection` | int (1–10) | `1` |
| `duoSectionName` | string | `"Rookie"` |
| `duoUnit` | int (within section) | `3` |
| `duoUnitTitle` | string | `"Get around in a city"` |
| `duoLesson` | int (within unit) | `2` |
| `grammarConcepts` | string[] | `["possessive_mi_tu", "estar_singular", "question_donde"]` |
| `vocabIntroduced` | string[] | `["el banco", "aquí", "dónde"]` |
| `vocabReinforced` | string[] | `["yo", "estar"]` |

Existing fields stay (`front`, `back`, `phonetic`, `cefrLevel`). Old `unit`/`section` fields become legacy — we either migrate or keep alongside.

We will need a controlled vocabulary for `grammarConcepts` (see §6 below).

---

## 4. SECTION 1 — Rookie (CEFR Intro / pre-A1)

8 units. Detailed data confirmed for Units 1, 2, 3, 6, 8; Units 4, 5, 7 are partial and need verification from the Duolingo app.

### Unit 1.1 — Form basic sentences
- **Lessons:** ~4
- **Grammar:**
  - Gender of nouns: `el/un` (masc.), `la/una` (fem.)
  - Subject pronouns: `yo`, `tú`, `él`, `ella`
  - `ser` singular: `soy`, `eres`, `es`
  - Subject pronoun drop
  - Regular -er verb conjugation (singular): `comer`, `beber`
- **Vocab introduced:** `el hombre`, `la mujer`, `el niño`, `la niña`, `la manzana`, `el pan`, `el agua`, `la leche`, `comer`, `beber`, `ser`, `un/una`, `el/la`, `yo`, `tú`, `él`, `ella`, `soy`, `eres`, `es`
- **Sample cards:**
  - "Yo bebo agua." → I drink water.
  - "Él come manzanas." → He eats apples.
  - "Ella es una niña." → She is a girl.

### Unit 1.2 — Greet people
- **Lessons:** ~4
- **Grammar:**
  - `hablar` singular conjugation (yo hablo, tú hablas, él/ella habla)
  - `ser` for introductions
  - Yes/no questions via intonation (`¿Tú hablas...?`)
- **Vocab introduced:** `hola`, `buenos días`, `buenas noches`, `adiós`, `gracias`, `de nada`, `por favor`, `mucho gusto`, `disculpe`, `perdón`, `lo siento`, `sí`, `no`, `hablar`
- **Sample cards:**
  - "¡Buenos días, Ana! Mucho gusto." → Good morning, Ana! Nice to meet you.
  - "¿Tú hablas español?" → Do you speak Spanish?
  - "Yo hablo inglés." → I speak English.

### Unit 1.3 — Get around in a city
- **Lessons:** ~5
- **Grammar:**
  - Possessives: `mi` (my), `tu` (your) — invariant for gender
  - `estar` singular for location
  - `tener`, `necesitar` (singular)
  - Question form: `¿Dónde está…?`
- **Vocab introduced:** `el banco`, `el hospital`, `el museo`, `el supermercado`, `la calle`, `el hotel`, `el boleto`, `el autobús`, `el tren`, `el taxi`, `el dinero`, `el teléfono`, `el pasaporte`, `la maleta`, `la reserva`, `aquí`, `dónde`, `cerrado`, `tener`, `a`, `mi`, `tu`
- **Sample cards:**
  - "Tu autobús está aquí." → Your bus is here.
  - "¿Dónde está el hospital?" → Where is the hospital?
  - "Un boleto, por favor." → One ticket, please.
  - "Yo tengo una maleta." → I have a suitcase.

### Unit 1.4 — Order food and drink ⚠️ partial
- **Lessons:** ~5
- **Grammar:**
  - Prepositions: `con`, `sin`, `para`, `de`
  - Numbers 1–10
  - Continued plural usage
- **Vocab introduced:** `la ensalada`, `el tomate`, `el sándwich`, `la hamburguesa`, `el queso`, `la carne`, `el pescado`, `la sal`, `el/la azúcar`, `el café`, `el jugo`, `la naranja`, `el vaso`, `la taza`, `la mesa`, `la cuenta`, `las personas`, numbers `uno…diez`
- **Verify from app:** Lesson-level breakdown not confirmed. Vocab list inferred from cross-source compilation.

### Unit 1.5 — Describe your family ⚠️ partial
- **Lessons:** ~5
- **Grammar:**
  - Adjective placement after noun + gender agreement (`bonito/a`)
  - `vivir` singular
  - Preposition `en` (in/at) for location (needed with `vivir`)
- **Vocab introduced:** `la familia`, `la madre`, `el padre`, `el hermano`, `la hermana`, `el hijo`, `la hija`, `el abuelo`, `la abuela`, `el esposo`, `la esposa`, `el perro`, `la casa`, `el apartamento`, `el carro`/`el automóvil`, `la bicicleta`, `grande`, `bonito`, `inteligente`, `interesante`, `elegante`, `perfecto`, `muy`, `vivir`, `en`
- **Verify from app:** No lesson-level breakdown found.

### Unit 1.6 — Shop for clothes, Use present tense
- **Lessons:** ~5
- **Grammar:**
  - Conjunction `o`
  - Present tense singular across ~10 verbs (`comprar`, `querer`, `necesitar`, `pagar`, `tener`, `estar`, `vivir`, etc.)
  - Demonstrative `ese`
  - Color adjective agreement
- **Vocab introduced:**
  - Clothing: `el abrigo`, `la chaqueta`, `la camisa`, `la camiseta`, `la falda`, `el vestido`, `el pantalón`, `el cinturón`, `el sombrero`, `la cartera`, `el reloj`
  - Adjectives: `barato`, `caro`, `cómodo`, `favorito`, `diferente`, `demasiado`
  - Colors: `rojo`, `azul`, `verde`, `gris`, `marrón`
  - Verbs/connectors: `comprar`, `querer`, `pagar`, `o`, `y`, `ese`, `el regalo`
  - Retail nouns: `la tienda`, `la ropa` (needed in the confirmed sample below)
- **Sample card:** "Yo quiero comprar una cartera marrón en mi tienda de ropa favorita." → I want to buy a brown wallet at my favorite clothing store.

### Unit 1.7 — Talk about school ⚠️ thin
- **Lessons:** ~5
- **Grammar:** Continued present-tense singular conjugation in school context
- **Vocab (partial, needs verification):** `el bolígrafo`, `el libro`, `la escuela`, `el/la estudiante`, `la maestra`/`el maestro`, `la clase`; verbs `leer`, `escribir`, `aprender`
- **Verify from app:** Title-only confirmation. Vocab and grammar need to be pulled from the Duolingo app or a community deck.

### Unit 1.8 — Say where people are from
- **Lessons:** ~4
- **Grammar:**
  - Structure `[Subj] + ser + de + [place]`
  - `de` (from) vs `en` (in/at)
  - Questions: `¿De dónde eres?`, `¿Cuál es…?`
  - Nationality adjective agreement (`mexicano/mexicana`)
- **Vocab introduced:** `americano/a`, `cubano/a`, `mexicano/a`, `Cuba`, `China`, `España`, `Francia`, `México`, `Estados Unidos`, `de`, `en`
- **Sample cards:**
  - "Yo soy de Estados Unidos." → I'm from the United States.
  - "¿De dónde eres?" → Where are you from?
  - "Ella es mexicana." → She is Mexican.

---

## 5. SECTION 2 — Explorer (CEFR A1)

26 units. **Notation:**
- **✅ confirmed** — vocab/grammar/sentences pulled from a per-unit source (The Owl and Me blog) and align with Duolingo's actual content.
- **🧠 inferred** — unit title is confirmed (duolingodata.com); vocab/grammar/sentences below are an educated guess based on the title, pedagogical sequence within Section 2, and typical A1 Spanish curricula. **These need verification before card generation.** Anything sourced this way should be card-tagged so it can be regenerated when authoritative data arrives.
- ⚠️ partial — some data is confirmed, other parts are inferred (mixed).

Confirmed units: 2.1, 2.2, 2.4, 2.5, 2.6, 2.7, 2.8 (7 of 26). Inferred units: 2.3, 2.9–2.26 (19 of 26).

### Unit 2.1 — Ask how people are ✅ confirmed
- **Lessons:** ~4–5
- **Grammar:**
  - `estar` singular for temporary states/locations vs. `ser` for permanent traits
  - Reflexive intros: `me llamo`, `te llamas`
  - Formal vs informal: `tú` vs `usted`
  - Adjective agreement (`cansado/cansada`)
- **Vocab introduced:** `ocupado/a`, `feliz`, `cansado/a`, `mal`, `¿cómo estás?`, `hasta luego`
- **Story:** "Buenos días" (Vikram and Priti)

### Unit 2.2 — Express travel needs ✅ confirmed
- **Lessons:** ~5 (heavy review of Section 1 travel vocab)
- **Grammar:**
  - Present singular of `saber`, `usar`
  - `por favor`, `más + noun`
  - `usted` reinforced
- **Vocab (new + reviewed):** `la maleta`, `el taxi`, `el bolígrafo`, `el boleto`, plus airport/travel items; `saber`, `usar`, `necesitar`, `tener`
- **Sample cards:**
  - "Yo necesito un taxi, por favor." → I need a taxi, please.
  - "Señora, ¿tiene usted su maleta?" → Ma'am, do you have your suitcase?
  - "¿Tienes tu boleto?" → Do you have your ticket?
- **Story:** "¿Dónde está tu novia?" (airport-themed)

### Unit 2.3 — Talk about schedules 🧠 inferred
- **Grammar (inferred):**
  - Days of the week + "on Mondays" pattern: `los lunes`, `el lunes`
  - Time expressions: `hoy`, `mañana`, `cuando`, `siempre`, `nunca` (preview), `a veces`
  - Continued present tense singular; light intro of "los lunes" recurring time
- **Vocab (inferred):** `lunes`, `martes`, `miércoles`, `jueves`, `viernes`, `sábado`, `domingo`, `hoy`, `mañana`, `el día`, `la semana`, `el cumpleaños`, `la fiesta`, `el partido`, `el fútbol`, `el béisbol`, `cuando`, `siempre`, `a veces`, `el fin de semana`, `todos los días`, `¿cuándo?`
- **Sample cards (inferred):**
  - "Mi cumpleaños es el viernes." → My birthday is on Friday.
  - "Trabajo los lunes." → I work on Mondays.
  - "¿Cuándo es la fiesta?" → When is the party?
  - "El partido es el sábado." → The game is on Saturday.

### Unit 2.4 — Talk about your life ✅ confirmed
- **Grammar:**
  - Question words `dónde` (where), `quién` (who)
  - Infinitive after modals: `querer + infinitive`, `necesitar + infinitive`
  - Present tense for regular -ar / -er / -ir verbs
  - Preposition `en` for workplace/location
  - Indefinite articles with drinks (`un té`, `un café`)
  - Simple negation in present tense
- **Vocab introduced:** `béisbol`, `carne`, `casa`, `ensalada`, `estudiar`, `Europa`, `fábrica`, `francés`, `Francia`, `fútbol`, `Inglaterra`, `jugo`, `oficina`, `partido`, `sándwich`, `té`, `trabajar`, `vino`, `vivir`
- **Sample cards:**
  - "¿Dónde vives?" → Where do you live?
  - "Yo vivo en una casa." → I live in a house.
  - "Él quiere hablar inglés." → He wants to speak English.
  - "Necesito estudiar español." → I need to study Spanish.
  - "Trabajo en la oficina." → I work in the office.
  - "Yo no trabajo el domingo." → I do not work on Sunday.
  - "¿Quién es ella?" → Who is she?
- **Story/dialogue:** Paco and his friend talk about their town and jobs in Barichara, Colombia.

### Unit 2.5 — Discuss others' lives ✅ confirmed
- **Grammar:**
  - `ser` as infinitive after conjugated modals (e.g., `querer ser`)
  - Preposition `con` for togetherness
  - Adjective placement (after noun); `joven` invariant for gender
  - Present tense of `dar` (to give) and `encantar` (to like/love)
  - Indirect object pronouns used with `encantar` (`me encantan`)
- **Vocab introduced:** `amigo`, `camarero`, `celular`, `ciudad`, `con`, `da` (3sg of dar), `dirección`, `escuela`, `familia`, `gato`, `hermano`, `hermana`, `hombre joven`, `maestro`, `me encantan`, `médica`, `médico`, `novia`, `novio`, `número`, `película`, `perro`, `portugués`, `pueblo`, `restaurante`, `siempre`, `hoy`; adjectives `divertido`, `joven`, `grande`, `importante`
- **Sample cards:**
  - "¡La familia de Héctor es muy grande!" → Héctor's family is very big!
  - "Mi hermana es médica." → My sister is a doctor.
  - "¿Vives con tu novio?" → Do you live with your boyfriend?
  - "El español es divertido." → Spanish is fun.
  - "Esteban tiene un gato y se llama Fred." → Esteban has a cat, and his name is Fred.
  - "Mi pueblo tiene un restaurante mexicano." → My town has a Mexican restaurant.

### Unit 2.6 — Talk about college, Use gender agreement ✅ confirmed
- **Grammar:**
  - Explicit gender agreement on nouns and adjectives
  - Singular vs. plural noun forms (masc./fem. distinctions)
  - Number usage with singular and plural nouns
  - Present tense of `aprender` (to learn)
  - Gender-invariant adjectives ending in -e (e.g., `interesante`)
  - Plural `estudiantes` for mixed or single-gender groups
- **Vocab introduced:** `aprender`, `biblioteca`, `libro`, `libros`, `pregunta`, `universidad`, numbers `cero`, `uno`, `dos`, `tres`, `cuatro`, `cinco`, `seis`, `siete`, `ocho`, `nueve`, `diez`
- **Sample cards:**
  - "Ella aprende español en Guatemala." → She is learning Spanish in Guatemala.
  - "Yo tengo seis clases en la universidad." → I have six classes at the university.
  - "La universidad necesita tres bibliotecas." → The university needs three libraries.
  - "Carmen aprende francés en la universidad." → Carmen is learning French at university.
  - "Tengo cero dinero." → I have zero money.
  - "Mi clase tiene siete estudiantes." → My class has seven students.

### Unit 2.7 — Describe your family ✅ confirmed
- **Grammar:**
  - Adjective agreement: masc./fem. and sing./pl. endings (`alto/alta/altos/altas`)
  - Gender-invariant adjectives in -e (`inteligente`)
  - Reflexive `se llama` ("is called")
  - Possessives: `su` (his/her/your-formal/their) matching number not gender; `tu` (your-informal)
  - Using family vocab in context with descriptive attributes
- **Vocab introduced:** `abuela`, `abuelo`, `alto/a`, `año`, `bajo/a`, `bonito/a`, `calle`, `dirección`, `español/española`, `esposa`, `esposo`, `hija`, `hijo`, `inglés/inglesa`, `italiano/a`, `largo/a`, `madre`, `mascota`, `padre`, `pequeño/a`, `plátano`, `simpático/a`, `su`
- **Sample cards:**
  - "Yo soy Luz y él es mi esposo, Hans." → I'm Luz and he's my husband, Hans.
  - "¿Cómo se llama tu esposa?" → What is your wife's name?
  - "¿Dónde vive tu abuela?" → Where does your grandmother live?
  - "Ella tiene una abuela española." → She has a Spanish grandmother.
  - "Tengo tres hijas." → I have three daughters.
  - "Yo vivo con mi hija y mi gato. Mi familia es pequeña." → I live with my daughter and my cat. My family is small.

### Unit 2.8 — Talk about office work ✅ confirmed
- **Grammar:**
  - Infinitive after modal verbs (e.g., after `querer`, `necesitar`)
  - Article agreement with masc. nouns ending in -a (`un problema`)
  - `cuál` vs `qué`: `¿Cuál es...?` vs `¿Qué + noun?`
  - `para` for recipient, deadline, and purpose
  - `poco` for "little / not much"
  - Direct address with commas around names
  - `con + person` (no personal *a* required)
  - Present-tense conjugations of `leer`, `escribir`, `trabajar`
- **Vocab introduced:**
  - Office: `jefa/jefe`, `teléfono`, `lápiz`, `papel`, `archivador`, `documento`, `secretaria`, `escritorio`, `computadora`
  - Work concepts: `tarea`, `organización`, `trabajo en equipo`, `trabajo`, `negocio`, `fábrica`, `oficina`
  - Communication: `carta`, `correo electrónico`, `mensaje`
  - Adjectives: `nuevo/a`, `poco/a`, `importante`, `simpático/a`, `ocupado/a`, `marrón`
  - Adverbs/preps: `ahora`, `en el trabajo`
  - Verbs (infinitive): `enviar`, `firmar`, `llamar`, `escribir`, `leer`, `trabajar`
- **Sample cards:**
  - "La secretaria escribe las cartas los lunes." → The secretary writes the letters on Mondays.
  - "¿Cuál es el problema?" → What's the matter?
  - "Yo necesito las cartas para el lunes." → I need the letters by Monday.
  - "Ella escribe un mensaje para el jefe." → She is writing a message for the boss.
  - "Necesito leer mi correo electrónico ahora." → I need to read my email now.
  - "La secretaria no quiere trabajar aquí." → The secretary does not want to work here.
  - "Yo quiero tener un jefe simpático." → I want to have a nice boss.

### Unit 2.9 — Describe emotions 🧠 inferred
- **Grammar (inferred):**
  - `estar + emotion adjective` (extends 2.1)
  - Intensifiers: `muy`, `un poco`, `bastante`
  - Causal `por` / `porque` (preview)
- **Vocab (inferred):** `contento/a`, `triste`, `enojado/a`, `nervioso/a`, `preocupado/a`, `aburrido/a`, `emocionado/a`, `tranquilo/a`, `asustado/a`, `sorprendido/a`, `mejor`, `peor`, `un poco`, `bastante`, `porque`, `por qué`
- **Sample cards (inferred):**
  - "Hoy estoy muy contento." → Today I'm very happy.
  - "¿Por qué estás triste?" → Why are you sad?
  - "Mi amigo está un poco nervioso." → My friend is a little nervous.

### Unit 2.10 — Say where people are from 🧠 inferred
- **Grammar (inferred):** Revisits 1.8: `ser + de + place`; nationality adjective agreement (sing./pl., masc./fem.)
- **Vocab (inferred):** Countries `Argentina`, `Brasil`, `Alemania`, `Italia`, `Japón`, `China`, `Canadá`, `Inglaterra`, `Rusia`, `Portugal`, `Colombia`, `Perú`; nationalities `argentino/a`, `brasileño/a`, `alemán/alemana`, `italiano/a`, `japonés/japonesa`, `chino/a`, `canadiense`, `inglés/inglesa`, `ruso/a`, `portugués/portuguesa`, `colombiano/a`, `peruano/a`
- **Sample cards (inferred):**
  - "Mi amiga es de Argentina." → My friend is from Argentina.
  - "Ellos son alemanes." → They are German.
  - "¿De dónde son ustedes?" → Where are you (pl.) from?

### Unit 2.11 — Describe clothing 🧠 inferred
- **Grammar (inferred):**
  - Adjective agreement on clothing (extends 1.6)
  - Present tense of `llevar` (to wear) and `usar` (singular and plural)
- **Vocab (inferred):** `la blusa`, `los zapatos`, `los calcetines`, `las gafas`, `la corbata`, `la bufanda`, `el guante`, `el suéter`, `llevar`, `usar`, `la talla`, `pequeño/mediano/grande`, plus revisit of colors and 1.6 clothing items
- **Sample cards (inferred):**
  - "Yo llevo una camisa azul." → I'm wearing a blue shirt.
  - "Esta blusa es muy bonita." → This blouse is very pretty.
  - "¿Qué talla usas?" → What size do you wear?

### Unit 2.12 — Ask for directions 🧠 inferred
- **Grammar (inferred):**
  - Location prepositions: `cerca de`, `lejos de`, `al lado de`, `enfrente de`, `detrás de`, `delante de`, `entre`
  - Direction phrases (likely as fixed expressions, not full imperative conjugation yet)
- **Vocab (inferred):** `cerca`, `lejos`, `al lado de`, `enfrente de`, `detrás de`, `delante de`, `entre`, `derecho` (straight), `a la izquierda`, `a la derecha`, `la esquina`, `el semáforo`, `la cuadra`, `¿cómo llego a...?`, `perdone`, `disculpe`, `la plaza`, `el parque`
- **Sample cards (inferred):**
  - "El banco está cerca." → The bank is nearby.
  - "Gire a la derecha en la esquina." → Turn right at the corner.
  - "Perdone, ¿dónde está el museo?" → Excuse me, where is the museum?

### Unit 2.13 — Talk about free time, Form the present tense 🧠 inferred
- **Grammar (inferred):** **Major unit.** Full present tense for regular -ar / -er / -ir verbs in **all persons including plurals** (nosotros, ustedes, ellos/ellas). First comprehensive plural coverage.
- **Vocab (inferred):** `el tiempo libre`, `el deporte`, `correr`, `nadar`, `bailar`, `cantar`, `escuchar música`, `ver la tele`, `tocar la guitarra`, `el cine`, `el parque`, `el gimnasio`, `los amigos`, `juntos`, `los fines de semana`
- **Sample cards (inferred):**
  - "Nosotros corremos en el parque." → We run in the park.
  - "Ellos bailan los viernes." → They dance on Fridays.
  - "¿Ustedes leen mucho?" → Do you (pl.) read a lot?
  - "Mis amigos y yo vemos películas juntos." → My friends and I watch movies together.

### Unit 2.14 — Describe activities 🧠 inferred
- **Grammar (inferred):**
  - Continued present plural across new activity verbs
  - Time-of-day adverbs: `por la mañana`, `por la tarde`, `por la noche`
- **Vocab (inferred):** `cocinar`, `limpiar`, `viajar`, `salir`, `descansar`, `mirar`, `terminar`, `empezar`, `llegar`, `regresar`/`volver`, `tarde`, `temprano`, `juntos`, `el viaje`
- **Sample cards (inferred):**
  - "Cocinamos juntos los domingos." → We cook together on Sundays.
  - "Yo limpio mi casa el sábado." → I clean my house on Saturday.
  - "Ellos viajan mucho." → They travel a lot.

### Unit 2.15 — Express preferences 🧠 inferred
- **Grammar (inferred):**
  - `gustar` pattern: `me gusta / te gusta / le gusta + infinitive`
  - `me gusta + el/la singular noun` vs. `me gustan + los/las plural noun`
  - `también` (also), `tampoco` (neither)
  - `preferir` (with `e→ie` stem change preview)
- **Vocab (inferred):** `me gusta(n)`, `te gusta(n)`, `le gusta(n)`, `encantar`, `preferir`, `prefiero`, `el favorito`, `también`, `tampoco`, `mejor que`, `peor que`
- **Sample cards (inferred):**
  - "Me gusta el café." → I like coffee.
  - "¿Te gustan las películas de acción?" → Do you like action movies?
  - "A ella le gusta bailar." → She likes to dance.
  - "Yo prefiero el té." → I prefer tea.

### Unit 2.16 — Describe your routine 🧠 inferred
- **Grammar (inferred):**
  - **Reflexive verbs** introduced: `me / te / se / nos / se + verb`
  - Time-of-day expressions: `por la mañana`, `a las siete`, `antes de`, `después de`
- **Vocab (inferred):** `levantarse`, `despertarse`, `ducharse`, `vestirse`, `lavarse`, `peinarse`, `acostarse`, `dormirse`, `sentarse`, `ponerse`, `antes`, `después`, `temprano`, `tarde`, `cada día`
- **Sample cards (inferred):**
  - "Me levanto a las siete." → I get up at seven.
  - "Mi esposa se viste rápido." → My wife gets dressed quickly.
  - "Nos acostamos tarde los viernes." → We go to bed late on Fridays.

### Unit 2.17 — Describe your home 🧠 inferred
- **Grammar (inferred):**
  - `hay` (there is / there are)
  - Re-use of location prepositions from 2.12
- **Vocab (inferred):** `el cuarto`, `la habitación`, `el dormitorio`, `la sala`, `el comedor`, `la cocina`, `el baño`, `el jardín`, `el balcón`, `la pared`, `la ventana`, `la puerta`, `la cama`, `la mesa`, `la silla`, `el sofá`, `el sillón`, `la lámpara`, `el espejo`, `el armario`, `el refrigerador`, `la estufa`
- **Sample cards (inferred):**
  - "Mi casa tiene tres dormitorios." → My house has three bedrooms.
  - "Hay un sofá en la sala." → There's a sofa in the living room.
  - "La cocina es pequeña pero bonita." → The kitchen is small but pretty.

### Unit 2.18 — Order at a restaurant 🧠 inferred
- **Grammar (inferred):**
  - Polite `quisiera` (would like) — fixed form, conditional preview
  - `para mí / para nosotros` (for me / for us)
  - Full plural conjugations applied to restaurant verbs
- **Vocab (inferred):** `el menú`, `la propina`, `el mesero`/`la mesera`, `un poco de`, `mucho`, `frío`, `caliente`, `picante`, `dulce`, `salado`, `sabroso`, `delicioso`, `listo`, `traer`, `pedir`, `recomendar`, `la cuenta` (revisit), `el plato`
- **Sample cards (inferred):**
  - "Quisiera una hamburguesa, por favor." → I'd like a hamburger, please.
  - "¿Qué recomienda usted?" → What do you recommend?
  - "Para mí, una ensalada." → For me, a salad.

### Unit 2.19 — Refer to family members 🧠 inferred
- **Grammar (inferred):**
  - Full possessives: `mi/mis`, `tu/tus`, `su/sus`, `nuestro/a/os/as`
  - Number agreement of possessives
- **Vocab (inferred):** `el tío`, `la tía`, `el primo`, `la prima`, `el sobrino`, `la sobrina`, `el nieto`, `la nieta`, `el suegro`, `la suegra`, `el cuñado`, `la cuñada`, `mayor`, `menor`, `casado/a`, `soltero/a`
- **Sample cards (inferred):**
  - "Mis primos viven en México." → My cousins live in Mexico.
  - "Nuestra tía es maestra." → Our aunt is a teacher.
  - "Su sobrino estudia en la universidad." → Her nephew studies at the university.

### Unit 2.20 — Shop for clothes 🧠 inferred
- **Grammar (inferred):**
  - Numbers 11–100
  - `costar` (to cost) — singular and plural agreement
  - Polite forms for shopping interaction
- **Vocab (inferred):** `el precio`, `costar`, `¿cuánto cuesta?`, `¿cuánto cuestan?`, `caro`, `barato`, `la talla`, `el descuento`, `la tarjeta de crédito`, `en efectivo`, `probarse`, `demasiado`, numbers `once`, `doce`, `trece`, `catorce`, `quince`, `dieciséis`, `diecisiete`, `dieciocho`, `diecinueve`, `veinte`, `treinta`, `cuarenta`, `cincuenta`, `sesenta`, `setenta`, `ochenta`, `noventa`, `cien`
- **Sample cards (inferred):**
  - "¿Cuánto cuesta esta camisa?" → How much does this shirt cost?
  - "Este vestido es demasiado caro." → This dress is too expensive.
  - "Quiero probarme los pantalones." → I want to try on the pants.

### Unit 2.21 — Describe people, Use ser and estar 🧠 inferred grammar, confirmed title
- **Grammar:** Explicit `ser` vs `estar` distinction — the centerpiece grammar unit. (Title confirmed; specific contrasts taught are inferred.)
  - `ser` for identity, origin, profession, permanent traits (`Mi hermano es alto.`)
  - `estar` for location, temporary states, conditions (`Mi hermano está cansado.`)
  - Common contrast pairs (e.g., `ser aburrido` vs `estar aburrido`)
- **Vocab (inferred):** Physical descriptors `alto`, `bajo`, `delgado`, `guapo`, `bonita`, `feo`, `joven`, `viejo`, `rubio`, `moreno`, `calvo`, `fuerte`, `débil`; personality `amable`, `serio`, `gracioso`, `listo`, `tonto`; full conjugations of `ser` and `estar`
- **Sample cards (inferred):**
  - "Mi hermano es alto y delgado." → My brother is tall and thin.
  - "La oficina está cerca de mi casa." → The office is near my house.
  - "Hoy estoy cansada, pero soy una persona activa." → Today I'm tired, but I'm an active person.

### Unit 2.22 — Talk about likes 🧠 inferred
- **Grammar (inferred):**
  - Full indirect-object pronouns: `me`, `te`, `le`, `nos`, `les`
  - Clarifying / emphasizing phrases: `a mí`, `a ti`, `a él/ella`, `a usted`, `a nosotros`, `a ellos/ustedes`
  - `gustar` with plural subjects; `encantar`, `interesar`, `importar`
- **Vocab (inferred):** `a mí me gusta`, `a ti te gusta`, `a él/ella le gusta`, `a nosotros nos gusta`, `a ellos/ustedes les gusta`, `encantar`, `interesar`, `importar`, `faltar`
- **Sample cards (inferred):**
  - "A mí me encanta la música." → I love music.
  - "¿A ti te gustan los gatos?" → Do you like cats?
  - "A mi hermana le importa el trabajo." → My sister cares about work.

### Unit 2.23 — Talk about interactions 🧠 inferred
- **Grammar (inferred):**
  - Verbs of interaction; personal `a` with people (e.g., `Yo veo a María.`)
  - Continued IO/DO pronoun practice from 2.22
- **Vocab (inferred):** `conocer`, `saludar`, `despedirse`, `hablar con`, `llamar por teléfono`, `mandar mensajes`, `ver`, `escuchar`, `ayudar`, `invitar`, `recibir`, `dar`, `prestar`, `regalar`, `contestar`, `preguntar`, `responder`
- **Sample cards (inferred):**
  - "Yo conozco a mi vecino." → I know my neighbor.
  - "Nosotros hablamos con la maestra." → We talk with the teacher.
  - "Ella me invita a la fiesta." → She invites me to the party.

### Unit 2.24 — Describe how you feel 🧠 inferred
- **Grammar (inferred):**
  - `tener` idioms: `tener hambre / sed / sueño / miedo / frío / calor / prisa / razón / X años`
  - `sentirse` (reflexive) preview
- **Vocab (inferred):** `tener hambre`, `tener sed`, `tener sueño`, `tener miedo`, `tener frío`, `tener calor`, `tener prisa`, `tener razón`, `tener X años`, `sentirse`, `enfermo`, `sano`, `mal`, `fatal`, `genial`
- **Sample cards (inferred):**
  - "Tengo mucha hambre." → I'm very hungry.
  - "¿Tienes frío?" → Are you cold?
  - "Mi abuela se siente mejor hoy." → My grandmother feels better today.

### Unit 2.25 — Use pronouns 🧠 inferred
- **Grammar (inferred):**
  - Direct-object pronouns: `lo`, `la`, `los`, `las`
  - Indirect-object pronouns review: `me`, `te`, `le`, `nos`, `les`
  - Placement: before conjugated verb (`Lo veo.`) or attached to infinitive (`Voy a verlo.`)
  - Double-object preview (`Se lo doy.`) — likely not full coverage at A1
- **Vocab (inferred):** the pronouns above; verbs from prior units used as practice
- **Sample cards (inferred):**
  - "Lo tengo aquí." → I have it here.
  - "¿La ves?" → Do you see her/it?
  - "Te llamo mañana." → I'll call you tomorrow.
  - "Voy a comprarlo." → I'm going to buy it.
  - "Le doy un regalo a mi hermana." → I give a present to my sister.

### Unit 2.26 — Use irregular verbs 🧠 inferred
- **Grammar (inferred):**
  - Capstone for present tense. Irregular yo-forms and stem changes:
    - `hacer → hago`, `salir → salgo`, `poner → pongo`, `traer → traigo`, `dar → doy`, `conocer → conozco`, `saber → sé`, `ver → veo`, `decir → digo`, `venir → vengo`, `oír → oigo`
    - `ir → voy/vas/va/vamos/van` (fully irregular)
  - `ir + a + infinitive` for near future (preview)
- **Vocab (inferred):** all verbs above + common collocations:
  - `hacer la tarea`, `hacer ejercicio`, `hacer preguntas`
  - `salir con amigos`, `salir de casa`
  - `poner la mesa`, `traer comida`
  - `dar un regalo`, `dar las gracias`
  - `conocer una ciudad`, `saber + infinitive`
  - `ver una película`, `oír música`
  - `decir la verdad`, `decir adiós`
  - `venir aquí`, `ir al cine / al supermercado`
- **Sample cards (inferred):**
  - "Yo hago la tarea ahora." → I'm doing the homework now.
  - "Mis amigos vienen a la fiesta." → My friends are coming to the party.
  - "Sé hablar tres idiomas." → I know how to speak three languages.
  - "¿Qué dices?" → What are you saying?
  - "Voy al supermercado." → I'm going to the supermarket.

---

## 6. Controlled vocabulary for `grammarConcepts`

To make filtered review and progression tracking work, grammar tags need to be consistent. Proposed initial tag set (extend as we go):

**Nouns & articles**
- `gender_masc`, `gender_fem`
- `article_def` (el/la), `article_indef` (un/una)
- `plural_noun`

**Pronouns**
- `pronoun_subject` (yo, tú, él, ella, …)
- `pronoun_subject_drop`
- `pronoun_object_direct` (lo, la, …)
- `pronoun_object_indirect` (me, te, le, …)
- `formal_usted`

**Verbs — tense/mood**
- `present_singular`, `present_plural`, `present_full`
- `reflexive_verb`
- `gustar_pattern`

**Verbs — specific high-frequency**
- `verb_ser`, `verb_estar`, `verb_ser_vs_estar`
- `verb_tener`, `verb_ir`, `verb_hacer`, `verb_querer`, `verb_saber`
- `irregular_yo_form`

**Adjectives**
- `adj_agreement_gender`, `adj_agreement_number`
- `adj_placement_after`, `adj_placement_before`

**Function words**
- `prep_con_sin`, `prep_para_de`, `prep_a`, `prep_en`
- `conj_y_o`
- `question_donde`, `question_que`, `question_cuando`, `question_de_donde`

**Numbers**
- `numbers_1_10`, `numbers_10_100`

---

## 7. Data status and next steps

### Confirmation status

| Section/Unit | Status |
| --- | --- |
| 1.1, 1.2, 1.3, 1.6, 1.8 | ✅ confirmed (vocab + grammar + sample sentences) |
| 1.4, 1.5, 1.7 | ⚠️ partial — vocab inferred from cross-sources, no lesson-level data |
| 2.1, 2.2, 2.4, 2.5, 2.6, 2.7, 2.8 | ✅ confirmed (from The Owl and Me) |
| 2.3, 2.9–2.26 | 🧠 inferred — titles confirmed, vocab/grammar/samples are educated guesses |

19 of 26 Section 2 units are currently inferred. **Cards generated from inferred data should be flagged at the card level** so they can be regenerated once authoritative data exists.

### How to verify inferred units (in priority order)

1. **Duolingo app Guidebook** — open each unit, screenshot the in-app Guidebook (vocab list + grammar tips). Authoritative.
2. **The Owl and Me blog** — actively publishing per-unit walkthroughs; new posts roughly every 2–4 weeks. Check `https://theowlandme.blog/category/duolingo/duolingo-spanish/` periodically and pull confirmed data for newly-published units.
3. **duome.eu forum** — has Path-era unit data but currently inaccessible from automated tools; you may be able to reach it from your browser.
4. **Per-unit Quizlet sets** — fragmented across many creators; treat as supplementary only (no single creator covers Section 2 completely).

### Card-level recommendation

When `Card` records are generated for this structure, include a `dataSource` field on each card:
- `"confirmed"` — from a per-unit source (Owl and Me, Duolingo Guidebook screenshot)
- `"inferred"` — from this doc's educated guesses (Section 2.3, 2.9–2.26)
- `"legacy"` — from the existing 851-card seed (origin uncertain)

This makes it trivial to regenerate or replace inferred cards once we get real data, without losing user progress on confirmed cards.

### Suggested next steps

1. Decide whether to migrate the existing 851 cards into this structure or regenerate from scratch.
2. Update `Card.swift` schema with the proposed metadata fields (§3) including `dataSource`.
3. Pin down the controlled vocabulary list in §6 (extend after a first pass).
4. Generate cards for all ✅ confirmed units first.
5. Generate cards for 🧠 inferred units with `dataSource: "inferred"` so they can be regenerated later.
6. Periodically re-pull The Owl and Me blog for newly-published units and promote inferred → confirmed.
7. Extend this doc with Section 3+ once Sections 1–2 are stable.

---

## 8. Sources

- [duolingodata.com 286-unit Spanish course](https://duolingodata.com/dat/esfen286.html) — authoritative for unit titles and counts
- [The Owl and Me blog](https://theowlandme.blog/) — per-unit walkthroughs (Section 1 Units 3, 6, 8; Section 2 Units 1, 2 as of Feb 2026)
- [Duolingo Wiki (fandom)](https://duolingo.fandom.com/) — older Tree-era data, useful but mixes versions
- [SpanishDict Duolingo Unit 1](https://www.spanishdict.com/lists/3420215/duolingo-unit-1), [Unit 2](https://www.spanishdict.com/lists/5600639/duolingo-unit-2), [Unit 3](https://www.spanishdict.com/lists/5809700/duolingo-unit-3) — topical vocab compilations (not 1:1 with Duolingo units)
