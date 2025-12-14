# easycamper

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# Sicurezza Account & Audit Log (Aggiornamento 20/07/2025)

Questa release introduce:
- Audit log per tutte le operazioni di login, logout e revoca device (tracciate in `AuditLog` con userId, operazione, deviceInfo, IP, data/ora).
- Notifica all’utente su login da nuovo device o revoca device (mock via console.log, estendibile via email/push).
- Salvataggio IP e fingerprint (hash di User-Agent + IP) in `RefreshToken` e `AuditLog`.
- Test automatici per token scaduto, manomesso, refresh da device non autorizzato (`server/__tests__/securityRefreshToken.test.js`).

## Visualizzazione Audit Log
- Query diretta su tabella `audit_logs` (admin):
  - Esempio SQL: `SELECT * FROM audit_logs WHERE user_id = '...' ORDER BY created_at DESC;`
- Possibile endpoint REST `/admin/auditlog` (da implementare per frontend admin).

Per dettagli tecnici vedi anche `docs/roadmap.md` e i test in `server/__tests__`.
