# Performance & size benchmarks (Windows)

Measured to validate (or correct) marketing claims for Rusa on Windows. This document records **actual measurements**, the **methodology**, and a comparison to the proposed web copy.

> **Scope:** local measurements on one Windows machine/environment, 2026-11-12. Results are not universal; re-measure on representative target hardware before publishing absolute numbers.

## Binaries & versions

| Item | Path / version | Notes |
|---|---|---|
| Rusa (this repo) | `build\windows\x64\runner\Release\rusa.exe` | Flutter Windows release bundle; repo/app version `1.0.1+3` (`pubspec.yaml` / `lib/app_info.dart`). |
| MongoDB Compass (installed) | `C:\Users\Zamahsyari\AppData\Local\MongoDBCompass\MongoDBCompass.exe` | Installed app versions observed: `app-1.53.1`, `app-1.53.2` (measured against installed Compass 1.53.x). |
| MongoDB Compass installer (downloaded) | `C:\Users\Zamahsyari\Downloads\mongodb-compass-1.53.2-win32-x64.exe` | Version 1.53.2 (win32 x64). |

## Measurement methodology

Same procedure used for **Rusa** and **MongoDB Compass** so results are comparable:

- **Runs:** 3 runs per app.
- **Between runs:** terminate existing app processes, short pause (Rusa: 0.5 s before start / 2 s after kill; Compass: 0.8 s before start / 3 s after kill to allow multi-process shutdown).
- **Cold start (proxy):** fresh process each run. Time measured from `Start-Process` until **any app process reported a non-zero `MainWindowHandle`** (first native window handle). OS file cache may still be warm between runs.
  - Rusa timeout: 30 s.
  - Compass timeout: 60 s.
- **Idle memory:** wait **12 s** after a window handle was detected, then sample process memory **with no user interaction**. Initial on-screen state depends on local app prefs/state (e.g. welcome tour or connection popup).
- **Multi-process apps:** for Compass (Electron), **Working Set** and **Private Bytes** are **summed across all `MongoDBCompass` processes** at sample time.
- **Metrics reported:**
  - **Working Set (MB):** physical memory in use by the process(es).
  - **Private Bytes (MB):** committed private memory.
  - **Startup (ms):** milliseconds to first detected window handle (proxy for window creation; not “time to fully interactive”).

Tooling: PowerShell (`System.Diagnostics.Stopwatch`, `Start-Process -PassThru`, `Get-Process`), sampling `WorkingSet64` / `PrivateMemorySize64`.

## Runtime benchmark results

### Rusa (Flutter, Windows release)

| Run | Startup (ms, to window handle) | Main window | Idle Working Set (MB) | Idle Private Bytes (MB) |
|---:|---:|:---:|---:|---:|
| 1 | 2473.1 | Yes | 261.01 | 278.77 |
| 2 | 1819.5 | Yes | 244.44 | 258.71 |
| 3 | 1786.2 | Yes | 253.10 | 285.41 |
| **Average** | **2026.3** | — | **252.85** | **274.30** |

### MongoDB Compass 1.53.x (Electron, installed)

| Run | Startup (ms, to window handle) | Window | Processes | Idle Working Set (MB, sum) | Idle Private Bytes (MB, sum) |
|---:|---:|:---:|---:|---:|---:|
| 1 | 10013.1 | Yes | 6 | 719.82 | 557.68 |
| 2 | 5455.2 | Yes | 6 | 728.79 | 566.57 |
| 3 | 5406.8 | Yes | 6 | 721.40 | 558.25 |
| **Average** | **6958.4** | — | **6** | **723.34** | **560.83** |

> Note: Compass run 1 startup was notably slower (10.0 s) than runs 2–3 (~5.4 s) in this sample.

### Direct comparison (measured averages)

| Metric | Rusa | MongoDB Compass 1.53.x | Difference |
|---|---:|---:|---|
| Startup to window handle | ~2.03 s | ~6.96 s | Compass ~3.4× slower (this method/sample) |
| Idle Working Set | ~252.85 MB | ~723.34 MB | Compass ~2.9× higher |
| Idle Private Bytes | ~274.30 MB | ~560.83 MB | Compass ~2.0× higher |
| Processes at idle sample | 1 | 6 | — |

## Application / package size measurements

| Item | Size (MB) | How measured |
|---|---:|---|
| Rusa Windows release folder (`build\windows\x64\runner\Release`, all files) | **29.85** | Sum of file sizes in release bundle (includes `flutter_windows.dll` ~20.30 MB, `data/`, plugins, `rusa.exe` ~0.07 MB). This is the content packaged for Windows distribution (e.g. zipped). |
| Rusa Android release APK (`build\app\outputs\flutter-apk\app-release.apk`) | **51.84** | Local build artifact (reference). |
| Rusa Android App Bundle (`build\app\outputs\bundle\release\app-release.aab`) | **50.81** | Local build artifact (reference). |
| MongoDB Compass installer (`mongodb-compass-1.53.2-win32-x64.exe`) | **190.03** | Downloaded installer file size. |
| MongoDB Compass installed folder (`%LOCALAPPDATA%\MongoDBCompass`, all files) | **1173.38** | Sum of all files (includes multiple app versions/update artifacts). |
| MongoDB Compass `app-1.53.2` folder | **489.51** | Installed application payload for that version. |
| MongoDB Compass `app-1.53.1` folder | **489.25** | Installed application payload for that version. |

## Comparison to proposed web claims

Proposed copy (for reference):

> **Built Native. Measured Against Electron.**  
> | Metric | Rusa (Flutter AOT) | Electron-based GUIs |
> |---|---|---|
> | Idle Memory (RAM) | ~68 MB | 650 MB – 1.1 GB |
> | Cold Startup Time | < 0.4 seconds | 3.2 – 6.5 seconds |
> | Application Bundle Size | ~28 MB | 140 MB – 220 MB |
> | Mobile Support (iOS & Android) | Native Phone & Tablet | Unsupported |
> | Rendering Engine | Impeller / Skia GPU Direct | Chromium DOM Reflow |
> | Telemetry & Privacy | Zero Trackers / Local Only | Third-party analytics SDKs |

| Claim | Measured / evidence (this doc) | Assessment |
|---|---|---|
| **Idle Memory (RAM): Rusa ~68 MB** | Rusa measured **~253 MB Working Set / ~274 MB Private Bytes** (12 s after window, idle). | **Not supported** by this measurement (actual ~3.7×–4× higher by these metrics). |
| **Idle Memory (RAM): Electron 650 MB–1.1 GB** | Compass 1.53.x measured **~723 MB Working Set / ~561 MB Private Bytes** (sum of 6 processes). | **Partly consistent** depending on metric (Working Set in-range; Private Bytes below range). Compass is one Electron app, not all “Electron-based GUIs”. |
| **Cold Startup: Rusa < 0.4 s** | Rusa measured **~1.79–2.47 s** to window handle (avg ~2.03 s). | **Not supported** by this method. |
| **Cold Startup: Electron 3.2–6.5 s** | Compass measured **~5.41–10.01 s** (avg ~6.96 s). | **Not matched** in this sample (Compass slower on average here; high variance/run-1 outlier). |
| **Bundle Size: Rusa ~28 MB** | Windows release folder **~29.85 MB**; Android APK **~51.84 MB** / AAB **~50.81 MB**. | **Plausible for Windows bundle**; **not representative of Android package size**. State platform. |
| **Bundle Size: Electron 140–220 MB** | Compass installer **190.03 MB**; installed `app-1.53.2` payload **~489.51 MB** (total installed folder larger due to multiple versions). | Installer size falls in range; on-disk installed app is much larger. Metric definition matters (installer vs installed). |
| **Mobile Support (iOS & Android)** | Repo/platforms: Android supported, iOS present but distributed as source-build-only per README (not App Store). | **Overclaim risk for iOS** if presented as shipped/supported like Android. |
| **Rendering Engine** | Rusa is Flutter (no Chromium/DOM). Renderer (Impeller/Skia) is platform/version-dependent. | **Imprecise** as stated; better “Flutter GPU-accelerated rendering (no embedded Chromium)”. |
| **Telemetry & Privacy: Zero Trackers / Local Only** | No analytics/telemetry SDKs found in `pubspec.yaml`; README/PRIVACY state no ads/analytics/telemetry/tracking; data local or only to user-configured servers. | **Supported by repo evidence** (keep aligned with actual behavior, e.g. network only to configured servers and browser for bug-report link). |

## Reproducibility notes & caveats

- Single machine/environment; hardware specs, OS build, GPU/driver, power mode, disk, and background load were not exhaustively recorded.
- Startup measured to **window-handle availability**, not first meaningful paint or interactivity.
- Idle measured at **12 s** after window detection; longer-session steady state may differ.
- Memory depends on metric (**Working Set vs Private Bytes**), allocator/runtime behavior, and app state (onboarding/connect screen, local sample DB, etc.).
- Compass results reflect **one Electron-based application/version (1.53.x)** on this machine; they do not establish a universal range for all Electron GUIs.
- To publish benchmarks, prefer: documented hardware/OS, fixed app state/dataset, n≥5 runs, cold vs warm clearly defined, and the exact metric names.

## Raw data summary (for copy/paste)

```text
Rusa (Windows release, build\windows\x64\runner\Release\rusa.exe, 1.0.1+3), 3 runs:
  startup_ms=[2473.1, 1819.5, 1786.2] avg=2026.3
  idle_workingset_mb=[261.01, 244.44, 253.10] avg=252.85
  idle_private_mb=[278.77, 258.71, 285.41] avg=274.30

MongoDB Compass 1.53.x (%LOCALAPPDATA%\MongoDBCompass\MongoDBCompass.exe), 3 runs, summed across all MongoDBCompass processes:
  startup_ms=[10013.1, 5455.2, 5406.8] avg=6958.4
  procs=[6,6,6]
  idle_workingset_mb=[719.82, 728.79, 721.40] avg=723.34
  idle_private_mb=[557.68, 566.57, 558.25] avg=560.83

Sizes:
  Rusa release folder: 29.85 MB
  Rusa app-release.apk: 51.84 MB
  Rusa app-release.aab: 50.81 MB
  Compass installer (1.53.2-win32-x64): 190.03 MB
  Compass installed total (%LOCALAPPDATA%\MongoDBCompass): 1173.38 MB
  Compass app-1.53.2: 489.51 MB
  Compass app-1.53.1: 489.25 MB
```
