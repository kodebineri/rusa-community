import 'mongo_models.dart';

/// A single open collection tab in the main pane (mirrors MongoDB Compass's
/// tabbed workspace: every collection selected in the sidebar opens in its own
/// tab). Besides the collection it points at, a tab remembers the UI state
/// (section tab, document view mode and query) that is restored whenever the
/// tab is re-activated — switching back to a tab feels exactly like leaving it.
class CollectionTab {
  String dbName;
  String collName;

  /// Section tab: documents, aggregations, schema, indexes.
  String activeSection;

  /// Document view mode: tree, json, table.
  String docViewMode;

  /// Filter/sort/paging for the documents section of this collection.
  QueryFilterOptions queryOptions;

  CollectionTab({
    required this.dbName,
    required this.collName,
    this.activeSection = 'documents',
    this.docViewMode = 'tree',
    QueryFilterOptions? queryOptions,
  }) : queryOptions = queryOptions ?? QueryFilterOptions();

  /// Whether this tab points at `dbName`.`collName`.
  bool isSameTarget(String dbName, String collName) =>
      this.dbName == dbName && this.collName == collName;
}
