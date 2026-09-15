# OTMS — Online Teaching & Management System

A class-management platform for teachers and students, built as a Flutter client
on top of a PHP + MySQL JSON API.

| Role | What they can do |
| --- | --- |
| **Teacher** | Create classes, share a join code, publish lessons and materials (notes, booklets, video, files), build assessments (multiple choice, true/false, yes/no, fill-in-the-blank, essay), post homework, grade submissions and essays, answer student questions |
| **Student** | Join a class with a teacher's code, read lessons and materials, take timed assessments, see results, submit homework, ask questions |

The repository contains both halves of the product:

| Path | What it is |
| --- | --- |
| [`otms_flutter/`](otms_flutter/) | The Flutter client — Android and web |
| [`backend/`](backend/) | The PHP 8 + MySQL API the client talks to (39 endpoints) |
| [`tools/`](tools/) | End-to-end API and security test scripts |
| `docs/` | Extra documentation — see [راهنمای اجرا](docs/راهنمای-اجرا.md) (Persian) |

---

## Contents

- [Requirements](#requirements)
- [Quick start on Windows with XAMPP](#quick-start-on-windows-with-xampp)
- [Quick start without XAMPP](#quick-start-without-xampp)
- [Running the app](#running-the-app)
- [Previewing in a browser without a device](#previewing-in-a-browser-without-a-device)
- [Configuration](#configuration)
- [Tests](#tests)
- [Troubleshooting](#troubleshooting)
- [Project layout](#project-layout)
- [Deploying](#deploying)
- [Security notes](#security-notes)
- [Known limitations](#known-limitations)

---

## Requirements

| Tool | Version | Needed for |
| --- | --- | --- |
| [XAMPP](https://www.apachefriends.org/) | any recent | Apache + MySQL + PHP on Windows |
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | 3.13 or newer | building the app |
| Android Studio, or Chrome | — | running the app on an emulator / in the browser |
| Git | — | cloning the repository |

`flutter doctor` should report Flutter and (for Android) the Android toolchain
as OK before you continue.

---

## Quick start on Windows with XAMPP

The backend must be served by Apache from a folder named `OTMS1`, because the
client's default API address is `http://localhost/OTMS1/backend`.

### 1. Put the project in `htdocs`

```bat
cd C:\xampp\htdocs
git clone https://github.com/seyedmohammadsinahosseini/my_flutter_app.git OTMS1
```

The clone **must** be named `OTMS1`. If you already have the folder under
another name, just rename it.

> Already have `C:\xampp\htdocs\OTMS1` with your own work in it? Clone elsewhere
> and copy `backend\` and `otms_flutter\` into it, or use a different folder name
> and pass `--dart-define=OTMS_API_BASE=...` when running the app (see
> [Configuration](#configuration)).

### 2. Start Apache and MySQL

Open the **XAMPP Control Panel** and press **Start** next to both **Apache** and
**MySQL**. Both should turn green.

### 3. Create the database

The schema file creates the database, all 17 tables and some demo data.

```bat
C:\xampp\mysql\bin\mysql.exe -u root < C:\xampp\htdocs\OTMS1\backend\schema.sql
```

If you are using **PowerShell**, `<` redirection is not supported — run it
through `cmd` instead:

```powershell
cmd /c "C:\xampp\mysql\bin\mysql.exe -u root < C:\xampp\htdocs\OTMS1\backend\schema.sql"
```

Or skip the command line entirely: open <http://localhost/phpmyadmin>, choose
**Import**, select `backend/schema.sql` and press **Go**.

Then optionally load the demo data, so every screen has real content instead of
empty states — five classes, seven students, lessons and materials, assessments
with graded work, homework waiting to be marked and Q&A threads:

```bat
C:\xampp\mysql\bin\mysql.exe -u root otms < C:\xampp\htdocs\OTMS1\tools\demo_seed.sql
```

To start over with a clean slate, re-import `backend/schema.sql` on its own.

### 4. Check the backend is alive

Open this in your browser:

```
http://localhost/OTMS1/backend/api/me.php
```

You should see `{"error":"Not authenticated"}`. That is the correct answer — it
means Apache is serving the PHP API, the database connection works, and the
endpoint is enforcing authentication. Anything else (a 500, a blank page, or a
page full of HTML) means something in this section needs fixing — see
[Troubleshooting](#troubleshooting).

### 5. Run the app

```bat
cd C:\xampp\htdocs\OTMS1\otms_flutter
flutter pub get
flutter run -d chrome --dart-define=OTMS_API_BASE=http://localhost/OTMS1/backend
```

> Nothing here starts the backend for you: `flutter run` only runs the client.
> Apache and MySQL are separate processes — leave XAMPP from step 1 running.
> The `--dart-define` above is mandatory, because the Flutter dev server picks a
> random port and the web app otherwise looks for the backend on *its* origin
> (`http://localhost:53241/OTMS1/backend`), not on Apache. The URL inside the
> error message says which one it tried.

Log in with the seeded accounts:

| Email | Password | Role |
| --- | --- | --- |
| `teacher@otms.test` | `password` | teacher |
| `student@otms.test` | `password` | student |

For an Android emulator the flag is not needed — the app defaults to
`http://10.0.2.2/OTMS1/backend`, which is how the emulator reaches your PC:

```bat
flutter run
```

> **Note (only if your database already existed before the login-throttling
> change):** run the migration once, otherwise sign-in fails:
> ```bat
> C:\xampp\mysql\bin\mysql.exe -u root otms < C:\xampp\htdocs\OTMS1\backend\migrations\2026-09-15_login_attempts.sql
> ```

---

## Quick start without XAMPP

Any PHP 8 with `pdo_mysql` will do. From the repository root:

```bash
# 1. Create the database (uses the OTMS_DB_* variables, defaults: root, no password)
php -r 'require "backend/config.php"; db();' || true
mysql -u root < backend/schema.sql
mysql -u root otms < tools/demo_seed.sql     # optional sample content

# 2. Serve the project
php -S 127.0.0.1:8080 -t .

# 3. The API is now at http://127.0.0.1:8080/backend/api/
```

Then run the app against it:

```bash
cd otms_flutter
flutter pub get
flutter run -d chrome --dart-define=OTMS_API_BASE=http://127.0.0.1:8080/backend
```

---

## Running the app

| Target | Command | API base used |
| --- | --- | --- |
| Web (development) | `flutter run -d chrome --dart-define=OTMS_API_BASE=http://localhost/OTMS1/backend` | must be passed — the dev server runs on a random port |
| Android emulator | `flutter run` | `http://10.0.2.2/OTMS1/backend` (automatic) |
| Desktop / iOS simulator | `flutter run` | `http://localhost/OTMS1/backend` (automatic) |
| Physical phone on Wi-Fi | `flutter run --dart-define=OTMS_API_BASE=http://<your-ip>/OTMS1/backend` | must be passed |

Find your machine's address with `ipconfig` (Windows) or `ip addr` (Linux/macOS)
— something like `192.168.1.15`. The phone and the computer must be on the same
network, and Apache must be allowed through the firewall (on Windows, allow
Apache on **private** networks the first time it asks).

If you use VS Code, [`.vscode/launch.json`](.vscode/launch.json) already contains
these three configurations, so you can just press <kbd>F5</kbd>. Android Studio
has the same three under `.idea/runConfigurations/`.

#### Running on a physical phone

A phone is not the emulator, so `10.0.2.2` (the emulator's alias for your PC) and
`localhost` (which on a phone means *the phone*) both fail. The app has to be
told where the backend is:

```bat
:: 1. the PC's address on the local network -- read the IPv4 Address line
ipconfig

:: 2. allow Apache through the firewall, once (cmd as Administrator)
netsh advfirewall firewall add rule name="OTMS dev HTTP" dir=in action=allow protocol=TCP localport=80

:: 3. run against that address
flutter run --dart-define=OTMS_API_BASE=http://192.168.1.15/OTMS1/backend
```

Before blaming the app, open `http://192.168.1.15/OTMS1/backend/api/me.php` **in the
phone's browser**. Seeing `{"error":"Not authenticated"}` proves the network,
firewall and Apache are fine.

No shared Wi-Fi, or the firewall will not cooperate? Forward the port over the USB
cable instead — `adb reverse tcp:8080 tcp:80`, then use
`--dart-define=OTMS_API_BASE=http://localhost:8080/OTMS1/backend`.

A full step-by-step for Android Studio, including the run configuration dialog and
a troubleshooting table, is in
[docs/اجرا-روی-گوشی.md](docs/اجرا-روی-گوشی.md) (Persian).

### Previewing in a browser without a device

To click through the app on a computer — or open it on a phone's browser — build
the web version and put it under `htdocs` next to `backend/`. Serving both from
one origin means no CORS origin to configure and no `--dart-define`: the app
resolves its API from the address it was served from.

**Windows (Command Prompt), with Apache already running:**

```bat
cd C:\xampp\htdocs\OTMS1\otms_flutter
flutter build web --debug --base-href=/OTMS1/preview/

mkdir C:\xampp\htdocs\OTMS1\preview
xcopy /E /I /Y build\web C:\xampp\htdocs\OTMS1\preview
```

Then open `http://localhost/OTMS1/preview/`. No `php -S` needed — Apache serves it:

```
C:\xampp\htdocs\OTMS1\
├── backend\        the API (already there)
├── otms_flutter\   the app source (already there)
└── preview\        the build output (the only thing you add)
```

`--base-href` is required: served from a subpath, the app's assets
(`main.dart.js`, `canvaskit/`) must be requested under `/OTMS1/preview/`, or the
browser 404s them and you get a blank page.

**Linux / macOS** — the same idea, into whatever your document root is:

```bash
cd otms_flutter
flutter build web --debug --base-href=/OTMS1/preview/
mkdir -p /var/www/html/OTMS1/preview
cp -r build/web/. /var/www/html/OTMS1/preview/
```

#### Why not the symlink approach

The older instructions here used `ln -s ../../backend ../preview/OTMS1/backend`
and served the build from a throwaway directory. That works on Linux/macOS, but
on Windows `ln` does not exist, and its replacement `mklink` is a **cmd builtin**
(so it fails from PowerShell with `The term 'mklink' is not recognized`) that
also needs Administrator rights for a directory link. The `--base-href` route
above needs neither.

Windows equivalents if you do want the symlink:

| POSIX | Windows |
| --- | --- |
| `ln -s target link` | `mklink /D link target` (cmd, as Administrator) |
| `mkdir -p a/b` | `mkdir a\b` (creates intermediate directories) |
| `cp -r src/. dst/` | `xcopy /E /I /Y src dst` or `robocopy src dst /E` |
| `php …` when not on PATH | `C:\xampp\php\php.exe …` |
| `a && b` | fine in **cmd**; not in PowerShell 5.1 — use separate lines |

## Configuration

### App: `OTMS_API_BASE`

A compile-time setting, so it cannot be changed after a build without rebuilding:

```bash
flutter run   --dart-define=OTMS_API_BASE=http://192.168.1.15/OTMS1/backend
flutter build apk --dart-define=OTMS_API_BASE=https://example.com/otms/backend
```

When it is not set, the app guesses:

| Platform | Default | Why |
| --- | --- | --- |
| Web | the origin the app was served from | a web build deployed next to `backend/` works with no configuration |
| Android | `http://10.0.2.2` | the emulator's alias for the host machine's `localhost` |
| Everything else | `http://localhost` | desktop and the iOS simulator |

The path `/OTMS1/backend` is appended to the guess. See
`lib/core/config/env.dart`.

### Backend: environment variables

Defaults match a stock XAMPP install, so nothing needs setting for local work.
Every value can be overridden so that no credentials live in the repository:

| Variable | Default | Purpose |
| --- | --- | --- |
| `OTMS_DB_HOST` | `127.0.0.1` | database host |
| `OTMS_DB_NAME` | `otms` | database name |
| `OTMS_DB_USER` | `root` | database user |
| `OTMS_DB_PASS` | *(empty)* | database password |
| `OTMS_ALLOWED_ORIGINS` | *(empty)* | extra CORS origins for the web client, comma separated |

Apache:

```apache
SetEnv OTMS_DB_PASS "your-password"
SetEnv OTMS_ALLOWED_ORIGINS "https://otms.example.com"
```

CLI server:

```bash
OTMS_DB_PASS="your-password" php -S 127.0.0.1:8080 -t .
```

Local web development needs no CORS configuration: any `localhost`,
`127.0.0.1`, `[::1]` or `10.0.2.2` origin is accepted, on any port.

---

## Tests

```bash
# Client: static analysis and widget/unit tests
cd otms_flutter
flutter analyze
flutter test

# Backend: API behaviour (40 checks)
bash tools/api_test.sh

# Backend: security regressions (31 checks)
bash tools/api_security_test.sh
```

Both backend scripts start their own PHP development server on a free port, so
Apache does not need to be running for them. They need the database from
`backend/schema.sql`, and they erase nothing — they create a throwaway class and
its contents each run.

On Windows run them from **Git Bash** (they are bash scripts). Change the port
with `PORT=8099 bash tools/api_test.sh`.

The same checks run on every push through
[GitHub Actions](.github/workflows/ci.yml).

---

## Troubleshooting

**`{"error":"Database unavailable."}` (HTTP 500)**
The API could not reach MySQL. Is MySQL started in the XAMPP Control Panel? If
you use a password for `root`, set it with `OTMS_DB_PASS` (see
[Configuration](#configuration)). The real error is written to the PHP error
log — `C:\xampp\apache\logs\error.log`.

**`{"error":"Table 'otms.login_attempts' doesn't exist"}` or sign-in fails**
Your database predates the login-throttling change. Run the migration:

```bat
C:\xampp\mysql\bin\mysql.exe -u root otms < C:\xampp\htdocs\OTMS1\backend\migrations\2026-09-15_login_attempts.sql
```

**The app shows "Could not reach the server at …"**
The message names the exact address it tried. Either the backend is not running,
or that address is not the one the device can reach. For web development pass
`--dart-define=OTMS_API_BASE=http://localhost/OTMS1/backend`; for a physical
phone use your LAN IP, not `localhost` — on a phone, `localhost` is the phone
itself.

**A CORS error in the browser console**
The origin was not allowlisted. `localhost`, `127.0.0.1` and `10.0.2.2` on any
port are allowed by default; anything else must be added to
`OTMS_ALLOWED_ORIGINS`.

**Blank page after copying the build into a subfolder**
The build was made without `--base-href`, so the app asks for `/main.dart.js`
instead of `/OTMS1/preview/main.dart.js`. Rebuild with
`flutter build web --debug --base-href=/OTMS1/preview/`.

**`'ln' is not recognized` / `'mklink' is not recognized`**
`ln` is a POSIX command and `mklink` is a cmd builtin that PowerShell cannot
call, and that needs Administrator rights for `/D`. Either use the
`--base-href` route in [Previewing in a browser](#previewing-in-a-browser-without-a-device),
or open cmd as Administrator.

**PowerShell complains about `<`**
PowerShell does not support input redirection with `<`, so `mysql … < file.sql`
fails there. Wrap it in `cmd /c "…"` or use phpMyAdmin's Import tab.

**Directory listing instead of the app at `http://localhost/OTMS1/`**
That is expected — `htdocs/OTMS1` is the project root, not the app. The API lives
under `backend/`, and the web build is whatever you deploy yourself (see below).

**Uploading a file returns 415**
The file type is not on the allowlist. PDF, Office documents, text, images,
audio/video and archives are accepted; scripts, executables and HTML/SVG are
not (see [Security notes](#security-notes)).

**500 errors on every request to `uploads/`**
`.htaccess` directives are only honoured when Apache allows them. XAMPP's
default (`AllowOverride All` for `htdocs`) works out of the box; a custom
`httpd.conf` may need adjusting.

---

## Project layout

```
.
├── backend/
│   ├── api/         39 endpoint scripts (login, classes, lessons, assessments, …)
│   ├── migrations/  incremental SQL for databases created before a change
│   ├── uploads/     runtime user uploads (not committed) + .htaccess guard
│   ├── config.php   PDO connection, environment driven
│   ├── cors.php     origin allowlist
│   ├── helpers.php  auth, role checks, upload handling, login throttling
│   ├── schema.sql   full schema + demo seed data
│   └── smoketest*.sh  legacy Windows-only smoke tests
├── otms_flutter/
│   ├── lib/
│   │   ├── app.dart      root widget, provider tree, auth gate
│   │   ├── main.dart     bootstrap only
│   │   ├── core/         API base URL configuration
│   │   ├── models/       data models mirroring the API JSON
│   │   ├── services/     ApiClient — the single HTTP layer
│   │   ├── state/        AuthProvider, ThemeProvider
│   │   └── screens/      auth / shared / student / teacher
│   └── test/             widget, network and auth tests
├── tools/          API and security test scripts
└── .github/        CI workflow
```

---

## Deploying

The backend is plain PHP, so it runs on any shared host with PHP 8 and MySQL:
create the database from `backend/schema.sql`, upload `backend/`, and set the
`OTMS_DB_*` variables. Then build the client against that server:

```bash
cd otms_flutter
flutter build apk --dart-define=OTMS_API_BASE=https://example.com/otms/backend
flutter build web --dart-define=OTMS_API_BASE=https://example.com/otms/backend
```

For the web build, `flutter build web --release` produces `build/web/`. Copy its
contents into a folder next to `backend/` and omit the flag entirely — the app
then talks to the origin it was served from.

---

## Security notes

Please read these before putting this anywhere public.

* **Uploads** are extension-allowlisted and capped at 8 MB, and
  `backend/uploads/.htaccess` disables script execution and directory listing.
  That file is Apache-only: on nginx, add the equivalent rules (there is a
  snippet inside it). Uploaded files are still readable by anyone who knows the
  URL — serving them through an authorised endpoint is the next step.
* **Change the database password** and stop using `root` for a public
  deployment; set `OTMS_DB_PASS` instead of editing code.
* **App permissions.** The manifest declares `android.permission.INTERNET` (the
  app is entirely API-driven; Flutter's template puts that permission only in the
  debug/profile manifests, which would have left a release build with no network
  at all) and `android:usesCleartextTraffic="true"` so it can reach a plain-HTTP
  development server. Drop the cleartext flag once the backend is HTTPS.
* **Sessions** are bearer tokens valid for 30 days. Sign-in is throttled to 10
  failed attempts per account per address per 15 minutes; delete a user's rows
  from `sessions` to revoke access.
* **CORS** is an allowlist, so a random website cannot drive the API from a
  visitor's browser.

---

## Known limitations

Structural debt in the client, deliberately left for a follow-up refactor:

* `teacher_dashboard.dart` and `student_dashboard.dart` share roughly 476 lines
  of near-identical code — stat cards, class cards, upcoming lists and a
  `_LiveTab` widget. These belong in `lib/screens/shared/`.
* `lib/screens/shared/sidebar.dart` (≈800 lines) mixes navigation, the user
  menu, the profile dialog and the change-password dialog.
* Navigation is inline `Navigator.push(MaterialPageRoute(...))` in 15 files with
  no central router, so routes cannot be tested or deep-linked.
* Only `AuthProvider` and `ThemeProvider` are shared; every other screen fetches
  its own data with `setState`, which duplicates loading and error handling and
  provides no caching.
* The client has no way to leave or delete a class from the sidebar; teachers
  delete classes from `teacher_home.dart` only.
