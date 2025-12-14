# Progetto Frontend & Integrazione API

// ...existing code...

## API Mappa & POI – Contratto per Flutter/Web

### GET /spots

Recupera la lista di spot/POI visibili nella viewport corrente, con filtri parcheggio/servizi.

**Query params**
- `bbox` (string, obbligatorio): `latMin,lngMin,latMax,lngMax`
- `types[]` (array, opzionale): lista di tipi parcheggio.
- `services[]` (array, opzionale): lista di servizi richiesti.
- `minRating` (number, opzionale): rating minimo (es. 3, 4, 4.5).
- `page` (number, opzionale): default 1.
- `limit` (number, opzionale): default 50, max 200.

**Esempio richiesta**
`GET /spots?bbox=45.0,9.0,45.5,9.5&types[]=area_camper_gratuita&services[]=electricity&services[]=water&minRating=4&page=1&limit=50`

**Response 200**
```json
{
  "page": 1,
  "limit": 50,
  "total": 123,
  "spots": [
    {
      "id": "spot_123",
      "name": "Area Camper Lago Quieto",
      "shortDescription": "Area camper gratuita in riva al lago, molto tranquilla di notte.",
      "latitude": 45.12345,
      "longitude": 9.23456,
      "type": "area_camper_gratuita",
      "ratingAverage": 4.6,
      "ratingCount": 37,
      "services": {
        "electricity": true,
        "water": true,
        "wc": true,
        "showers": false,
        "wifi": false,
        "petsAllowed": true
      },
      "tags": ["tranquillo", "panoramico"]
    }
  ]
}
```

### GET /spots/:id

Recupera il dettaglio completo di uno spot per popup/scroll di dettaglio.

**Esempio richiesta**
`GET /spots/spot_123`

**Response 200**
```json
{
  "id": "spot_123",
  "name": "Area Camper Lago Quieto",
  "shortDescription": "Area camper gratuita in riva al lago, molto tranquilla di notte.",
  "description": "Area camper proprio in riva al lago, fondo pianeggiante, ombreggiata. Ideale per soste di 1-2 notti. Alcune piazzole sono leggermente in pendenza.",
  "latitude": 45.12345,
  "longitude": 9.23456,
  "type": "area_camper_gratuita",
  "ratingAverage": 4.6,
  "ratingCount": 37,
  "services": {
    "electricity": true,
    "water": true,
    "wc": true,
    "showers": false,
    "wifi": false,
    "petsAllowed": true,
    "wasteDisposal": true,
    "blackWater": true,
    "laundry": false,
    "lpg": false
  },
  "tags": ["tranquillo", "panoramico", "vicino_autostrada"],
  "photos": [
    { "url": "https://cdn.easycamper.app/spots/spot_123_1.jpg", "caption": "Vista dal lago" },
    { "url": "https://cdn.easycamper.app/spots/spot_123_2.jpg", "caption": "Piazzole" }
  ],
  "openingHours": "Sempre aperto",
  "priceInfo": "Gratuito, donazione facoltativa",
  "lastUpdate": "2025-07-26T10:15:00.000Z"
}
```

**Note implementative**
- I nomi dei campi sono pensati per essere usati direttamente in Flutter (`map_screen.dart`, `spot_marker.dart`, `filters_panel.dart`).
- Il backend può estendere `services` e `tags` in futuro senza rompere il contratto.

---

## Convenzioni per file di test (backend + Flutter)

Per distinguere chiaramente ambiente di test e di produzione, TUTTI i file di test seguono la nomenclatura `*.test.*`:

- Backend Node (Jest):
  - `server/__tests__/route.test.js`
  - `server/__tests__/auth.test.js`
  - `server/__tests__/spots.test.js` (nuovo, per /spots)
- Flutter/Dart:
  - `test/map_screen_test.dart`
  - `test/spot_marker_test.dart`
  - `test/filters_panel_test.dart`

Questa convenzione va mantenuta per tutte le nuove suite di test (sia backend che Flutter/web) per rendere immediata la distinzione dai file di produzione.

// ...existing code...