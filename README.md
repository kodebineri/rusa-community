# Rusa

**Rusa — a MongoDB database client, for desktop and mobile.**

[![Linux packages](https://github.com/kodebineri/rusa-community/actions/workflows/build-linux-packages.yml/badge.svg)](https://github.com/kodebineri/rusa-community/actions/workflows/build-linux-packages.yml)
[![Windows build](https://github.com/kodebineri/rusa-community/actions/workflows/build-windows.yml/badge.svg)](https://github.com/kodebineri/rusa-community/actions/workflows/build-windows.yml)

Rusa is an independent, open-source GUI client for MongoDB, built with
[Flutter](https://flutter.dev). Browse and edit documents, build aggregation
pipelines, analyse schemas, manage indexes, and run a mongosh-style shell —
from a Linux or Windows desktop, an Android phone, or a tablet.

Out of the box, Rusa runs fully offline against a built-in local database
engine seeded with sample data, so you can explore every feature without a
server. When you are ready for live data, connect with a standard
`mongodb://` or `mongodb+srv://` URI — self-hosted deployments, replica sets,
and MongoDB Atlas are all supported.

**Private by design:** no account, no ads, no analytics, no telemetry. Saved
connection profiles are kept in your device's encrypted platform storage
(libsecret on Linux, DPAPI on Windows, Keystore on Android), and your data
only ever travels between your device and the server you point it at.

Rusa is free software under the **GPL-3.0** licence.

---

## Contents

- [About Rusa](#about-rusa) — features and platform support
- [Installing](#installing) — Linux (APT / pacman / DNF), Windows, Android, iOS, and from source
- [Verifying packages](#verifying-packages) — the repository signing key
- [Documentation](#documentation)
- [Licence and trademark](#licence-and-trademark)

## About Rusa

### Features

**Connect**

- `mongodb://` and `mongodb+srv://` connection strings
- Self-hosted MongoDB, replica sets, and MongoDB Atlas
- Save connection profiles in encrypted platform storage and reuse them after
  a restart

**Browse and query**

- Databases and collections in a searchable sidebar
- Documents as a tree, formatted JSON, or a table
- Filter, project, sort, skip, and limit — queries only run when you press
  **Find**, so large result sets are never fetched by accident

**Aggregation pipelines**

- Visual pipeline builder with raw JSON editing
- `$match`, `$group`, `$sort`, `$project`, `$limit`, `$skip`, `$unwind`,
  `$count`, and `$lookup` stages
- Stage presets, enable/disable toggles, and paginated previews
- Save a pipeline as a view

**Schema and indexes**

- Schema analysis: field types, distributions, distinct counts, missing
  values, min/max
- Create and drop indexes, including unique indexes
- The protected `_id_` index is clearly marked

**Documents and data**

- Insert, edit, clone, and delete documents
- Import and export JSON and CSV — clipboard or file
- Inspect a view's DDL, update the view, or copy its pipeline to Aggregations

**Shell**

- mongosh-style terminal with command history and Tab completion
- Destructive operations ask for confirmation before they run

**Look and feel**

- Eight themes across dark and light palettes (Rain Forest Night, Dracula,
  Tokyo Night, Night Owl, and their light variants)
- Responsive layouts for desktop, tablet, and phone, with finger-sized touch
  targets

### Platform support

| Platform | Status | How to get it |
| --- | --- | --- |
| Linux — Debian, Ubuntu, Mint… | Supported | APT repository or `.deb` (see below) |
| Linux — Arch Linux | Supported | pacman repository or `.pkg.tar.zst` (see below) |
| Linux — Fedora, RHEL, CentOS… | Supported | DNF repository or `.rpm` (see below) |
| Windows 10/11 (x64) | Supported | Portable `.zip` from [releases] |
| Windows 11 (Arm64) | Supported | Portable `.zip` from [releases] |
| Android 7.0+ | Supported | Google Play (in preparation) or build an APK |
| iOS | Source builds only | Build with Flutter + Xcode (needs macOS) |
| macOS | Not supported | — |

All Linux repositories publish both `x86_64`/`amd64` and `aarch64`/`arm64`
builds. Every release is also attached to the [releases page][releases] as
plain `.deb`, `.pkg.tar.zst`, and `.rpm` files if you prefer one-off
downloads.

[releases]: https://github.com/kodebineri/rusa-community/releases/latest

## Installing

All Linux packages are published to a single signed repository at
<https://kodebineri.github.io/rusa-community/>, and install the package
`rusa-community`. After installing, launch **Rusa Community** from your
application menu, or run `rusa` in a terminal (the `rusa-community` command
is also available).

### Debian, Ubuntu, Mint… (APT)

```bash
# 1. Install the repository signing key
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://kodebineri.github.io/rusa-community/KEY.gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/rusa-community.gpg

# 2. Add the repository
echo "deb [signed-by=/etc/apt/keyrings/rusa-community.gpg] https://kodebineri.github.io/rusa-community/apt/ stable main" \
  | sudo tee /etc/apt/sources.list.d/rusa-community.list

# 3. Install
sudo apt update
sudo apt install rusa-community
```

> **Note for early adopters:** the very first `.deb` release (`v1.0.0-1`)
> shipped a broken launcher symlink. If you have it installed, remove it
> (`sudo apt remove rusa-community`) before following the steps above.

### Arch Linux (pacman)

```bash
# 1. Add the repository to /etc/pacman.conf
sudo tee -a /etc/pacman.conf <<'EOF'

[rusa]
Server = https://kodebineri.github.io/rusa-community/arch/$arch
EOF

# 2. Trust the signing key
curl -fsSLO https://kodebineri.github.io/rusa-community/arch/KEY.gpg
sudo pacman-key --add KEY.gpg
sudo pacman-key --lsign-key 278621A8B4A4EDFD
rm KEY.gpg

# 3. Install
sudo pacman -Syu rusa-community
```

The repository database is named `rusa.db`, so the `pacman.conf` section is
`[rusa]` even though the package is `rusa-community`.

To install without adding the repository, download the `.pkg.tar.zst` for
your architecture from the [releases page][releases] and run
`sudo pacman -U <file>`.

### Fedora, RHEL, CentOS… (DNF)

```bash
# Fedora 41+ / CentOS Stream 10
sudo dnf config-manager addrepo \
  --from-repofile=https://kodebineri.github.io/rusa-community/rpm/rusa-community.repo

# Fedora 40 and older / RHEL 8–9
sudo dnf config-manager --add-repo \
  https://kodebineri.github.io/rusa-community/rpm/rusa-community.repo

sudo dnf install rusa-community
```

The `.repo` file enables both package and repository metadata signature
checks, so `dnf` verifies everything automatically.

### Windows

1. Download `rusa-community_<version>_windows_x64.zip` (Intel/AMD) or
   `rusa-community_<version>_windows_arm64.zip` (Snapdragon / Copilot+ PCs)
   from the [latest release][releases].
2. Extract it anywhere (for example `C:\Tools\Rusa`) — Rusa is fully
   portable: no installer, no admin rights, no registry entries.
3. Run `rusa.exe`.

### Android

Rusa runs on Android 7.0 (API 24) or later. A Google Play listing is in
preparation; until it is live you can sideload an APK built from source:

```bash
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

### iOS

Rusa is not yet distributed on the App Store, but the iOS platform is part of
the source tree. With a Mac running Xcode:

```bash
flutter pub get
open ios/Runner.xcworkspace   # then pick your signing team and run
```

### Any OS — build from source

Requirements: the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(3.24 or newer) and the platform toolchains (Visual Studio + Windows SDK on
Windows, or the packages below on Linux).

```bash
git clone https://github.com/kodebineri/rusa-community.git
cd rusa-community
flutter pub get
flutter run                 # first available device
flutter run -d windows      # or: -d linux, -d <android-device-id>
```

Linux build prerequisites (Debian/Ubuntu package names):

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev
```

Release builds:

```bash
flutter build linux --release      # → build/linux/*/release/bundle/
flutter build windows --release    # → build/windows/x64/runner/Release/ (or arm64)
flutter build apk --release        # → build/app/outputs/flutter-apk/
flutter build appbundle --release  # → build/app/outputs/bundle/release/
```

The Windows target architecture follows the host: an Arm64 build needs an
Arm64 Windows machine **and** a Flutter SDK checked out from git rather than the
stable archive (Flutter does not publish a Windows Arm64 SDK archive yet; the
tool then downloads the Arm64 Dart SDK itself). See the `arm64` leg of
`.github/workflows/build-windows.yml` for the exact CI steps.

Contributions should keep `flutter analyze` clean and `flutter test` green.

## Verifying packages

Everything published to the package repositories is signed with one GPG key:

```text
fingerprint: 5095 052B 9918 4D54 6C18 096E 2786 21A8 B4A4 EDFD
key id:      278621A8B4A4EDFD
uid:         Rusa Community <kodebineri@gmail.com>
```

The public key is available at
<https://kodebineri.github.io/rusa-community/KEY.gpg>.

- **APT** — the `Release` files are signed; the key is installed by the
  `signed-by` step above.
- **pacman** — the database and packages carry detached signatures.
- **RPM** — packages and `repomd.xml` are signed, and the `.repo` file
  enables `gpgcheck` and `repo_gpgcheck`.

## Documentation

| Document | Contents |
| --- | --- |
| [`docs/architecture.md`](docs/architecture.md) | App shell, state, navigation, modal orchestration |
| [`docs/engine.md`](docs/engine.md) | Query/aggregation engine, models, connecting |
| [`docs/ui.md`](docs/ui.md) | Widgets, themes, icons |
| [`docs/testing.md`](docs/testing.md) | Test suite and patterns |

The in-app end-user licence agreement ([`EULA.md`](EULA.md)) and privacy policy
([`PRIVACY.md`](PRIVACY.md)) also live in this repository.

## Licence and trademark

Rusa is © Kodebineri Software and licensed under the
[GNU General Public License v3](LICENSE).

Rusa is an independent, unofficial client. It is not affiliated with,
endorsed by, or sponsored by MongoDB, Inc. "MongoDB" is a trademark of
MongoDB, Inc., used here only to describe compatibility. Rusa does not use
the MongoDB leaf logo.

Bugs and feedback: <https://github.com/kodebineri/rusa-community/issues>.
