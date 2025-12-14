# Roadmap EasyCamper

## Mappa & Mapbox

- [x] Estrarre token Mapbox dal codice in file di config/env dedicato (`lib/mapbox_config.dart` + `.env` / `MAPBOX_ACCESS_TOKEN`).
- [x] Esporre metodo `centerOn(LatLng target)` su `EasyCamperMapState` per permettere alla UI di recentrare la camera.
- [x] Implementare centratura sulla posizione reale (geolocalizzazione) su iOS/Android via `geolocator`:
  - richiesta permessi
  - centratura iniziale dopo login/apertura
  - pulsante "my_location" per recenter.
- [ ] Attivare search bar "Cerca destinazioni o servizi" sulla mappa (senza usare servizi Mapbox a pagamento):
  - digitazione testo + suggerimenti basati sulle nostre API / index full‑text (no Mapbox Geocoding/Places API)
  - ricerca spot attorno alla posizione corrente (stile Park4Night) usando i nostri endpoint backend
  - filtri combinati con `SpotFilters`/BBOX corrente
  - UX mobile first.
- [ ] Ottimizzazioni stile/performance mappa (usiamo solo le mappe base Mapbox, nessun servizio a consumo):
  - clustering simboli/marker implementato lato client
  - debounce caricamento spot su `onCameraIdle`
  - uso di immagini custom per marker (sprite/icon sheet nostre, nessun asset premium).

## Security & Account (vedi README)
- [x] Audit log login/logout/revoca device.
- [x] Tracking IP/fingerprint per `RefreshToken`.
- [ ] Endpoint REST admin per audit log.
