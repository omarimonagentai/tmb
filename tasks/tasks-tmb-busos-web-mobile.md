# Task List: TMB Busos — Migració a web pública amb PWA mòbil

Basat en `tasks/prd-tmb-busos-web-mobile.md`.

## Relevant Files

- `firebase.json` - Configuració de Firebase Hosting i Functions, incloent els rewrites `/api/**` → funció `api`.
- `.firebaserc` - Aliases del projecte Firebase (production).
- `firestore.rules` - Regles de seguretat de Firestore: deny-all per a clients, només Cloud Functions hi escriuen.
- `.gitignore` - Exclou `node_modules/`, `.firebase/`, `.env`, build outputs i credencials locals.
- `functions/package.json` - Dependències del backend (`firebase-functions`, `firebase-admin`, `express`).
- `functions/index.js` - Entry point de la Cloud Function `api`. Defineix l'app Express i els 4 endpoints.
- `functions/tmb-client.js` - Wrapper sobre `fetch` a `api.tmb.cat` amb credencials llegides de `functions.config()`.
- `functions/cache.js` - Utilitats de caché: `Map` in-memory amb TTL per a iBus i lectura/escriptura a Firestore amb `expires_at` per a dades estables.
- `public/index.html` - Estructura de l'SPA: bottom-nav amb 4 seccions, viewport meta mobile, enllaços a Leaflet, manifest i registre del SW.
- `public/app.css` - Estils mobile-first, paleta TMB (`#cc0000`), targets de toc 44x44px, layout responsive.
- `public/app.js` - Lògica de l'SPA: tabs, crides al backend, render de cards, integració Leaflet, refresc 20s, geolocalització, preferits.
- `public/manifest.json` - Manifest PWA (nom, short_name, icones, theme_color, display standalone).
- `public/sw.js` - Service Worker amb estratègia cache-first per a assets estàtics i fallback offline.
- `public/icons/icon-192.png` - Icona PWA 192x192.
- `public/icons/icon-512.png` - Icona PWA 512x512.
- `README.md` - Instruccions de setup local, emulator i desplegament.

### Notes

- **No hi ha tests automatitzats al scope d'aquest projecte** (§8.6 de les especificacions originals i §5 del PRD). La validació és manual amb una checklist al 6.3.
- **Frontend vanilla sense build step**: no cal `npm install` per al frontend. Només `functions/` necessita `npm install`.
- **Desenvolupament local**: `firebase emulators:start` cobreix Hosting + Functions + Firestore en local; el frontend s'obre a `http://localhost:5000`.
- **Credencials TMB**: configurades amb `firebase functions:config:set tmb.app_id=... tmb.app_key=...`. Mai al codi font ni al frontend.
- **Tot el desenvolupament passa a la branca creada al 0.1** i es desplega a Firebase un cop validat al 6.x.

## Tasks

- [ ] 0.0 Crear branca de feature
  - [ ] 0.1 Crear i checkout d'una branca nova per a aquesta feature (ex.: `git checkout -b feature/tmb-busos-web-mobile`)

- [ ] 1.0 Configurar la infraestructura de Firebase (Hosting, Functions, Firestore, secrets, rewrites `/api/*`)
  - [ ] 1.1 Crear el projecte a la Firebase Console (pla **Spark / free**)
  - [ ] 1.2 Instal·lar Firebase CLI: `npm install -g firebase-tools` i fer login amb `firebase login`
  - [ ] 1.3 Inicialitzar Firebase al repo: `firebase init` seleccionant Hosting, Functions (Node 20, JavaScript) i Firestore
  - [ ] 1.4 Editar `firebase.json` per afegir el rewrite `/api/**` → funció `api`
  - [ ] 1.5 Configurar `firestore.rules` amb deny-all per a clients (només les Functions escriuen via Admin SDK)
  - [ ] 1.6 Guardar les credencials TMB: `firebase functions:config:set tmb.app_id="5b96be62" tmb.app_key="314b33f1943df74d47681bebc8378abd"`
  - [ ] 1.7 Afegir al `.gitignore`: `node_modules/`, `.firebase/`, `.env`, `functions/lib/`, `*.local.json`
  - [ ] 1.8 Validar que el projecte funciona en local amb `firebase emulators:start`

- [ ] 2.0 Implementar el backend (4 endpoints Cloud Functions amb caché de 2 nivells)
  - [ ] 2.1 Instal·lar dependències a `functions/`: `firebase-functions`, `firebase-admin`, `express`, `cors`
  - [ ] 2.2 Crear `functions/tmb-client.js` que centralitza les crides a `api.tmb.cat` afegint `app_id` i `app_key` llegits de `functions.config().tmb`
  - [ ] 2.3 Crear `functions/cache.js` amb:
    - Caché in-memory `Map<string, {data, expires_at}>` amb funcions `get(key)` i `set(key, data, ttl_ms)`
    - Utilitats Firestore: `firestoreGet(collection, doc)` i `firestoreSet(collection, doc, data, ttl_seconds)` que afegeixen i validen `expires_at`
  - [ ] 2.4 A `functions/index.js`, crear una app Express muntada com a Cloud Function `api` exportada
  - [ ] 2.5 Implementar `GET /api/stops/:stop_code` amb caché in-memory TTL 10s (FR32, FR37)
  - [ ] 2.6 Implementar `GET /api/line/:line_name`:
    - Resoldre `CODI_LINIA` consultant el catàleg amb caché Firestore 24h
    - Recuperar parades i trajectes (caché Firestore 24h cada un)
    - Agrupar parades per `SENTIT` i ordenar per `ORDRE`
    - Tornar `{line, stops_by_dir, shapes_by_dir}` (FR32, FR38)
  - [ ] 2.7 Implementar `GET /api/line_buses/:line_name`:
    - Resoldre `CODI_LINIA` i recuperar parades (caché Firestore)
    - Crida paral·lela a `/api/stops/:codi` per cada parada amb `Promise.all` limitat a 10 concurrents
    - Per cada parada, filtrar busos de la línia i agafar el `t-in-min` mínim
    - Tornar `{stops: [...]}` amb `next_min`, `destination`, `vehicle_id` (FR32, FR35, FR36)
  - [ ] 2.8 Implementar `GET /api/stops_catalog`:
    - Iterar el catàleg de línies i recuperar parades de cada línia
    - Deduplicar per `CODI_PARADA` i tornar `[{codi, nom, coords: [lon, lat]}, ...]`
    - Caché Firestore 24h (clau `stops_catalog`) (FR33, FR38)
  - [ ] 2.9 Afegir gestió d'errors: si TMB falla en endpoints secundaris (`/trajectes`, `/parades` d'un sol bus), tornar dades parcials amb log d'avís (FR36)
  - [ ] 2.10 Afegir `console.log` estructurat a totes les crides TMB: `{endpoint, status, latency_ms, cache_hit}`
  - [ ] 2.11 Provar tots els endpoints amb el emulator (`firebase emulators:start`) i comprovar contracte amb un client REST

- [ ] 3.0 Construir el frontend mobile-first amb paritat funcional (15 FR del bloc 4.1 del PRD)
  - [ ] 3.1 Crear `public/index.html` amb:
    - `<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">`
    - Bottom-nav amb 4 botons (A prop meu, Proper bus, Línia, Preferits)
    - Contenidors per a cada vista
    - Inclusió de Leaflet CSS+JS via CDN (`unpkg.com/leaflet@1.9.4`)
  - [ ] 3.2 Crear `public/app.css`:
    - Mobile-first: estils base per a < 768px primer
    - Variable CSS `--tmb-red: #cc0000` i ús als badges/capçaleres
    - Targets de toc: mínim 44x44px en botons i botons de pestanya
    - Fonts del sistema (`-apple-system, Segoe UI, Roboto, sans-serif`)
    - Tipografia base 16px (evita zoom automàtic a iOS en inputs)
  - [ ] 3.3 Crear `public/app.js` amb arquitectura modular:
    - `state = { activeTab, refreshTimer, currentLine, ... }`
    - Funció `switchTab(tabName)` que també atura el refresc si surt de "Línia" (FR14)
  - [ ] 3.4 Vista "Proper bus" (FR1, FR15):
    - Input numèric + botó "Cerca" + Enter
    - `fetch('/api/stops/' + code)`
    - Render cards: badge línia, destinació (`destination_ca` amb fallback a `destination`), minuts (`Imminent` si `t-in-min == 0`, sinó `{n} min`)
    - Missatge groc si llista buida o `!res.ok`
  - [ ] 3.5 Vista "Parades d'una línia" — cerca inicial (FR2):
    - Input + botó "Cerca", uppercase abans del fetch
    - `fetch('/api/line/' + code.toUpperCase())`
  - [ ] 3.6 Vista "Parades d'una línia" — mapa Leaflet (FR3):
    - `L.map('map').setView([41.3874, 2.1686], 13)`
    - Tiles OSM `https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png`
  - [ ] 3.7 Render del traçat per sentit (FR4, FR5):
    - `A` → `#1976d2`, `T` → `#f57c00`, altres → `#555`
    - `L.polyline` opacitat 0.75 si hi ha shape real
    - Polyline discontínua de fallback (línia → línia entre parades), més fina i transparent si hi ha shape real
    - Suport `LineString` i `MultiLineString`
  - [ ] 3.8 Render de parades com `circleMarker` (FR6):
    - Radi 5, color del sentit
    - Tooltip: `{ORDRE}. {NOM_PARADA}\nCodi: {CODI_PARADA}\nSentit: {SENTIT}`
  - [ ] 3.9 Llegenda `topright` (FR7):
    - `L.control({position: 'topright'})` amb HTML que llista cada sentit amb el seu color i nom de la parada terminal
  - [ ] 3.10 Llistat textual de parades sota el mapa (FR8):
    - Agrupat per sentit, capçalera `{Direcció} → {destí} ({N} parades)`
    - Ordenat per `ORDRE`
  - [ ] 3.11 Refresc de posicions cada 20s (FR9, FR11, FR12, FR13):
    - `setInterval(refreshBuses, 20_000)` guardat a `state.refreshTimer`
    - Crida `fetch('/api/line_buses/' + code)`
    - Per cada bus: aplicar fórmula `frac = (AVG - next_min) / AVG` amb `AVG = 2`
    - Si `next_min >= AVG` no pintar
    - Si primera parada del sentit, pintar sobre la parada
    - Calcular bearing entre `prev` i `s` per rotar la icona SVG
    - Icona SVG inline d'un bus vist des de dalt, acolorida per sentit
    - Tooltip: `Línia {X} — {Direcció} → {destí}`, pròxima parada, minuts, vehicle_id si existeix
  - [ ] 3.12 Comptador i botó "Actualitza ara" (FR9, FR10):
    - Comptador descendent visible (20...19...18) actualitzat cada segon
    - Barra de progrés CSS (`width: {(20-c)/20*100}%`)
    - Botó "Actualitza ara" que dispara `refreshBuses()` immediat i reinicia el comptador
  - [ ] 3.13 Atura el cicle de refresc en canviar de pestanya (FR14):
    - A `switchTab`, si surt de "Línia": `clearInterval(state.refreshTimer)`

- [ ] 4.0 Afegir capa PWA (manifest, service worker, instal·labilitat, icones)
  - [ ] 4.1 Crear `public/manifest.json` (FR16):
    ```json
    {
      "name": "TMB Busos",
      "short_name": "TMB",
      "start_url": "/",
      "display": "standalone",
      "theme_color": "#cc0000",
      "background_color": "#ffffff",
      "icons": [
        { "src": "/icons/icon-192.png", "sizes": "192x192", "type": "image/png" },
        { "src": "/icons/icon-512.png", "sizes": "512x512", "type": "image/png" }
      ]
    }
    ```
  - [ ] 4.2 Dissenyar/exportar les icones a `public/icons/icon-192.png` i `public/icons/icon-512.png` amb estètica TMB vermella (FR20). Si no hi ha logo, usar una icona genèrica de bus com a placeholder
  - [ ] 4.3 Enllaçar el manifest a `index.html`: `<link rel="manifest" href="/manifest.json">` + `<meta name="theme-color" content="#cc0000">`
  - [ ] 4.4 Crear `public/sw.js` amb estratègia cache-first per als assets estàtics (FR17):
    - Llista de fitxers a cachejar a la instal·lació: `/`, `/app.js`, `/app.css`, `/manifest.json`, icones, CDN de Leaflet
    - `fetch` event: respondre del caché si hi és, sinó xarxa
  - [ ] 4.5 Registrar el SW a `app.js`: `navigator.serviceWorker.register('/sw.js')` dins de `DOMContentLoaded`
  - [ ] 4.6 Gestionar offline (FR18):
    - Detectar `navigator.onLine === false` o errors de fetch
    - Mostrar missatge "Sense connexió" al panell actiu si no es poden carregar dades fresques
  - [ ] 4.7 Validar amb Lighthouse PWA audit a Chrome DevTools (FR19): score ≥ "Installable"

- [ ] 5.0 Implementar funcionalitats mòbil noves (geolocalització + preferits)
  - [ ] 5.1 Afegir l'estructura DOM de la vista "A prop meu" a `index.html`:
    - Botó "Cerca parades properes"
    - Contenidor per a la llista de resultats
    - Missatge d'estat (carregant / permís denegat / sense resultats)
  - [ ] 5.2 Flux de geolocalització (FR22, FR23):
    - En clicar el botó: `navigator.geolocation.getCurrentPosition(success, error)`
    - Si error: mostrar missatge amb instruccions per concedir permís a la configuració del navegador
  - [ ] 5.3 Càrrega del catàleg complet (FR26):
    - Primera vegada: `fetch('/api/stops_catalog')` i guardar a memòria
    - El SW del 4.0 ja cachejarà la resposta GET per a càrregues posteriors offline-friendly
  - [ ] 5.4 Implementar Haversine a `app.js` (FR24):
    - Funció `haversine(lat1, lon1, lat2, lon2)` retornant metres
    - Calcular distància de l'usuari a totes les parades
  - [ ] 5.5 Render de les 10 parades més properes (FR25):
    - Ordenades ascendent per distància
    - Mostrar: nom, distància (`{n} m` o `{n.n} km`), codi
    - Cada element clicable
  - [ ] 5.6 Clicar parada propera → obre "Proper bus" pre-omplerta i executada (FR25):
    - `switchTab('proper-bus')` + omplir input + disparar la cerca
  - [ ] 5.7 Botó "estrella" als resultats de "Proper bus" i "Parades d'una línia" (FR27):
    - Toggle visual + crida a `toggleFavorite(type, code, name)`
  - [ ] 5.8 Implementar el store de preferits a `localStorage` (FR30, FR31):
    - Clau `tmb_favorites` amb format `{stops: [...], lines: [...]}`
    - Cada item: `{type, code, name, savedAt}`
    - Funcions `getFavorites()`, `addFavorite(item)`, `removeFavorite(type, code)`, `isFavorite(type, code)`
  - [ ] 5.9 Vista "Preferits" (FR28):
    - Dues seccions: "Parades" i "Línies"
    - Mostrar nom + codi + botó "treure"
  - [ ] 5.10 Clicar un preferit → obre la vista corresponent pre-omplerta i executada (FR29)

- [ ] 6.0 Desplegar a producció i validar end-to-end
  - [ ] 6.1 `firebase deploy` complet (hosting + functions + firestore.rules)
  - [ ] 6.2 Verificar que `https://{projecte}.web.app` carrega correctament
  - [ ] 6.3 Executar la checklist de paritat funcional dels 15 FR del bloc 4.1 del PRD; documentar resultats
  - [ ] 6.4 Executar Lighthouse PWA audit a la URL pública; objectiu ≥ "Installable" (FR19)
  - [ ] 6.5 Mesurar temps de càrrega inicial amb DevTools throttling 4G en un mòbil de gamma mitjana; objectiu < 3s
  - [ ] 6.6 Validar el flux complet de geolocalització en un mòbil real (iOS i Android)
  - [ ] 6.7 Validar que `/api/line_buses` no triga > 5s amb caché en fred (línies llargues)
  - [ ] 6.8 Verificar al dashboard de Firebase Billing que el cost del primer mes és **0 €**
  - [ ] 6.9 Redactar `README.md` amb: setup local, emulator, secrets, desplegament, troubleshooting
  - [ ] 6.10 Fer merge de la branca a `main` un cop tot validat
