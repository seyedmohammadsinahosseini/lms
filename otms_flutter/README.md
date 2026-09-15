# otms_flutter

The Flutter client for **OTMS** (Online Teaching & Management System) — a class
management app for teachers and students. Runs on Android and the web.

Project-wide setup, backend instructions and the API test scripts live in the
[repository README](../README.md).

## Quick start

```bash
flutter pub get
flutter run -d chrome        # web
flutter run                  # attached device or emulator
```

The app needs the PHP backend (`../backend`) running. The API base URL is
resolved automatically:

* **web** — the origin the app was served from
* **Android emulator** — `http://10.0.2.2/OTMS1/backend` (the host machine)
* **anything else** — `http://localhost/OTMS1/backend`

Point it somewhere else explicitly with:

```bash
flutter run --dart-define=OTMS_API_BASE=http://192.168.1.15/OTMS1/backend
```

See `lib/core/config/env.dart` for the resolution rules.

## Checks

```bash
flutter analyze
flutter test
```

## Layout

```
lib/
├── app.dart              Root widget, provider tree, auth gate
├── main.dart             Bootstrap only
├── core/config/env.dart  API base URL configuration
├── models/               Plain data models mirroring the API JSON
├── services/             ApiClient — the single HTTP layer
├── state/                AuthProvider, ThemeProvider
├── theme/                Light and dark themes
└── screens/
    ├── auth/             Login and registration
    ├── shared/           Sidebar, common widgets
    ├── student/          Student screens and tabs
    └── teacher/          Teacher screens and tabs
```
