# NEXORA — Fix Log

**Date:** 2026-09-30
**Scope:** Fixes applied from `AUDIT_REPORT.md`. Dead code was **retained** per instruction; `lib/features/**` remains excluded from analysis.

## Verification (all re-run after changes)

| Check | Result |
|---|---|
| `flutter analyze` | **No issues found** (was 4 warnings) |
| `flutter test` | **25/25 pass** (was 14; +11 new regression tests) |
| `flutter build web` | Succeeds |
| Web bundle `dart:io` leak | **Eliminated** — `nexus_docs` / `Directory._systemTemp` no longer present in `main.dart.js` |
| `firebase` rules emulator | **Not run** — requires JDK 21; only JDK 17 is installed |

---

## 1. firestore.rules — rewritten and hardened

| Fix | Detail |
|---|---|
| `adminNotifications` block added | The collection had **no rules at all**, so every write was default-denied and silently swallowed at `auth_service.dart` — admins were never alerted. Now gated on `isAdmin()` for read/delete and validated on create. |
| `users` directory readable | Split `get` (self or admin) from `list` (`isVerified() \|\| isAdmin()`). Previously a single `read` rule denied the Members tab to every non-admin. |
| Genesis bootstrap | New `bootstrap/initialized` sentinel with a single-use `create` bound to `request.auth.uid`, plus `isGenesisClaimer()`. The old first-member check queried `users/`, which the rules denied — **registration was impossible for anyone but the hardcoded developer**. |
| Ledger now actually non-erasable | `notes` `update` restricts changed keys to content fields, so `authorName`/`authorRegNo`/`postedByUid` are immutable. `delete` is superadmin-only. |
| `notes` read requires auth | Was `allow read: if true` — every verified student's name and reg number was world-readable. |
| `noteNotifications` delete is admin-only | Any signed-in user could delete every broadcast. |
| `noteNotifications` create validated | `authorUid` must match the caller and required keys must be present. |
| Role escalation server-gated | `role` changes require superadmin via a dedicated rule branch; self-service edits explicitly cannot touch `role`/`status`/`adminColorHex`/`approvedBy`. |
| `pendingUsers` list is admin-only | `read` covered `list`, so any user could enumerate the queue. |
| `noteDeletionLogs` create validated | `deletedByUid` must match the caller; delete is superadmin-only (was admin, allowing one tap to erase the audit trail). |

## 2. Registration / auth flow — the critical break

- **Re-opened the registration entry point.** The live `login_screen.dart` is Google-only, and `/register` was pushed from exactly one place: a *dead* file. The live `RegisterScreen` and `AuthService.login()` were both unreachable. Added a "Register instead" link to the live login screen.
- **`AuthService.login` is now `{required String email, required String password}`** — the retained dead `features/auth` login screen calls it with named args, which did not compile against the old positional signature.
- **Replaced the denied first-member query** with a read of `bootstrap/initialized`.
- **Claim-before-write ordering** for the genesis path, with a fallback into the normal pending-user flow if the sentinel is already claimed — so a race cannot mint two superadmins.
- **`_submitAsPending` extracted** so the genesis path can fall through to it.
- **`claimGenesisSuperAdmin` re-checks the developer email** server-side rather than relying on the button being hidden.
- `proctorName`/`facultyAdvisor` resolution fixed to prefer the non-empty value.

## 3. AuthGate — approval bypass closed

`_isApproved` was `status == 'approved' || approvedBy.isNotEmpty || (role.isNotEmpty && role != 'candidate')`. **Nothing ever writes `'candidate'`**, so any non-empty role — including garbage — passed as verified. Now requires a positive signal (`status == 'approved'`, an approver stamp, or an admin/superadmin role), and an explicit non-approved status wins.

Added `_GateErrorScreen`: a read failure previously fell through to the onboarding form, so an approved user with a transient error was shown the registration screen.

The approval transaction in `admin_portal_screen.dart` now stamps `status: 'approved'` and `createdAt` — `AuthGate` checks `status` first and the approval path never wrote it.

## 4. Materials caching — every layer fixed

| Defect | Fix |
|---|---|
| `HiveError: Cannot write, unknown type: Timestamp` | `CacheService._normalise` converts `Timestamp`/`DateTime`/nested structures to primitives; `_revive` restores date fields as `Timestamp` on read. **Verified by test.** |
| Cached materials never rendered | `_visibleMaterials` returns cached rows when the stream is cold; a `_CacheBanner` explains why. |
| `setState()` during `build()` | `_loadMaterialsCache()` moved from the build path into `initState`. This was a framework error previously masked by the Hive failure. |
| `isExpired` computed and ignored | Replaced with `CacheService.isMaterialsCacheStale` (30-min TTL) driving `getFreshMaterials()`. |
| Unbounded pagination cap | Real cursor pagination via `startAfterDocument`; `_lastCursor` tracks the last consumed doc. "Load more" footer with error retry. |
| Pull-to-refresh changed the result set | `refreshMaterials` dropped the `.limit()` that `getNexusMaterials` applied, so the list silently grew. Unified behind one query builder. |
| `onRefresh` awaited a fixed 600 ms | Now awaits the new stream's first emission. |
| `saveMaterials` threw into an unhandled future | Returns `bool`; failure is caught and logged. |
| `init()` used `??=` on box handles | A closed box left a stale non-null handle; now checks `isOpen`. Found by the new tests. |
| `Stream.empty()` masked init failure | `watchMaterials` returns `null`; the UI shows `_NexusUnavailableState` with the real error and a retry, instead of "No materials found". |

## 5. PDF viewer + document cache

- **`dart:io` split behind a conditional import** (`pdf_disk_cache.dart` → `_io` / `_web`). Previously `Directory.systemTemp` threw `UnsupportedError` on web and was swallowed by three `catch (_) {}` blocks, making the disk cache a silent no-op. Confirmed the web bundle no longer contains it.
- **LRU-bounded caches** — 24 in-memory entries, 40 disk files, oldest evicted.
- **PDF magic-byte validation** on both cache read and network response; a corrupt cached file is deleted rather than served.
- **Removed the dead-link remapping** that silently served a *different* document (`Linear_algebra.pdf` → `Linear_algebra_CAT_2.pdf`).
- **Narrowed PDF detection** — no longer treats every `huggingface.co/.../resolve/` URL as a PDF.
- `parts` count now required; the old fallback of `10` produced 404s.
- Refresh now actually evicts the cached file and disables while loading.

## 6. Nexus ↔ Nexora integration

- **Sync is awaited and its result surfaced.** `syncApprovalToNexus` returns `NexusSyncResult` (merged / staged / skipped / failed); the admin sees the outcome instead of failures vanishing.
- **No more phantom users.** When no Nexus account exists, the approval is staged in `nexoraApprovals/` rather than fabricating a `users` document keyed by a sanitised email that no real sign-in could ever claim.
- **No fabricated auth provenance.** Dropped the hardcoded `'provider': 'google'`.
- **Name is not overwritten** on the Nexus side; only set when empty.
- **`initialize()` is concurrency-safe** via a memoised in-flight future — the previous version could hit `[core/duplicate-app]` when app startup, the Nexus tab, and registration raced.
- **Web embed now delivers the user's identity** via `postMessage` (was accepted and dropped), and handles inbound `open_pdf` messages. Target origin is derived from the Nexus URL, not wildcarded.
- Web `canGoBack()` documented as structurally unavailable for an iframe rather than silently returning `false`.

## 7. Error handling

- Notification unread tracker now has `onError` — a `PERMISSION_DENIED` was an unhandled stream error for the app's lifetime.
- Broadcast deletion gated to admins in **both** the UI and the action handler, matching the new rules.
- `_saveCourseCatalog` wrapped in try/catch; role promotion and reorders no longer fail silently. Index guards added to reorder/edit/delete (a shrinking catalog could `RangeError`).
- Text controllers disposed via `whenComplete` instead of immediately after `showDialog` (use-after-dispose during the exit animation).
- Nexus identity read failure no longer silently downgrades a user to `student`.

## 8. Data integrity

- **Course truncation fixed.** `ProfileEdit` rendered a hardcoded 7 rows and wrote all 7 back; setup allowed 12, so students silently lost courses 8-12 on any profile save. Both now derive from `kMaxCourses = 12`.
- Image size limits (`kMaxNoteImageBytes`, `kMaxProfileImageBytes`) were **declared but never checked** — `maxWidth`/`imageQuality` bound dimensions, not bytes. Now enforced.
- `AcademicInfo` read paths disagreed and lost the advisor for empty-string `proctorName`. Unified.
- `NoteModel` no longer renders fabricated identity (`'Verified Scholar'` / `'UNVERIFIED'`).
- `members_screen` and `FirestoreService` now page with real cursors; `loadMoreUsers` previously re-ran the same first-page query.
- `main.dart` uses `kAppName` instead of a duplicated literal.

## 9. Build / config

- **`storage.rules` created** — `firebase.json` referenced a file that did not exist, so `firebase deploy` would fail.
- **`firebase.json` extended** with a hosting block (`build/web`, SPA rewrite, cache headers).
- **`analysis_options.yaml` contradiction fixed** — `prefer_single_quotes` / `prefer_const_constructors` were enabled under `linter.rules` and simultaneously suppressed under `analyzer.errors`.
- **Stray root files removed**: `build.log`, `build.err`, `flutter_01.png`, `scratch_nexus.py`.
- **`README.md` rewritten** — it was still the unmodified Flutter template.
- `.gitignore` already covers `*.log`; the project is still not a git repository, which remains outstanding.

---

## Deliberately not changed

Per instruction, dead code was kept: `lib/features/**`, `user_service.dart`, `storage_service.dart`, `models/note.dart`, `verification_badge.dart`, `webview_platform_*.dart`, `note_deletion_logs_screen.dart`. Unused dependencies (`qr_flutter`, `mobile_scanner`, `webview_flutter_web`, `firebase_storage`) and unreferenced assets remain.

`lib/features/**` is still excluded from `analysis_options.yaml` — the exclusion is now documented in-file with the reason.

## Outstanding

1. **Rules are not emulator-verified** — `firebase emulators:exec` needs JDK 21; only 17 is installed. The rules are syntactically reviewed but untested against a live Firestore. **Deploy to a staging project and run the auth-flow checks before production.**
2. **Secrets remain in source** (`app_config.dart`, incl. a live ImgBB key). Needs `--dart-define` or a generated file plus rotation.
3. **No version control** — not a git repository, so none of this is committed or reviewable.
4. **Nexus-side rules are unknown** — the `nexus-e7a36` project is not in this repo, so whether `syncApprovalToNexus` writes are permitted cannot be verified here.
5. **MainShell still builds all three tabs eagerly**, so the Nexus WebView initialises at app launch. `memory/AGENT_MATRIX` specifies `IndexedStack`.
6. **`use_build_context_synchronously` is globally suppressed** in `analysis_options.yaml`, so async-gap context use is not flagged.
