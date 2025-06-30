# EasyCamper – Roadmap & Checklist (Aggiornata al 30/06/2025)

## 0. Vision
«Un’unica app per camperisti con routing “camper-aware”, community spot, filtri avanzati, prezzi carburante in tempo reale e navigazione integrata in-car».

---

## 1. Infra & Sharding – COMPLETATO
- [x] **VPS IONOS unico nodo (8 GB RAM)**
  - **Stato:** L'infrastruttura Docker è stata creata, testata e validata.
- [x] **Definizione e creazione Shard**
  - **Stato:** Completato. Il sistema è stato suddiviso in **5 shard** per una distribuzione ottimale del carico.
  - **Shard di Produzione (`/shards`):** `europa-nord`, `europa-centro`, `europa-ovest`, `europa-sud`, `europa-sud-est`.
  - **Shard di Test (`/assets/data`):** `nord`, `centro`, `ovest`, `sud`, `sud-est`.
- [x] **Importazione e Caching GraphHopper**
  - **Stato:** Completato. L'importazione per tutti e 5 gli shard è automatizzata tramite `docker-compose`. Le cartelle `graph-cache` vengono generate e caricate correttamente.

---

## 2. Routing Multi-Shard – COMPLETATO
- [x] **Architettura di Routing Custom**
  - **Stato:** Completato. È stata implementata un'architettura custom robusta per gestire percorsi che attraversano più shard.
  - **Componenti Chiave:**
    - **`Orchestrator`:** Un servizio Node.js dedicato che riceve le richieste, interroga gli shard necessari e "cuce" insieme i segmenti di percorso.
    - **`NGINX`:** Funge da reverse proxy, smistando il traffico verso l'orchestrator.
    - **`server/utils/shardUtils.js`:** Contiene la logica per determinare lo shard corretto in base alle coordinate.
- [x] **Modelli di Routing Camper-Aware**
  - **Stato:** Completato. I modelli `camper_eco`, `camper_scenic`, `camper_fast` sono stati creati e vengono caricati correttamente da ogni shard.
- [x] **Test di Copertura**
  - **Stato:** Completato. Sono stati implementati test di integrazione (`server/__tests__/route.test.js`) che validano sia i percorsi single-shard che quelli multi-shard.

---

## 3. Storage & Media – PRIORITÀ ALTA (Sprint Corrente)
- [ ] **Setup MinIO Docker**
- [ ] Creare il bucket `easycamper-media` con policy di lettura pubblica.
- [ ] Implementare il servizio `services/fileStorage.js` per l'upload di immagini (es. foto degli spot).
- [ ] Configurare le variabili d'ambiente (`MINIO_ENDPOINT`, `MINIO_KEY`, etc.).

---

## 4. Mappa Interattiva & Filtri – ALTA (Prossimo Sprint)
- [ ] **Layer Mappa Base**
  - [ ] Visualizzare su mappa gli spot della community (da API).
  - [ ] Implementare il bottom-sheet "Naviga qui" che avvia la richiesta di percorso all'API di routing.
- [ ] **Filtri Avanzati (stile Park4night)**
  - [ ] Sviluppare UI per i filtri (es. checkbox, slider).
  - [ ] **Filtri per Servizi:** Acqua potabile, scarico acque grigie/nere, elettricità, Wi-Fi, docce.
  - [ ] **Filtri per Tipo di Luogo:** Area sosta attrezzata, campeggio, parcheggio, agriturismo.
  - [ ] **Filtri per Attività/Ambiente:** Vicino al mare, in montagna, vicino a un lago, adatto ai bambini.
  - [ ] Aggiornare le API degli spot per supportare query con filtri multipli.

---

## 5. Navigazione In-Car – MEDIA
- [ ] Integrazione Mapbox Navigation SDK.
- [ ] Sviluppo modulo per Apple CarPlay.
- [ ] Sviluppo modulo per Android Auto.
- [ ] Gestione cache offline per mappe e spot (es. MapboxOfflineRegion + Hive).

---

## 6. Database Veicoli – MEDIA
- [ ] Creare tabella `VehicleModels`.
- [ ] Sviluppare servizio `vehicleSpecFetch.js` per popolare il DB da API esterne (es. CarQuery/NHTSA).
- [ ] Implementare endpoint `/vehicle-models` con autocompletamento.

---

## 7. Prezzi Carburante – MEDIA
- [ ] Sviluppare `fuelService.js` per recuperare dati da API (es. Openfuel) con un cron job.
- [ ] Creare layer sulla mappa per visualizzare i prezzi.
- [ ] Implementare notifiche push per avvisi sui prezzi.

---

## 8. UX Premium – MEDIA
- [ ] Live Activities / Widgets (ETA + prezzo carburante).
- [ ] Wizard “Aggiungi spot” (3 step, validazione inline).
- [ ] AI tagging foto (TFLite on-device, offline).

---

## 9. Observability & Strumenti – BASSA
- [ ] **Logging:** Pino → Loki (Grafana Cloud free tier).
- [ ] **Metrics:** Prometheus + Alertmanager.
- [ ] **Tracing:** Grafana Tempo (Docker).
- [ ] **Error Reporting:** Sentry free plan (mobile + backend).
- [ ] **Visualizzatore Percorsi di Test:**
  - [x] Creato `map.html` per visualizzare i percorsi generati dai test.
  - [ ] Migliorare lo script Python per un aggiornamento automatico.

---

## 10. CI/CD & Backup – BASSA
- [ ] GitHub Actions per build e test automatici.
- [ ] Fastlane per deploy beta nightly su TestFlight / Play Internal.
- [ ] `cron.daily` backup script per database e media.

---

## Checklist Sicurezza
- [x] **helmet:** Attivo e configurato.
- [x] **cors:** Attivo e configurato.
- [ ] **express-rate-limit:** Installato, ma da attivare e configurare in `app.js`.
- [ ] **xss-clean / hpp:** Da installare e configurare.
- [ ] **JWT & Refresh Token:**
  - **Stato Attuale:** Implementata logica base con token senza scadenza per facilitare i test.
  - **Prossimi Passi (pre-produzione):** Implementare scadenza di 15 min per il JWT e logica di Refresh Token (scadenza 30 gg).
- [ ] **Gestione Secrets:** Da verificare e centralizzare (es. Docker secrets, /opt/easycamper/.secrets).

---

## Milestones (Gantt semplificato aggiornato)
```mermaid
gantt
    title Roadmap EasyCamper
    dateFormat  W
    axisFormat W%W

    section Sviluppo Principale
    Infra & Sharding      :done, W1, 2w
    Routing Multi-Shard   :done, W1, 2w
    Storage & Media       :active, W3, 1w
    Mappa & Filtri        :W4, 2w
    Navigazione In-Car    :W5, 2w
    Database Veicoli      :W6, 1w
    Prezzi Carburante     :W7, 1w
    UX Premium            :W8, 1w
```

> **Target beta pubblica**: fine settimana 9.