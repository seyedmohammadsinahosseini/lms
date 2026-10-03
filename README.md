# OTMS — Online Teaching & Management System

OTMS is a phone-first Flutter learning-management application backed by a
versioned PHP API and MariaDB. Android is the primary native target; the same
client has a responsive Flutter Web portfolio mode.

## What works

- Student/teacher registration, login, profile editing and password changes
- Teacher invitation control and one-use, expiring class-enrollment grants
- Classes, lessons, text/video/booklet content and authorized private files
- Versioned assessments, timed attempts, attempt limits, auto/manual grading,
  answer-release policies and teacher lifecycle controls
- Homework deadlines, late/resubmission policy, immutable submission versions
  and grading feedback
- Class Q&A, role-specific server dashboards, and Live session management
- Isolated, expiring synthetic demo sandboxes
- Cookie + CSRF Web sessions and secure native bearer-token storage

The API is exposed under `/api/v1`. Flat `/api/*.php` routes are retained only
as a compatibility window and use the same implementations.

## Repository map

```text
backend/                         PHP 8 API and fresh MariaDB schema
backend/api/v1/                  stable versioned public entry points
backend/migrations/              preserving upgrade migration
otms_flutter/                    Android/Web Flutter client
tools/api_test.sh                48-check lifecycle regression suite
tools/api_security_test.sh       upload/auth/CSRF/CORS security suite
tools/demo_seed.sql              non-production local fixture
.github/workflows/ci.yml         backend, Flutter, Web and Android CI
IMPLEMENTATION_PROGRESS_FA.md    Persian implementation checklist
```

## Requirements

- PHP 8.2+ with PDO MySQL and `mbstring`
- MariaDB 10.6+ (MariaDB 11 is tested) or a compatible MySQL 8 installation
- Flutter 3.47.6 / Dart 3.13 or compatible newer stable SDK
- Android: JDK 21 and Android SDK 36

## Local start (Linux/macOS)

From the repository root:

```bash
mysql -u root -p -e 'CREATE DATABASE otms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
mysql -u root -p otms < backend/schema.sql
mkdir -p config
cp backend/.env.example config/otms.env
```

Edit `config/otms.env` for local use. At minimum set the database values,
`OTMS_APP_ENV=local`, a random `OTMS_APP_KEY`, an absolute private
`OTMS_STORAGE_PATH`, `OTMS_DEMO_MODE=1`, and:

```dotenv
OTMS_PUBLIC_BASE_URL=http://127.0.0.1:8080
OTMS_ALLOWED_ORIGINS=http://127.0.0.1:3000,http://localhost:3000
OTMS_LIVE_PROVIDER=jitsi
```

Then run the backend from the repository root:

```bash
php -S 0.0.0.0:8080 -t backend
curl http://127.0.0.1:8080/api/v1/health.php
```

In a second terminal:

```bash
cd otms_flutter
flutter pub get
flutter run -d chrome \
  --dart-define=OTMS_API_BASE=http://127.0.0.1:8080/api/v1 \
  --dart-define=OTMS_APP_MODE=development
```

For an Android emulator use `http://10.0.2.2:8080/api/v1`. A release Android
build refuses cleartext HTTP, so production must use HTTPS.

The optional SQL fixture is for a fresh local database only:

```bash
mysql -u root -p otms < tools/demo_seed.sql
# teacher@otms.test / password
# student@otms.test / password
```

Do not import that fixture into production. Public portfolio demonstrations use
the app's **Try demo** action, which creates a separate expiring sandbox.

Windows/XAMPP and physical-phone steps are in [docs/راهنمای-اجرا.md](docs/راهنمای-اجرا.md)
and [docs/اجرا-روی-گوشی.md](docs/اجرا-روی-گوشی.md).

## Configuration rules

Client compile-time values:

| Define | Values | Purpose |
|---|---|---|
| `OTMS_API_BASE` | HTTPS URL ending in `/api/v1` | API endpoint |
| `OTMS_APP_MODE` | `development`, `portfolio_demo`, `production` | visible mode and release safeguards |

Server variables are documented in `backend/.env.example`. Keep the real env
file, upload storage, JaaS private key and Android keystore outside the public
directory and outside Git.

In production:

- `OTMS_APP_ENV` must be `production`.
- `OTMS_APP_KEY`, explicit HTTPS `OTMS_PUBLIC_BASE_URL`, and
  `OTMS_ALLOWED_ORIGINS` are required.
- Enable `OTMS_TRUST_PROXY=1` only behind the hosting provider's trusted HTTPS
  proxy.
- Keep teacher self-registration disabled. Generate a one-use invite over SSH:

```bash
OTMS_ENV_FILE=/absolute/path/config/otms.env \
  php tools/create_teacher_invite.php 24
```

## Quality checks

```bash
# PHP syntax
find backend -type f -name '*.php' -print0 | xargs -0 -n1 php -l

# API tests; each needs a clean database imported from backend/schema.sql
OTMS_DB_NAME=otms_test bash tools/api_test.sh
OTMS_DB_NAME=otms_security bash tools/api_security_test.sh

# Flutter
cd otms_flutter
flutter analyze
flutter test
```

The lifecycle suite covers 48 contracts. The security suite covers upload
extension/MIME/size rejection, private storage, signed links, role boundaries,
CSRF and configured CORS. CI additionally validates the preserving migration,
local seed, release Web build, browser boot and Android debug compilation.

## Upgrading an existing database

`backend/migrations/2026-10-02_full_remediation.sql` preserves legacy integer
identifiers while adding the new lifecycle/security model. Never apply it first
on the only copy of real data.

1. Stop writes and create a full database backup.
2. Restore that backup to staging.
3. Run the migration against staging.
4. Run both API suites and inspect important records/files.
5. Only then repeat on production during a maintenance window.

The migration is intentionally one-way. Recovery means restoring the backup.

## Deployment and releases

- Free portfolio deployment on HelioHost Johnny:
  [docs/استقرار-رایگان.md](docs/استقرار-رایگان.md)
- Signed universal Android APK and SHA-256:
  [docs/انتشار-اندروید.md](docs/انتشار-اندروید.md)
- GitHub upload instructions:
  [docs/پوش-به-گیتهاب.md](docs/پوش-به-گیتهاب.md)

`tools/package_heliohost.sh` builds a same-origin Web/API bundle with HelioHost's
`httpdocs` layout. It does not upload anything or alter an external account. `tools/build_signed_apk.sh`
requires your own durable application ID and signing key and never permits a
debug-signing fallback.

## Security design

Uploads are allow-listed by extension and detected MIME, capped at 8 MiB,
stored outside the document root with random server names, and streamed only
after authorization or through a user-bound five-minute HMAC URL. Web sessions
use HttpOnly/Secure/SameSite cookies plus CSRF tokens; Android tokens use the
platform's secure storage. Authentication and sensitive operations are rate
limited and audited. Production CORS never auto-allows localhost.

Public `meet.jit.si` rooms are deliberately development-only. Production Live
sessions require JaaS credentials; without them the API returns a clear
configuration error rather than creating an insecure room.

## Current release constraints

The repository contains the complete release path, but two actions require
owner-controlled external material:

1. creating/configuring the hosting account and database; and
2. choosing a unique Android application ID and safeguarding a signing key.

JaaS credentials are separately required if the public demo must start secure
production Live rooms.
