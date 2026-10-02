# Nexora

A verified, non-erasable academic notes platform. Flutter + Firebase.

Every note, slot, and course is tied to an admin-approved student identity —
there is no anonymous posting.

## Architecture

| Area | Location | Notes |
|---|---|---|
| Entry point / DI | `lib/main.dart` | Providers for `AuthService` and `FirestoreService` |
| Auth gate | `lib/screens/auth/auth_gate.dart` | Routes on Auth state + `users/{uid}` approval |
| App shell | `lib/screens/main_shell.dart` | 3-tab `PageView`: Notes, Nexus, Members |
| Nexus (materials) | `lib/screens/nexus/nexus_screen.dart` | Firestore feed, offline cache, in-app PDF viewer, embedded PWA |
| PDF cache | `lib/screens/nexus/pdf_disk_cache.dart` | Conditional import: `dart:io` on mobile, no-op on web |
| Cross-project sync | `lib/services/nexus_service.dart` | Nexora (`nexora-bee78`) ↔ Nexus (`nexus-e7a36`) |
| Offline cache | `lib/core/cache/cache_service.dart` | Hive; normalises Firestore `Timestamp` before writing |
| Secrets | `lib/core/config/app_config.dart` | See "Configuration" below |

## Two Firebase projects

Nexora and Nexus are **separate projects with separate Auth instances**. A
user's UID differs between them even for the same Google account, so all
cross-project lookups match on **email, never UID**. `NexusService` is the only
place that talks to Nexus.

## Data model

- `users/{uid}` — verified students (`role`: `student` | `admin` | `superadmin`, `status`, `approvedBy`, `academic`, `courses`, `searchIndices`)
- `pendingUsers/{uid}` — awaiting admin verification
- `notes/{noteId}` — the academic ledger
- `noteNotifications/{id}` — broadcasts
- `adminNotifications/{id}` — admin inbox for new candidates
- `config/courses` — admin-managed course catalog
- `bootstrap/initialized` — genesis sentinel, written exactly once

Nexus (separate project): `materials/{id}`, `users/{id}`, `nexoraApprovals/{id}`.

## Security model

`firestore.rules` is the authority:

- The ledger (`notes`) requires a verified account and is **immutable** — an author
  can revise content but can never rewrite `authorName`, `authorRegNo`, or
  `postedByUid`, and only a superadmin can delete a document.
- `role` changes require superadmin; self-service profile edits are limited to
  `phoneNo`, `photoUrl`, `academic`, `courses`, `searchIndices`, `updatedAt`.
- Deleting broadcasts is admin-only.
- Client-side role checks in the UI are conveniences, not the boundary.

## Configuration

`lib/core/config/app_config.dart` holds the ImgBB key and both Firebase projects'
keys, committed with live values. `app_config.example.dart` is the blank template.

**Before shipping publicly:** move these to `--dart-define` or a generated file,
and rotate the ImgBB key. The key is sent from the client, so it is extractable
from any build.

## Running

```bash
flutter pub get
flutter run                 # Android / iOS
flutter run -d chrome       # web
flutter test
flutter analyze
```

Deploy the rules before the first run, or the app will be denied:

```bash
firebase deploy --only firestore:rules,storage
```

## Known state

`lib/features/**` is an abandoned parallel architecture. It is excluded from
analysis in `analysis_options.yaml` because it does not compile against the
current services (it calls `auth.registerUser`, `firestore.createNote`, and
`auth.currentUser?.role`, none of which exist). Delete it, or restore the
exclusion removal after fixing it — currently the analyzer cannot see it.

See `memory/AUDIT_REPORT.md` for the full audit and fix log, and
`memory/AGENT_MATRIX.txt` for the data contracts.
