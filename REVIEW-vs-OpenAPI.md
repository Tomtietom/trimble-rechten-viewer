# Review trimble-rechten-viewer vs Trimble Connect OpenAPI spec

**Spec**: `../Trimble Connect API/openapi-spec` (OpenAPI 3.0, v2.0/v2.1)
**Reviewed**: hoofdbestand `index.html`
**Datum**: 2026-05-11

## Samenvatting

Functioneel werkend, maar heeft drie endpoints die per spec **niet bestaan** (dead code als fallbacks), en mist `/regions` discovery die expliciet in een code-comment al genoemd wordt. Verder solide token-handling en pagination. Volgorde van fixes hieronder is gericht.

## Bevindingen (gerangschikt)

### P1 — Fallback endpoint `/projects/{id}/folders` bestaat niet in spec

**Locatie**: `index.html:1365`

```javascript
const folders = await tcFetch(`/projects/${tcProject.id}/folders`);
```

**Spec**: er is **geen** `/projects/{projectId}/folders` endpoint. De project-paths in de spec zijn (`openapi-spec` paths-overzicht):
- `/projects/{projectId}` (regel 4608)
- `/projects/{projectId}/image, /license, /metrics, /objects, /roles, /settings, /status, /users, /users/{userId}`

Geen `/folders` onder `/projects/{projectId}`. De root folder hoort uit `GET /projects/{projectId}` als `rootId` te komen (`openapi-spec:4420` geeft `rootId: "c3IGIU_sAJA"` als response-voorbeeld) — wat de primaire pad in de code al doet (regel 1357).

**Risico**: de fallback faalt met 404, wordt door de `try/catch` geslikt, en daarna gooit de code "Root folder niet gevonden" (regel 1377). Dat betekent: als om welke reden dan ook `rootId` niet in de `/projects/{id}` response zit, **breekt de viewer altijd**.

**Fix**: verwijder de fallback (regel 1362-1375). Bij ontbrekende `rootId` direct een duidelijke melding tonen aan de user dat het project geen toegankelijke root heeft. Of: verifieer empirisch of `projData.rootId` in alle response-vormen aanwezig is — voor zover de spec laat zien is dat in v2.0 het geval.

---

### P1 — Fallback endpoint `/projects/{id}/groups` bestaat niet in spec

**Locatie**: `index.html:1629`

```javascript
const groupEndpoints = [
  `/groups?projectId=${tcProject.id}`,
  `/projects/${tcProject.id}/groups`   // ← bestaat niet
];
```

**Spec**: `openapi-spec:3832-3856` (`/groups` GET) is de canonieke manier om groepen op te halen, met `projectId` als **required query parameter**. Geen `/projects/{projectId}/groups` pad in de spec.

**Risico**: identiek aan P1 #1 — fallback faalt met 404 en wordt geslikt. Geen functioneel effect (de primaire endpoint werkt), maar het is dead code die de loop nodeloos verlengt en bij debugging een verkeerd spoor geeft ("er zijn 2 endpoints" → ontwikkelaars gaan tijd verspillen aan de tweede).

**Fix**: verwijder de tweede entry uit `groupEndpoints` (regel 1629). Het feit dat alleen `/groups?projectId=X` overblijft maakt het ook helderder dat dit geen pagination-loop hoeft te zijn (zie P2 hieronder).

---

### P1 — Region hardcoded, geen `/regions` discovery

**Locatie**: `index.html:1058-1067`

```javascript
const TC_API_REGIONS = {
  'europe':  'https://app21.connect.trimble.com/tc/api/2.0',
  'north america': 'https://app.connect.trimble.com/tc/api/2.0',
  'asia':    'https://app31.connect.trimble.com/tc/api/2.0',
};
```

De code-comment (regel 1058-1061) noemt dit zelf al als verbeterpunt: *"bij een vierde regio of hostname-rename is de canonieke aanpak: GET /regions"*.

**Spec**: `openapi-spec:5373-5391` (`/regions` GET, geen auth nodig, `security: []`). De PROD-regio `app32.connect.trimble.com` (AP2) staat al in de servers-lijst (`openapi-spec:23-24`) maar **ontbreekt in `TC_API_REGIONS`** — AP2-projecten breken nu silent.

**Risico**: P1 zodra een gebruiker een AP2- of toekomstige regio-project probeert te openen.

**Fix**: pattern uit `tc-viewer/index.html:1031-1076` overnemen (`_discoverRegionBase`). Werkwijze:
1. Eerste keer GET `https://app.connect.trimble.com/tc/api/2.0/regions` (zonder Auth nodig per spec, maar mét Authorization zoals tc-viewer doet werkt ook).
2. Cache 24u in `localStorage`.
3. Match `tcProject.location` (lowercased) tegen `region.id`/`region.location` met alias-tabel (`europe` ↔ `eu`, `north america` ↔ `na`/`us`, `asia` ↔ `ap`, etc.).
4. Bij faal: behoud huidige hardcoded fallback maar log warning.

De rechten-viewer en tc-viewer zijn beide vanilla-JS extensies — de functie kan grotendeels gekopieerd worden. Naam: pas `cacheKey` aan naar `'rechten-viewer-regions'` om geen state te delen.

---

### P2 — `tcFetchPaginated` op `/folders/{id}/items` (v2.0) — Range-header onzeker

**Locatie**: `index.html:1565`

```javascript
const items = await tcFetchPaginated(`/folders/${id}/items`);
```

`tcFetchPaginated` (regel 1505-1549) zet altijd `Range: items=0-99` header.

**Spec**: `openapi-spec:3698-3734` (v2.0 `/folders/{folderId}/items`) — response is `200` met array, geen `206` response gedefinieerd, geen Range-parameter gedocumenteerd. De top-level spec-beschrijving zegt wel *"All collections/lists support a Range header"*.

**Risico**: gemengd:
- Wanneer server 200 (volledige lijst) teruggeeft → `Content-Range` header ontbreekt → `hasMore = false` (regel 1546) → loop stopt na 1 page. **Werkt correct** voor folders ≤ default-size.
- Wanneer server 206 (gepaginate) teruggeeft → loop werkt prima.
- Wanneer server Range silently negeert en alleen eerste 100 stuurt zonder Content-Range → loop stopt na 100, grote folders **afgekapt**. Empirisch testen vereist.

**Fix-aanbeveling**: switch naar v2.1 cursor-paginated `/2.1/folders/{folderId}/items` (`openapi-spec:244-353`, max `pageSize=500`). Dat is expliciet gepaginate en de spec garandeert `links.next.href` semantics.

```javascript
async function tcFetchFolderItemsV21(folderId) {
  const all = [];
  let skipToken = null;
  for (let page = 0; page < 100; page++) {
    const qp = '?pageSize=500' + (skipToken ? '&skipToken=' + encodeURIComponent(skipToken) : '');
    const resp = await tcFetch('/2.1/folders/' + folderId + '/items' + qp);
    const items = resp.items || resp;  // spec geeft array, sommige TC versies wrappen
    if (Array.isArray(items)) all.push(...items);
    const nextHref = resp.links && resp.links.next && resp.links.next.href;
    if (!nextHref) break;
    const m = /[?&]skipToken=([^&]+)/.exec(nextHref);
    skipToken = m ? decodeURIComponent(m[1]) : null;
    if (!skipToken) break;
  }
  return all;
}
```

(NB: `TC_API_BASE` eindigt nu op `/tc/api/2.0` — voor v2.1 moet de base `/tc/api` worden, en `/2.1/...` als pad. Pas die strategie aan vóór deze fix.)

---

### P2 — `tcFetchPaginated` op `/groups` en `/groups/{id}/users` is overkill

**Locaties**: `index.html:1633` (groups) en `1655` (group members)

**Spec**:
- `/groups` GET (`openapi-spec:3832-3894`) — response `200` array, geen pagination-parameters of -response gedocumenteerd.
- `/groups/{groupId}/users` GET (`openapi-spec:3986-4011`) — response `200` array, geen pagination-parameters.

**Risico**: laag. Range-header wordt vermoedelijk genegeerd; server geeft volledige array; `Content-Range` ontbreekt; loop stopt na 1 page. Werkt — alleen onnodige complexity.

**Fix**: gebruik `tcFetch` (zonder Range-loop) voor deze twee endpoints. Spaart code-complexiteit en maakt het duidelijker dat het geen paginated calls zijn.

---

### P2 — Geen retry op 429 / 5xx

**Locatie**: `tcFetch` (regel 1485-1503) en `tcFetchPaginated` (regel 1505-1549)

**Observatie**: 401 wordt afgehandeld met één token-refresh + retry. 429 (rate-limit) en 5xx (server-error) gooien gewoon een error.

**Spec**: niet expliciet voorgeschreven, maar het algemene 429-Retry-After patroon is standaard en zit al in zowel `tc-viewer/index.html:1120-1180` als `trimble-mcp-server/src/trimble/_http.ts:84-103`.

**Risico**: bij rate-limiting (tegelijk 20 parallel permission-requests, regel 1601) gaat een batch volledig stuk.

**Fix**: kopieer het retry-patroon uit tc-viewer of trimble-mcp-server (exponential backoff, Retry-After parsing). Maak het generiek in `tcFetch` zodat `tcFetchPaginated` het automatisch erft.

---

### P3 — Hardcoded camelCase region-key mismatch

**Locatie**: `index.html:1062-1067` (key `'north america'` met spatie) vs spec response `location: "northAmerica"` (camelCase, `openapi-spec:4425`)

**Risico**: laag, want huidige selectie gebruikt waarschijnlijk een UI-string. Maar als rechten-viewer in een NA-project geopend wordt en `tcProject.location` is `"northAmerica"`, dan faalt de lookup en valt de code stilletjes terug op `europe` default (regel 1067).

**Fix**: normaliseer beide kanten (project location camelCase → spaced lowercase) of voeg directe alias toe. Wordt overbodig zodra P1 #3 (`/regions` discovery) is toegepast — dan komt de match uit live data.

---

### Informatief — Wel goed gedaan

- **Token-refresh** met JWT exp-check + 60s margin + 401-retry (regel 1448-1467, 1494-1497) — match met tc-viewer.
- **Pagination dedup** op `id` (regel 1530-1536) — voorkomt double-counting bij overlappende ranges.
- **`/folders/fs/{folderId}/permissions`** (regel 1603) — pad klopt met spec regel 3222.
- **`/projects/{id}/users` met Range header** via `tcFetchPaginated` (regel 1620) — spec ondersteunt dit (regel 5184-5238, response 206).
- **`/groups?projectId={id}`** (regel 1628) — match met spec regel 3832-3856, query-param `projectId` is required en correct meegegeven.
- **`/groups/{groupId}/users`** (regel 1655) — match met spec regel 3986.
- **Batching van permission-calls** (20 parallel, regel 1601) — pragmatisch, maar zie P2-retry hierboven.
- **Workspace API auth-flow** met event-listener fallback (regel 1121-1149) — robuust.

## Aanbevolen vervolgactie

1. **P1 #1** — verwijder `/projects/{id}/folders` fallback. Eenregelig.
2. **P1 #2** — verwijder tweede entry uit `groupEndpoints`. Eenregelig.
3. **P1 #3** — implementeer `/regions` discovery. Code uit tc-viewer overnemen (~50 regels).
4. **P2 #1** — switch naar v2.1 `/2.1/folders/{id}/items` met cursor. Vereist `TC_API_BASE` refactor.
5. **P2 #3** — voeg 429/5xx retry toe aan `tcFetch`. Patroon uit trimble-mcp-server overnemen.
