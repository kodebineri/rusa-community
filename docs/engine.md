# Engine & Data Layer — `lib/services/*`, `lib/models/*`

Companion to root `AGENTS.md`. Covers the in-memory Mongo engine, seed data, query and
aggregation semantics, the models, and the real-server service. Line numbers are approximate
anchors and drift as files change.

## The global (`lib/services/mongo_engine.dart`, 9 lines)

```dart
LocalMongoEngine mongoEngine = LocalMongoEngine.instance;
```

A **mutable top-level global** — the only way widgets access data. Defaults to the seeded
in-memory engine; swapped to a `RealMongoService` on connect and back on disconnect (always
inside `setState`). Every view/modal imports this file. Reads must stay **synchronous**
(`build()` calls `findDocuments` directly).

## `LocalMongoEngine` (`lib/services/local_mongo_engine.dart`, ~1123 lines)

- `class LocalMongoEngine` — mirrors the React `mongoEngine` synchronous API.
- Singleton: `static final LocalMongoEngine instance = LocalMongoEngine.seeded();`
  (`factory LocalMongoEngine.seeded() => LocalMongoEngine()..seedSampleData();`)
- State: public `List<MongoDatabase> databases` (mutated in place — **collection document
  lists are live references**, so holding `coll.documents` across a mutation is valid).

### Full public API

| Method | Signature | Notes |
|---|---|---|
| `seedSampleData` | `void ()` | (L35) loads the Dart-literal seed; overwrites `databases` |
| `getDatabases` | `List<MongoDatabase> ()` | raw list |
| `getDatabase` | `MongoDatabase? (String name)` | null if missing |
| `getCollection` | `MongoCollection? (String dbName, String collName)` | null if missing |
| `findDocuments` | `QueryResult (db, coll, QueryFilterOptions)` | filter→sort→skip/limit→project; never throws |
| `distinct` | `List<dynamic> (db, coll, field, filter)` | unique values of `field` across matching docs (used by the shell's `distinct`); reads the mirror, so it works for the local engine and a connected server |
| `analyzeSchema` | `List<SchemaFieldStat> (db, coll)` | `[]` if missing/empty |
| `resetToDefaults` | `void ()` | just calls `seedSampleData()` (real service overrides to re-load from server) |
| `generateObjectId` | `String ()` | 24-char lowercase hex: epoch-seconds hex + 16 random hex chars, then `.substring(0, 24)` (timestamp is 8 chars, so the tail is effectively 16 random chars — verified at L379–383) |
| `createDatabase` | `bool (String dbName, [String initialCollName = 'users'])` | false if exists; seeds 1 sample doc + `_id_` index |
| `dropDatabase` | `bool (String)` | |
| `createCollection` | `bool (db, coll)` | false if db missing/name exists; adds `_id_` index |
| `createView` | `bool (db, viewName, sourceColl, List pipeline)` | **throws** on validation errors (see below) |
| `dropCollection` | `bool (db, coll)` | |
| `renameDatabase` | `bool (old, new)` | **throws** on invalid/duplicate names |
| `renameCollection` | `bool (db, old, new)` | **throws**; rebuilds map in order; retargets views |
| `insertDocument` | `MongoDocument (db, coll, Map doc)` | unique checks, **inserts at index 0** |
| `updateDocument` | `bool (db, coll, String docId, Map updatedFields)` | `$set`/`$inc`/`$unset` (first match wins) or **full replace**; throws on views |
| `deleteDocument` | `bool (db, coll, String docId)` | throws on views |
| `deleteMany` / `deleteOne` | by filter | missing coll/view → 0/false (no throw) |
| `updateMany` | by filter + update | missing coll/view → 0; plain map = **replace each matched doc**, operator map = merge |
| `createIndex` | `bool (db, coll, MongoIndex)` | false on name collision; random `sizeKb` 16–55 |
| `dropIndex` | `bool (db, coll, String indexName)` | false for `_id_` (protected) |
| `saveValidator` | `bool (db, coll, Map? validator, String level, String action)` | |
| `tolerantParse` | `dynamic (String jsonStr)` | lenient JSON (unquoted keys, `'`→`"`); may throw on second decode — callers try/catch |
| `runAggregation` | `QueryResult (db, coll, List pipeline)` | Stopwatch-timed; **rethrows** stage errors |
| `parseAggregationScript` | `List (String script)` | strips `db.x.aggregate([…]);` wrapper, then tolerantParse |

### Critical behaviors

- **Insert order:** `coll.documents.insert(0, newDoc)` — newest first. Seed docs keep
  literal order (first-listed = index 0).
- **`_id`:** `newMap['_id'] = doc['_id'] ?? generateObjectId()` — clones already carry a
  fresh id from `main.dart`.
- **Unique-index enforcement (insert only, never on update):** for each `unique` index, a
  conflict requires **every** index key non-null in *both* docs and `==` equal (nulls never
  conflict → implicit sparse). Enforced for `_id_`, `isbn_1` (books), `username_1`/`email_1`
  (users). Exact thrown message (single line):
  ```
  Exception: E11000 duplicate key error collection: <db>.<coll> index: <indexName>
  ```
  e.g. `Exception: E11000 duplicate key error collection: library.books index: isbn_1`.
  The `Exception: ` prefix comes from `'$err'` stringification in `main.dart`.
- **Views are read-only:** `isView == true` → `insertDocument`/`updateDocument`/
  `deleteDocument` throw `Cannot insert/update/delete document: "<name>" is a read-only
  MongoDB view.`; `deleteMany`/`deleteOne`/`updateMany` silently return 0/false.
  `createView` **materializes once** (pipeline runs immediately; docs snapshot, no live
  re-evaluation). `createView` throws on: missing DB, empty name, name containing `$` or
  starting with `.`, name already existing, missing source collection.
- **Rename validation:** DB name cannot match `[/\\. "$*<>:|?]` or be ≥64 chars; collection
  names cannot contain `$` or start with `system.`.
- **Update operators (`_applyUpdate`, shared by `updateDocument` and `updateMany`):** all
  present operators apply, in order `$set` → `$unset` → `$inc` → `$push` (supports
  `{ $each: [...] }`) → `$pull`. A map with **no** operator key is a **full replacement**
  (`{...update, '_id': <existing>}`): any field omitted is **removed**, and `_id` is always
  preserved. (Plain maps therefore mean replacement, matching MongoDB.) `updateMany` applies
  the same helper to every matched document.

### Line map of `local_mongo_engine.dart`

| Lines | Section |
|---|---|
| 13–26 | class, singleton, ctors |
| **35–224** | `seedSampleData()` (books 36–59, publishers 61–76, genres 78–94, users 96–121, posts 123–140, comments 142–157, assembly 159–223) |
| 226–239 | getters |
| 241–297 | `findDocuments` |
| 299–358 | `analyzeSchema` |
| 361–369 | `_jsonTypeOf` |
| 371–383 | `resetToDefaults`, `generateObjectId` |
| 385–526 | create/drop/rename db & coll, `createView` |
| 528–558 | `insertDocument` (view check, `_id`, unique checks 538–553, insert(0) 556) |
| 560–650 | `updateDocument`, deletes, `updateMany` |
| 652–689 | indexes, validator |
| 691–707 | `tolerantParse` |
| 709–744 | `runAggregation`, `parseAggregationScript` |
| 746–848 | `_runPipeline`, `_applyStage` |
| 850–920 | `_applyGroup` |
| 922–1018 | `_matchesFilter` |
| 1020–1061 | `_applyProjection`, `_sortDocs` |
| 1063–1123 | `_asNum`, `_compare`, `_resolvePath`, `_setPath`, `_unsetPath` |

## Seed data (2 databases, 6 collections, 13 documents)

**DB `library`**

| Coll | Docs | Indexes |
|---|---|---|
| `books` | 2 — *The Silent Horizon* (`60c72b2f9b1d8b0015f8a001`, isbn `978-3-16-148410-0`), *Algorithms of the Mind* (`…a002`, isbn `978-1-23-456789-7`) | `_id_` unique, **`isbn_1` unique**, `title_text` (text), `publisher_id_1` |
| `publishers` | 2 — Apex Academic Press, Vanguard Publishing House (`…a010`, `…a011`) | `_id_` unique, `name_1` (not unique) |
| `genres` | 3 — Science Fiction, Mystery, Technology (`…a020`–`…a022`) | `_id_` unique, `name_1` |

books fields: `_id, title, author, isbn, published_year, publisher_id, genre_ids[],
copies_available, rating`; publishers: `_id, name, city, country, founded_year`;
genres: `_id, name, description`. Cross-references: `publisher_id` → publishers,
`genre_ids` → genres.

**DB `social_networks`**

| Coll | Docs | Indexes |
|---|---|---|
| `users` | 2 — `coder_sam`, `design_maya` (`…a030`, `…a031`) | `_id_` unique, **`username_1` unique**, **`email_1` unique** |
| `posts` | 2 (`…a040`, `…a041`) | `_id_` unique, `author_id_1`, `tags_1` |
| `comments` | 2 (`…a050`, `…a051`) | `_id_` unique, `post_id_1`, `author_id_1` |

users fields: `_id, username, email, profile{display_name,bio,location}, followers_count,
created_at`; posts: `_id, author_id, content, tags[], likes_count, created_at`;
comments: `_id, post_id, author_id, text, created_at`.

**JSON ⇄ Dart mirroring (invariant 3):** `sample_library.json` feeds `library`,
`sample_social_network.json` feeds `social_networks`. The JSON files use extended JSON
(`{"$oid": …}`, `{"$date": …}`) and are **not loaded at runtime** — Dart literals in
`seedSampleData()` are a hand-mirrored copy (normalization: `$oid` → 24-hex string,
`$date` → ISO-8601 with `.000Z` millis appended). Edit both or neither.
`resetToDefaults()` re-runs the literals.

## Query semantics (`findDocuments`, L241–297)

`QueryFilterOptions` (`lib/models/mongo_models.dart` L107): mutable
`filter, project, sort` (strings), `collation?, maxTimeMS?` (stored, **never consumed**),
`skip = 0`, `limit = 20`, plus `copyWith(...)`.

- Pipeline order: **filter → sort → skip/limit → project**. `totalCount` = post-filter count
  (before pagination). `executionTimeMs` is the constant `0.8`.
- Each of filter/project/sort parses inside its own try/catch — **invalid JSON anywhere
  yields an empty result, never a thrown error** (must never blow up a build).
- `tolerantParse`: quotes bare keys after `{`/`,`, swaps `'`→`"` (known limitation:
  apostrophes inside strings corrupt the JSON), then `jsonDecode` with a second fallback
  decode that *can* throw (callers wrap).

**`_matchesFilter` operators** (L922–1018):
- Logical (top-level): `$and`, `$or`, `$nor` (list values only).
- Field-level: `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte` (null/incomparable → fails),
  `$in`/`$nin` (list-aware: if doc value is a List → intersection semantics), `$exists`,
  `$regex` (options from sibling `$options`, **default case-insensitive `'i'`**),
  `$size`.
- Plain equality: doc value List → `list.contains(expected)` (Mongo array match).
- Unknown operators silently ignored. Dotted paths via `_resolvePath` (maps + numeric
  list indices).

**Sort** (`_sortDocs`): multi-key, `1`/`-1`; **nulls always sort last** regardless of
direction; non-comparable pairs treated as 0.

**Projection** (`_applyProjection`): exclusive mode iff any value is `0`; `_id` kept by
default, dropped only on explicit `_id: 0`; exclusive mode removes listed top-level keys;
inclusive copies dotted paths with value `1`.

## Aggregation (L709–920)

- `runAggregation(db, coll, pipeline)` → deep-copies input, times with `Stopwatch`,
  `totalCount = results.length`; missing collection → empty result; **stage errors
  rethrow**.
- `parseAggregationScript` strips an optional `db.<coll>.aggregate([ … ]);` wrapper; a bare
  Map is wrapped as `[map]`.
- `_applyStage` dispatches on the first `$…` key. **Supported stages:**
  `$lookup` (same-DB equality join on `from/localField/foreignField/as`, default
  `as: 'joined'`), `$match`, `$project`, `$sort`, `$limit`, `$skip`, `$count`,
  `$addFields` (literal or `$field` shallow paths), `$unwind` (string or
  `{path, preserveNullAndEmptyArrays}`), `$group`.
- `$group` accumulators: `$sum` (literal → count×literal, or `$field`), `$avg`, `$min`,
  `$max`, `$push`, `$first`. **Not supported (silently ignored):** `$last`, `$addToSet`,
  `$stdDev*`. Grouping `_id` expression: `"$field"`, `null`, or literal Map (jsonEncode'd).
- **Unknown stages fall through `default:` and pass docs through unchanged** (no error).

Consumer: `AggregationsView` (visual mode builds a `List` from enabled `PipelineStage`s;
raw mode uses `parseAggregationScript`).

## `analyzeSchema` output (L299–358)

Returns `List<SchemaFieldStat>` — one entry per distinct **top-level** field, first-seen
order; nested objects count as a single `Object` type (no flattening). Per field:
- `name`/`path` (same top-level key), `types: List<SchemaFieldTypeStat>` (`{type, count,
  percentage}`), types from `_jsonTypeOf`: `String | Int32 | Double | Boolean | Array |
  Object | Null`, `_id` forced to `ObjectId`. Percentages are integer floors over **all**
  docs.
- `totalValues`, `missingCount`, `missingPercentage`, `distinctCount` (jsonEncode-based
  Set), `sampleValues` (first 3), `min`/`max` (numeric only, else null).

## Models (`lib/models/mongo_models.dart`)

| Class | Fields |
|---|---|
| `MongoDocument` | `final String id` (from `_id?.toString() ?? 'unknown'`), `final Map<String,dynamic> data`, `fromMap`, `toMap()`, `operator []` |
| `MongoIndex` | `final String name`, `final Map<String,dynamic> keys`, `final bool unique` (false), `final bool sparse` (false), `final int sizeKb` (16), `fromMap` |
| `MongoCollection` | `final String name`; **mutable** `List<MongoDocument> documents`; `List<MongoIndex> indexes`; `Map? validator`; `validationLevel='moderate'`; `validationAction='error'`; `bool isView=false`; `String? viewOn`; `List? pipeline` |
| `MongoDatabase` | `final String name`; mutable `Map<String, MongoCollection> collections` |
| `ConnectionProfile` | `id, name, uri, color?, favorite, lastConnected?, readOnly` |
| `QueryFilterOptions` | see above |
| `QueryResult` | `final List<MongoDocument> documents`, `final int totalCount`, `final double executionTimeMs` |
| `PipelineStage` | `final String id`, `String operator`, `String content`, `bool enabled=true`, `copyWith` |
| `SchemaFieldTypeStat` | `type, count, percentage` |
| `SchemaFieldStat` | `name, path, types, totalValues, missingCount, missingPercentage, distinctCount, sampleValues, min, max` |

(There is no `IndexDefinition` or `SchemaInfo` class.)

`lib/models/collection_tab.dart`: `CollectionTab { dbName, collName,
activeSection='documents', docViewMode='tree', queryOptions, isSameTarget(db, coll) }` —
the per-tab UI state restored on tab switch.

## `RealMongoService` (`lib/services/real_mongo_service.dart`, ~957 lines) — production path

- `class RealMongoService extends LocalMongoEngine` — that inheritance is why assigning it to
  the `mongoEngine` global type-checks.
- **Mirror architecture:** on connect it mirrors server → the inherited in-memory `databases`
  list so `build()` can read synchronously. Mutations run `super.*` first (updates the
  mirror) then are **fire-and-forget replayed** to the server (`_fire*`; errors → `lastError`
  + `onError`; `onDataChanged` callback triggers background `setState`).
- API: `static Future<void> test(String uri)` (quick open+ping, no mirroring),
  `static Future<RealMongoService> connect(String uri)`, `Future<void> reloadFast()`,
  `Future<void> _loadAllDataInBackground()`, `Future<void> loadCollectionData(db, coll)`,
  `Future<void> reload()`, `Future<void> dispose()`. Cap:
  **`maxDocsPerCollection = 5000`** (was 20000).
- **Connect is two-phase:** `connect` does `Db.create → open (20 s) → reloadFast (20 s)`,
  throwing on bad URI/unreachable/auth. `reloadFast` lists databases and creates *empty*
  `MongoDatabase` entries immediately (UI tree appears fast), then `_loadAllDataInBackground`
  fills collections/docs/indexes and calls `onDataChanged`. `loadCollectionData` lazily loads
  one collection (10 s docs / 8 s indexes).
- `reload()` (full, synchronous-style): listDatabases → per-db `getCollectionInfos`, skips
  `system.*`, detects views (`type == 'view'`), loads docs + indexes.
- Overrides every mutation (insert/update/delete/index/db/coll/view/validator) plus
  `resetToDefaults` (**reloads from server instead of re-seeding**) and `analyzeSchema`
  (uses `_bsonTypeName`: `Date`, `Boolean`, runtime fallback; percentages over present
  values; up to 4 samples). `updateDocument` replays a **plain map** with `replaceOne`
  (so removed fields are deleted on the server too) and an operator map with `updateOne` +
  `_toServerUpdate`. `updateMany` does the same: a plain map replays one `replaceOne` per
  matched document (ids captured before the mirror is mutated), an operator map one
  `updateMany`.
- Value conversion: `ObjectId → .oid` hex string, `DateTime → ISO-8601 string`,
  `Uint8List → base64`, Int64/Decimal → int-or-string; back via `ObjectId.tryParse(hex) ??
  hex`; plain update maps wrapped in `$set`. `_ensureDbPath` defaults empty path to `/test`.
- Wired in `main.dart`: `_realService` field, `_handleConnectProfile` (connect + swap
  global), disconnect/reset handlers, read-only gating. **Not experimental.**
