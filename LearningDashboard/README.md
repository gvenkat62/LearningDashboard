# Learning Dashboard (iOS · SwiftUI · MVVM + Clean Architecture)

**Run:** open `LearningDashboard.xcodeproj`, run on an iOS simulator. Log in with `learner@example.com` / `Password123` (DEBUG builds have a "Fill demo account" button). **Test:** ⌘U.
**Try every state:** the account menu (top right) has a DEBUG section to *Simulate Offline* and switch the mock API to *Empty* or *Server error (500)*. Turning off your Mac's Wi‑Fi also works: the mock client reads real reachability.

```
Presentation  SwiftUI Views → @Observable ViewModels (state enums)     Login / Dashboard / CourseDetail
Domain        Entities, ProgressCalculator, CourseMerger, validators,  pure Swift, no frameworks
              repository *protocols*
Data          DefaultCourseRepository / DefaultAuthRepository
              ├─ Remote: CourseAPI/AuthAPI → HTTPClient (MockHTTPClient | URLSessionHTTPClient)
              └─ Local:  SwiftDataCourseStore (offline cache), Keychain (session)
App           AppContainer: composition root, constructor injection
```

### 1. Architecture
MVVM keeps views declarative and easy to test: each ViewModel exposes one explicit state enum (`loading / loaded / empty / failed`), so the UI can't end up in an impossible state. Clean Architecture layers make dependencies point inward. Business rules (how progress is calculated, how server and cache data are merged, input validation) live in the Domain layer as pure functions. Repositories hide where data comes from. Only `AppContainer` knows the concrete types, so swapping the mock backend for a real one means changing one line. I left out use-case classes that would only pass calls through to a repository. I'd add them when a rule needs more than one repository. All requests go through the real HTTP path (endpoints, status-code mapping, decoding); only the transport is mocked.

### 2. Offline support
- **Reads (network-first, cache fallback):** fresh data is written to SwiftData (SQLite). If any request fails, cached courses are shown with an "offline, last updated X" banner. Lessons for every course are prefetched after each fetch, so course details also work offline.
- **Writes (local-first):** completing a lesson is saved to the database before the network call and flagged `pendingSync`. Queued completions are sent on the next refresh, or as soon as the connection comes back.
- **Conflicts:** completion only ever moves forward, so a merge keeps a lesson completed if either side says it is. A stale server response can't erase offline progress, and no sync engine is needed. This is covered by unit tests.

### 3. Security
Store tokens in the **Keychain** (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), as `KeychainSessionStorage` already does. Never put them in UserDefaults, files or the database. For production I'd add short-lived access tokens with refresh-token rotation, clear the Keychain on first launch after a reinstall (already done), and wipe the cache on logout (already done). I'd also consider certificate pinning, jailbreak checks for sensitive data, and keeping personal data out of logs (`os.Logger` privacy).

### 4. Scale (1M users, hundreds of courses)
1. **Pagination and delta sync:** cursor-paged `/courses`, `ETag`/`If-Modified-Since`, and a server-side `updatedAt` so clients download only what changed.
2. **Durable outbox:** a background sync queue (`BGTaskScheduler`) with exponential backoff, jitter and idempotency keys. Prefetch only courses that are in progress.
3. **Backend and CDN:** cache course catalogues at the CDN edge, serve per-user progress from a separate service, and add rate limiting.
4. **Observability:** crash and error reporting, API latency and error metrics, MetricKit, and feature flags for staged rollouts.
5. **Modularization:** split into Swift packages (Domain, Data, each feature) so teams can build and test independently. Add UI and snapshot tests in CI, plus localization and accessibility audits.

### 5. Second platform: Android
The same layers map one-to-one. Jetpack Compose screens and `ViewModel`s expose `StateFlow<UiState>` (a sealed class for loading, content, empty and error). Kotlin coroutines handle async work. Retrofit/OkHttp with kotlinx.serialization handles networking, with an interceptor that attaches tokens. **Room** replaces SwiftData as the cache, and the repository exposes a `Flow` so the UI updates automatically. **WorkManager** pushes pending completions when the network is available. Tokens go in **EncryptedSharedPreferences/DataStore** backed by the Android Keystore. Hilt handles dependency injection, and JUnit with Turbine tests the ViewModels. The Domain logic (progress, merge) would be ported almost line for line, or shared through Kotlin Multiplatform.
