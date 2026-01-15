# Roadmap EasyCamper

- [x] Nuova app Flutter (progetto root) con schermata Mappa
  - [x] Integrazione Mapbox su iOS (mappa reale, build in Release, permessi Info.plist sistemati)
  - [x] Gestione filtri mappa (tipologia parcheggi, servizi, rating minimo, raggio, tipologia) con pannello apri/chiudi
  - [x] Caricamento POI da backend tramite `/api/spots` con fallback a `mock_data/spot.json`
  - [x] Mock su macOS: placeholder/preview mappa al posto della mappa + caricamento POI da `mock_data/spot.json`
  - [x] Lista / card POI su desktop (macOS) con tap → dettaglio
  - [x] Funzione dettaglio POI riusabile (da lista/card e da marker)
  - [x] Collegamento tap marker Mapbox → apertura dettaglio POI (card bassa + bottom sheet)
  - [x] Nuova UI filtri come card centrata sopra la mappa (responsive desktop/mobile)
  - [x] Badge sull’icona filtri quando ci sono filtri attivi
  - [ ] Verifica licenze Mapbox: usare solo mappe base/tiles e SDK client, nessun servizio aggiuntivo a pagamento (geocoding, routing, search, ecc.). Servizi avanzati saranno implementati con la nostra logica/backend o altri provider free.

- [ ] Mappa: completare filtri e card spot
  - [ ] Estendere `mock_data/spot.json` con `services` e `rating` coerenti con il pannello filtri
  - [ ] Applicare filtri `services` e `rating` anche sui mock (desktop e fallback mobile)
  - [x] Arricchire la card bassa spot con tipo area, rating (stelline) e 2–3 icone servizi principali
  - [x] Preview foto nella card bassa spot (stile Park4Night) con prefetch dettagli spot e cache in-memory

- [ ] Schermata Profilo utente
  - [x] Mostrare email utente letta da `AuthState` (session.email) in `ProfileScreen`
  - [x] Passare l'email corrente come `initialEmail` a `PersonalDataScreen` per precompilare i dati
  - [x] Mostrare anche il nome/username (`session.username`) al posto dell'UUID quando disponibile
  - [ ] Consentire all'utente di impostare/modificare il proprio nickname/username dal profilo/dati personali (endpoint backend + UI)
  - [ ] Creare `ProfileScreen` (tab Profilo) con layout base dark in linea con login/mappa
  - [ ] Aggiungere pulsante Logout in fondo (spostato qui dalla mappa)

- [x] Gestione veicoli e libreria modelli
  - [x] Backend: modello `VehicleModel` e tabella `VehicleModels`
    - [x] Definita tabella `VehicleModels` (brand, model, year_from, length_m, height_m, weight_kg, type, brand_slug)
    - [x] Model Sequelize `VehicleModel` registrato in `server/models`
    - [x] Seed iniziale da `server/easycamper/server/data/vehicle_models.json` tramite `server/sync.js` (upsert idempotente)
    - [x] API `GET /api/vehicle-models?search=&brand=&limit=&offset=` con paginazione e test Jest/Supertest
  - [x] Backend: integrazione `Vehicles` ↔ `VehicleModels`
    - [x] Aggiunto campo opzionale `vehicleModelId` al model `Vehicle` e associazione `belongsTo(VehicleModel)`
    - [x] Estese le route `/vehicles` (POST/PUT) per accettare `vehicleModelId` e, se `length/height/weight` mancano, ereditare i valori dal `VehicleModel` associato
    - [x] Test Jest/Supertest per integrazione `/vehicles` ↔ `VehicleModels` (`server/__tests__/vehicles.vehicleModel.test.js`)
  - [ ] App Flutter: integrazione libreria modelli nel form veicolo
    - [x] Creato client `lib/api/vehicle_models_api.dart` con DTO `VehicleModelDto` per `/api/vehicle-models`
    - [x] Aggiunta schermata `VehicleModelSearchScreen` per cercare modelli (marca/modello) e selezionarne uno
    - [ ] Integrata `VehicleModelSearchScreen` in `vehicle_form_screen.dart` con pulsante "Cerca modello dal catalogo" che precompila marca/modello/dimensioni/peso in base al modello scelto (disattivato: ora inserimento manuale)
  - [x] App Flutter: veicoli (flusso manuale)
    - [x] Campi tecnici obbligatori e validati in UI (lunghezza/altezza/larghezza/peso) per navigazione camper-aware
    - [x] Immagine veicolo opzionale in "I miei veicoli" con salvataggio locale (SharedPreferences) e preview in lista
    - [x] Pulizia automatica immagine in SharedPreferences quando un veicolo viene eliminato

- [x] Navigazione verso POI (UI)
  - [x] Fix UI: testo bianco su bottone "AVVIA NAVIGAZIONE"
  - [x] Blocco avvio navigazione se non esiste almeno 1 veicolo salvato: redirect a "I miei veicoli" per aggiungerlo

- [x] Scheda POI (dettaglio spot)
  - [x] Visualizzare scheda dettaglio spot con titolo, descrizione, servizi (Amenities) e sezione Reviews
  - [x] Aggiungere schermata `SpotReviewsScreen` con elenco recensioni da backend
  - [x] Aggiungere azioni **Modifica/Elimina** (menu ⋮) **solo per spot creati dall’utente** (UX minimale, conferma delete + form edit base)
  - [ ] Ownership reale: far restituire dal backend `userId`/`ownerId` in `GET /spots` e `GET /spots/:id` e mappare in `SpotDto` per abilitare correttamente Modifica/Elimina (senza euristiche client)
  - [ ] Estendere la modifica spot: supportare anche tipo, servizi e posizione (oltre a nome/descrizione)
  - [ ] Collegare il rating medio e il conteggio recensioni a dati reali da backend (`/spots/:id` + `/spots/:id/reviews`), sostituendo valori mock residui

- [x] Gestione foto spot / POI
  - [x] Decidere soluzione storage per le foto (S3 compatibile: Cloudflare R2)
  - [x] Definire API upload file (route `POST /api/uploads`) e integrazione storage S3-compatible (Cloudflare R2)
  - [x] Supporto foto su spot: salvataggio e lettura lista foto nello spot (DTO + UI dettaglio + preview in mappa)
  - [x] Supporto foto su recensioni: migration + model `SpotReview` con campo foto e gestione in route spots
  - [x] Aggiornare configurazione env per URL pubblici Cloudflare R2 (`S3_PUBLIC_BASE_URL`)
  - [x] Collegare creazione spot (`POST /spots`) al salvataggio delle foto selezionate in `AddSpotScreen` (presigned PUT → public URL → commit su spot)

- [x] Schermata inserimento spot (AddSpotScreen)
  - [x] Creare schermata `AddSpotScreen` con layout ispirato al mock Figma: titolo, hero mappa/posizione (placeholder), descrizione, sezione amenities a card e sezione photos
  - [x] Collegare il pulsante "Aggiungi spot" sulla mappa all'apertura di `AddSpotScreen`
  - [x] Gestire selezione servizi con lista completa in bottom sheet + pilloline di riepilogo sulla schermata principale
  - [x] Gestire selezione posizione in modalità mock: "Usa mia posizione (mock)" + "Scegli sulla mappa (mock)" con coordinate predefinite
  - [x] Integrare anteprima mappa/posizione reale: usare posizione corrente (GPS) o tap sulla mappa per settare lat/lng dello spot
  - [x] Definire payload `POST /spots` (inclusi lat/lng, tipo, servizi, foto) e relativa route backend
  - [x] Collegare `AddSpotScreen` al backend (`POST /spots`) e ricaricare i POI sulla mappa dopo inserimento riuscito

- [ ] Backend: stabilizzare infrastruttura test (Jest + Sequelize)
  - [ ] Verificare e documentare DB usato in produzione vs test (Postgres in produzione, SQLite in test) e motivazioni
  - [ ] **Decisione DB per i test**: scegliere tra
    - [ ] SQLite in-memory (massima velocità, ma differenze SQL/dialect)
    - [ ] Postgres in Docker (più lento, ma fedele a produzione)
  - [ ] **Verifica stack attuale**: controllare cosa usiamo davvero in produzione (ENV/compose) e in base a quello procedere
    - [ ] Se produzione = Postgres → impostare default test su Postgres Docker (E2E) e mantenere SQLite solo per unit test veloci
    - [ ] Se produzione = SQLite → uniformare e rimuovere dipendenze Postgres-specific (es. `ILIKE`)
  - [ ] Centralizzare bootstrap DB per i test in `server/jest.setup.js` (una sola init + `sequelize.sync({ force: true })` quando serve)
  - [ ] Rendere i test idempotenti: cleanup sicuro anche se `beforeAll` fallisce (evitare `where: { id: undefined }`)
  - [x] Eliminare flakiness dovuta a inizializzazioni multiple dei modelli/Sequelize (caricamento dei modelli una volta, evitare side effect a import-time)
  - [ ] Fix query cross-dialect (SQLite vs Postgres): rimuovere `Op.iLike` (Postgres-only) in `/api/vehicle-models` e usare strategia compatibile (es. `lower(col) LIKE lower(:q)` con `Sequelize.fn`) oppure condizionale per dialect
  - [ ] Allineare configurazioni `server/config/config.js` e `server/config/config.json` (evitare doppie fonti divergenti)
  - [x] Definire modalità E2E: SQLite file-based oppure Postgres via `server/docker-compose.test.yml` (documentare e automatizzare)
  - [x] Supportare run test su Postgres anche senza `DATABASE_URL` (fallback a config quando `TEST_DB=postgres`)
  - [x] Fix script `cleanupRefreshTokens.js` + test (unit/E2E) per pulizia token scaduti deterministica

- [ ] Backend: Avatar utente privato (GDPR-friendly)
  - [ ] Aggiungere campo `avatar_key` (nullable) su `User`
  - [ ] Endpoint: `POST /users/me/avatar/presigned-upload` (genera key privata e URL di upload)
  - [ ] Endpoint: `POST /users/me/avatar/confirm` (fa HEAD sullo storage e salva `avatar_key` solo se l’oggetto esiste)
  - [ ] Endpoint: `GET /users/me/avatar/presigned-download` (URL firmata a scadenza breve)
  - [ ] Endpoint: `DELETE /users/me/avatar` (idempotente: rimuove file + azzera `avatar_key`)
  - [ ] Integrare cancellazione dati utente: eliminare anche l’avatar dallo storage in fase di delete account
  - [ ] Test: suite dedicata per avatar (happy path + errori + privacy: accesso solo al proprietario)

- [ ] Integrazione con API esterne per meteo e traffico
- [ ] Implementazione sistema di notifiche push
- [ ] Ottimizzazione performance e riduzione consumo batteria
- [ ] Test e debug su dispositivi Android
- [ ] Pubblicazione su App Store e Google Play
- [ ] Allineare UI auth Flutter al design Figma/Stitch
  - [ ] Schermata `EC_login` (LoginScreen): layout, sfondi, immagine hero, bottoni social
  - [ ] Schermata `EC_registrazione_nuovo_utente` (RegisterScreen): ordine campi, bottoni social, stile card
  - [ ] Flusso reset password (`EC_password_reset`, `EC_mail_sent_password`): testi e layout