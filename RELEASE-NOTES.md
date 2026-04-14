# Rechten Viewer — Release Notes

---

## Versie 1.1 — 9 april 2026

### Schrijfrechten fix

**Wat was het probleem?**
Schrijfrechten (Full Access) werden niet correct weergegeven in de Rechten Viewer. Mappen waar groepen of gebruikers schrijfrechten op hadden, toonden deze als leesrechten of helemaal niet. Dit gold voor het hele project — circa 593 mappen waren getroffen.

**Oorzaak**
De Trimble Connect API gebruikt de sleutel `FULL_ACCESS` voor schrijfrechten. De Rechten Viewer herkende deze sleutel niet, waardoor alle schrijfrechten verloren gingen bij het verwerken van de data.

Daarnaast werden overgeerfde rechten (inherited permissions) niet altijd meegenomen. Als een map directe rechten had voor groep A, werden overgeerfde rechten voor groep B genegeerd.

**Wat is er opgelost?**
- `FULL_ACCESS` wordt nu correct herkend als schrijfrecht
- Directe en overgeerfde rechten worden samengevoegd (merged) per map
- Bij een overlap wint het hoogste recht (Full Access boven Read)
- Rechten worden correct doorgegeven aan submappen die geen eigen rechten hebben

**Resultaat**
- 593 mappen tonen nu correct schrijfrechten (was 0)
- 134 groepen worden herkend in de rechtenstructuur (was 44)
- De rechtenweergave komt nu overeen met wat Trimble Connect zelf toont

---

## Versie 1.0 — maart 2026

Eerste versie van de Rechten Viewer met de volgende functionaliteit:

- Dashboard met samenvatting van het project
- Rechtenweergave per groep, per gebruiker en per map
- Excel export van de rechtenmatrix
- Detectie van onbereikbare mappen (alleen via directe link)
- Werkt als Trimble Connect Extension (sidebar) en standalone
- Uitleg hoe het Trimble Connect rechtenmodel werkt

---

## Testomgeving

Getest in het **Trimble Trainingproject** (regio Europa, ~2280 mappen, 59 gebruikers, 138 groepen).

## Disclaimer

Deze tool is ontwikkeld door At Fielt als hulpmiddel voor het inzichtelijk maken van rechten in Trimble Connect. De ontwikkelaar is geen professioneel softwareontwikkelaar. Gebruik is op eigen risico — controleer belangrijke rechten altijd ook in Trimble Connect zelf.

---

*[At Fielt](https://bimplementeer.nl)*
