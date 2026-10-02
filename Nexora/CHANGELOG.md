# Changelog

## 0.1.0 — 2026-10-02
- Initial release targeting itch.io
- Notes feed, member directory, custom logo, admin portal
- Firebase Auth (email + Google), Firestore database, Hive caching
- Push notifications via FCM

## Known issues (pre-release audit 2026-10-02)
- Fixed null dereference risks in auth_service, note_service, firestore_service
- Fixed pagination errors in members_screen
- Fixed notes_screen delete button crash
- Added .env / .env.example, LICENSE, CHANGELOG
