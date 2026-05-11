# Handover-prompt voor de trimble-rechten-viewer sessie

Plak onderstaande tekst (alles onder de regel) als prompt in de sessie die je voor `trimble-rechten-viewer` hebt open staan. De prompt is zelf-bevattend.

---

In deze sessie staat het project `trimble-rechten-viewer` open — een Trimble Connect Workspace-API extensie (vanilla JS, single-file `index.html`) die folder-permissions en group/user access visualiseert.

We hebben in een aparte review-sessie het project tegen de officiële OpenAPI 3.0 spec van de Trimble Connect Core REST API gelegd. Het volledige review-rapport staat op:

- **Rapport**: `./REVIEW-vs-OpenAPI.md`
- **Spec ter referentie**: `../Trimble Connect API/openapi-spec` (YAML)

Voer de **drie P1-fixes** uit het rapport uit, in onderstaande volgorde.

## Fix 1 — Verwijder `/projects/{id}/folders` fallback (endpoint bestaat niet)

**Locatie**: `index.html:1362-1375`

De huidige code probeert `/projects/{tcProject.id}/folders` als fallback voor root-folder-discovery. Dit endpoint **bestaat niet** in de OpenAPI spec — er is alleen `/projects/{projectId}` (met `rootId` in de response). De fallback faalt altijd met 404, wordt geslikt, en daarna gooit de code "Root folder niet gevonden".

Verwijder de hele fallback-blok (regel 1362-1375). Vervang door een duidelijke gebruikersmelding wanneer `projData.rootId` ontbreekt:

```javascript
if (!rootFolderId) {
  throw new Error('Project heeft geen toegankelijke root folder. Controleer projectrechten of upload data handmatig.');
}
```

## Fix 2 — Verwijder `/projects/{id}/groups` fallback (endpoint bestaat niet)

**Locatie**: `index.html:1629`

De `groupEndpoints` array probeert twee endpoints:
```javascript
const groupEndpoints = [
  `/groups?projectId=${tcProject.id}`,
  `/projects/${tcProject.id}/groups`   // ← dit bestaat niet in spec
];
```

`/projects/{projectId}/groups` staat **niet** in de OpenAPI spec. De enige canonieke manier is `/groups?projectId={id}` (spec regel 3832-3856, `projectId` is required query parameter).

Verwijder de tweede entry. Aangezien er dan nog maar één endpoint over is, kun je ook de `for`-loop opruimen:

```javascript
let groups = [];
try {
  const result = await tcFetchPaginated(`/groups?projectId=${tcProject.id}`);
  if (Array.isArray(result)) groups = result;
} catch (e) {
  console.warn('[TC] Groepen ophalen mislukt:', e.message);
}
```

(Overweeg `tcFetchPaginated` te vervangen door `tcFetch` voor deze call — de spec definieert geen pagination op `/groups`. Zie P2 in het rapport, optioneel.)

## Fix 3 — Implementeer `/regions` discovery (vervangt hardcoded regio's)

**Locatie**: `index.html:1058-1067` (hardcoded `TC_API_REGIONS` constant)

Het bestaande commentaar in de code (regel 1058-1061) erkent dit al als verbeterpunt. Probleem: **AP2 (`app32.connect.trimble.com`)** ontbreekt, dus AP2-projecten breken silent.

Kopieer de `_discoverRegionBase` functie uit **`../tc-viewer/index.html` regel 1031-1076** en pas aan:
- Naam: kan hetzelfde blijven.
- `cacheKey`: verander naar `'rechten-viewer-regions'` zodat het niet conflicteert met tc-viewer.
- Aliassen: voeg AP2-variant toe (`'asia-pacific 2'`, `'ap2'`).
- Roep aan in `initTCExtension` (rond regel 1270 waar `tcProject.location` wordt verwerkt) en vervang de huidige lookup:

```javascript
// Vóór: TC_API_BASE = TC_API_REGIONS[loc] || TC_API_REGIONS['europe'];
const discovered = await _discoverRegionBase(tcProject.location);
TC_API_BASE = discovered || TC_API_REGIONS[loc] || TC_API_REGIONS['europe'];
```

Behoud `TC_API_REGIONS` als fallback voor wanneer `/regions` faalt.

**Spec-referentie**: `openapi-spec:5373-5391` (`/regions` GET, geen auth nodig per `security: []`, maar Bearer-token meegeven werkt ook).

## Verificatie

1. **Fix 1**: open een project. Als `projData.rootId` direct werkt (in de meeste projecten), gebeurt er niks merkbaar. Maar bij een corrupt project zie je nu een duidelijke melding in plaats van een silent break.
2. **Fix 2**: open een project met groepen. In de console verschijnt `[TC] Groepen opgehaald via /groups?projectId=...`. Géén `[TC] Groepen endpoint mislukt: /projects/...` warning meer.
3. **Fix 3**: test met een EU-project (default), een NA-project (location `"northAmerica"`), en idealiter een AP2-project. In de console verschijnt `[TC] Regions ontdekt: N` en `TC_API_BASE` wijst naar de juiste host. Check via `localStorage.getItem('rechten-viewer-regions')` dat de cache wordt gevuld.

## Niet in scope

P2- en P3-bevindingen (v2.1 folder-items switch, retry-logica, region key-mismatch) — laat staan tenzij je expliciet wilt opruimen. Die kunnen in een latere ronde.

Maak één commit per fix. Push pas na live-test in minstens 2 regio's.
