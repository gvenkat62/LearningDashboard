Learning Dashboard is a SwiftUI iOS app built with MVVM and Clean Architecture. You log in, see your courses, open one to mark lessons complete, and it keeps working offline.

Screens
Login: email and password with checks on each field (valid email format, password of at least 8 characters), a spinner while logging in, and error messages such as “Incorrect email or password” or “You’re offline”. The demo login is learner@example.com / Password123.
Course Dashboard: each course shows its title, instructor, a progress bar, the lesson count and a Continue button. There are loading, list, empty and error-with-retry screens, plus pull to refresh.
Course Detail: a progress header and the lesson list, each lesson marked ✓ Completed or ○ Pending. “Mark Complete” updates the lesson and the course progress straight away, and the dashboard shows the new value when you go back.
Architecture
UI (SwiftUI Views)
 ↓
ViewModels (@Observable, one state enum per screen)
 ↓
Domain (Course/Lesson models, progress maths, merge rules, validation, repository protocols)
 ↓
Data (Repositories → Remote API + Local SwiftData cache + Keychain)
No impossible screens: each ViewModel exposes one state enum (loading / loaded / empty / failed), so the UI can’t be in two states at once.
Business rules in one place: they live in the Domain layer as plain Swift with no framework code, so they’re easy to test.
Composition root: AppContainer is the only place that knows the concrete classes. Moving from the mock to a real backend means changing one line.
API layer: requests go through real endpoints, status-code handling and JSON decoding. Only the last step, the network transport, is faked, and it reads bundled JSON.
Offline support
Reading: the app tries the network first. If that fails it shows the saved data from SwiftData, with a banner saying “You’re offline, showing courses saved X ago”.
Lessons offline: lessons for every course are downloaded in the background, so course details also open offline.
Completing lessons: a completion is saved on the device first and marked to send later. It goes to the server on the next refresh, or as soon as the connection comes back.
No lost progress: completed lessons never become incomplete, so an out-of-date server response can’t erase progress made offline.
Production touches
Security: the login token is stored in the Keychain, and the cache is cleared on logout.
Errors and logging: one error type turns failures into friendly messages, and logs use Apple’s logging system with personal data kept private.
Debug menu: it can simulate offline or force an empty list or a server error, so every screen state can be checked without editing code.
Accessibility: screens have accessibility labels and support larger text sizes.
Tests

All 12 unit tests pass in Xcode:

Repository offline behaviour: cached courses are served when offline, an empty cache shows an error, an expired session isn’t hidden behind cached data, and a lesson completed offline syncs later and survives an out-of-date server response.
Dashboard states: empty, error, and offline with saved courses.
Login: field validation, a wrong password, and a successful login.
Progress maths: rounding, zero lessons and out-of-range numbers.
README

README.md is one page and answers the five questions: architecture, offline support, token security, what to improve for scale, and how I’d build the same app on Android with Compose, Room, WorkManager and the Keystore.
