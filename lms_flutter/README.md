# LMS Flutter client

Phone-first Flutter client for the LMS repository. Android is the primary native
target and the same codebase builds a responsive portfolio Web client.

## Run locally

```bash
flutter pub get
flutter run -d chrome --web-port=3000 \
  --dart-define=LMS_API_BASE=http://127.0.0.1:8080/api/v1 \
  --dart-define=LMS_APP_MODE=development
```

For an Android emulator, use `http://10.0.2.2:8080/api/v1`. Release builds only
accept an HTTPS production API.

## Checks

```bash
flutter analyze
flutter test
flutter build web --release --no-wasm-dry-run \
  --dart-define=LMS_API_BASE=https://example.test/api/v1 \
  --dart-define=LMS_APP_MODE=portfolio_demo
```

Signed Android releases are created from the repository root with
`tools/build_signed_apk.sh`; see `../docs/انتشار-اندروید.md`.
