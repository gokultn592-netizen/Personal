# NEXORA — Project Audit Report

**Date:** 2026-09-30
**Scope:** Full static + build + runtime-behaviour audit of `D:\Project\Nexora` (Flutter 3.47.5 / Dart 3.13, Firebase)
**Primary focus:** Nexus ↔ Nexora integration, and caching of materials

---

## 0. Verification performed (executed, not assumed)

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | 4 warnings, 0 errors |
| Unit/widget tests | `flutter test` | 14/14 pass |
| Web compilation | `flutter build web` | Succeeds (53s) |
| Import graph / reachability | Custom transitive closure from `lib/main.dart` | 2,900+ lines unreachable |
| Hive serialisation probe | Temporary test, since deleted | `HiveError: Cannot write, unknown type: Timestamp` |
| Compiled-JS inspection | `build/web/main.dart.js` | `Directory._systemTemp` → `throw UnsupportedError` |
| Rules ↔ code cross-check | Manual trace of every collection/query/write | 5 denial paths, 1 phantom collection |
| Config/deps audit | `pubspec.yaml`, `firebase.json`, `.firebaserc`, platform folders | 3 broken deploy configs, 2 unused deps |

> Note: the project is **not a git repository** (`git status` → fatal), so there is no history and no CI, despite `memory/AGENT_MATRIX.md.txt:17` documenting "GitHub Actions CI/CD".

---

## 1. CRITICAL — App-breaking defects

### 1.1 **No new user can onboard at all** (two independent breaks)

**Break A — the only onboarding entry point is a dead route.**
The live login screen (`lib/screens/auth/login_screen.dart`) is **Google-only**: the sole sign-in action is `signInWithGoogle` (`:28`, `:80`). There is no email/password form and no link to `RegisterScreen`.
- `'/register'` (`main.dart:58`) is pushed from **exactly one place**: `lib/features/auth/screens/login_screen.dart:154` — a **dead file** (§6.1).
- The live `RegisterScreen` (`lib/screens/auth/register_screen.dart`, which calls `registerCandidate` at `:57`) is therefore **unreachable**.
- `AuthService.login()` (`auth_service.dart:274`) has **zero live callers** — its only caller is the same dead file (`features/.../login_screen.dart:32`).
- `'/shell'` (`main.dart:59`) also has zero `pushNamed` callers; `AuthGate` returns `MainShell()` as a widget (`auth_gate.dart:60`).

**Break B — the profile submission it would lead to is denied by the rules.**
`lib/services/auth_service.dart:93`
```dart
final existingUsers = await _firestore.collection('users').limit(1).get();
isFirstMember = existingUsers.docs.isEmpty;
```
`firestore.rules:30`
```
allow read: if isAuth() && (request.auth.uid == uid || isAdmin());
```
A **collection query** cannot satisfy `request.auth.uid == uid`, and a brand-new registrant is not an admin. The read throws `PERMISSION_DENIED`, which is caught at `auth_service.dart:211` and returned as an error string — so `submitCandidateProfile()` **never reaches the `pendingUsers` write at line 184**. No non-developer can register.

This is the `isFirstMember` bootstrap check. It is skipped for the hardcoded developer email (`auth_service.dart:88`, `constants.dart:9-11`), which is why this has not been noticed.

**Net effect:** the only reachable entry point is Google sign-in (`auth_gate.dart:41` → `ProfileSetupScreen`), and submitting that profile hits Break B and fails. Except for `gokultn592@gmail.com`, **the app admits nobody.**

**Fix:** gate on a dedicated singleton document (`/stats/initialized`) readable by any authenticated user, or drop the check entirely and rely on `firestore.rules:31` (`allow create: if isAdmin()`) to refuse a second genesis user.

### 1.2 The Members tab fails for every non-admin
`lib/screens/members/members_screen.dart:38` → `FirestoreService().streamVerifiedUsers()` (`firestore_service.dart:94`) → `collection('users').limit(50).snapshots()`. Same rule, same denial.

`members_screen.dart:40-50` renders "Directory unavailable" — and because `self` is extracted from that same query (`members_screen.dart:59-67`), the user also **loses their own pinned card and the admin-portal button**.

**Fix:** either allow `read` on `users` for any authenticated verified user, or query by a searchable index (`searchIndices.faculties`) instead of listing the collection.

### 1.3 `adminNotifications` has no rules block — the feature is a guaranteed no-op
`auth_service.dart:195` writes to `collection('adminNotifications')`. `firestore.rules` contains **no `match` block for it** (default deny). The write is wrapped in `catch (_) {}` at `auth_service.dart:187, 208`, so admins are **never alerted** about new candidates and no error is surfaced.

### 1.4 Materials cache is 100% non-functional (three independent failures)
The `NexusService`/Hive path intended to make the Nexus materials feed work offline never works. See §3 for full detail. Summary: writes always throw, reads never render, and the read path calls `setState()` during `build()`.

---

## 2. Nexus ↔ Nexora integration

Nexus (`nexus-e7a36`) and Nexora (`nexora-bee78`) are separate Firebase projects with separate Auth. `lib/services/nexus_service.dart` correctly documents this (`:9-12`) and correctly matches **by email, never UID** (`:137-142`). That part is sound. Everything around it is not.

### 2.1 The cross-project approval sync is only wired to 1 of 3 approval paths

| Approval path | Nexus sync? |
|---|---|
| Admin portal approve — `admin_portal_screen.dart:118` | ✅ called, but **not awaited**, and hardcoded `isAdmin: false` (`:124`) |
| Developer / first-member auto-approve — `auth_service.dart:106-155` | ❌ none |
| `claimGenesisSuperAdmin` — `auth_service.dart:235-264` | ❌ none |

Two further approval implementations exist and are **completely orphaned**:
- `FirestoreService.approveUserTransaction()` — `firestore_service.dart:12-63` — never called
- `UserService.approve()` — `user_service.dart:97-140` — never called (`UserService` has zero call sites app-wide)

Consequence: because `admin_portal_screen.dart:124` always passes `isAdmin: false`, a Nexora **admin** is written into Nexus with `role: 'friend'` (`nexus_service.dart:169`). Nexus admins can never be produced by this integration.

### 2.2 The sync is fire-and-forget and failure-invisible
`admin_portal_screen.dart:118`
```dart
NexusService().syncApprovalToNexus(...);   // not awaited
```
and every failure inside is swallowed at `nexus_service.dart:192-194`. A Nexus write that fails leaves **no trace** and does not affect the approval result.

Worse, the pre-transaction snapshot is reused after the transaction deleted that document (`admin_portal_screen.dart:57` → used at `:118`), so the Nexus doc can be written from stale data.

### 2.3 Fabricated provenance written into a second production project
`nexus_service.dart:164-177` writes, from an unauthenticated secondary client:
- `'provider': 'google'` — even when the student has never signed in to Nexus with Google
- `'approved': true`, `'verifiedStudent': true`, `'verifiedByNexora': true`
- and for students who have not joined Nexus, it **creates a phantom user document** keyed by a sanitised email (`nexus_service.dart:185`) that no Nexus auth UID can ever claim.

Nexus's own Firestore rules are **not in this repository**, so whether these writes are even permitted cannot be verified — the integration is unverifiable and silently failing if not.

### 2.4 `checkNexusApproval` contradicts its own documented intent
`nexus_service.dart:117` treats Nexus `role == 'admin'` as "approved". The doc comment at `:97-98` and `auth_service.dart:98-100` both state Nexus membership must **not** grant verification. The result drives the "Nexus Member" badge (`auth_service.dart:169`) shown to admins as a shortcut around Nexora verification.

### 2.5 Role vocabulary is inconsistent across four vocabularies
| Vocabulary | Where | Produced by |
|---|---|---|
| `student` / `admin` / `superadmin` | `user_model.dart:165`, `auth_service.dart:113`, `firestore.rules:18` | ✅ live |
| `student` / `approver` / `admin` | `constants.dart:23-25`, `utils.dart:155,161` | ❌ **nothing ever writes `'approver'`** |
| `friend` / `admin` | `nexus_service.dart:117,169` | Nexus project |
| `'candidate'` | `auth_gate.dart:23`, `pending_screen.dart:69` | ❌ **nothing ever writes `'candidate'`** |

The `'candidate'` gap is a live auth-gate hole: `auth_gate.dart:22-27` approves a user if `status == 'approved' || approvedBy.isNotEmpty || (role.isNotEmpty && role != 'candidate')`. Since no code writes `'candidate'`, **any non-empty `role` string — including garbage — passes as verified.**

### 2.6 The web embed silently discards the user's identity
`nexus_embed_web.dart` declares `NexusUserBridgeData user` (`:23`) and **never reads `widget.user`**. On web, `nexus_screen.dart:867-888` subscribes to `users/{uid}`, resolves name/photo/role, builds the bridge object — and it is dropped on the floor. The Nexus PWA inside the iframe runs with **no Nexora identity at all**, no login-link hiding, no admin badge.

Also `nexus_embed_web.dart:76` — `canGoBack()` hardcoded `false`, so the `PopScope` handler at `nexus_screen.dart:221-227` can never navigate inside the iframe on web.

`webview_platform_stub.dart` and `webview_platform_web.dart` are **never imported by anything** — the `webview_flutter_web` dependency is dead weight.

### 2.7 WebView role injection renders wrong labels
`nexus_screen.dart:876` passes the **Nexora** role (`'student'` / `'admin'` / `'superadmin'`) into the bridge. The injected JS at `nexus_embed_mobile.dart:278, 293` branches on `'admin'` → `ADMIN`, `'friend'` → `MEMBER`, else `role.toUpperCase()`. Therefore:
- every student renders as **`STUDENT`** (a label Nexus has no styling for; `MEMBER` is unreachable)
- a `superadmin` renders as `SUPERADMIN` and **fails** the `role === 'admin'` test at `:265`, so gets **no admin badge**
- `nexus_embed_mobile.dart:244` writes the Nexora vocabulary into Nexus's own `localStorage` key `nexus_user_role_*`.

### 2.8 `NexusService.initialize()` is not concurrency-safe
`_initialized` is only set at the end (`:41`, `:51`) and there is no in-flight guard. `initialize()` is reachable from `main.dart:29`, `auth_service.dart:104`, `nexus_service.dart:152`, and `nexus_screen.dart:42`. Any overlap → duplicate `[core/duplicate-app]` throw, swallowed at `:51-53`, leaving `_firestore` null permanently for that session.

### 2.9 A Nexus init failure is reported as "no content"
`nexus_service.dart:62, 84` return `Stream.empty()` when `_firestore == null`. `Stream.empty()` emits no data and no error, so `nexus_screen.dart:509-516` renders **"No materials found"** — indistinguishable from a genuinely empty collection. The real cause (bad/invalid Nexus Firebase config, network block, duplicate app) is invisible to the user and to logs.

### 2.10 Web platform is not actually supported for Nexus features
`main_shell.dart:32-36` instantiates **all three tabs eagerly** (`const [NotesScreen(), NexusScreen(), MembersScreen()]`) inside a `PageView`. The WebView controller is built in `NexusEmbedView.initState` (`nexus_embed_mobile.dart:135`), so a full Android WebView is created at app launch even if the user never opens the Nexus tab. (`memory/AGENT_MATRIX.md.txt:99` specifies `IndexedStack`; the code uses `PageView` + `NeverScrollableScrollPhysics`.)

---

## 3. Caching the materials — every layer is broken

This was the primary focus and has four distinct defects.

### 3.1 Hive can never serialise the materials payload (verified empirically)
`nexus_screen.dart:501-507` hands raw Firestore documents to the cache:
```dart
final copy = Map<String, dynamic>.from(d);   // d contains Timestamp(createdAt)
copy['docId'] = doc.id;
...
CacheService().saveMaterials(materialsList);
```
`cache_service.dart:45` does `_materialsCache!.put(_materialsKey, {'data': materials, ...})`.

Probe result:
```
PROBE_HIVE_RESULT:  HiveError: Cannot write, unknown type: Timestamp. Did you forget to register an adapter?
PROBE_HIVE_CONTROL: SUCCESS   (same payload, Timestamp stringified)
```
**Materials are never written to Hive.** There is no `TypeAdapter` and no field normalisation. The `Future` is also never awaited, so the throw surfaces as an unhandled zone error and is silently discarded.

### 3.2 The cached materials are never rendered
`nexus_screen.dart:423-433` loads the cache into `_cachedMaterials`, but `_cachedMaterials` is then only used in one condition (`:442`) — to *suppress the skeleton*. It is never mapped into any widget. While the stream is `waiting`:
- `docs = snapshot.data?.docs ?? []` → `[]` (`:499`)
- the "No materials found" early-return is skipped because `connectionState == waiting` (`:509`)
- → an empty `CustomScrollView` renders: **a blank pane with "Showing 0 materials"**.

So even with a working cache, the offline path paints nothing. (`_materialsEverLoaded`, `:421`, is set but never read — the analyzer flags this as `unused_field`.)

### 3.3 `setState()` is called during `build()` — latent framework exception
`nexus_screen.dart:436`
```dart
Widget _buildNativeMaterialsFeed() {
  _loadMaterialsCache();        // <-- called from build()
```
and `_loadMaterialsCache` calls `setState` at `:428-431` whenever the cache is non-empty. This is `setState() or markNeedsBuild() called during build` — a hard Flutter framework error. It is currently masked **only** by the Hive failure in §3.1; the moment caching is fixed naively, the Nexus tab crashes. It must be moved to `initState`.

### 3.4 Expiry, pagination and refresh are all fake
- `isExpired` is computed at `nexus_screen.dart:426` and **never used** (analyzer: `unused_local_variable`). Stale data would be served forever.
- **Pagination does not exist.** `getNexusMaterials({int limit = 20})` (`nexus_service.dart:61`) hard-codes a 20-item cap. `loadMoreMaterials` (`nexus_service.dart:72-80`) returns `List<QuerySnapshot>` — a fake pagination contract — and **has zero call sites**. The feed is permanently capped at 20 materials.
- **Pull-to-refresh changes the result set.** `refreshMaterials()` (`nexus_screen.dart:544`) drops the `.limit()` that `getNexusMaterials()` applies (`nexus_service.dart:67` vs `:85-89`). First load = 20 items; after one pull-to-refresh = *all* materials. The list silently grows.
- `onRefresh` awaits `Future.delayed(600ms)` (`nexus_screen.dart:546`) instead of the stream — the spinner completes before any data arrives.
- `NexusService.clearMaterialsCache()` (`:93-95`) has zero call sites.

### 3.5 The PDF cache is mobile-only and fails silently on web
`nexus_pdf_viewer_screen.dart:2` imports `dart:io`; the file is imported unconditionally by `nexus_screen.dart:15` and `nexus_embed_mobile.dart:7`, so it is in the web bundle. Verified in the compiled JS:
```js
bNI(a){ throw A.c(A.am("Directory._systemTemp")) }
```
`Directory.systemTemp` (`nexus_pdf_viewer_screen.dart:67, 81, 92`) throws `UnsupportedError` on web. It is swallowed by three bare `catch (_) {}` blocks (`:74`, `:86`, `:105`), so on web the RAM cache works but the disk cache is a **silent no-op** — contradicting the file's own doc comment (`:9-12`, "Cache-First architecture").

Additional cache issues:
- **Unbounded growth** — nothing evicts by size or count; only by version (`_evictOlderVersions`, `:90-106`).
- **Version invalidation is bypassed.** `nexus_embed_mobile.dart:151` and `:188` construct `NexusPdfViewerScreen` without `docId`/`version`, so `nexus_screen.dart`'s version-aware cache key (`:44-50`) degrades to a URL hash for every document opened from the PWA.
- **The parallel chunk downloader (`:222-281`) is unreachable from the native feed**, because `_resolveViewUrl` (`nexus_screen.dart:134-137`) strips `.partN` markers before the viewer ever sees the URL. It defaults `partsCount` to `10` when only `.part` is present (`:227`).

### 3.6 `assets/materials/` is a declared-but-empty cache surface
`pubspec.yaml` bundles `assets/materials/`, but that directory contains only `README.txt` and **is referenced by zero Dart files**. The "materials" directory concept was never implemented — materials come only from the remote Nexus Firestore/Hugging Face.

---

## 4. Security

### 4.1 The "non-erasable, verified" ledger is public and mutable
`pubspec.yaml:2` — *"a verified, **non-erasable** academic notes platform"*; `memory/AGENT_MATRIX.md.txt:10,142` — *"immutable, vouched academic ledger"*.

Against that:
- `firestore.rules:42` — `allow read: if true` on `notes`. **No authentication whatsoever.** Every note carries `authorName` + `authorRegNo` (`post_note_sheet.dart:141-142`), so the full identity and registration number of every verified student is world-readable. The Firebase API key ships inside the app (`app_config.dart:3`), so there is no barrier at all. This defeats the project's stated purpose.
- `firestore.rules:48` — `allow update, delete: if isAuth() && resource.data.postedByUid == request.auth.uid`. The author may **delete** the note, and may `update()` `authorName` / `authorRegNo` / `postedByUid` to arbitrary values — the rules only validate attribution **on create** (`:43-47`). Attribution is client-mutable, not server-immutable.
- `features/notes/note_detail_screen.dart:214` displays the string *"This post cannot be edited or deleted"* — in dead code, and false.

### 4.2 The compensating audit trail is dead and deletable
- `NoteService.deleteNoteWithAudit()` (`note_service.dart:26`) — **zero call sites.** No deletion is ever audited.
- `NoteDeletionLogsScreen` (`note_deletion_logs_screen.dart`, 450 lines) — **no navigation route exists.** Entirely unreachable; `NoteService` is transitively dead with it.
- Even if reachable, `firestore.rules:61` allows admin delete and the UI ships "Clear All Deletion Logs" → `NoteService.clearAllAuditLogs` (`note_service.dart:77-84`) batch-deletes the whole trail.

### 4.3 Anyone can delete every broadcast notification
`firestore.rules:54` — `allow delete: if isAuth()` on `noteNotifications`, with no field validation on create (`:53`). `note_notifications_sheet.dart:599` exposes **"Clear All Broadcasts"** to every user → `NotificationService.clearAllNotifications` batch-deletes the collection. Any signed-in user can silence announcements campus-wide.

### 4.4 Role escalation is client-gated, not server-gated
`firestore.rules:32-37` permits **any** `admin` to write `role`/`adminColorHex` on any user; the "Promotions" tab is superadmin-only only in the UI (`admin_portal_screen.dart:39, 312, 596`). The role dropdown also offers `'superadmin'` (`admin_portal_screen.dart:196-200`). Additionally `auth_gate`/`pending_screen` test `role != 'candidate'`, a value nothing writes (§2.5).

### 4.5 Hardcoded secrets in source
`lib/core/config/app_config.dart` is committed with **live** values: ImgBB key (`:2`), three Nexora Firebase keys (`:3-5`), and the complete second-project Nexus config (`:6-12`). `app_config.example.dart` exists alongside it, proving the intent to keep keys out of source. The ImgBB key is transmitted from the client (`imgbb_service.dart:48`) and is extractable from any build.

The ImgBB failure path returns `null` with **no logging** (`:37-39`, `:68-70`), so an upload loss surfaces to the user as an unrelated error message.

### 4.6 Silent error handling that hides the above
- `admin_portal_screen.dart:331-460, 505-604` — permission denials render as **"No pending candidate applications"** / **"No verified members found"**. Indistinguishable from empty.
- `admin_portal_screen.dart:637` — promotions tab shows an **infinite spinner** on error (`hasData` is false, error never handled).
- `auth_gate.dart:45,64` — a permission error sends a legitimately approved user to the **registration form**.
- `notification_service.dart:28` — the badge subscription is created in the constructor with **no `onError`**; a denial is an unhandled stream error for the app's lifetime.
- Unawaited, unguarded writes: `admin_portal_screen.dart:248` (role promotion), `:895-900` (`_reorderCourse`), `:953, 1018, 1057, 1094` (course catalog).
- Controllers created and never disposed: `admin_portal_screen.dart:903`, `:973`.

---

## 5. Data-model inconsistencies

### 5.1 Two incompatible note writers
- `note_model.dart:72-84` writes `content` + `timestamp` + `postedByUid` (+ no `id`, contradicting `AGENT_MATRIX.txt:61`).
- `note_service.dart:95-110` writes `body` + `createdAt` + `authorUid` (+ `id`).

`NoteService.publish` has **zero call sites**, so it is dead — but it is the exact schema `notes_screen.dart:122-126` expects (`orderBy('timestamp')`). Any note written through it would be invisible in the feed and render with empty content (`note_model.dart:54`).

### 5.2 Undocumented / inconsistently-written fields
`status`, `createdAt`, `isNexusMember`, `nexusRole`, `noOfCourses`, `noOfClubs`, `proctorName` are all written by the app but absent from the contract in `memory/AGENT_MATRIX.txt`. `status` is the field `AuthGate` checks first (`auth_gate.dart:22,25`) but the admin approval path never writes it (`admin_portal_screen.dart:82-110`).

`AcademicInfo` has two disagreeing read paths — `user_model.dart:33` (`map['proctorName'] ?? map['facultyAdvisor']`) and `user_model.dart:17` (`proctorName.isNotEmpty ? ... : facultyAdvisor`) — which diverge for the empty-string `proctorName` that every approval path writes (`auth_service.dart:133`, `admin_portal_screen.dart:97`).

### 5.3 Silent course data loss
`profile_setup_screen.dart:126` allows **12** courses; `profile_edit_screen.dart:53-58` renders only **7** and writes all 7 back on save. Students with 8-12 enrolled courses **silently lose** courses 8-12 whenever they edit their profile.

### 5.4 Fabricated attribution on read
`note_model.dart:57-58` — missing attribution renders as `'Verified Scholar'` / `'UNVERIFIED'` in the ledger UI, i.e. the app displays invented identity data.

---

## 6. Dead code, unused features, broken links

### 6.1 Entire duplicated `lib/features/` tree — ~2,286 lines, unreachable
Nothing in the live tree imports it. `analysis_options.yaml:8` **excludes `lib/features/**` from analysis**, so it is invisible to `flutter analyze` — which is why 4 warnings is not a sign of a clean codebase.

`lib/features/auth/screens/{login,register}_screen.dart` (396), `lib/features/members/*` (1,007, incl. `member_pokemon_card.dart` + `scan_qr_screen.dart`), `lib/features/notes/*` (832), `lib/features/shell/shell_screen.dart` (51). These duplicate `lib/screens/auth/*`, `lib/screens/members/members_screen.dart`, `lib/screens/notes/notes_screen.dart` and consume a **divergent model** (`lib/core/models/nexora_models.dart`, reading `faculty`/`slot`/`profilePicUrl`/`auditSeals` — none of which exist in the live `users/{uid}` schema) and a **second theme** (`lib/core/theme/app_theme.dart`, only referenced from dead code).

### 6.2 Unused features / dependencies
| Item | Evidence |
|---|---|
| **QR card + ID scanning** | `qr_flutter`, `mobile_scanner` used **only** in dead `lib/features/members/*` → both deps ship for nothing |
| **Firebase Storage** | `storage_service.dart` has **zero call sites**; `firebase_storage` unused. Images go to third-party ImgBB instead. `kStorageNotesFolder`, `kStorageProfileFolder`, `kMaxNoteImageBytes`, `kMaxProfileImageBytes` are all unreferenced (`constants.dart:116-120`) |
| **Deletion audit trail** | `NoteDeletionLogsScreen` + `NoteService` unreachable (§4.2) |
| **`user_service.dart`** (145 lines) | Zero call sites; writes a parallel, incompatible `users/{uid}` schema |
| **`models/note.dart`** | Zero references |
| **`widgets/verification_badge.dart`** | Zero references |
| `webview_platform_stub.dart`, `webview_platform_web.dart` | Never imported; `webview_flutter_web` effectively dead |
| `CacheService.saveNotes/getNotes` | Only called from **dead** `lib/features/notes/notes_screen.dart` — the live notes feed does no caching at all |
| `NexusService.loadMoreMaterials`, `clearMaterialsCache` | Zero call sites |
| `NoteService.publish`, `deleteNoteWithAudit`, `loadMoreNotes` | Zero call sites |
| `FirestoreService.approveUserTransaction`, `loadMoreUsers`, `loadMorePendingUsers` | Zero call sites |
| `isPrivilegedRole`, `roleLabel` (`utils.dart:154-165`) | Zero call sites |
| `openExternal()` | Defined twice, called zero times |
| `NexusConfig.embedRetryIntervalMs/embedMaxRetries` (`constants.dart:16-17`) | Zero call sites — **there is no retry logic at all** |
| `kSlots`, `kFaculties` | Zero call sites |

### 6.3 Hardcoded dead-link remapping
`nexus_screen.dart:121-123` and `nexus_pdf_viewer_screen.dart:115-117` map one dead GitHub release URL to a Hugging Face file of a **different name**:
```
.../1786383825722_Linear_algebra.pdf  →  .../Linear_algebra_CAT_2.pdf
```
Users clicking a note titled "Linear algebra" are silently served a different document. This is a hardcoded patch over broken data, duplicated in three places.

### 6.4 Over-broad PDF detection
`nexus_screen.dart:154-156` treats **any** `huggingface.co/.../resolve/` URL as a PDF regardless of `fileType`, so non-PDF Hugging Face assets are routed into the Syncfusion PDF viewer.

### 6.5 Unused assets
`assets/images/nexora_logo.png` (645 KB) and `nexora_logo.jpg` (365 KB) are unreferenced (only `nexora_icon.png` is used). Stray files at repo root: `flutter_01.png` (36 KB), `build.log`, `build.err`, `scratch_nexus.py`, and a generated `.widget_preview/` scratch project.

### 6.6 The dead tree would not even compile
`analysis_options.yaml:8` excludes `lib/features/**` from analysis, which hides that this tree is **broken**, not merely unused:
- `lib/features/shell/shell_screen.dart:4` imports `../nexus/nexus_screen.dart` — **that directory does not exist**.
- `lib/features/auth/screens/login_screen.dart:32` calls `auth.login(email:, password:)`; `AuthService.login` (`auth_service.dart:274`) is **positional** `(String email, String password)` — signature mismatch.
- `lib/features/auth/screens/register_screen.dart:58` calls `auth.registerUser(...)` — **no such method exists**.
- `lib/features/members/members_screen.dart:17` reads `auth.currentUser?.role`; `AuthService.currentUser` returns a `firebase_auth.User` (`auth_service.dart:22`), which has no `.role`.
- `lib/features/notes/notes_screen.dart:111` uses `firestore.notesStream` and `create_note_screen.dart:56` uses `firestore.createNote(...)` — **neither exists** on `FirestoreService`.

So ~2,286 lines of `lib/features/` are unreachable, uncompilable, and hidden from the analyzer. `test/widget_test.dart` imports none of it, which is why the suite still passes.

### 6.7 Orphaned public API surface (live files, dead members)
| File | Dead members |
|---|---|
| `firestore_service.dart` | `approveUserTransaction` (:12), `rejectUser` (:66), `loadMoreUsers` (:102), `streamPendingUsers` (:108), `loadMorePendingUsers` (:115), `streamCourseNames` (:121), `updateCourseNames` (:152), `resetCourseNamesToDefault` (:161) — the admin portal writes raw Firestore instead (`admin_portal_screen.dart:113, 888`) |
| `cache_service.dart` | `saveNotes` (:21), `getNotes` (:29), `getNotesCachedAt` (:36), `clearAll` (:65) + `_notesBox`/`_notesKey` — `init()` still opens the notes box (`:17`) for nothing |
| `nexus_service.dart` | `loadMoreMaterials` (:72), `clearMaterialsCache` (:93) |
| `notification_service.dart` | `dispose` (:122) — never called on the singleton |
| `utils.dart` | `defaultSignatureColorFor` (:41), `firestoreErrorMessage` (:130), `isPrivilegedRole` (:154), `roleLabel` (:157) |
| widgets | `BootScreen` (`status_screens.dart:5`), `NxDropdown` (`nx_field.dart:102`), `VerificationBadge` |
| `constants.dart` | `kAppName` (:4 — `main.dart:44` hardcodes the literal instead), `kRoleStudent/kRoleApprover/kRoleAdmin` (reachable only through dead code), `kFaculties` (:27), `kSlots` (:99) — **8 of 20 constants are wholly unreferenced** |

`kMaxNoteImageBytes` / `kMaxProfileImageBytes` (`constants.dart:119-120`) are also unreferenced — image size is capped only by `maxWidth`/`imageQuality` (`post_note_sheet.dart:58-70`, `profile_edit_screen.dart:85-89`), so the intended 6 MB / 4 MB guards **do not exist**.

### 6.8 Model class collisions
Three classes named `Note` (`models/note.dart:3`, `models/note_model.dart:3`, `core/models/nexora_models.dart:100`) with three different Firestore schemas, and three user models (`UserModel`, `PendingUserModel`, `NexoraUser`) with divergent field sets. `NoteService.publish` (`note_service.dart:96-110`) writes the *dead* `note.dart` field set (`body`/`createdAt`/`verified`) while the live feed orders by `timestamp`.

### 6.9 Design-token violation
`memory/AGENT_MATRIX.md.txt:153` — *"Import tokens exclusively from `lib/core/theme.dart`"*. `nexus_screen.dart` hardcodes an independent Nexus palette (`0xFF0D0D12`, `0xFF13131A`, `0xFFEF4444`, …) and mixes in `NexoraTheme.primary` for the badge/loader (`:340, :849`). `_subjectBgColor` (`:61-76`) has two dead branches — `'DB'` and `'OS'` return identical colours.

---

## 7. Broken build / deploy configuration

| Issue | Evidence |
|---|---|
| **`firebase deploy` will fail** | `firebase.json:6` declares `"storage": { "rules": "storage.rules" }` but **`storage.rules` does not exist** |
| **No hosting target** | `firebase.json` has no `hosting` section, despite a full `web/` PWA and a production Nexus-style web app |
| **No version control** | Not a git repository; no `.gitignore`; no `.github/` (CI documented at `memory/AGENT_MATRIX.md.txt:17` does not exist) |
| **Web cache is a silent no-op** | §3.5 |
| **`build.log`** | Truncated mid-NDK-install (4 lines) — a failed build was left in the repo root |
| **`README.md`** | Still the unmodified Flutter template; documents none of the actual architecture |
| **`memory/AGENT_MATRIX.txt` vs `AGENT_MATRIX.md.txt`** | Two divergent copies of the same spec; neither mentions `nexus_service.dart`, `cache_service.dart`, `app_config.dart`, or the PDF viewer — the Nexus integration is entirely undocumented |
| **Analysis blind spot** | `analysis_options.yaml:8` excludes `lib/features/**` |
| **Lint config self-contradiction** | `analysis_options.yaml:14-17` sets `errors: deprecated_member_use: ignore`, `prefer_const_constructors: ignore`, `prefer_single_quotes: ignore`, `prefer_interpolation_to_compose_strings: ignore` while `linter.rules` (`:22-27`) enables `prefer_single_quotes` and `prefer_const_constructors` — the rules are disabled the moment they fire |
| **Stale scratch script** | `scratch_nexus.py` — dev leftover that scrapes the live Nexus site; the source of the hardcoded `kNexusUrl` |

---

## 8. Remaining analyzer warnings (the only 4)

```
warning  unused_field              nexus_screen.dart:421  _materialsEverLoaded
warning  unused_local_variable     nexus_screen.dart:426  isExpired
warning  unnecessary_cast          firestore_service.dart:110
warning  unnecessary_cast          firestore_service.dart:117
```
Notably, **two of the four are in the broken materials-cache path** — the analyzer is pointing directly at the defect described in §3.

---

## 9. Recommended fix order

1. **`firestore.rules`** — add `adminNotifications`; fix the `users` read rule (or replace collection queries with index queries); require auth on `notes`; restrict `noteNotifications` delete to admins; lock `role`/`authorName`/`authorRegNo` against client writes.
2. **Re-open the registration entry point** — the live login screen has no email/password path and `/register` is pushed only from a dead file (§1.1 Break A).
3. **`auth_service.dart:93`** — remove or replace the first-member query so profile submission works for everyone (§1.1 Break B).
3. **Materials cache** — move `_loadMaterialsCache()` to `initState`, normalise `Timestamp`→ISO string before `saveMaterials`, `await` the write, and actually render `_cachedMaterials` when the stream is idle; honour `isExpired`.
4. **Pagination** — implement real paging or drop the fake `loadMore*` APIs; make `refreshMaterials()` use the same `.limit()` as `getNexusMaterials()`; await the real stream in `onRefresh`.
5. **`nexus_embed_web.dart`** — implement the user bridge (or document web as unsupported) and real `canGoBack()`.
6. **Role vocabulary** — collapse to one enum; make the WebView injection translate `student → friend`, `superadmin → admin`; fix the `'candidate'` hole in `auth_gate.dart`.
7. **Nexus sync** — `await` it, make it transactional with the approval, pass the real `isAdmin`, drop `'provider': 'google'`, and stop creating phantom email-keyed documents.
8. **PDF cache** — move `dart:io` behind a conditional import, add a size/count eviction policy, pass `docId`/`version` from the PWA bridge.
9. **Delete dead code** — `lib/features/**`, `user_service.dart`, `note_service.dart`, `note_deletion_logs_screen.dart`, `storage_service.dart`, `models/note.dart`, `verification_badge.dart`, `webview_platform_*.dart`; remove `qr_flutter` + `mobile_scanner` + `webview_flutter_web`; drop `lib/features/**` from `analysis_options.yaml` exclusions so the analyzer can see the real codebase.
10. **Config** — add `storage.rules`, add hosting to `firebase.json`, initialise git, delete the scratch/stray files, refresh `README.md`, rotate the ImgBB key, and consolidate the two `AGENT_MATRIX` copies with a Nexus/cache section.

---

## 10. Bottom line

The app **compiles, passes all 14 tests, and builds for web**, but the green build is misleading — the test suite covers only constants, models, and presentational widgets, and the analyzer is configured to hide 2,286 lines of the tree that would not even compile if analysed.

**Nobody can join the app.** The only reachable sign-in is Google (the live login screen has no email/password UI, and `/register` is pushed only from a dead file), and the profile submission that follows is denied by `firestore.rules` at the first-user check. Only the hardcoded developer email gets in. The same rule silently breaks the Members tab for every non-admin.

The Nexus ↔ Nexora bridge is the weakest link: the cross-project sync reaches only one of three approval paths, is unawaited, writes fabricated `provider: 'google'` provenance into a second production project, and the **web** embed discards the user's identity entirely (`nexus_embed_web.dart` never reads `widget.user`).

The materials cache is non-functional at every layer — Hive rejects the payload with `Cannot write, unknown type: Timestamp` (empirically confirmed), the cached data is never rendered, the read path would crash on `setState()` during `build()` if the cache ever worked, pagination is a hard 20-item cap with a dead `loadMoreMaterials`, and pull-to-refresh silently drops the `.limit()` so the list grows.

Underneath both, `firestore.rules` permits world-readable, author-mutable "non-erasable" notes, lets any signed-in user delete every broadcast notification, and denies `adminNotifications` outright — while the features built to compensate (deletion audit trail, admin alerts) are either rule-denied or unreachable dead code.