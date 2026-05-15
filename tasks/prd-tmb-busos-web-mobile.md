# PRD: TMB Busos — Migració a web pública amb PWA mòbil

## 1. Introduction/Overview

L'aplicació TMB Busos és actualment una eina d'escriptori local: un servidor Python (`server.py`) que serveix una SPA monofitxer (`index.html`) i fa de proxy contra l'API pública de TMB. Per usar-la cal arrencar un `.bat` que llança Chrome a `localhost:8001`.

Aquest PRD descriu la migració a una **aplicació web pública** accessible per qualsevol usuari via URL HTTPS, amb un focus explícit en **dispositius mòbils**: l'app serà una **PWA instal·lable amb geolocalització**, perquè el cas d'ús més habitual del transport públic és consultar-lo des del mòbil, sovint a l'aire lliure abans de pujar a un bus.

L'objectiu és mantenir el 100% de la paritat funcional amb l'app actual i sumar tres millores específicament mòbil: **PWA instal·lable**, **parades a prop meu (geolocalització)** i **preferits**.

## 2. Goals

1. App accessible via URL pública HTTPS, sense cap arrencada local per part de l'usuari.
2. Paritat funcional 100% amb l'aplicació actual (pestanya "Proper bus", pestanya "Parades d'una línia" amb mapa, traçat real, posicions interpolades cada 20s).
3. PWA instal·lable al home screen d'iOS i Android.
4. Nova funcionalitat: **parades a prop meu** via geolocalització del dispositiu.
5. Nova funcionalitat: **preferits** (parades i línies habituals) emmagatzemats al dispositiu.
6. Treure les credencials de TMB del codi i no exposar-les mai al frontend.
7. Cost operatiu mensual: **0 €** (free tier de Firebase).

## 3. User Stories

1. **Com a viatger**, vull obrir l'app al mòbil i veure les parades a prop meu sense haver d'escriure cap codi, per saber d'on puc agafar un bus ara mateix.
2. **Com a usuari habitual**, vull marcar parades i línies com a favorites perquè no haig d'escriure el codi cada vegada que les consulto.
3. **Com a usuari de mòbil**, vull instal·lar l'app al home screen com si fos nativa per obrir-la d'un toc.
4. **Com a usuari**, vull saber quants minuts falten per al pròxim bus a una parada concreta.
5. **Com a usuari**, vull veure en un mapa per on circula una línia, quines parades fa i on són els busos ara mateix.

## 4. Functional Requirements

### 4.1 Paritat amb l'aplicació actual (no negociables)

1. **FR1**: L'app ha d'oferir una pestanya "Proper bus" on l'usuari introdueix un codi numèric de parada i veu el llistat de pròxims busos amb línia, destinació i minuts. Si `t-in-min == 0`, mostrar "Imminent".
2. **FR2**: L'app ha d'oferir una pestanya "Parades d'una línia" on l'usuari introdueix un nom de línia (`H10`, `V21`, `7`...). La cerca és case-insensitive (comparació uppercase).
3. **FR3**: A la pestanya de línia, mostrar un mapa Leaflet centrat a Barcelona amb tiles d'OpenStreetMap.
4. **FR4**: Per cada sentit (anada `A` / tornada `T`), dibuixar el traçat real com a polyline acolorida (`A` = blau `#1976d2`, `T` = taronja `#f57c00`).
5. **FR5**: Quan no hi ha traçat real, dibuixar una polyline discontínua que connecta les parades en ordre com a fallback visual.
6. **FR6**: Cada parada ha de ser un `circleMarker` amb tooltip amb `ORDRE`, `NOM_PARADA`, `CODI_PARADA` i sentit.
7. **FR7**: El mapa ha d'incloure una llegenda (`topright`) amb el color i nom de la parada terminal de cada sentit.
8. **FR8**: Mostrar el llistat textual de parades sota el mapa, agrupat per sentit amb capçalera `{Direcció} → {destí} ({N} parades)`.
9. **FR9**: Refrescar les posicions estimades dels busos cada **20 segons**, amb comptador descendent visible i barra de progrés.
10. **FR10**: Botó "Actualitza ara" que dispara el refresc immediat i reinicia el comptador.
11. **FR11**: Estimar la posició dels busos amb la fórmula `frac = (AVG - next_min) / AVG` amb `AVG = 2 min`, com a l'app actual. Només pintar bus si `next_min < AVG`. Si és la primera parada del sentit, pintar sobre la parada.
12. **FR12**: La icona del bus ha de ser un SVG orientat al rumb (bearing geogràfic entre la parada anterior i la de destí).
13. **FR13**: Tooltip del bus: línia, sentit, destí, pròxima parada i minuts restants.
14. **FR14**: Aturar el cicle de refresc quan l'usuari canvia de pestanya.
15. **FR15**: Tota la UI en català.

### 4.2 PWA instal·lable

16. **FR16**: Incloure un `manifest.json` amb `name`, `short_name`, `icons` (mínim 192x192 i 512x512), `theme_color` (`#cc0000`), `background_color`, `display: "standalone"`, `start_url`.
17. **FR17**: Registrar un Service Worker (`sw.js`) que cacheja els assets estàtics (HTML, CSS, JS, icones, manifest) per a funcionament offline.
18. **FR18**: Si l'usuari obre l'app sense connexió, mostrar la UI cachejada amb un missatge "Sense connexió" als panells que requereixen dades.
19. **FR19**: L'app ha de ser detectada com a "instal·lable" pels navegadors (Chrome, Edge, Safari iOS) — es valida amb Lighthouse PWA audit.
20. **FR20**: Icones de l'app en estètica TMB (vermell `#cc0000`).

### 4.3 Geolocalització: parades a prop meu

21. **FR21**: Afegir una tercera pestanya/secció "A prop meu" amb un botó "Cerca parades properes".
22. **FR22**: En clicar el botó, sol·licitar permís de geolocalització mitjançant `navigator.geolocation.getCurrentPosition`.
23. **FR23**: Si l'usuari denega el permís, mostrar un missatge clar amb instruccions per concedir-lo a la configuració del navegador.
24. **FR24**: Un cop obtinguda la posició, calcular la distància (Haversine) entre l'usuari i totes les parades de bus de Barcelona, i mostrar les 10 més properes ordenades per distància ascendent.
25. **FR25**: Cada parada de la llista mostra: nom, distància en metres, codi de parada. Clicar-la obre la pestanya "Proper bus" amb el codi pre-omplert i la cerca executada.
26. **FR26**: El catàleg complet de parades es descarrega del backend la primera vegada (cache al Service Worker) per evitar dependència del backend en càrregues posteriors.

### 4.4 Preferits

27. **FR27**: Botó "estrella" a cada resultat de cerca (parada o línia) per marcar/desmarcar com a favorit.
28. **FR28**: Pestanya/secció "Preferits" que llista parades i línies guardades, separades per tipus.
29. **FR29**: Clicar un preferit obre la pestanya corresponent ("Proper bus" o "Parades d'una línia") amb el codi pre-omplert i la cerca executada.
30. **FR30**: Preferits emmagatzemats al `localStorage` del dispositiu. Sense sincronització entre dispositius (sense backend de usuaris).
31. **FR31**: Cada preferit guarda: tipus (`stop` | `line`), codi, nom curt per mostrar.

### 4.5 Backend (proxy a TMB)

32. **FR32**: Exposar els 3 endpoints amb el **mateix contracte de resposta** que l'app actual:
    - `GET /api/stops/{stop_code}` — proxy directe a iBus
    - `GET /api/line/{line_name}` — agregat: línia + parades agrupades per sentit + traçat
    - `GET /api/line_buses/{line_name}` — posicions estimades dels busos
33. **FR33**: Afegir un quart endpoint nou: `GET /api/stops_catalog` — retorna tot el catàleg de parades de bus de Barcelona amb coordenades i codis, per a la funcionalitat de geolocalització.
34. **FR34**: Credencials TMB (`app_id`, `app_key`) llegides exclusivament de **Firebase Functions config** (`firebase functions:config:set tmb.app_id=... tmb.app_key=...`) o Secret Manager. Mai al codi font ni al frontend.
35. **FR35**: Concurrència per a `/api/line_buses`: crida les iBus de totes les parades en paral·lel (`Promise.all`), amb un límit configurable (per defecte 10 simultànies).
36. **FR36**: Si TMB falla en algun dels endpoints secundaris (p. ex. `/trajectes` no retorna), l'endpoint ha de continuar funcionant amb les dades disponibles (mateix comportament que `try/except` de l'app actual).

### 4.6 Caché

37. **FR37**: Caché in-memory dins el procés de la Cloud Function per a `/api/stops/{code}` amb TTL **10 segons**. Clau: `stop_code`.
38. **FR38**: Caché a **Firestore** (colecció `tmb_cache`) per a:
    - Catàleg de línies (`/v1/transit/linies/bus`) — TTL **24 hores**.
    - Parades d'una línia (`/v1/transit/linies/bus/{codi}/parades`) — TTL **24 hores**.
    - Trajectes d'una línia (`/v1/transit/linies/bus/{codi}/trajectes`) — TTL **24 hores**.
    - Catàleg complet de parades (per a FR33) — TTL **24 hores**.
39. **FR39**: La caché de Firestore guarda `{data: <resposta TMB>, expires_at: <timestamp>}`. En llegir, comprovar `expires_at` i invalidar si ha passat.

## 5. Non-Goals (Out of Scope)

1. **Sense autenticació d'usuaris**: l'app és anònima, els preferits viuen al dispositiu.
2. **Sense sincronització entre dispositius**: si l'usuari canvia de mòbil, perd els preferits.
3. **Sense notificacions push** ("el teu bus arribarà en 2 min"): pot ser una fase 2.
4. **Sense app nativa** (iOS/Android al store): només PWA.
5. **Sense multillenguatge**: només català.
6. **Sense rate limiting al backend**: amb pocs usuaris esperats i caché agressiva no és necessari per ara.
7. **Sense analytics ni mètriques de negoci**: només logs operatius bàsics.
8. **Sense back-office d'administració** ni invalidació manual de caché via UI.
9. **No es reescriu el càlcul de posició estimada del bus**: TMB segueix sense exposar GPS real; mantenim l'algorisme d'interpolació actual.

## 6. Design Considerations

### 6.1 Mobile-first

- L'app es dissenya **primer per a mòbil** i s'adapta a pantalles més grans, no al revés.
- Tipografia mínima llegible: `16px` per al cos en mòbil (evita zoom automàtic a iOS).
- Botons i àrees clicables: mínim **44x44 px** (recomanació d'Apple HIG) per a touch.
- Espais de marge generosos entre elements clicables.

### 6.2 Navegació

- A mòbil, navegació per **pestanyes inferiors** (bottom navigation bar) amb 4 seccions:
  1. "A prop meu" (icona ubicació)
  2. "Proper bus" (icona parada)
  3. "Línia" (icona ruta)
  4. "Preferits" (icona estrella)
- A escriptori, les mateixes seccions com a pestanyes superiors.

### 6.3 Estètica

- **Vermell TMB `#cc0000`** com a color primari (capçaleres, badges, theme color).
- Mode clar com a default. Mode fosc està **fora de l'scope d'aquest PRD** (es pot afegir més tard).
- Tipografia del sistema (`-apple-system, Segoe UI, Roboto, sans-serif`) per evitar càrrega de fonts externes.

### 6.4 Mapa Leaflet

- Mantenir Leaflet 1.9.4 servit per CDN (unpkg).
- Tiles d'OpenStreetMap.
- A mòbil, els controls de zoom han d'estar a una posició còmoda per al polze.

## 7. Technical Considerations

### 7.1 Stack

- **Frontend**: HTML, CSS, JavaScript **vanilla**, sense framework ni bundler. Fitxers separats:
  - `index.html` — estructura
  - `app.js` — lògica
  - `app.css` — estils
  - `sw.js` — Service Worker
  - `manifest.json` — manifest PWA
  - `icons/` — icones de l'app (192, 512)
- **Backend**: **Firebase Cloud Functions** amb Node.js 20. Un sol arxiu `functions/index.js` o organitzat en mòduls petits.
- **Hosting frontend**: **Firebase Hosting**.
- **Base de dades / caché persistent**: **Firestore** (per a la caché de catàleg).
- **Credencials**: `firebase functions:config:set tmb.app_id=... tmb.app_key=...` (o Secret Manager si es prefereix).

### 7.2 Estructura del repositori

```
/
├── public/                  # Frontend (servit per Firebase Hosting)
│   ├── index.html
│   ├── app.js
│   ├── app.css
│   ├── sw.js
│   ├── manifest.json
│   └── icons/
├── functions/               # Backend (Cloud Functions)
│   ├── index.js
│   ├── package.json
│   └── cache.js
├── firebase.json
├── .firebaserc
├── firestore.rules
└── README.md
```

### 7.3 Compatibilitat de contracte

Els 3 endpoints existents (`/api/stops/{code}`, `/api/line/{code}`, `/api/line_buses/{code}`) han de mantenir **exactament les mateixes claus de resposta** descrites a §4 de les especificacions originals. Això permet reutilitzar el codi del frontend sense reescriure'l.

### 7.4 Geolocalització: catàleg de parades al client

Per a la funcionalitat "a prop meu", el catàleg complet de parades (~3.000 parades a Barcelona) es descarrega del backend la primera vegada via `GET /api/stops_catalog` i es cacheja al Service Worker. El càlcul de distàncies (Haversine) es fa al navegador. Això evita haver de fer una query geoespacial al backend i fa la funcionalitat instantània un cop carregat el catàleg.

### 7.5 CORS

Frontend i backend al mateix domini de Firebase (`projecte.web.app`). Cloud Functions exposades sota `/api/*` via reescriptures de Firebase Hosting (`firebase.json`):

```json
{
  "hosting": {
    "rewrites": [
      { "source": "/api/**", "function": "api" }
    ]
  }
}
```

Així el frontend crida `/api/stops/1872` (mateix origen) i no hi ha problema de CORS.

### 7.6 Logs i observabilitat

- Cloud Functions ja registra logs a Firebase Console: latència, errors, invocacions.
- Afegir `console.log` als handlers amb status code de TMB i hit/miss del caché per debugar.

## 8. Success Metrics

1. **Accessibilitat**: l'app respon a una URL pública HTTPS sense necessitat de cap acció local per part de l'usuari. ✅ / ❌
2. **Paritat funcional**: les 15 FR del bloc 4.1 es comporten idènticament a l'app actual. Validat manualment. ✅ / ❌
3. **Cost**: factura mensual de Firebase **= 0 €** durant els primers 3 mesos d'operació. ✅ / ❌
4. **Rendiment mòbil**: la càrrega inicial de l'app (HTML + CSS + JS + manifest) ha de ser **< 3 segons** en una connexió 4G simulada (Chrome DevTools throttling) en un mòbil de gamma mitjana.
5. **PWA-isme**: Lighthouse PWA audit ha de donar **100/100** o, com a mínim, marcar l'app com "Installable".
6. **Geolocalització**: després de concedir el permís de GPS, la llista de parades més properes ha d'aparèixer en **< 2 segons**.

## 9. Open Questions

1. **Domini**: usem el subdomini gratuït `{projecte}.web.app` que dona Firebase, o comprem un domini propi? Aquest últim té cost anual (~10€).
2. **Consentiment GDPR / cookies**: la geolocalització requereix un banner de consentiment explícit? L'app no guarda dades de l'usuari al servidor, però sí accedeix a la seva ubicació al client.
3. **Política de privacitat**: cal redactar-la i enllaçar-la al peu de l'app (mínim per a PWA installable amb permís de geo).
4. **Quota TMB**: confirmar que l'`app_id` actual té quota suficient per al volum esperat. TMB té documentat el límit?
5. **Catàleg de parades complet**: TMB no exposa un endpoint únic amb totes les parades; caldria iterar línies i deduplicar parades. Cal validar el cost d'aquesta operació (es fa un cop al dia per la caché de 24h, però pot tenir un cost inicial).
6. **Icones de l'app**: cal dissenyar-les o reutilitzar logo existent? Si no n'hi ha, usem una icona genèrica de bus com a placeholder.
