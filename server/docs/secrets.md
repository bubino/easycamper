# Gestione Secrets – Documentazione Operativa

Questa pagina elenca tutte le variabili d’ambiente e i secrets richiesti dal backend EasyCamper. Non includere mai valori reali o credenziali in questo file.

## Principi
- Tutti i secrets devono essere gestiti tramite variabili d’ambiente sicure o Docker secrets.
- Nessun secret deve essere hardcoded nel codice o nei file di configurazione versionati.
- I file `.env` non devono essere mai committati su GitHub.

## Elenco variabili richieste

### Autenticazione
- JWT_SECRET
- REFRESH_TOKEN_SECRET

### Database
- POSTGRES_USER
- POSTGRES_PASSWORD
- POSTGRES_DB
- POSTGRES_HOST
- POSTGRES_PORT

### MinIO (file storage)
- MINIO_ACCESS_KEY
- MINIO_SECRET_KEY
- MINIO_ENDPOINT
- MINIO_PORT
- MINIO_USE_SSL
- MINIO_BUCKET

### Email/Notifiche
- EMAIL_SERVICE_API_KEY
- EMAIL_SENDER
- EMAIL_SMTP_HOST
- EMAIL_SMTP_PORT
- EMAIL_SMTP_USER
- EMAIL_SMTP_PASSWORD

### Altri servizi
- GOOGLE_CLIENT_ID
- GOOGLE_CLIENT_SECRET
- APPLE_CLIENT_ID
- APPLE_CLIENT_SECRET
- FACEBOOK_APP_ID
- FACEBOOK_APP_SECRET
- OPENFUEL_API_KEY

## Note operative
- In produzione, usare solo Docker secrets o variabili d’ambiente fornite dal sistema.
- Aggiornare questa lista ogni volta che viene aggiunto un nuovo servizio o secret.
- Verificare periodicamente che nessun secret sia presente nei file versionati.