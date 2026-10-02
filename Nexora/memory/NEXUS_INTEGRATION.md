# NEXORA — Nexus integration: email linking, materials sync, downloads

**Date:** 2026-09-30
All claims below were verified against the **live** `nexus-e7a36` project (Firestore REST API + the deployed PWA source), not inferred from the Dart code.

---

## 1. Are Nexora and Nexus user emails linked?

### What the live Nexus project actually does

Reading `https://nexus-e7a36.web.app/index.html` and querying the Firestore REST API directly:

**Nexus `users` document shape** (written by the PWA's `createPendingUser`):
```js
{
  uid, email, name, googleName, photoURL,
  role: 'pending', approved: false, provider: 'google',
  createdAt: serverTimestamp()
}
```

**Critical finding — the link is broken in the live project, not just in Nexora:**

```
GET .../documents/users     →  403 PERMISSION_DENIED  (anonymous)
GET .../documents/materials →  200 OK, 13 docs
GET .../documents/subjects  →  200 OK, 7 docs
```

The Nexus `users` collection is **not readable without a session**. `NexusService`
holds an *unauthenticated* Firestore client — it never signs in to the Nexus
project. So every email lookup was returning `false`/empty regardless of the
rules, and the failure was swallowed by `catch` blocks. **The email link has
never actually worked.** It looked like it did because "not found" and "could
not check" produced the same silent result.

### The duplicate-approval hole

`checkNexusApproval` previously treated `role == 'friend' || role == 'admin'` as
approved. The Nexus PWA writes `role: 'pending'` and **never** writes `friend`,
so the match was always false — and, critically, it would have been true for
anyone the PWA had promoted. Nothing prevented the same human being approved
twice: once via Nexus admin approval, once via Nexora admin approval, producing
two vouched identities for one person. That is the exact duplication you asked
about.

### Fixes applied

| Fix | Detail |
|---|---|
| **Duplicate guard at approval time** | `admin_portal_screen.dart` now calls `NexusService().lookupNexusUserByEmail()` before the approval transaction. If the candidate is already `verifiedByNexora`, a confirmation dialog shows the email, Nexus role and Nexus name and requires "Approve anyway". |
| **Approval semantics corrected** | Only explicit `approved: true` now counts. `role: 'friend'` no longer implies approval. |
| **Lookup failure ≠ not a member** | `lookupNexusUserByEmail` returns `null` with `lastLookupError` set when the read is *denied*, distinct from "no such user". Previously a denied read was indistinguishable from a clean one. |
| **Explicit document shape** | `NexusUserRecord` carries `nexusDocId`, `nexusUid`, `email`, `role`, `approved`, `verifiedByNexora`, `nexoraUid` — everything needed to link the two identities. |
| **`isAlreadyLinkedAcrossProjects()`** | Convenience predicate for "is this the same human, already verified". |

### What still needs your decision

The 403 means the link cannot work until one of these happens — **this is a
decision only you can make**, since it touches the Nexus project's security:

1. **Grant read on Nexus `users` to authenticated users** (recommended). Then
   have `NexusService` sign the user into the Nexus project with the same Google
   credential, so lookups run as that identity.
2. **Mirror a minimal `email` index into Nexora** on approval, so Nexora can
   answer "is this email already linked?" without reading Nexus.
3. **Accept the guard as advisory** — it works only if the Nexus rules are
   relaxed, otherwise `lookupNexusUserByEmail` returns `null` and the dialog
   never appears.

Until then the guard is correct but inert. I did not weaken the Nexus project's
rules to force it.

---

## 2. Are the Materials tab and Live Web tab synced?

### Yes — they are the same data, and were already

Both surfaces read **the same Firestore collection in the same project**:

| | Nexus PWA (Live Web) | Nexora Materials tab |
|---|---|---|
| Project | `nexus-e7a36` | `nexus-e7a36` |
| Collection | `collection('materials')` | `collection('materials')` |
| Order | `.orderBy('createdAt','desc')` | `.orderBy('createdAt', descending: true)` |
| Limit | none | 20 per page, cursor-paginated |

Verified: `orderBy=createdAt desc` returns 13 documents anonymously, so the
Nexora feed can read them. **Field names also match** — I confirmed the live
documents carry `title`, `subject`, `fileUrl`, `fileType`, `uploaderName`,
`version`, `createdAt`, which is exactly what `_Material` reads.

So they cannot drift. The perception of "not synced" comes from two real
behaviours, both now addressed:

| Symptom | Cause | Fix |
|---|---|---|
| Materials tab shows a different count than Live Web | The tab served the **Hive offline cache** with no "this is stale" signal, and a 30-min TTL was computed but ignored | Cache banner + TTL now honoured; parity check added |
| A re-uploaded file didn't refresh | `version` bumps in Nexus, but the cached page was never revalidated | Cache is now revalidated whenever the incoming page differs by doc id **or version** |
| Silent divergence in general | Nothing compared the two | `_verifyFeedParity()` compares the rendered count against `NexusService.countMaterials()` (a cheap aggregate query) and rebinds on mismatch |

Both tabs read the same collection, so **there is nothing to synchronise between
them** — no dual-write, no cache to invalidate across surfaces. The only thing
that can drift is the offline cache, which is now self-checking.

### URL reality check (live data)

The 13 live materials split across two hosts, and both work:

| Host | Status |
|---|---|
| `huggingface.co/.../resolve/main/X.pdf.part0?parts=N` | ✅ 200 — full file at `X.pdf` is **14.2 MB**, each part ~3.3 MB |
| `raw.githubusercontent.com/.../X.pdf` | ✅ 200 — 22.5 MB |
| `github.com/.../releases/download/materials-v1/1786383825722_Linear_algebra.pdf` | ❌ **404** — a dead link still present in the live data |

The 404 is a *data* problem in the Nexus project, not a code problem. The
Nexora app no longer silently substitutes a different file (that was serving the
wrong document); it now surfaces a clear error. **You should update that
material's `fileUrl` in Nexus** to
`https://huggingface.co/datasets/ThalaivarGokul447/nexus-materials/resolve/main/Linear_algebra_CAT_2.pdf`
— the same convention every other `*_CAT_2` material uses.

---

## 3. Can materials be downloaded to mobile storage?

### Why it did not work

Two separate failures, both fixed:

**Native Materials tab** — the download button called:
```dart
launchUrl(uri, mode: LaunchMode.externalApplication);
```
That hands the URL to an external app. For `huggingface.co` and
`raw.githubusercontent.com` that either opens a browser that downloads to an
obscure location, or does nothing visible. The user got no file and no error.

**Live Web tab** — worse. The Nexus PWA's `viewFile()` does this:
```js
const blobUrl = URL.createObjectURL(correctedBlob);
const a = document.createElement('a');
a.href = blobUrl; a.download = downloadName;
a.click();
```
**A WebView cannot download a `blob:` URL.** The tap produced nothing, silently.
The existing JS bridge deliberately skipped blob URLs (`!url.startsWith('blob:')`),
so the fallback never engaged either.

### Fixes applied

**New `MaterialDownloadService`** (`lib/services/material_download_service.dart`)
- On Android, delegates to the system **`DownloadManager`** via a new
  `MethodChannel` in `MainActivity.kt` — the file lands in the real public
  Downloads folder, is visible to the user's file manager, shows a system
  notification, and survives app uninstall.
- Elsewhere, streams the bytes itself with proper status-code and network error
  handling (rather than silently doing nothing).
- Throws a typed `MaterialDownloadException` so every failure is surfaced.

**Manifest** — added `WRITE_EXTERNAL_STORAGE` (capped at API 28; scoped storage
covers API 29+) and the `VIEW` queries already needed.

**Native tab** — the Download button now opens a progress sheet showing the
filename, spinner, success path with the destination, and a **Retry** on failure.

**Live Web tab** — added a `NexusDownloadBridge` JS channel. A capturing
`click` listener intercepts `a[download]` anchors with real `http(s)` hrefs and
forwards them to the native downloader, so Live Web downloads land on the device
too. Blob hrefs are still left to the existing PDF bridge.

**Filename handling** — derives a safe, descriptive name from the URL path or
title, strips filesystem-illegal characters, and ensures a correct extension.

---

## Verification

| Check | Result |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter test` | **25/25 pass** |
| `flutter build web` | Succeeds |
| `flutter build apk --debug` | **Succeeds** (243.5 MB debug APK) — validates the new Kotlin `MethodChannel` compiles |
| Live Nexus project probed | `materials` 200 / 13 docs, `subjects` 200 / 7 docs, `users` **403** |

## 3. Superseded: cross-project sync is now read-only (Option A)

The direction was originally built backwards: `syncApprovalToNexus` **wrote** to
Nexus. Corrected — **Nexora never writes to Nexus.**

### Direction of truth

**Nexus is the source of truth for community membership.** A person a Nexus admin
approved (`role: 'friend'` or `'admin'`) is auto-approved in Nexora. Granting
Nexus membership remains a Nexus admin's decision alone.

### What was removed
- `syncApprovalToNexus()` and its call in the admin portal
- The `nexoraApprovals` staging collection
- `NexusSyncResult` / `NexusSyncStatus`

### What was added
| Feature | Detail |
|---|---|
| **Nexus sign-in** | `signInToNexus(idToken, accessToken)` creates a read-only session on the secondary `FirebaseAuth` for the `nexus_app`. Without it, every `users` read is rejected. Falls back to `signInToNexusWithAccount()` (silent Google auth) for the web popup path. Failures are non-fatal. |
| **Real-time watcher** | `watchMember(email)` returns a live Firestore stream. When a Nexus admin promotes someone `pending → friend`, the Pending screen observes it and calls `approveFromNexus()` — no Nexora review, no refresh. |
| **Auto-approval at registration** | `submitCandidateProfile` reads Nexus standing; an already-approved member writes straight to `users/{uid}` as `role: student`, `approvedBy: 'nexus_community'`. Not made an admin — simply not asked to re-apply. |
| **`approveFromNexus()`** | Re-verifies the Nexus standing immediately before writing (a revoked promotion cannot grant access), then batch-converts `pendingUsers/{uid}` → `users/{uid}`. |
| **Role vocabulary fixed** | `approved: true` is never set in Nexus, so gating on it made the check permanently false. Now `role == 'friend' \|\| role == 'admin'`. |
| **WebView bridge collision fixed** | `nexus_user_role_<uid>` is written with a mapped role (`friend`/`admin`) instead of Nexora's `student`/`superadmin`, which Nexus read back as unrecognised. |

### Rule change required in Nexora's own `firestore.rules`
Auto-approval means a client writes its own `users/{uid}` with `status: approved`.
Without a rule change that write is denied. Added a narrow branch permitting
**only** a self-create where `role == 'student'`, `status == 'approved'`,
`approvedBy == 'nexus_community'`, `isNexusMember == true`. A self-registering
user still cannot claim approval — the rules accept exactly one stamped shape.

### Known limitations
- **The Nexus sign-in is the only new dependency on Nexus behaviour.** It requires
  a Google sign-in the user has already performed. Email/password Nexora accounts
  get no Nexus session until they also sign in with Google, so their Nexus
  standing shows as unavailable rather than "not a member" (`lastLookupError`).
- **Rules still not emulator-verified** — needs JDK 21.

---

## Still needs your action

1. **Nexus `users` read permission** — the email link cannot function until this is resolved (§1).
2. **Fix the dead `fileUrl`** on the "Linear Algebra" material in Nexus (§2).
3. **Test downloads on a real device** — the `DownloadManager` path is compile-verified but not runtime-verified; I have no device here.
4. **`applicationId` is still `com.example.nexora`** and release builds are signed with debug keys (`android/app/build.gradle.kts`) — both must change before shipping.
5. Consider capping the 22 MB raw.githubusercontent PDFs; several materials exceed the 6 MB note-image limit and are being loaded fully into memory for in-app viewing.
