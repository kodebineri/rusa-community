import 'local_mongo_engine.dart';

/// The engine the UI reads from.
///
/// Defaults to the in-memory engine preloaded with the bundled sample datasets
/// and is swapped to a `RealMongoService` when the user connects to an actual
/// MongoDB server (and back on disconnect). Widgets must call `setState` after
/// mutating this so the tree rebuilds against the new engine.
LocalMongoEngine mongoEngine = LocalMongoEngine.instance;
