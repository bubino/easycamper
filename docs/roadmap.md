# EasyCamper – Roadmap & Checklist (Aggiornata)

## 0. Vision
«Un’unica app per camperisti con routing “camper-aware”, community spot, prezzi carburante in tempo reale e navigazione integrata in-car».

---

## 1 Infra & Storage ‑ PRIORITÀ ALTA (Sprint 1)
- [~] **VPS IONOS unico nodo (8 GB RAM)**
  - **Stato Attuale:** L'intera infrastruttura Docker è stata creata, testata e validata in ambiente locale. È pronta per il deploy su un VPS di produzione.
- [ ] **MinIO** Docker
- [ ] Bucket `easycamper-media` + policy read-only public
- [ ] Express → `services/fileStorage.js` (minio-sdk)
- [ ] ENV ➜ `MINIO_ENDPOINT`, `MINIO_KEY`, `MINIO_SECRET`, `MINIO_BUCKET`

---

## 2 GraphHopper Import & Sharding – ALTA (Sprint 1-2)
- [x] **Definizione e creazione Shard**
  - **Stato Attuale:** Completato. Abbiamo implementato una suddivisione in 4 shard (`nord`, `centro-ovest`, `centro-est`, `sud`) per una migliore distribuzione del carico. I file `.osm.pbf` sono stati creati.
- [x] **Importazione e Caching GraphHopper**
  - **Stato Attuale:** Completato. L'importazione per tutte e 4 le shard è automatizzata tramite `docker-compose`. Le cartelle `graph-cache` vengono generate e caricate correttamente all'avvio.
- [~] **NGINX upstream intelligent dispatch (lat/lon in query).**
  - **Stato Attuale:** In corso. Abbiamo un NGINX funzionante come reverse proxy di base. Il prossimo passo è implementare l'"intelligent dispatch" usando il **Router-Proxy integrato di GraphHopper**, che è l'obiettivo della nostra Fase 3.

---

## 3 Routing Camper-Aware – ALTA (Sprint 2)
- [x] **`camper_eco`, `camper_scenic`, `camper_fast` in `custom_model.json`**
  - **Stato Attuale:** Completato. I modelli personalizzati sono stati creati, inclusi nell'immagine Docker e vengono caricati correttamente da ogni shard.
- [~] **/api/route payload & Middleware per mappatura shard**
  - **Stato Attuale:** In corso. Questo sarà gestito dal **Router-Proxy di GraphHopper**, non da un middleware Express custom. Questo semplifica l'architettura e aumenta la robustezza.
- [ ] Benchmark < 600 ms median VPS

---

## 4 Mobile Map & In-Car – MEDIA (Sprint 3)
- [ ] Flutter Mapbox layer spot (user + third-party)
- [ ] Bottom-sheet “Naviga qui” → /api/route
- [ ] Mapbox Navigation SDK – CarPlay / Android Auto module
- [ ] Offline cache tile (MapboxOfflineRegion) + Hive for spots

---

## 5 Camper DB & Vehicle Models – MEDIA (Sprint 3)
- [ ] Tabella `VehicleModels`
- [ ] Service `vehicleSpecFetch.js` → CarQuery/NHTSA → cache
- [ ] Autocomplete `/vehicle-models`
- [ ] Batch seed 2010-oggi

---

## 6 Fuel Stations & Pricing – MEDIA (Sprint 4)
- [ ] Service `fuelService.js` fetch Openfuel.io → cron 6 h
- [ ] Layer Mapbox + popup prezzi
- [ ] Cloud Functions → FCM push «Diesel < 1.78€ a 5 km»

---

## 7 Observability – MEDIA (Sprint 4)
- [ ] Pino → **Loki** (Grafana Cloud free tier)
- [ ] Metrics `/metrics` → **Prometheus** + Alertmanager
- [ ] Tracing OTel → **Grafana Tempo** (Docker)
- [ ] Sentry free plan (mobile + backend)

---

## 8 CI/CD & Backup – BASSA (Sprint 5)
- [ ] GitHub Actions
- [ ] Fastlane nightly beta TestFlight / Play Internal
- [ ] `cron.daily` backup script

---

## 9 UX Premium – BASSA (Sprint 6)
- [ ] Live Activities / Widgets (ETA + prezzo carburante)
- [ ] Wizard “Aggiungi spot” (3 step, validazione inline)
- [ ] AI tagging foto (TFLite on-device, offline)

---

## Checklist Sicurezza
- [ ] helmet ✔️
- [ ] cors whitelist ✔️
- [ ] express-rate-limit ✔️
- [ ] xss-clean + hpp ✔️
- [ ] JWT 15 min + refresh 30 gg
- [ ] Secrets in `/opt/easycamper/.secrets` (no git)

---

## Milestones (Gantt semplificato aggiornato)
```
Wk1  Wk2  Wk3  Wk4  Wk5  Wk6  Wk7  Wk8  Wk9
[Infra/MinIO]■■■■
[Shard GH ]     ■■■■
[Routing   ]         ■■
[Map UI    ]            
[Camper DB ]               
[Fuel Price]                 
[Observab. ]                    
[CI/CD     ]                       
[UX Prem.]                           
```

> **Target beta pubblica**: fine settimana 9.
