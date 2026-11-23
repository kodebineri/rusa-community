/// Helpers for the MongoDB connection string shown in the connect dialog.
library;

/// Returns [uri] with `authSource=<authDatabase>` added, or [uri] unchanged
/// when that would be meaningless or destructive:
///
/// * [authDatabase] is blank (the user cleared the field — MongoDB then uses
///   the database in the URI path, or `admin` when there is none).
/// * the URI has no credentials (`user:pass@`) — there is nothing to scope.
/// * the URI already names an `authSource` (case-insensitive) — the explicit
///   value wins, so pasted connection strings are never overridden.
///
/// Safe to call twice: the second call is a no-op.
String appendAuthSource(String uri, String authDatabase) {
  final trimmed = uri.trim();
  final db = authDatabase.trim();
  if (trimmed.isEmpty || db.isEmpty) return trimmed;
  if (!_hasCredentials(trimmed)) return trimmed;
  if (_hasAuthSource(trimmed)) return trimmed;

  final encoded = Uri.encodeComponent(db);
  final hash = trimmed.indexOf('#');
  final base = hash >= 0 ? trimmed.substring(0, hash) : trimmed;
  final fragment = hash >= 0 ? trimmed.substring(hash) : '';

  final queryIndex = base.indexOf('?');
  if (queryIndex < 0) return '$base?authSource=$encoded$fragment';

  final query = base.substring(queryIndex + 1);
  final separator = query.isEmpty || query.endsWith('&') ? '' : '&';
  return '${base.substring(0, queryIndex + 1)}$query$separator'
      'authSource=$encoded$fragment';
}

/// Reads the `authSource` value out of [uri], or `null` when it is absent.
/// Used to pre-fill the Authentication Database field when editing a profile.
String? authSourceFromUri(String uri) {
  final queryIndex = uri.indexOf('?');
  if (queryIndex < 0) return null;

  final hash = uri.indexOf('#');
  final query = uri.substring(
    queryIndex + 1,
    hash >= 0 && hash > queryIndex ? hash : uri.length,
  );
  for (final pair in query.split('&')) {
    final equals = pair.indexOf('=');
    if (equals < 0) continue;
    if (pair.substring(0, equals).toLowerCase() != 'authsource') continue;
    final value = Uri.decodeComponent(pair.substring(equals + 1)).trim();
    return value.isEmpty ? null : value;
  }
  return null;
}

bool _hasAuthSource(String uri) => authSourceFromUri(uri) != null;

/// True when the authority section carries `user[:pass]@`.
bool _hasCredentials(String uri) {
  final schemeEnd = uri.indexOf('://');
  if (schemeEnd < 0) return false;

  final authorityStart = schemeEnd + 3;
  var authorityEnd = uri.length;
  for (final separator in const ['/', '?', '#']) {
    final index = uri.indexOf(separator, authorityStart);
    if (index >= 0 && index < authorityEnd) authorityEnd = index;
  }
  return uri.substring(authorityStart, authorityEnd).contains('@');
}