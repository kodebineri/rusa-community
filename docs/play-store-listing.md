# Google Play listing — Rusa

Ready-to-paste store metadata. Character limits are shown next to each field.

## App name (max 30)

```text
Rusa: MongoDB Client
```

20 characters. Fallback if review questions the trademark in the title:

```text
Rusa: Database Client
```

21 characters. Keep the MongoDB disclaimer in the full description either way.

## Short description (max 80)

```text
Explore MongoDB databases: browse, query, aggregate, manage indexes.
```

68 characters.

## Full description (max 4000; this copy is 2432 characters)

```text
Rusa is an independent MongoDB client for Android, built for developers who want to inspect and work with their databases from a phone or tablet.

Try it immediately with bundled sample data — no server or account required.

CONNECT
• Connect with mongodb:// or mongodb+srv:// connection strings
• Works with self-hosted MongoDB, replica sets, and MongoDB Atlas
• Save connection profiles on your device and reuse them after a restart

BROWSE AND QUERY
• Browse databases and collections in a collapsible sidebar
• View documents as a tree, formatted JSON, or a table
• Filter, project, sort, skip, and limit results
• Run queries explicitly with Find, so large result sets are never fetched by accident

AGGREGATION PIPELINES
• Build pipelines visually or edit raw JSON
• Add and reorder stages: $match, $group, $sort, $project, $limit, $skip, $unwind, $count, and $lookup
• Start from presets, enable or disable stages, and preview paginated results
• Save a pipeline as a view

SCHEMA AND INDEXES
• Analyze collection schemas with field types, distributions, and sample values
• Inspect distinct counts, missing values, and min/max values
• Create and drop indexes, including unique indexes
• Protected _id_ index is clearly marked

DOCUMENTS, IMPORTS, AND VIEWS
• Insert, edit, clone, and delete documents
• Import and export JSON
• Inspect a view's DDL, update the view, or copy its pipeline to Aggregations

SHELL
• mongosh-style terminal with command history and Tab completion
• Confirm destructive operations before they run

MADE FOR SMALL SCREENS
• Responsive phone and tablet layouts with finger-sized controls
• Tree, JSON, and table document views
• Eight themes across dark and light palettes, including Rain Forest Night, Dracula, Tokyo Night, and Monokai

PRIVATE BY DESIGN
• No account, ads, analytics, or telemetry
• Credentials and database contents stay between your device and the server you choose
• Bundled sample data contains no personal information
• Saved connection profiles stay in encrypted platform storage on your device, never on our servers

ABOUT
Rusa is an independent, unofficial client. It is not affiliated with, endorsed by, or sponsored by MongoDB, Inc. "MongoDB" is a trademark of MongoDB, Inc., used only to describe compatibility.

Rusa requires Android 7.0 or later. A MongoDB server is required for live connections. Sample datasets are included so you can explore the app without one.
```

## What's new (max 500; this copy is 442 characters)

```text
Initial release.
• Connect to MongoDB and Atlas with mongodb:// or mongodb+srv://
• Browse documents as tree, JSON, or table
• Build aggregation pipelines visually or in raw JSON
• Analyze schemas and manage indexes
• Insert, edit, clone, and delete documents
• Import and export JSON
• mongosh-style shell with history and Tab completion
• Eight themes and responsive phone/tablet layouts
• Bundled sample data — no server required to try it
```

## Store settings

| Setting | Value |
|---|---|
| App name | `Rusa: MongoDB Client` (20 / 30) |
| Short description | `Explore MongoDB databases: browse, query, aggregate, manage indexes.` (68 / 80) |
| Category | **Tools** (alternative: Productivity) |
| Tags | Developer tools, Database, Productivity |
| Contact email | *your support address* — Play requires a monitored address |
| Privacy policy URL | *public URL for `PRIVACY.md`* — Play requires a reachable HTTPS page |
| Website | Optional: `https://github.com/kodebineri/rusa-community` |
| Ads | No |
| In-app purchases | No |
| Target audience | **18+** (developer tool; keeps it out of Families) |
| Content rating | Complete the questionnaire; expect **Everyone** |
| App access | No account. Reviewers can use the bundled sample data; live connections need a MongoDB URI |
| Data safety | No data collected or shared; saved profiles stay on-device in encrypted platform storage; no analytics or telemetry. Credentials go only to the server the user configures |
| Government app | No |
| News app | No |

### App access instructions for reviewers

```text
No account or login is required.

1. Open the app. The first-run welcome screen explains the bundled sample data.
2. Choose the sample data to explore library and social_networks offline.
3. To test a live connection, open Connect and enter a MongoDB URI
   (mongodb:// or mongodb+srv://). No credentials are bundled.
4. All main screens — documents, aggregations, schema, and indexes — work
   against the bundled sample data without a server.
```

## Graphic assets

| Asset | Requirement |
|---|---|
| App icon | 512 × 512 PNG, 32-bit, ≤ 1 MB |
| Feature graphic | 1024 × 500 PNG or JPEG, no alpha |
| Phone screenshots | 2–8 images, 16:9 or 9:16, shortest side ≥ 320 px, longest side ≤ 3840 px |
| 7-inch tablet screenshots | Recommended (the touch layout is tested) |
| 10-inch tablet screenshots | Recommended |
| Promo video | Optional YouTube URL, 30 s–2 min |

Suggested screenshot captions, in order:

1. Your databases, on your phone
2. Tree, JSON, and table views
3. Build pipelines visually
4. Understand schemas at a glance
5. Create and manage indexes
6. A shell in your pocket
7. Light and dark themes
8. Sample data included

## Before uploading

- **Replace the release signing config.** `android/app/build.gradle.kts` still signs
  `release` with the debug key (`TODO` comment). Create a release keystore, keep it out of
  Git, and configure `signingConfigs.release` before building.
- Bump `version:` in `pubspec.yaml` (`1.0.1+2` → `1.0.1+3`, or a new version name). Play
  rejects a duplicate version code.
- Build the bundle with `flutter build appbundle --release`, then upload
  `build/app/outputs/bundle/release/app-release.aab`.
- Confirm the current Play target-API requirement against the Flutter SDK's
  `targetSdkVersion`; update the Flutter/Android toolchain if needed.
- Host `PRIVACY.md` at a stable public HTTPS URL and use that exact URL in Play Console.
- Make the Data safety answers match `PRIVACY.md`: no collection, no sharing, no analytics,
  no ads, no account.
- Upload the 512 × 512 Play icon separately — `flutter_launcher_icons` only generates the
  in-app launcher assets.
- Start with an **Internal testing** track, install from the Play link, and verify the
  first-run tour, connection flow, and the phone/tablet layouts before promoting to
  production.
- Verify the package name stays `com.kodebineri.rusa`; it cannot change after the first
  upload.
- Do not use the MongoDB leaf logo or imply endorsement. The word "MongoDB" is used
  descriptively only.
